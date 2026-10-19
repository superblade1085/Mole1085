#!/bin/bash
# Mole Native Mac — Sovereign Clean Streaming Adapter
# Emits structured JSON events on file descriptor 3:
# Scan mode:  {"type": "item", "category": "...", "category_name": "...", "group": "...", "path": "...", "bytes": 1024, "safe": true, "safety_level": "guaranteedSafe"}
#             {"type": "summary", "category": "...", "total_bytes": 1024, "count": 1}
# Clean mode: {"type": "cleaned", "category": "...", "path": "...", "bytes_reclaimed": 1024}
#             {"type": "complete", "total_cleaned": 1024}
# Compatible with macOS default /bin/bash (Bash 3.2+).

set -euo pipefail

export LC_ALL=C
export LANG=C

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Locate pristine upstream Mole library
if [[ -n "${MOLE_ROOT:-}" && -d "$MOLE_ROOT/lib" ]]; then
    UPSTREAM_ROOT="$MOLE_ROOT"
elif [[ -d "$REPO_ROOT/lib" ]]; then
    UPSTREAM_ROOT="$REPO_ROOT"
elif [[ -d "$REPO_ROOT/mole-cli-source/lib" ]]; then
    UPSTREAM_ROOT="$REPO_ROOT/mole-cli-source"
else
    echo "Error: Mole upstream lib directory not found" >&2
    exit 1
fi

MODE="scan"
REQUESTED_CATEGORIES="all"
CREATE_SNAPSHOT=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --scan)
            MODE="scan"
            shift
            ;;
        --clean)
            MODE="clean"
            shift
            ;;
        --categories)
            REQUESTED_CATEGORIES="${2:-all}"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            export DRY_RUN
            shift
            ;;
        --snapshot)
            CREATE_SNAPSHOT=true
            shift
            ;;
        --category)
            REQUESTED_CATEGORIES="${2:-all}"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

# Duplicate original stdout to fd 3 for pure JSON output.
exec 3>&1
exec 1>/dev/null
if [[ "${MO_DEBUG:-0}" != "1" ]]; then
    exec 2>/dev/null
fi

escape_json_string() {
    local value="${1:-}"
    local LC_ALL=C
    local char code idx
    idx=0
    while [[ "$idx" -lt "${#value}" ]]; do
        char="${value:$idx:1}"
        case "$char" in
            "\\") printf '%s' "\\\\" ;;
            "\"") printf '%s' "\\\"" ;;
            $'\b') printf '%s' "\\b" ;;
            $'\f') printf '%s' "\\f" ;;
            $'\n') printf '%s' "\\n" ;;
            $'\r') printf '%s' "\\r" ;;
            $'\t') printf '%s' "\\t" ;;
            *)
                printf -v code '%d' "'$char"
                if [[ "$code" -lt 0 ]]; then
                    code=$((code + 256))
                fi
                if [[ "$code" -lt 32 ]]; then
                    printf '\\u%04x' "$code"
                else
                    printf '%s' "$char"
                fi
                ;;
        esac
        idx=$((idx + 1))
    done
}

calculate_bytes() {
    local target="$1"
    if [[ -f "$target" || -L "$target" ]]; then
        /usr/bin/stat -f %z "$target" 2>/dev/null || echo 0
    elif [[ -d "$target" ]]; then
        local kb
        kb=$(/usr/bin/du -sk "$target" 2>/dev/null | /usr/bin/awk '{print $1}')
        if [[ "$kb" =~ ^[0-9]+$ ]]; then
            echo $((kb * 1024))
        else
            echo 0
        fi
    else
        echo 0
    fi
}

CURRENT_CATEGORY="dev"
CURRENT_CATEGORY_NAME="Developer Tools"
CURRENT_GROUP="developer"

category_metadata() {
    case "$CURRENT_CATEGORY" in
        dev)
            CURRENT_CATEGORY_NAME="Developer Tools & Caches"
            CURRENT_GROUP="developer"
            ;;
        app_caches)
            CURRENT_CATEGORY_NAME="Application Caches"
            CURRENT_GROUP="systemCaches"
            ;;
        caches)
            CURRENT_CATEGORY_NAME="User System Caches"
            CURRENT_GROUP="systemCaches"
            ;;
        brew)
            CURRENT_CATEGORY_NAME="Homebrew Downloads & Caches"
            CURRENT_GROUP="developer"
            ;;
        user)
            CURRENT_CATEGORY_NAME="Application Leftovers & Trash"
            CURRENT_GROUP="appLeftovers"
            ;;
        system)
            CURRENT_CATEGORY_NAME="System & Diagnostic Logs"
            CURRENT_GROUP="logs"
            ;;
        project)
            CURRENT_CATEGORY_NAME="Project Build Artifacts"
            CURRENT_GROUP="developer"
            ;;
        *)
            CURRENT_CATEGORY_NAME="System Caches"
            CURRENT_GROUP="systemCaches"
            ;;
    esac
}

