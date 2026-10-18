#!/bin/bash
# scripts/preflight_check.sh
# Mole for Mac — 4-Tier Automated Verification Gate & Preflight Test Runner
# Verifies upstream CLI integrity, Bats test suites, Go modules, and Native Swift/SwiftUI app.
# Compatible with macOS default /bin/bash (Bash 3.2+).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Ensure fallback tools (like tools/bin/bats) are available in PATH
if [[ -d "$REPO_ROOT/tools/bin" ]]; then
    export PATH="$REPO_ROOT/tools/bin:$PATH"
fi

# Locate pristine CLI source root
if [[ -n "${MOLE_ROOT:-}" && -d "$MOLE_ROOT/lib" ]]; then
    CLI_ROOT="$MOLE_ROOT"
elif [[ -d "$REPO_ROOT/lib" && -f "$REPO_ROOT/lib/core/base.sh" ]]; then
    CLI_ROOT="$REPO_ROOT"
elif [[ -d "$REPO_ROOT/mole-cli-source/lib" ]]; then
    CLI_ROOT="$REPO_ROOT/mole-cli-source"
else
    CLI_ROOT="$REPO_ROOT"
fi

# Color and formatting definitions
USE_COLOR=true
if [[ ! -t 1 || "${NO_COLOR:-}" != "" || "${TERM:-}" == "dumb" ]]; then
    USE_COLOR=false
fi

if $USE_COLOR; then
    BOLD="\033[1m"
    GREEN="\033[32m"
    RED="\033[31m"
    YELLOW="\033[33m"
    BLUE="\033[34m"
    CYAN="\033[36m"
    RESET="\033[0m"
else
    BOLD=""
    GREEN=""
    RED=""
    YELLOW=""
    BLUE=""
    CYAN=""
    RESET=""
fi

SWIFT_ONLY=false
CLI_ONLY=false
QUICK_MODE=false

print_usage() {
    cat << EOF
Usage: $(basename "$0") [options]

Mole for Mac 4-Tier Verification Gate:
  Tier 1: Upstream CLI Lints & Style Checks (check.sh)
  Tier 2: Bats Shell & Contract Test Suites
  Tier 3: Go Engine & Command Modules (go test)
  Tier 4: Native macOS Swift / SwiftUI Test Suite (swift test)

Options:
  --swift-only   Run only Tier 4 (Swift / SwiftUI test suite)
  --cli-only     Run only Tiers 1–3 (CLI checks, Bats, and Go tests)
  --quick        Skip slow or extended tests
  --no-color     Disable ANSI color formatting
  --help, -h     Show this help message
EOF
}

# Parse command line options
while [[ $# -gt 0 ]]; do
    case "$1" in
        --swift-only)
            SWIFT_ONLY=true
            shift
            ;;
        --cli-only)
            CLI_ONLY=true
            shift
            ;;
        --quick)
            QUICK_MODE=true
            shift
            ;;
        --no-color)
            USE_COLOR=false
            BOLD=""; GREEN=""; RED=""; YELLOW=""; BLUE=""; CYAN=""; RESET=""
            shift
            ;;
        --help|-h)
            print_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            print_usage >&2
            exit 1
            ;;
    esac
done

echo -e "${BOLD}${CYAN}======================================================${RESET}"
echo -e "${BOLD}${CYAN}    Mole for Mac — Automated Preflight Verification    ${RESET}"
echo -e "${BOLD}${CYAN}======================================================${RESET}"
echo "Repository Root: $REPO_ROOT"
echo "CLI Engine Root: $CLI_ROOT"
echo ""

START_TIME=$(date +%s)
FAILED_TIERS=0

# Ensure isolated build, home sandbox, and cache directories to avoid polluting host and prevent privacy prompts
export TMPDIR="/tmp"
export CLANG_MODULE_CACHE_PATH="/tmp/clang-cache"
export MOLE_TEST_NO_AUTH=1
export MOLE_DRY_RUN=1
mkdir -p "$CLANG_MODULE_CACHE_PATH"

PREFLIGHT_HOME="$(mktemp -d "${TMPDIR:-/tmp}/mole-mock-home-XXXXXX")"
mkdir -p "$PREFLIGHT_HOME/Library/Caches"
cleanup_preflight() {
    rm -rf "$PREFLIGHT_HOME" # SAFE: exact mktemp-created mock sandbox home directory
}
trap cleanup_preflight EXIT
export HOME="$PREFLIGHT_HOME"

run_tier_1_cli_check() {
    echo -e "${BOLD}${BLUE}--- Tier 1: Upstream CLI Code Quality Checks ---${RESET}"
    if [[ -f "$CLI_ROOT/scripts/check.sh" ]]; then
        echo "Running: $CLI_ROOT/scripts/check.sh --no-format"
        if (cd "$CLI_ROOT" && ./scripts/check.sh --no-format); then
            echo -e "${GREEN}✔ Tier 1 CLI quality checks passed.${RESET}\n"
        else
            echo -e "${RED}✘ Tier 1 CLI quality checks failed.${RESET}\n"
            FAILED_TIERS=$((FAILED_TIERS + 1))
        fi
    else
        echo -e "${YELLOW}⚠ scripts/check.sh not found at $CLI_ROOT/scripts/check.sh, skipping CLI lint.${RESET}\n"
    fi
}

