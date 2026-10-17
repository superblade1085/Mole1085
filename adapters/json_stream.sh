#!/bin/bash
# Mole Native Mac — Pristine CLI JSON Streaming Adapter
# Emits structured JSON events: {"category": "...", "path": "...", "bytes": 1024, "safe": true}
# Strictly read-only / dry-run: never modifies or deletes files on disk.
# Compatible with macOS default /bin/bash (Bash 3.2+).

set -euo pipefail

export LC_ALL=C
export LANG=C

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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

# Parse command line arguments
REQUESTED_CATEGORY="all"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --category)
            REQUESTED_CATEGORY="${2:-all}"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [dev|caches|app_caches|brew|user|system|project|all]"
            exit 0
            ;;
        dev|caches|app_caches|brew|user|system|project|all)
            REQUESTED_CATEGORY="$1"
            shift
            ;;
        *)
            shift
            ;;
    esac
done

# Set strict dry-run / non-interactive environment flags
export DRY_RUN=true
export MOLE_DRY_RUN=1
export MOLE_NON_INTERACTIVE=1
export MOLE_TEST_MODE=1
export MOLE_SKIP_MAIN=1

# Duplicate original stdout to fd 3 for pure JSON output.
# Redirect standard stdout & stderr to /dev/null to silence upstream logs, spinners, and echoes.
exec 3>&1
exec 1>/dev/null
exec 2>/dev/null

# Track emitted paths to prevent duplicate JSON events (Bash 3.2 compatible delimiter string)
SEEN_PATHS=""
CURRENT_CATEGORY="dev"