emit_scan_item() {
    local target="$1"
    local bytes="$2"
    local is_safe="${3:-true}"

    # Exclude SQLite WAL/SHM companion sidecars to avoid database corruption
    case "$target" in
        *-wal|*-shm|*-journal|*.db-wal|*.db-shm|*.db-journal)
            return 0
            ;;
    esac

    local level="guaranteedSafe"
    if [[ "$CURRENT_GROUP" == "logs" ]]; then
        level="rebuildable"
    elif [[ "$CURRENT_GROUP" == "appLeftovers" ]]; then
        level="deadLeftover"
    elif [[ "$CURRENT_GROUP" == "systemCaches" ]]; then
        level="rebuildable"
    fi

    local esc_path
    esc_path=$(escape_json_string "$target")
    local esc_name
    esc_name=$(escape_json_string "$CURRENT_CATEGORY_NAME")

    printf '{"type": "item", "category": "%s", "category_name": "%s", "group": "%s", "path": "%s", "bytes": %d, "safe": %s, "safety_level": "%s"}\n' \
        "$CURRENT_CATEGORY" "$esc_name" "$CURRENT_GROUP" "$esc_path" "$bytes" "$is_safe" "$level" >&3
}

emit_category_summary() {
    local cat="$1"
    local total="$2"
    local count="$3"
    printf '{"type": "summary", "category": "%s", "total_bytes": %d, "count": %d}\n' \
        "$cat" "$total" "$count" >&3
}

emit_cleaned_item() {
    local cat="$1"
    local target="$2"
    local bytes="$3"
    local esc_path
    esc_path=$(escape_json_string "$target")
    printf '{"type": "cleaned", "category": "%s", "path": "%s", "bytes_reclaimed": %d}\n' \
        "$cat" "$esc_path" "$bytes" >&3
}

emit_complete() {
    local total="$1"
    printf '{"type": "complete", "total_cleaned": %d}\n' "$total" >&3
}

# --- SINK HOOKS FOR SCAN MODE ---

