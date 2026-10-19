#!/bin/bash
# Mole Native Mac — Sovereign Disk Analyzer Adapter
# Wraps upstream bin/analyze-go --json if present;
# Falls back to native Darwin traversal emitting identical schema.
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

TARGET_PATH="$HOME"
IS_OVERVIEW=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --path)
            TARGET_PATH="${2:-$HOME}"
            shift 2
            ;;
        --overview)
            IS_OVERVIEW=true
            shift
            ;;
        *)
            if [[ -d "$1" || -e "$1" ]]; then
                TARGET_PATH="$1"
            fi
            shift
            ;;
    esac
done

# Resolve canonical path
if [[ -d "$TARGET_PATH" ]]; then
    TARGET_PATH="$(cd "$TARGET_PATH" && pwd -P)"
fi

GO_BIN="$ENGINE_ROOT/bin/analyze-go"

if [[ -x "$GO_BIN" ]]; then
    if $IS_OVERVIEW; then
        exec "$GO_BIN" --json --overview "$TARGET_PATH"
    else
        exec "$GO_BIN" --json "$TARGET_PATH"
    fi
fi

# Fallback: Produce identical jsonOutput schema using native Darwin utilities
escape_json() {
    local str="$1"
    str="${str//\\/\\\\}"
    str="${str//\"/\\\"}"
    str="${str//$'\t'/\\t}"
    str="${str//$'\r'/\\r}"
    str="${str//$'\n'/\\n}"
    printf '%s' "$str"
}

ENTRIES_JSON=""
TOTAL_SIZE=0
TOTAL_FILES=0
FIRST=true

if [[ -d "$TARGET_PATH" ]]; then
    # List immediate children
    while IFS= read -r child_name; do
        [[ -z "$child_name" ]] && continue
        child_path="$TARGET_PATH/$child_name"
        [[ ! -e "$child_path" && ! -L "$child_path" ]] && continue

        TOTAL_FILES=$((TOTAL_FILES + 1))
        is_dir=false
        [[ -d "$child_path" && ! -L "$child_path" ]] && is_dir=true

        size_bytes=0
        if [[ -f "$child_path" || -L "$child_path" ]]; then
            size_bytes=$(/usr/bin/stat -f %z "$child_path" 2>/dev/null || true)
            [[ -z "$size_bytes" ]] && size_bytes=0
        elif [[ -d "$child_path" ]]; then
            kb=$(/usr/bin/du -sk "$child_path" 2>/dev/null | /usr/bin/awk '{print $1}' || true)
            if [[ "$kb" =~ ^[0-9]+$ ]]; then
                size_bytes=$((kb * 1024))
            fi
        fi

        TOTAL_SIZE=$((TOTAL_SIZE + size_bytes))

        entry=$(cat <<EOF
    {
      "scan_status": "complete",
      "name": "$(escape_json "$child_name")",
      "path": "$(escape_json "$child_path")",
      "size": $size_bytes,
      "is_dir": $is_dir
    }
EOF
)
        if $FIRST; then
            ENTRIES_JSON="$entry"
            FIRST=false
        else
            ENTRIES_JSON="$ENTRIES_JSON,
$entry"
        fi
    done < <(/bin/ls -1A "$TARGET_PATH" 2>/dev/null || true)
fi

cat <<EOF
{
  "scan_status": "complete",
  "path": "$(escape_json "$TARGET_PATH")",
  "overview": $IS_OVERVIEW,
  "entries": [
$ENTRIES_JSON
  ],
  "total_size": $TOTAL_SIZE,
  "total_files": $TOTAL_FILES
}
EOF