emit_json_event() {
    local cat="$1"
    local raw_path="$2"
    local bytes="$3"
    local is_safe="$4"

    [[ -n "$raw_path" ]] || return 0
    case "$SEEN_PATHS" in
        *"|$raw_path|"*) return 0 ;;
    esac
    SEEN_PATHS="${SEEN_PATHS}|$raw_path|"

    # Escape JSON special characters in path
    local escaped_path
    escaped_path=$(printf '%s' "$raw_path" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')

    printf '{"category": "%s", "path": "%s", "bytes": %d, "safe": %s}\n' \
        "$cat" "$escaped_path" "$bytes" "$is_safe" >&3
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

is_path_safe_for_clean() {
    local target="$1"
    if declare -f should_protect_path >/dev/null 2>&1; then
        if should_protect_path "$target"; then
            echo "false"
            return 0
        fi
    fi
    if declare -f is_path_whitelisted >/dev/null 2>&1; then
        if is_path_whitelisted "$target"; then
            echo "false"
            return 0
        fi
    fi
    echo "true"
}

# Override upstream sinks to stream JSON events without deleting
record_dry_run_cleanup_target() {
    local target="$1"
    local size_kb="${2:-0}"
    local bytes=0

    if [[ "$size_kb" =~ ^[0-9]+$ && "$size_kb" -gt 0 ]]; then
        bytes=$((size_kb * 1024))
    elif [[ -e "$target" || -L "$target" ]]; then
        bytes=$(calculate_bytes "$target")
    fi

    local safe
    safe=$(is_path_safe_for_clean "$target")
    emit_json_event "$CURRENT_CATEGORY" "$target" "$bytes" "$safe"
}

safe_clean() {
    local desc="${*: -1}"
    local targets=("${@:1:$#-1}")
    for p in "${targets[@]}"; do
        if [[ -e "$p" || -L "$p" ]]; then
            local bytes
            bytes=$(calculate_bytes "$p")
            local safe
            safe=$(is_path_safe_for_clean "$p")
            emit_json_event "$CURRENT_CATEGORY" "$p" "$bytes" "$safe"
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
        local bytes
        bytes=$(calculate_bytes "$cache_path")
        local safe
        safe=$(is_path_safe_for_clean "$cache_path")
        emit_json_event "$CURRENT_CATEGORY" "$cache_path" "$bytes" "$safe"
    fi
}

# Dummy stubs for upstream UI functions
start_section() { :; }
end_section() { :; }
start_section_spinner() { :; }
stop_section_spinner() { :; }
note_activity() { :; }
debug_log() { :; }
log_operation() { :; }
log_warning() { :; }
log_warning_to_file() { :; }
_run_developer_cleanup_step() { "$@" || true; }
_run_cleanup_step() { "$@" || true; }

# Source common upstream library
source "$UPSTREAM_ROOT/lib/core/common.sh"
if [[ -f "$UPSTREAM_ROOT/lib/clean/purge_shared.sh" ]]; then
    source "$UPSTREAM_ROOT/lib/clean/purge_shared.sh"
fi

# Runners for individual categories
run_category_dev() {
    CURRENT_CATEGORY="dev"
    if [[ -f "$UPSTREAM_ROOT/lib/clean/app_caches.sh" ]]; then
        source "$UPSTREAM_ROOT/lib/clean/app_caches.sh"
    fi
    if [[ -f "$UPSTREAM_ROOT/lib/clean/dev.sh" ]]; then
        source "$UPSTREAM_ROOT/lib/clean/dev.sh"
        clean_developer_tools || true
    fi
}

run_category_app_caches() {
    CURRENT_CATEGORY="app_caches"
    if [[ -f "$UPSTREAM_ROOT/lib/clean/app_caches.sh" ]]; then
        source "$UPSTREAM_ROOT/lib/clean/app_caches.sh"
        clean_xcode_tools || true
        clean_code_editors || true
        clean_communication_apps || true
        clean_user_gui_applications || true
    fi
}

run_category_caches() {
    CURRENT_CATEGORY="caches"
    if [[ -f "$UPSTREAM_ROOT/lib/clean/caches.sh" ]]; then
        source "$UPSTREAM_ROOT/lib/clean/caches.sh"
        if declare -f clean_caches >/dev/null 2>&1; then
            clean_caches || true
        fi
    fi
}

run_category_brew() {
    CURRENT_CATEGORY="brew"
    if [[ -f "$UPSTREAM_ROOT/lib/clean/brew.sh" ]]; then
        source "$UPSTREAM_ROOT/lib/clean/brew.sh"
        clean_homebrew || true
        clean_homebrew_service_logs || true
    fi
}

run_category_user() {
    CURRENT_CATEGORY="user"
    if [[ -f "$UPSTREAM_ROOT/lib/clean/user.sh" ]]; then
        source "$UPSTREAM_ROOT/lib/clean/user.sh"
        clean_user_essentials || true
        clean_trash || true
    fi
}

run_category_system() {
    CURRENT_CATEGORY="system"
    if [[ -f "$UPSTREAM_ROOT/lib/clean/system.sh" ]]; then
        source "$UPSTREAM_ROOT/lib/clean/system.sh"
        if declare -f clean_system >/dev/null 2>&1; then
            clean_system || true
        fi
    fi
}

run_category_project() {
    CURRENT_CATEGORY="project"
    if [[ -f "$UPSTREAM_ROOT/lib/clean/project.sh" ]]; then
        source "$UPSTREAM_ROOT/lib/clean/project.sh"
        if declare -f clean_project_caches >/dev/null 2>&1; then
            clean_project_caches || true
        fi
    fi
}

# Dispatch category
case "$REQUESTED_CATEGORY" in
    dev)
        run_category_dev
        ;;
    app_caches)
        run_category_app_caches
        ;;
    caches)
        run_category_caches
        ;;
    brew)
        run_category_brew
        ;;
    user)
        run_category_user
        ;;
    system)
        run_category_system
        ;;
    project)
        run_category_project
        ;;
    all)
        run_category_dev
        run_category_app_caches
        run_category_caches
        run_category_brew
        run_category_user
        run_category_system
        run_category_project
        ;;
esac

exit 0