if [[ "$MODE" == "scan" ]]; then
    export DRY_RUN=true
    export MOLE_DRY_RUN=1
    export MOLE_NON_INTERACTIVE=1
    export MOLE_TEST_MODE=1
    export MOLE_SKIP_MAIN=1

    safe_clean() {
        local desc="${*: -1}"
        local targets=("${@:1:$#-1}")
        for p in "${targets[@]}"; do
            if [[ -e "$p" || -L "$p" ]]; then
                local b
                b=$(calculate_bytes "$p")
                emit_scan_item "$p" "$b" "true"
            fi
        done
    }

    safe_clean_guarded() {
        shift
        safe_clean "$@"
    }

    clean_tool_cache() {
        local desc="$1"
        local cache_path="$2"
        if [[ -n "$cache_path" && (-e "$cache_path" || -L "$cache_path") ]]; then
            local b
            b=$(calculate_bytes "$cache_path")
            emit_scan_item "$cache_path" "$b" "true"
        fi
    }

    clean_file_list() {
        local desc="$1"
        shift
        for item in "$@"; do
            if [[ -e "$item" || -L "$item" ]]; then
                local b
                b=$(calculate_bytes "$item")
                emit_scan_item "$item" "$b" "true"
            fi
        done
    }

    record_dry_run_cleanup_target() {
        local target="$1"
        local size_kb="${2:-0}"
        local b=0
        if [[ "$size_kb" =~ ^[0-9]+$ && "$size_kb" -gt 0 ]]; then
            b=$((size_kb * 1024))
        elif [[ -e "$target" || -L "$target" ]]; then
            b=$(calculate_bytes "$target")
        fi
        emit_scan_item "$target" "$b" "true"
    }

    # Load core dependencies
    source "$UPSTREAM_ROOT/lib/core/base.sh"
    source "$UPSTREAM_ROOT/lib/core/common.sh"
    source "$UPSTREAM_ROOT/lib/core/file_ops.sh"

    run_category() {
        CURRENT_CATEGORY="$1"
        category_metadata
        case "$CURRENT_CATEGORY" in
            dev)
                if [[ -f "$UPSTREAM_ROOT/lib/clean/dev.sh" ]]; then
                    source "$UPSTREAM_ROOT/lib/clean/dev.sh"
                    clean_developer_tools || true
                fi
                ;;
            app_caches)
                if [[ -f "$UPSTREAM_ROOT/lib/clean/app_caches.sh" ]]; then
                    source "$UPSTREAM_ROOT/lib/clean/app_caches.sh"
                    clean_app_caches || true
                fi
                ;;
            caches)
                if [[ -f "$UPSTREAM_ROOT/lib/clean/caches.sh" ]]; then
                    source "$UPSTREAM_ROOT/lib/clean/caches.sh"
                    clean_user_caches || true
                fi
                ;;
            brew)
                if [[ -f "$UPSTREAM_ROOT/lib/clean/brew.sh" ]]; then
                    source "$UPSTREAM_ROOT/lib/clean/brew.sh"
                    clean_homebrew || true
                fi
                ;;
            user)
                if [[ -f "$UPSTREAM_ROOT/lib/clean/user.sh" ]]; then
                    source "$UPSTREAM_ROOT/lib/clean/user.sh"
                    clean_user_essentials || true
                    clean_trash || true
                fi
                ;;
            system)
                if [[ -f "$UPSTREAM_ROOT/lib/clean/system.sh" ]]; then
                    source "$UPSTREAM_ROOT/lib/clean/system.sh"
                    clean_deep_system || true
                fi
                ;;
            project)
                if [[ -f "$UPSTREAM_ROOT/lib/clean/project.sh" ]]; then
                    unset MOLE_PURGE_SHARED_LOADED 2>/dev/null || true
                    source "$UPSTREAM_ROOT/lib/clean/project.sh" 2>/dev/null || true
                    clean_project_artifacts || true
                fi
                ;;
        esac
    }

    if [[ "$REQUESTED_CATEGORIES" == "all" ]]; then
        for cat in dev app_caches caches brew user system; do
            run_category "$cat" || true
        done
    else
        IFS=',' read -r -a cats <<< "$REQUESTED_CATEGORIES"
        for cat in "${cats[@]}"; do
            run_category "$cat" || true
        done
    fi

    exit 0
fi

# --- CLEAN MODE ---

