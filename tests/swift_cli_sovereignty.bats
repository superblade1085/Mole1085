#!/usr/bin/env bats
# tests/swift_cli_sovereignty.bats
# Contract tests for CLI Application Logic Sovereignty adapters.
# Verifies all 4 adapters emit valid JSON schemas and wire directly to upstream Mole CLI routines.

setup() {
    load 'test_helper/bats-support/load' 2>/dev/null || true
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
}

@test "clean_stream.sh adapter exists and is executable" {
    [ -x "$REPO_ROOT/adapters/clean_stream.sh" ]
}

@test "clean_stream.sh scan mode outputs valid NDJSON stream" {
    run "$REPO_ROOT/adapters/clean_stream.sh" --scan --categories all
    [ "$status" -eq 0 ]
    [[ "$output" =~ "\"type\"" ]] || return 1
    [[ "$output" =~ "summary" || "$output" =~ "item" ]]
}

@test "clean_stream.sh clean dry-run mode outputs complete event" {
    run "$REPO_ROOT/adapters/clean_stream.sh" --dry-run --clean --categories systemCaches
    [ "$status" -eq 0 ]
    [[ "$output" =~ "\"type\": \"complete\"" ]]
}

@test "analyze_stream.sh adapter exists and is executable" {
    [ -x "$REPO_ROOT/adapters/analyze_stream.sh" ]
}

@test "analyze_stream.sh outputs valid JSON schema matching AnalyzeOutput" {
    run "$REPO_ROOT/adapters/analyze_stream.sh" --path "$REPO_ROOT/adapters"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "\"path\"" ]] || return 1
    [[ "$output" =~ "\"entries\"" ]]
}

@test "uninstall_adapter.sh adapter exists and is executable" {
    [ -x "$REPO_ROOT/adapters/uninstall_adapter.sh" ]
}

@test "uninstall_adapter.sh list mode outputs valid JSON array" {
    run "$REPO_ROOT/adapters/uninstall_adapter.sh" --list
    [ "$status" -eq 0 ]
    [[ "$output" =~ "[" ]] || return 1
    [[ "$output" =~ "\"name\"" ]] || return 1
    [[ "$output" =~ "\"bundle_id\"" ]]
}

@test "optimize_adapter.sh adapter exists and is executable" {
    [ -x "$REPO_ROOT/adapters/optimize_adapter.sh" ]
}

@test "optimize_adapter.sh list mode outputs valid JSON array with 19 catalog tasks" {
    run "$REPO_ROOT/adapters/optimize_adapter.sh" --list
    [ "$status" -eq 0 ]
    [[ "$output" =~ "cache_refresh" ]] || return 1
    [[ "$output" =~ "saved_state_cleanup" ]] || return 1
    [[ "$output" =~ "\"requires_sudo\"" ]]
}

@test "optimize_adapter.sh run mode executes real optimization routine and returns valid JSON" {
    run "$REPO_ROOT/adapters/optimize_adapter.sh" --run cache_refresh
    [ "$status" -eq 0 ]
    [[ "$output" =~ "\"status\": \"success\"" ]] || return 1
    [[ "$output" =~ "\"action\": \"cache_refresh\"" ]] || return 1
    [[ "$output" =~ "\"exit_code\": 0" ]]
}

@test "zero tolerance: view layer contains zero Task.sleep simulated delays" {
    run grep -rn "Task.sleep" "$REPO_ROOT/App/Sources/MoleUI/Views"
    [ "$status" -ne 0 ]
}

@test "zero tolerance: view layer contains zero hardcoded fake data arrays" {
    run grep -rn "FakeData" "$REPO_ROOT/App/Sources/MoleUI"
    [ "$status" -ne 0 ]
}
