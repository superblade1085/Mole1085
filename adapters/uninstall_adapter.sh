#!/bin/bash
# Mole Native Mac — Sovereign Software Hunter & Uninstaller Adapter
# Wraps upstream bin/uninstall.sh and lib/core/app_protection.sh
# Emits structured JSON for application list, leftover items, and removal.
# Compatible with macOS default /bin/bash (Bash 3.2+).

set -euo pipefail

export LC_ALL=C
export LANG=C

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Locate engine root
if [[ -n "${MOLE_ROOT:-}" && -d "$MOLE_ROOT" ]]; then
    ENGINE_ROOT="$MOLE_ROOT"
elif [[ -d "$REPO_ROOT/bin" ]]; then
    ENGINE_ROOT="$REPO_ROOT"
else
    ENGINE_ROOT="$REPO_ROOT"
fi

MODE="list"
BUNDLE_ID=""
APP_NAME=""
APP_PATH=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --list)
            MODE="list"
            shift
            ;;
        --leftovers)
            MODE="leftovers"
            BUNDLE_ID="${2:-}"
            APP_NAME="${3:-}"
            APP_PATH="${4:-}"
            shift
            [[ $# -gt 0 ]] && shift
            [[ $# -gt 0 ]] && shift
            [[ $# -gt 0 ]] && shift
            ;;
        --uninstall)
            MODE="uninstall"
            APP_PATH="${2:-}"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

escape_json() {
    local str="$1"
    str="${str//\\/\\\\}"
    str="${str//\"/\\\"}"
    str="${str//$'\t'/\\t}"
    str="${str//$'\r'/\\r}"
    str="${str//$'\n'/\\n}"
    printf '%s' "$str"
}

calculate_bytes() {
    local target="$1"
    if [[ -f "$target" || -L "$target" ]]; then
        /usr/bin/stat -f %z "$target" 2>/dev/null || echo 0
    elif [[ -d "$target" ]]; then
        local kb
        kb=$(/usr/bin/du -sk "$target" 2>/dev/null | /usr/bin/awk '{print $1}' || true)
        if [[ "$kb" =~ ^[0-9]+$ ]]; then
            echo $((kb * 1024))
        else
            echo 0
        fi
    else
        echo 0
    fi
}

classify_leftover_type() {
    local path="$1"
    case "$path" in
        *"/Caches/"*)
            echo "cache"
            ;;
        *"/Application Support/"*)
            echo "applicationSupport"
            ;;
        *"/Preferences/"*)
            echo "preference"
            ;;
        *"/Containers/"*|*"/Group Containers/"*)
            echo "container"
            ;;
        *"/WebKit/"*|*"/HTTPStorages/"*)
            echo "cache"
            ;;
        *"/Saved Application State/"*)
            echo "state"
            ;;
        *"/Logs/"*|*"/DiagnosticReports/"*)
            echo "log"
            ;;
        *)
            echo "other"
            ;;
    esac
}

# --- MODE: LIST ---
if [[ "$MODE" == "list" ]]; then
    # bin/uninstall.sh --list emits pure JSON when stdout is not a TTY
    if [[ -x "$ENGINE_ROOT/bin/uninstall.sh" ]]; then
        exec "$ENGINE_ROOT/bin/uninstall.sh" --list 2>/dev/null
    else
        echo "[]"
        exit 0
    fi
fi

# --- MODE: LEFTOVERS ---
if [[ "$MODE" == "leftovers" ]]; then
    source "$ENGINE_ROOT/lib/core/common.sh" 2>/dev/null || true
    source "$ENGINE_ROOT/lib/core/app_protection.sh" 2>/dev/null || true

    if ! command -v find_app_files >/dev/null 2>&1; then
        echo "[]"
        exit 0
    fi

    # Run upstream leftover discovery
    RAW_PATHS=$(find_app_files "$BUNDLE_ID" "$APP_NAME" "$APP_PATH" 2>/dev/null || true)

    FIRST=true
    printf '[\n'
    while IFS= read -r p; do
        [[ -z "$p" ]] && continue
        [[ ! -e "$p" && ! -L "$p" ]] && continue

        # Don't list the main app bundle itself as a leftover
        if [[ -n "$APP_PATH" && "$p" == "$APP_PATH" ]]; then
            continue
        fi

        b=$(calculate_bytes "$p")
        item_type=$(classify_leftover_type "$p")

        entry=$(cat <<EOF
  {
    "path": "$(escape_json "$p")",
    "size": $b,
    "type": "$item_type"
  }
EOF
)
        if $FIRST; then
            printf '%s' "$entry"
            FIRST=false
        else
            printf ',\n%s' "$entry"
        fi
    done <<< "$RAW_PATHS"
    printf '\n]\n'
    exit 0
fi

# --- MODE: UNINSTALL ---
if [[ "$MODE" == "uninstall" ]]; then
    if [[ -z "$APP_PATH" || (! -d "$APP_PATH" && ! -e "$APP_PATH") ]]; then
        echo '{"status": "error", "message": "App path does not exist"}'
        exit 1
    fi

    # Source upstream core for safe deletion and logging
    source "$ENGINE_ROOT/lib/core/common.sh" 2>/dev/null || true
    source "$ENGINE_ROOT/lib/core/app_protection.sh" 2>/dev/null || true

    APP_BUNDLE_ID=""
    if [[ -f "$APP_PATH/Contents/Info.plist" ]]; then
        APP_BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$APP_PATH/Contents/Info.plist" 2>/dev/null || echo "")
    fi
    APP_BASE_NAME="$(basename "$APP_PATH" .app)"

    TOTAL_RECLAIMED=0
    APP_SIZE=$(calculate_bytes "$APP_PATH")

    # Reversible deletion honoring SafeTrash contract
    trash_or_safe_remove() {
        local target="$1"
        [[ -e "$target" || -L "$target" ]] || return 0
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

    # Discover and remove leftovers
    if command -v find_app_files >/dev/null 2>&1; then
        LEFTOVERS=$(find_app_files "$APP_BUNDLE_ID" "$APP_BASE_NAME" "$APP_PATH" 2>/dev/null || true)
        while IFS= read -r lp; do
            [[ -z "$lp" ]] && continue
            if [[ -e "$lp" || -L "$lp" ]]; then
                lb=$(calculate_bytes "$lp")
                if trash_or_safe_remove "$lp"; then
                    TOTAL_RECLAIMED=$((TOTAL_RECLAIMED + lb))
                fi
            fi
        done <<< "$LEFTOVERS"
    fi

    # Remove app bundle itself via safe system trash or rm
    if trash_or_safe_remove "$APP_PATH"; then
        TOTAL_RECLAIMED=$((TOTAL_RECLAIMED + APP_SIZE))
    fi

    # Record in Mole audit log
    MOLE_LOG_DIR="$HOME/Library/Logs/mole"
    mkdir -p "$MOLE_LOG_DIR" 2>/dev/null || true
    if [[ -d "$MOLE_LOG_DIR" ]]; then
        TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"
        echo "[$TIMESTAMP] uninstall (reclaimed $TOTAL_RECLAIMED bytes) app: $APP_PATH bundle: $APP_BUNDLE_ID" >> "$MOLE_LOG_DIR/operations.log" 2>/dev/null || true
    fi

    cat <<EOF
{
  "status": "success",
  "app_path": "$(escape_json "$APP_PATH")",
  "bundle_id": "$(escape_json "$APP_BUNDLE_ID")",
  "reclaimed_bytes": $TOTAL_RECLAIMED
}
EOF
    exit 0
fi