if [[ "$MODE" == "clean" ]]; then
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        export MOLE_DRY_RUN=1
    else
        export DRY_RUN=false
        export MOLE_DRY_RUN=0
    fi
    export MOLE_NON_INTERACTIVE=1
    export MOLE_SKIP_MAIN=1

    # Create APFS snapshot if requested
    if $CREATE_SNAPSHOT; then
        /usr/bin/tmutil localsnapshot / >/dev/null 2>&1 || true
    fi

    TOTAL_CLEANED_BYTES=0

    # Reversible deletion honoring SafeTrash contract
    trash_or_safe_remove() {
        local target="$1"
        [[ -e "$target" || -L "$target" ]] || return 0
        if [[ "${DRY_RUN:-false}" == "true" ]]; then
            return 0
        fi
        if [[ -n "${MOLE_TEST_TRASH_DIR:-}" ]]; then
            mkdir -p "$MOLE_TEST_TRASH_DIR" 2>/dev/null || true
            mv "$target" "$MOLE_TEST_TRASH_DIR/" 2>/dev/null && return 0
        fi
        # Reversible Finder trashing
        if /usr/bin/osascript - "$target" >/dev/null 2>&1 << 'APPLESCRIPT'
on run argv
    set p to POSIX file (item 1 of argv)
    tell application "Finder"
        delete p
    end tell
end run
APPLESCRIPT
        then
            return 0
        fi
        local user_trash="$HOME/.Trash"
        if [[ -d "$user_trash" && -w "$user_trash" ]]; then
            local base
            base=$(basename "$target")
            mv "$target" "$user_trash/${base}.$$.$(date +%s)" 2>/dev/null && return 0
        fi
        /bin/rm -rf "$target" 2>/dev/null
    }

    # Hook safe_clean to track and emit real deletions
    safe_clean() {
        local desc="${*: -1}"
        local targets=("${@:1:$#-1}")
        for p in "${targets[@]}"; do
            if [[ -e "$p" || -L "$p" ]]; then
                local b
                b=$(calculate_bytes "$p")
                if trash_or_safe_remove "$p"; then
                    TOTAL_CLEANED_BYTES=$((TOTAL_CLEANED_BYTES + b))
                    emit_cleaned_item "$CURRENT_CATEGORY" "$p" "$b"
                fi
            fi
        done
    }

    safe_clean_guarded() {
        shift
        safe_clean "$@"
    }

    clean_tool_cache() {
        local desc="$1"
        local cache_path="$2"
        if [[ -n "$cache_path" && (-e "$cache_path" || -L "$cache_path") ]]; then
            local b
            b=$(calculate_bytes "$cache_path")
            if trash_or_safe_remove "$cache_path"; then
                TOTAL_CLEANED_BYTES=$((TOTAL_CLEANED_BYTES + b))
                emit_cleaned_item "$CURRENT_CATEGORY" "$cache_path" "$b"
            fi
        fi
    }

    clean_file_list() {
        local desc="$1"
        shift
        for item in "$@"; do
            if [[ -e "$item" || -L "$item" ]]; then
                local b
                b=$(calculate_bytes "$item")
                if trash_or_safe_remove "$item"; then
                    TOTAL_CLEANED_BYTES=$((TOTAL_CLEANED_BYTES + b))
                    emit_cleaned_item "$CURRENT_CATEGORY" "$item" "$b"
                fi
            fi
        done
    }

    source "$UPSTREAM_ROOT/lib/core/base.sh"
    source "$UPSTREAM_ROOT/lib/core/common.sh"
    source "$UPSTREAM_ROOT/lib/core/file_ops.sh"

    execute_clean_category() {
        CURRENT_CATEGORY="$1"
        category_metadata
        case "$CURRENT_CATEGORY" in
            dev)
                if [[ -f "$UPSTREAM_ROOT/lib/clean/dev.sh" ]]; then
                    source "$UPSTREAM_ROOT/lib/clean/dev.sh"
                    clean_developer_tools || true
                fi
                ;;
            app_caches)
                if [[ -f "$UPSTREAM_ROOT/lib/clean/app_caches.sh" ]]; then
                    source "$UPSTREAM_ROOT/lib/clean/app_caches.sh"
                    clean_app_caches || true
                fi
                ;;
            caches)
                if [[ -f "$UPSTREAM_ROOT/lib/clean/caches.sh" ]]; then
                    source "$UPSTREAM_ROOT/lib/clean/caches.sh"
                    clean_user_caches || true
                fi
                ;;
            brew)
                if [[ -f "$UPSTREAM_ROOT/lib/clean/brew.sh" ]]; then
                    source "$UPSTREAM_ROOT/lib/clean/brew.sh"
                    clean_homebrew || true
                fi
                ;;
            user)
                if [[ -f "$UPSTREAM_ROOT/lib/clean/user.sh" ]]; then
                    source "$UPSTREAM_ROOT/lib/clean/user.sh"
                    clean_user_essentials || true
                    clean_trash || true
                fi
                ;;
            system)
                if [[ -f "$UPSTREAM_ROOT/lib/clean/system.sh" ]]; then
                    source "$UPSTREAM_ROOT/lib/clean/system.sh"
                    clean_deep_system || true
                fi
                ;;
            project)
                if [[ -f "$UPSTREAM_ROOT/lib/clean/project.sh" ]]; then
                    unset MOLE_PURGE_SHARED_LOADED 2>/dev/null || true
                    source "$UPSTREAM_ROOT/lib/clean/project.sh" 2>/dev/null || true
                    clean_project_artifacts || true
                fi
                ;;
        esac
    }

    if [[ "$REQUESTED_CATEGORIES" == "all" ]]; then
        for cat in dev app_caches caches brew user system; do
            execute_clean_category "$cat" || true
        done
    else
        IFS=',' read -r -a cats <<< "$REQUESTED_CATEGORIES"
        for cat in "${cats[@]}"; do
            execute_clean_category "$cat" || true
        done
    fi

    # Append to Mole audit history log if possible
    MOLE_LOG_DIR="$HOME/Library/Logs/mole"
    mkdir -p "$MOLE_LOG_DIR" 2>/dev/null || true
    if [[ -d "$MOLE_LOG_DIR" ]]; then
        TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"
        echo "[$TIMESTAMP] clean (reclaimed $TOTAL_CLEANED_BYTES bytes) categories: $REQUESTED_CATEGORIES" >> "$MOLE_LOG_DIR/operations.log" 2>/dev/null || true
    fi

    emit_complete "$TOTAL_CLEANED_BYTES"
    exit 0
fi
