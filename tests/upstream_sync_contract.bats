#!/usr/bin/env bats
# tests/upstream_sync_contract.bats
# Contract tests for preflight check runner and upstream sync configuration.

setup() {
    load 'test_helper/bats-support/load' 2>/dev/null || true
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
}

@test "preflight_check script exists and is executable" {
    [ -x "$REPO_ROOT/scripts/preflight_check.sh" ]
}

@test "preflight_check script uses strict error handling (set -euo pipefail)" {
    run grep -E "set -[a-z]*e" "$REPO_ROOT/scripts/preflight_check.sh"
    [ "$status" -eq 0 ]
}

@test "preflight_check supports --help flag" {
    run "$REPO_ROOT/scripts/preflight_check.sh" --help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Usage:" ]]
}

@test "upstream-sync workflow exists and contains weekly schedule" {
    [ -f "$REPO_ROOT/.github/workflows/upstream-sync.yml" ]
    run grep -E "0 0 \* \* 1" "$REPO_ROOT/.github/workflows/upstream-sync.yml"
    [ "$status" -eq 0 ]
}

@test "upstream-sync workflow enforces non-fast-forward merge" {
    run grep -E "git merge --no-ff" "$REPO_ROOT/.github/workflows/upstream-sync.yml"
    [ "$status" -eq 0 ]
}