run_tier_2_bats_tests() {
    echo -e "${BOLD}${BLUE}--- Tier 2: Bats Shell & Contract Test Suites ---${RESET}"
    local tier_failed=0

    # 1. Contract tests for native macOS app & CI
    if [[ -f "$REPO_ROOT/tests/upstream_sync_contract.bats" ]]; then
        echo "Running Native App Upstream Sync Bats Contract Tests..."
        if bats "$REPO_ROOT/tests/upstream_sync_contract.bats"; then
            echo -e "${GREEN}✔ Upstream sync Bats contract tests passed.${RESET}"
        else
            echo -e "${RED}✘ Upstream sync Bats contract tests failed.${RESET}"
            tier_failed=1
        fi
    fi

    # 2. Upstream CLI Bats tests if full bats-core is available and not in quick mode
    if [[ -d "$CLI_ROOT/tests" && -f "$CLI_ROOT/scripts/test.sh" ]]; then
        if $QUICK_MODE; then
            echo -e "${YELLOW}⚡ Quick mode enabled: skipping extended upstream CLI bats suites.${RESET}"
        else
            local bats_ver=""
            bats_ver="$(bats --version 2>&1 || true)"
            if command -v bats-exec-file > /dev/null 2>&1 || [[ "$bats_ver" =~ Bats\ [0-9]+\.[0-9]+ && ! "$bats_ver" =~ minimal-fallback ]]; then
                echo "Running Upstream CLI Bats Test Runner..."
                if (cd "$CLI_ROOT" && MOLE_TEST_NO_AUTH=1 ./scripts/test.sh); then
                    echo -e "${GREEN}✔ Upstream CLI test runner passed.${RESET}"
                else
                    echo -e "${RED}✘ Upstream CLI test runner failed.${RESET}"
                    tier_failed=1
                fi
            else
                echo -e "${YELLOW}⚠ bats-core not installed on host (installed in CI via Homebrew); upstream CLI bats suite skipped locally.${RESET}"
            fi
        fi
    fi

    if [[ $tier_failed -eq 0 ]]; then
        echo -e "${GREEN}✔ Tier 2 Bats test suite passed.${RESET}\n"
    else
        echo -e "${RED}✘ Tier 2 Bats test suite failed.${RESET}\n"
        FAILED_TIERS=$((FAILED_TIERS + 1))
    fi
}

run_tier_3_go_tests() {
    echo -e "${BOLD}${BLUE}--- Tier 3: Go Engine & Command Modules ---${RESET}"
    if command -v go > /dev/null 2>&1; then
        if [[ -f "$CLI_ROOT/go.mod" ]]; then
            echo "Running: (cd $CLI_ROOT && go test ./...)"
            if (cd "$CLI_ROOT" && go test ./...); then
                echo -e "${GREEN}✔ Tier 3 Go tests passed.${RESET}\n"
            else
                echo -e "${RED}✘ Tier 3 Go tests failed.${RESET}\n"
                FAILED_TIERS=$((FAILED_TIERS + 1))
            fi
        else
            echo -e "${YELLOW}⚠ No go.mod found in $CLI_ROOT, skipping Go tests.${RESET}\n"
        fi
    else
        echo -e "${YELLOW}⚠ Go binary not installed on host, skipping Go tests.${RESET}\n"
    fi
}

run_tier_4_swift_tests() {
    echo -e "${BOLD}${BLUE}--- Tier 4: Native macOS Swift / SwiftUI Test Suite ---${RESET}"
    if [[ -d "$REPO_ROOT/App" ]]; then
        local swift_cmd=("swift" "test" "--disable-sandbox" "--package-path" "$REPO_ROOT/App")
        if $QUICK_MODE; then
            echo -e "${YELLOW}⚡ Quick mode enabled: running core smoke tests.${RESET}"
            swift_cmd+=("--filter" "MoleCoreTests")
        fi
        echo "Running: ${swift_cmd[*]}"
        if "${swift_cmd[@]}"; then
            echo -e "${GREEN}✔ Tier 4 Swift test suite passed.${RESET}\n"
        else
            echo -e "${RED}✘ Tier 4 Swift test suite failed.${RESET}\n"
            FAILED_TIERS=$((FAILED_TIERS + 1))
        fi
    else
        echo -e "${RED}✘ App directory not found at $REPO_ROOT/App.${RESET}\n"
        FAILED_TIERS=$((FAILED_TIERS + 1))
    fi
}

if ! $SWIFT_ONLY; then
    run_tier_1_cli_check
    run_tier_2_bats_tests
    run_tier_3_go_tests
fi

if ! $CLI_ONLY; then
    run_tier_4_swift_tests
fi

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

echo -e "${BOLD}${CYAN}======================================================${RESET}"
if [[ $FAILED_TIERS -eq 0 ]]; then
    echo -e "${BOLD}${GREEN}✔ ALL PREFLIGHT TIERS PASSED (${ELAPSED}s)${RESET}"
    echo -e "${BOLD}${CYAN}======================================================${RESET}"
    exit 0
else
    echo -e "${BOLD}${RED}✘ PREFLIGHT VERIFICATION FAILED: $FAILED_TIERS tier(s) failed (${ELAPSED}s)${RESET}"
    echo -e "${BOLD}${CYAN}======================================================${RESET}"
    exit 1
fi
