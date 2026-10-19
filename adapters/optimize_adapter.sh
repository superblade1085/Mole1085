#!/bin/bash
# Mole Native Mac — Sovereign System Optimization Adapter
# Wraps upstream lib/optimize/catalog.sh, tasks.sh, and outcomes.sh
# Emits structured JSON for task listing and real system optimization execution.
# Compatible with macOS default /bin/bash (Bash 3.2+).

set -euo pipefail

export LC_ALL=C
export LANG=C

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Locate engine root
if [[ -n "${MOLE_ROOT:-}" && -d "$MOLE_ROOT" ]]; then
    ENGINE_ROOT="$MOLE_ROOT"
elif [[ -d "$REPO_ROOT/lib" ]]; then
    ENGINE_ROOT="$REPO_ROOT"
else
    ENGINE_ROOT="$REPO_ROOT"
fi

MODE="list"
TARGET_ACTION=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --list)
            MODE="list"
            shift
            ;;
        --run)
            MODE="run"
            TARGET_ACTION="${2:-}"
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

# Source upstream dependencies
source "$ENGINE_ROOT/lib/core/base.sh" 2>/dev/null || true
source "$ENGINE_ROOT/lib/core/common.sh" 2>/dev/null || true
source "$ENGINE_ROOT/lib/optimize/catalog.sh" 2>/dev/null || true
source "$ENGINE_ROOT/lib/optimize/outcomes.sh" 2>/dev/null || true
source "$ENGINE_ROOT/lib/optimize/tasks.sh" 2>/dev/null || true

# --- MODE: LIST ---
if [[ "$MODE" == "list" ]]; then
    FIRST=true
    printf '[\n'
    for ((index = 0; index < ${#MOLE_OPTIMIZE_ACTIONS[@]}; index++)); do
        action="${MOLE_OPTIMIZE_ACTIONS[$index]}"
        health_name="${MOLE_OPTIMIZE_HEALTH_NAMES[$index]}"
        desc="${MOLE_OPTIMIZE_DESCRIPTIONS[$index]}"
        safe="${MOLE_OPTIMIZE_SAFE_VALUES[$index]:-true}"

        # Determine if sudo is required
        requires_sudo=false
        case "$action" in
            disk_permissions_repair|periodic_maintenance|disk_verify)
                requires_sudo=true
                ;;
        esac

        entry=$(cat <<EOF
  {
    "id": "$(escape_json "$action")",
    "name": "$(escape_json "$health_name")",
    "description": "$(escape_json "$desc")",
    "requires_sudo": $requires_sudo,
    "safe": $safe
  }
EOF
)
        if $FIRST; then
            printf '%s' "$entry"
            FIRST=false
        else
            printf ',\n%s' "$entry"
        fi
    done
    printf '\n]\n'
    exit 0
fi

# --- MODE: RUN ---
if [[ "$MODE" == "run" ]]; then
    if [[ -z "$TARGET_ACTION" ]]; then
        echo '{"status": "error", "message": "No action specified"}'
        exit 1
    fi

    # Verify action exists
    if ! optimize_catalog_index_for "$TARGET_ACTION" >/dev/null 2>&1; then
        echo "{\"status\": \"error\", \"message\": \"Unknown optimization action: $(escape_json "$TARGET_ACTION")\"}"
        exit 1
    fi

    # Capture real task execution output
    OUTPUT=""
    EXIT_CODE=0
    OUTPUT=$(execute_optimization "$TARGET_ACTION" 2>&1) || EXIT_CODE=$?

    # Record in Mole operation history log
    MOLE_LOG_DIR="$HOME/Library/Logs/mole"
    (
        mkdir -p "$MOLE_LOG_DIR"
        TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"
        echo "[$TIMESTAMP] optimize action: $TARGET_ACTION exit_code: $EXIT_CODE" >> "$MOLE_LOG_DIR/operations.log"
    ) 2>/dev/null || true

    cat <<EOF
{
  "status": "success",
  "action": "$(escape_json "$TARGET_ACTION")",
  "exit_code": $EXIT_CODE,
  "output": "$(escape_json "$OUTPUT")"
}
EOF
    exit 0
fi
