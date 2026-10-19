# CLI Application Logic Sovereignty Remediation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform the Mole native macOS Swift/SwiftUI presentation layer from a mock/hybrid scaffold into a 100% sovereign client for the `mole` CLI engine, eliminating all synthetic data, simulated sleeps, and duplicate deletion logic.

**Architecture:** The native Swift application serves strictly as an asynchronous presentation and process-orchestration client. All discovery heuristics, file measurements, system analysis, cleanup executions, optimizations, telemetry, and uninstalls delegate to upstream Go binaries (`analyze-go`, `status-go`), shell libraries (`lib/clean/*`, `lib/optimize/*`, `lib/uninstall/*`), and dedicated machine-readable adapters in `adapters/`.

**Tech Stack:** Native Swift 5.9+ (SwiftUI, Observation `@Observable`, AppKit), Go (1.21+), Darwin POSIX (`posix_spawnp`, `kill(-pgid)`), Bash 3.2+ (macOS default), Bats testing framework.

**Spec:** [`docs/superpowers/specs/2026-10-18-simulation-engine-and-neutral-ui-design.md`](file:///Users/I061264/Projects/Gemini_Projects/Mole_with_UI/docs/superpowers/specs/2026-10-18-simulation-engine-and-neutral-ui-design.md) & Comprehensive Architectural Audit in context.

## Global Constraints
- **Zero Junior Developer Policy:** No mock data, synthetic stubs, simulated sleeps (`Task.sleep`), placeholder shortcuts, or unverified assumptions in production code.
- **Production vs. Test Isolation:** `isMock` and test stubs must never exist in production classes (`MoleCoordinator`, views). Mocks belong strictly in test fixtures.
- **CLI Sovereignty Invariant:** Every user action in the UI must route through `ProcessStreamer` to an upstream CLI command or machine-readable adapter. No native file unlinking or manual trashing in Swift.
- **Upstream Synchronization Cleanliness:** Upstream files in `bin/`, `cmd/`, and `lib/` must remain pristine. Adapters live in `adapters/`.
- **macOS Compatibility:** Minimum deployment target macOS 14.0+ (Sonoma/Sequoia). Compatible with default `/bin/bash` (Bash 3.2+).

## Review Focus
1. **No Simulated Sleeps or Delays:** Confirm complete absence of `Task.sleep` used for simulated execution in views or coordinators.
2. **Real Stream Parsing:** Confirm all streaming responses parse real emitted keys (`category`, `bytes`, `path`, `safe`, `outcome`) instead of hardcoding multipliers.
3. **Engine Bundle Resolution:** Ensure `MoleEngineLocator` seamlessly finds engine assets whether running inside `Mole for Mac.app`, from the local Git repo during development/tests, or from a system install.
4. **Clean Deletion Audit Trail:** Verify that running a clean operation through the UI triggers upstream logging in `~/.mole/history.log` and honors upstream whitelists.
5. **No Regression on UI Polish:** Ensure the approved MacSpace neutral design system, 11pt typography floor, and Liquid Glass visual hierarchy remain intact.

---

### Task 1: Engine Bundling & Dynamic Engine Locator (`MoleEngineLocator`)

**Files:**
- Create: `App/Sources/MoleEngine/MoleEngineLocator.swift`
- Create: `App/Tests/MoleEngineTests/EngineLocatorTests.swift`
- Modify: `scripts/package_app.sh:10-70`

**Interfaces:**
- `MoleEngineLocator.shared.engineRootURL -> URL`
- `MoleEngineLocator.shared.resolveExecutable(named: String) -> URL?`
- `MoleEngineLocator.shared.resolveAdapter(named: String) -> URL?`

- [ ] **Step 1: Write failing test for `MoleEngineLocator`**
  Assert that `MoleEngineLocator.shared.engineRootURL` resolves to an existing directory containing `lib/` and `adapters/`, and resolves `bin/analyze-go` or `adapters/json_stream.sh`.
- [ ] **Step 2: Run test to verify it fails**
  `swift test --package-path App --filter EngineLocatorTests`
- [ ] **Step 3: Implement `MoleEngineLocator.swift`**
  Check:
  1. `Bundle.main.resourceURL?.appendingPathComponent("mole-engine")`
  2. `ProcessInfo.processInfo.environment["MOLE_ENGINE_ROOT"]`
  3. Upward directory traversal from `#filePath` finding `.git` or `lib/core/base.sh`
  4. System path `/usr/local/share/mole` or `~/.local/share/mole`
- [ ] **Step 4: Update `scripts/package_app.sh`**
  Ensure `make build` compiles Go binaries, and copies `bin/`, `lib/`, `adapters/`, and `mo` into `$BUNDLE_DIR/Contents/Resources/mole-engine/`.
- [ ] **Step 5: Run test to verify it passes**
  `swift test --package-path App --filter EngineLocatorTests`
- [ ] **Step 6: Commit**
  `git commit -m "feat(engine): implement MoleEngineLocator and bundle CLI engine in app package"`

---

### Task 2: Live Telemetry & Audit History Sovereignty (Status & History)

**Files:**
- Create: `App/Sources/MoleEngine/Models/TelemetryModels.swift`
- Create: `App/Sources/MoleEngine/Models/HistoryModels.swift`
- Modify: `App/Sources/MoleEngine/MoleCoordinator.swift`
- Modify: `App/Sources/MoleUI/Views/StatusView.swift`
- Modify: `App/Sources/MoleUI/Views/HistoryView.swift`
- Create: `App/Tests/MoleEngineTests/StatusHistoryTests.swift`

**Interfaces:**
- `MoleCoordinator.startStatusMonitoring()` -> Spawns `bin/status-go --watch --interval 1s` and streams NDJSON into `self.systemStatus`.
- `MoleCoordinator.fetchHistory(limit: Int)` -> Runs `bin/history.sh --json --limit <limit>` and populates `self.historyEntries`.

- [ ] **Step 1: Write failing test for `StatusHistoryTests`**
  Test decoding Go's `MetricsSnapshot` JSON format into `TelemetryModels`, and decoding `history.sh --json` output.
- [ ] **Step 2: Run test to verify it fails**
  `swift test --package-path App --filter StatusHistoryTests`
- [ ] **Step 3: Implement `TelemetryModels.swift` and `HistoryModels.swift`**
  Define `MetricsSnapshot`, `CPUStatus`, `MemoryStatus`, `ThermalStatus`, `BatteryStatus`, `HistoryEntry`, `HistoryManifest`.
- [ ] **Step 4: Wire `MoleCoordinator` to `status-go` and `history.sh`**
  Add async streaming via `ProcessStreamer` using paths resolved by `MoleEngineLocator`.
- [ ] **Step 5: Update `StatusView.swift` and `HistoryView.swift`**
  Bind live CPU%, Memory pressure, and APFS snapshot telemetry. In `HistoryView`, render real records and remove fake `isUndone` toggle.
- [ ] **Step 6: Run test to verify it passes**
  `swift test --package-path App --filter StatusHistoryTests`
- [ ] **Step 7: Commit**
  `git commit -m "feat(status-history): wire live Go telemetry and history stream into UI"`

---

### Task 3: Clean Workflow Sovereignty (Scan & Deletion Delegation)

**Files:**
- Create: `adapters/clean_stream.sh` (or upgrade `adapters/json_stream.sh`)
- Modify: `App/Sources/MoleEngine/MoleCoordinator.swift`
- Modify: `App/Sources/MoleUI/Views/CleanPreviewSheet.swift`
- Create: `App/Tests/MoleEngineTests/CleanStreamingTests.swift`

**Interfaces:**
- `clean_stream.sh --scan`: Streams NDJSON items with true bytes, category, and safety levels.
- `clean_stream.sh --clean --categories <cat_csv> [--snapshot]`: Invokes upstream clean routines with live progress NDJSON.
- `MoleCoordinator.scanReclaimableSpace()`: Dispatches `--scan` and parses real categorized items. Eliminates `1 MB` fake multiplier.
- `MoleCoordinator.performSafeCleanup(categories:createSnapshot:)`: Dispatches `--clean` via `ProcessStreamer`. Completely eliminates native Swift deletion loop.

- [ ] **Step 1: Write failing test for Clean Streaming**
  Verify parsing of NDJSON scan stream into `CleanCategory` hierarchy with accurate byte totals.
- [ ] **Step 2: Run test to verify it fails**
  `swift test --package-path App --filter CleanStreamingTests`
- [ ] **Step 3: Implement `adapters/clean_stream.sh`**
  Support `--scan` (emitting accurate category, name, path, bytes, safety) and `--clean` (calling upstream `safe_clean` / `perform_cleanup`).
- [ ] **Step 4: Refactor `MoleCoordinator.swift`**
  Remove `runMockScan()` and remove `isMock`. Parse real streams in `runRealScan()`. Re-implement `performSafeCleanup()` to delegate to `clean_stream.sh --clean`.
- [ ] **Step 5: Wire `CleanPreviewSheet.swift`**
  Connect `createSnapshotBeforeClean` toggle to `--snapshot` flag in `clean_stream.sh`.
- [ ] **Step 6: Run test to verify it passes**
  `swift test --package-path App --filter CleanStreamingTests`
- [ ] **Step 7: Commit**
  `git commit -m "feat(clean): achieve 100% CLI sovereignty for scan discovery and cleanup execution"`

---

### Task 4: Disk Analyzer Sovereignty (`AnalyzeTreemapView`)

**Files:**
- Create: `App/Sources/MoleEngine/Models/AnalyzeModels.swift`
- Modify: `App/Sources/MoleEngine/MoleCoordinator.swift`
- Modify: `App/Sources/MoleUI/Views/AnalyzeTreemapView.swift`
- Create: `App/Tests/MoleEngineTests/AnalyzeIntegrationTests.swift`

**Interfaces:**
- `MoleCoordinator.analyzeDiskUsage(path: String)` -> Spawns `bin/analyze-go --json <path>` and populates `self.analyzerRoot`.
- `AnalyzeTreemapView` displays the true directory tree rendered from Go's APFS traversal.

- [ ] **Step 1: Write failing test for Go analyzer output decoding**
  Test decoding `bin/analyze-go --json` schema (`entries`, `large_files`, `total_size`) into `TreemapNode`.
- [ ] **Step 2: Run test to verify it fails**
  `swift test --package-path App --filter AnalyzeIntegrationTests`
- [ ] **Step 3: Implement `AnalyzeModels.swift` and Coordinator method**
  Decode Go JSON output and convert directory hierarchy into proportional `TreemapNode`s.
- [ ] **Step 4: Update `AnalyzeTreemapView.swift`**
  Remove hardcoded `~/Library/Caches` breadcrumb. Add path input/selector and wire to `coordinator.analyzerRoot`.
- [ ] **Step 5: Run test to verify it passes**
  `swift test --package-path App --filter AnalyzeIntegrationTests`
- [ ] **Step 6: Commit**
  `git commit -m "feat(analyze): wire bin/analyze-go JSON output to interactive treemap"`

---

### Task 5: Software Hunter Sovereignty (`SoftwareView`)

**Files:**
- Create: `adapters/uninstall_adapter.sh`
- Create: `App/Sources/MoleEngine/Models/SoftwareModels.swift`
- Modify: `App/Sources/MoleEngine/MoleCoordinator.swift`
- Modify: `App/Sources/MoleUI/Views/SoftwareView.swift`
- Create: `App/Tests/MoleEngineTests/SoftwareIntegrationTests.swift`

**Interfaces:**
- `uninstall_adapter.sh --list`: Dispatches `bin/uninstall.sh --list` and emits JSON array of installed apps.
- `uninstall_adapter.sh --leftovers <app_name>`: Sources `lib/uninstall/batch.sh` and emits candidate leftover paths.
- `MoleCoordinator.fetchInstalledApps()`: Streams real installed apps into `self.installedApps`.
- `MoleCoordinator.fetchLeftovers(for app: InstalledAppInfo)`: Populates leftover paths.

- [ ] **Step 1: Write failing test for app inventory and leftover decoding**
  Verify parsing of `uninstall_adapter.sh` JSON outputs.
- [ ] **Step 2: Run test to verify it fails**
  `swift test --package-path App --filter SoftwareIntegrationTests`
- [ ] **Step 3: Implement `adapters/uninstall_adapter.sh`**
  Support `--list` and `--leftovers <app_name>`.
- [ ] **Step 4: Update `MoleCoordinator.swift` and `SoftwareView.swift`**
  Replace static array of Xcode/VSCode/Docker with live `@Bindable coordinator.installedApps`. Wire "Clean Leftovers" to real uninstaller dry-run / execution.
- [ ] **Step 5: Run test to verify it passes**
  `swift test --package-path App --filter SoftwareIntegrationTests`
- [ ] **Step 6: Commit**
  `git commit -m "feat(software): wire upstream uninstaller and leftover hunter into SoftwareView"`

---

### Task 6: System Optimize Sovereignty (`OptimizeView`)

**Files:**
- Create: `adapters/optimize_adapter.sh`
- Create: `App/Sources/MoleEngine/Models/OptimizeModels.swift`
- Modify: `App/Sources/MoleEngine/MoleCoordinator.swift`
- Modify: `App/Sources/MoleUI/Views/OptimizeView.swift`
- Create: `App/Tests/MoleEngineTests/OptimizeIntegrationTests.swift`

**Interfaces:**
- `optimize_adapter.sh --list`: Emits JSON catalog from `lib/optimize/catalog.sh`.
- `optimize_adapter.sh --run <task_id>`: Executes routine via `lib/optimize/tasks.sh` and emits outcome JSON.
- `MoleCoordinator.fetchOptimizeCatalog()`: Dispatches `--list`.
- `MoleCoordinator.executeOptimizeTask(id:)`: Dispatches `--run <id>`.

- [ ] **Step 1: Write failing test for optimize catalog and execution parsing**
  Test decoding task definitions and outcome events (`applied`, `unchanged`, `skipped`, `failed`).
- [ ] **Step 2: Run test to verify it fails**
  `swift test --package-path App --filter OptimizeIntegrationTests`
- [ ] **Step 3: Implement `adapters/optimize_adapter.sh`**
  Sourcing `lib/optimize/catalog.sh` and `lib/optimize/tasks.sh`.
- [ ] **Step 4: Update `MoleCoordinator.swift` and `OptimizeView.swift`**
  Completely eliminate `Task.sleep(nanoseconds: 500_000_000)` and static task array. Wire directly to `coordinator.executeOptimizeTask()`.
- [ ] **Step 5: Run test to verify it passes**
  `swift test --package-path App --filter OptimizeIntegrationTests`
- [ ] **Step 6: Commit**
  `git commit -m "feat(optimize): wire upstream optimization catalog and execution routines"`

---

### Task 7: Comprehensive Verification & Sovereignty Audit Lock

**Files:**
- Create: `tests/swift_cli_sovereignty.bats`
- Modify: `scripts/preflight_check.sh`
- Modify: `DECISIONS_LEDGER.md`

**Deliverables:**
- Automated Bats contract test suite verifying that all UI workflows invoke upstream commands and generate audit trails.
- 100% green preflight check across all 4 tiers (CLI quality, Bats tests, Go modules, Swift test suites).
- Final Principal Architect Sign-Off.

- [ ] **Step 1: Implement `tests/swift_cli_sovereignty.bats`**
  Contract tests asserting:
  1. `adapters/clean_stream.sh --scan` outputs valid NDJSON without modifying disk.
  2. `adapters/clean_stream.sh --clean` writes to `~/.mole/history.log`.
  3. `adapters/uninstall_adapter.sh --list` outputs valid JSON.
  4. `adapters/optimize_adapter.sh --list` matches `lib/optimize/catalog.sh`.
- [ ] **Step 2: Run Bats test suite**
  `tools/bin/bats tests/swift_cli_sovereignty.bats`
- [ ] **Step 3: Run full 4-tier preflight gate**
  `./scripts/preflight_check.sh`
- [ ] **Step 4: Record Decision in `DECISIONS_LEDGER.md`**
  Document Decision 013: 100% Upstream CLI Application Logic Sovereignty.
- [ ] **Step 5: Commit and Tag**
  `git commit -m "test(sovereignty): add bats contract suite and complete 100% CLI sovereignty remediation"`
