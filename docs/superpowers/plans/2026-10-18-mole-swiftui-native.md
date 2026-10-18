# Mole for Mac (Open-Source Native Edition) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native, open-source macOS utility (Swift/SwiftUI targeting macOS 14.0+) providing a Liquid Glass UI for system cleanup, disk treemap analysis, app uninstallation, maintenance optimization, and hardware telemetry powered by the Mole engine.

**Architecture:** A decoupled three-tier architecture comprising: 1) a native SwiftUI presentation layer with Liquid Glass materials and `@Observable` state; 2) a Swift `MoleEngine` coordinator handling async process streaming, 60 Hz display throttling, and APFS/TCC safety; and 3) unprivileged local CLI workers alongside a zero-trust `SMAppService.daemon` privileged helper verified via cryptographic audit tokens. Upstream CLI files in `lib/` and Go modules remain pristine, bridged via dedicated adapters.

**Tech Stack:** Swift 5.10+, SwiftUI, AppKit (`NSVisualEffectView`), Combine / Swift Concurrency (`AsyncStream`), `SMAppService.daemon`, `NSXPCConnection`, Security framework (`SecCodeCopyGuestWithAttributes`), Sparkle 2, Go 1.22+, POSIX shell.

**Spec:** `docs/superpowers/specs/2026-10-18-mole-swiftui-design.md`

## Global Constraints
- Target platform: macOS 14.0+ (Sonoma, Sequoia, and future versions) with Universal 2 (Apple Silicon & Intel) binary compilation.
- Non-sandboxed Hardened Runtime with standard network client entitlement for Sparkle updates.
- All deletions must route strictly through native `FileManager.default.trashItem(at:resultingItemURL:)` for APFS cross-volume awareness; raw wildcard `rm -rf *` is strictly prohibited.
- Never delete or unlink SQLite `.db-wal` or `.db-shm` companion files without their parent database.
- Dataless/iCloud stubs (`SF_DATALESS` / `NSURLIsUbiquitousItemKey`) must never be opened for inspection to prevent triggering multi-gigabyte cloud downloads.
- `SMAppService.daemon` must validate peer audit tokens against Developer ID Team ID and bundle identifier.
- Upstream CLI source files in `bin/`, `cmd/`, and `lib/` must remain 100% pristine; UI hooks live in `adapters/`.
- Git protocol: All merges must use merge commits (`git merge --no-ff`); CI must be green before pushing.

## Review Focus
1. Attempting to scan a dataless iCloud stub or offline cloud-backed directory must skip content inspection without triggering a cloud download.
2. Trashing a target located on an external APFS or secondary non-boot volume must move atomically to `<VolumeRoot>/.Trashes/<uid>/` rather than copying gigabytes across volume boundaries to `~/.Trash`.
3. An XPC connection attempted from an untrusted, unsigned, or third-party process to `com.mole.helper` must be rejected immediately with peer verification failure.
4. Scanning a directory containing 200,000+ files emitting 10,000 lines/sec must coalesce display updates to 60 Hz without UI stutter or memory bloating.
5. In-place Sparkle 2 application update must signal the privileged helper to shut down gracefully before replacing the app bundle, preventing file-in-use errors.

---

### Task 1: Project Scaffolding & Pristine Adapter Architecture

**Files:**
- Create: `App/Package.swift`
- Create: `adapters/json_stream.sh`
- Create: `App/Sources/MoleCore/MoleCore.swift`
- Test: `App/Tests/MoleCoreTests/ScaffoldingTests.swift`

**Interfaces:**
- Consumes: System environment and CLI binaries in `mole-cli-source/`
- Produces: `MoleCore` library target, Swift Package structure, and `adapters/json_stream.sh` structured scan output

- [ ] **Step 1: Write the failing test for project scaffolding and package configuration**

```swift
// App/Tests/MoleCoreTests/ScaffoldingTests.swift
import XCTest
@testable import MoleCore

final class ScaffoldingTests: XCTestCase {
    func testProjectTargetVersion() {
        XCTAssertEqual(MoleCore.minimumOSVersion, "14.0")
        XCTAssertTrue(MoleCore.isSupportedPlatform)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --package-path App`
Expected: FAIL with "error: no such package" or missing symbol

- [ ] **Step 3: Implement `Package.swift` and `MoleCore.swift`**

Create `App/Package.swift` targeting macOS 14.0 with targets for `MoleCore`, `MoleEngine`, `MoleUI`, and `MoleHelper`. Create `adapters/json_stream.sh` to wrap `lib/clean/*.sh` functions into structured JSON events (`{"category": "dev", "path": "...", "bytes": 1024, "safe": true}`) without altering upstream CLI source files.

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --package-path App`
Expected: PASS with 1 test executed successfully.

- [ ] **Step 5: Commit**

```bash
git add App/ adapters/
git commit -m "feat(scaffold): initialize SPM package and pristine CLI json adapter"
```

---

### Task 2: Subprocess Streaming & Process Group Engine (`MoleEngine`)

**Files:**
- Create: `App/Sources/MoleEngine/ProcessStreamer.swift`
- Create: `App/Sources/MoleEngine/ProcessGroupManager.swift`
- Create: `App/Sources/MoleEngine/DisplayThrottler.swift`
- Test: `App/Tests/MoleEngineTests/ProcessStreamerTests.swift`
- Test: `App/Tests/MoleEngineTests/DisplayThrottlerTests.swift`

**Interfaces:**
- Consumes: Foundation `Process`, `Pipe`, `DispatchSourceTimer`
- Produces:
  - `ProcessStreamer.stream(executable:arguments:) -> AsyncThrowingStream<String, Error>`
  - `ProcessGroupManager.terminateGroup(pid:pid_t)`
  - `DisplayThrottler<T>.emit(value:T)` emitting throttled batches at 60 Hz (16ms)

- [ ] **Step 1: Write failing tests for streaming, cancellation, and throttling**

```swift
// App/Tests/MoleEngineTests/ProcessStreamerTests.swift
import XCTest
@testable import MoleEngine

final class ProcessStreamerTests: XCTestCase {
    func testStreamProcessLines() async throws {
        let streamer = ProcessStreamer()
        var lines: [String] = []
        for try await line in streamer.stream(executable: "/bin/echo", arguments: ["hello\nworld"]) {
            lines.append(line.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        XCTAssertEqual(lines, ["hello", "world"])
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --package-path App --filter ProcessStreamerTests`
Expected: FAIL with symbol not found.

- [ ] **Step 3: Implement `ProcessStreamer`, `ProcessGroupManager`, and `DisplayThrottler` in `App/Sources/MoleEngine/`**

- `ProcessStreamer`: Spawns process with `setpgid(0, 0)` and yields lines over `Pipe.readabilityHandler`.
- `ProcessGroupManager`: Calls `kill(-pgid, SIGTERM)` with an async 1.5s escalation to `SIGKILL`.
- `DisplayThrottler`: Uses a coalescing `DispatchSourceTimer` firing every 16ms to update UI accumulators.

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --package-path App --filter ProcessStreamerTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add App/Sources/MoleEngine/ App/Tests/MoleEngineTests/
git commit -m "feat(engine): add async process streamer, process group cleanup and 60Hz display throttler"
```

---

### Task 3: Security & APFS Deletion Safety Layer (`MoleSafety`)

**Files:**
- Create: `App/Sources/MoleCore/Safety/SafeTrash.swift`
- Create: `App/Sources/MoleCore/Safety/DatalessGuard.swift`
- Create: `App/Sources/MoleCore/Safety/DatabaseGuard.swift`
- Create: `App/Sources/MoleCore/Safety/FullDiskAccess.swift`
- Test: `App/Tests/MoleCoreTests/SafetyTests.swift`

**Interfaces:**
- Consumes: Cocoa `FileManager`, `stat` (`SF_DATALESS`), `NSRunningApplication`
- Produces:
  - `SafeTrash.trashItem(at: URL) throws -> URL`
  - `DatalessGuard.isDatalessOrUbiquitous(url: URL) -> Bool`
  - `DatabaseGuard.bundleCompanionPaths(databaseURL: URL) -> [URL]`
  - `FullDiskAccess.isGranted() -> Bool`

- [ ] **Step 1: Write failing tests for APFS cross-volume trashing, dataless detection, and database bundling**

```swift
// App/Tests/MoleCoreTests/SafetyTests.swift
import XCTest
@testable import MoleCore

final class SafetyTests: XCTestCase {
    func testDatabaseCompanionBundling() {
        let db = URL(fileURLWithPath: "/tmp/test.db")
        let companions = DatabaseGuard.bundleCompanionPaths(databaseURL: db)
        let filenames = companions.map { $0.lastPathComponent }
        XCTAssertTrue(filenames.contains("test.db"))
        XCTAssertTrue(filenames.contains("test.db-wal"))
        XCTAssertTrue(filenames.contains("test.db-shm"))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --package-path App --filter SafetyTests`
Expected: FAIL.

- [ ] **Step 3: Implement safety guards in `App/Sources/MoleCore/Safety/`**

- `SafeTrash`: Invokes `FileManager.default.trashItem(at:resultingItemURL:)` and validates `volumeSupportsTrashKey`.
- `DatalessGuard`: Checks `st_flags & SF_DATALESS` and `NSURLIsUbiquitousItemKey`.
- `DatabaseGuard`: Resolves SQLite `-wal` and `-shm` sidecars to delete them as an atomic unit.
- `FullDiskAccess`: Uses silent `opendir("~/Library/Safari")` heuristic.

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --package-path App --filter SafetyTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add App/Sources/MoleCore/Safety/ App/Tests/MoleCoreTests/
git commit -m "feat(safety): add cross-volume trash, dataless protection and SQLite companion grouping"
```

---

### Task 4: Zero-Trust Privileged Helper Daemon (`MoleHelper`)

**Files:**
- Create: `App/Sources/MoleHelper/MoleHelperProtocol.swift`
- Create: `App/Sources/MoleHelper/HelperDaemon.swift`
- Create: `App/Sources/MoleHelper/XPCVerification.swift`
- Create: `App/Sources/MoleHelper/LaunchDaemons/com.mole.helper.plist`
- Test: `App/Tests/MoleHelperTests/XPCVerificationTests.swift`

**Interfaces:**
- Consumes: `NSXPCListener`, `audit_token_t`, `SecCodeCopyGuestWithAttributes`, `SecRequirementRef`
- Produces:
  - `@objc(MoleHelperProtocol) protocol MoleHelperProtocol`
  - `HelperDaemon`: Listener delegate with peer verification
  - Launchd plist with `KeepAlive: false` and MachServices socket activation

- [ ] **Step 1: Write failing test for XPC peer requirement verification**

```swift
// App/Tests/MoleHelperTests/XPCVerificationTests.swift
import XCTest
@testable import MoleHelper

final class XPCVerificationTests: XCTestCase {
    func testRequirementStringFormat() {
        let reqString = XPCVerification.designatedRequirementString(teamID: "TEAM123", bundleID: "com.mole.MoleApp")
        XCTAssertTrue(reqString.contains("identifier \"com.mole.MoleApp\""))
        XCTAssertTrue(reqString.contains("certificate leaf[subject.OU] == \"TEAM123\""))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --package-path App --filter XPCVerificationTests`
Expected: FAIL.

- [ ] **Step 3: Implement `MoleHelperProtocol`, `HelperDaemon`, and `XPCVerification`**

Implement `SecCodeCopyGuestWithAttributes` checking caller audit token against designated requirement string. Implement `requestGracefulShutdown(reply:)` for Sparkle 2 bundle replacement compatibility.

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --package-path App --filter XPCVerificationTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add App/Sources/MoleHelper/ App/Tests/MoleHelperTests/
git commit -m "feat(helper): implement zero-trust privileged daemon with audit token XPC verification"
```

---

### Task 5: Domain Models, State Management & Engine Coordinator (`MoleCoordinator`)

**Files:**
- Create: `App/Sources/MoleEngine/Models/StorageModels.swift`
- Create: `App/Sources/MoleEngine/Models/CleanCategory.swift`
- Create: `App/Sources/MoleEngine/Models/TreemapNode.swift`
- Create: `App/Sources/MoleEngine/MoleCoordinator.swift`
- Test: `App/Tests/MoleEngineTests/CoordinatorTests.swift`

**Interfaces:**
- Consumes: Swift 5.9+ `@Observable` Observation framework, `ProcessStreamer`, `SafeTrash`
- Produces:
  - `@Observable class MoleCoordinator`: Central state holder for scans, cleanup, and live status
  - `MoleCoordinator.scanReclaimableSpace() async throws`
  - `MoleCoordinator.performSafeCleanup(categories:[CleanCategory]) async throws`

- [ ] **Step 1: Write failing test for coordinator state tracking and category calculation**

```swift
// App/Tests/MoleEngineTests/CoordinatorTests.swift
import XCTest
@testable import MoleEngine

@MainActor
final class CoordinatorTests: XCTestCase {
    func testCategoryAggregation() {
        let coordinator = MoleCoordinator(isMock: true)
        let categories = [
            CleanCategory(id: "xcode", title: "Xcode Caches", bytes: 10_000_000, isSafe: true),
            CleanCategory(id: "logs", title: "System Logs", bytes: 5_000_000, isSafe: true)
        ]
        coordinator.updateCategories(categories)
        XCTAssertEqual(coordinator.totalReclaimableBytes, 15_000_000)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --package-path App --filter CoordinatorTests`
Expected: FAIL.

- [ ] **Step 3: Implement `@Observable` state models and `MoleCoordinator`**

Create `MoleCoordinator` coordinating asynchronous disk exploration (`cmd/analyze --json`), live metrics (`cmd/status --json`), and category safe cleanup.

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --package-path App --filter CoordinatorTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add App/Sources/MoleEngine/Models/ App/Sources/MoleEngine/MoleCoordinator.swift App/Tests/MoleEngineTests/CoordinatorTests.swift
git commit -m "feat(coordinator): add @Observable state models and MoleCoordinator engine"
```

---

### Task 6: Liquid Glass Design System Components (`MoleUI`)

**Files:**
- Create: `App/Sources/MoleUI/Theme/GlassTheme.swift`
- Create: `App/Sources/MoleUI/Components/VisualEffectView.swift`
- Create: `App/Sources/MoleUI/Components/AdaptiveGlassContainer.swift`
- Create: `App/Sources/MoleUI/Components/SpecularBorder.swift`
- Create: `App/Sources/MoleUI/Components/StorageGaugeBar.swift`
- Test: `App/Tests/MoleUITests/GlassThemeTests.swift`

**Interfaces:**
- Consumes: SwiftUI, AppKit `NSVisualEffectView`, `@Environment(\.accessibilityReduceTransparency)`
- Produces:
  - `AdaptiveGlassContainer`: Respects transparency and contrast accessibility overrides
  - `SpecularBorder`: Apple-grade specular glass inner stroke
  - `StorageGaugeBar`: Smooth multi-segment storage bar (Used, Reclaimable, Free)

- [ ] **Step 1: Write failing test for theme color tokens and accessibility adaptations**

```swift
// App/Tests/MoleUITests/GlassThemeTests.swift
import XCTest
import SwiftUI
@testable import MoleUI

final class GlassThemeTests: XCTestCase {
    func testGlassCornerRadius() {
        XCTAssertEqual(GlassTheme.cardRadius, 12.0)
        XCTAssertEqual(GlassTheme.specularLineWidth, 0.5)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --package-path App --filter GlassThemeTests`
Expected: FAIL.

- [ ] **Step 3: Implement Liquid Glass components in `App/Sources/MoleUI/`**

Build `VisualEffectView`, `AdaptiveGlassContainer`, `SpecularBorder`, and `StorageGaugeBar` with Apple Liquid Glass aesthetics.

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --package-path App --filter GlassThemeTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add App/Sources/MoleUI/ App/Tests/MoleUITests/
git commit -m "feat(ui): implement Liquid Glass design system and accessible materials"
```

---

### Task 7: Navigation & Core Views Implementation

**Files:**
- Create: `App/Sources/MoleUI/Views/SidebarView.swift`
- Create: `App/Sources/MoleUI/Views/CleanView.swift`
- Create: `App/Sources/MoleUI/Views/AnalyzeTreemapView.swift`
- Create: `App/Sources/MoleUI/Views/SoftwareView.swift`
- Create: `App/Sources/MoleUI/Views/OptimizeView.swift`
- Create: `App/Sources/MoleUI/Views/StatusView.swift`
- Create: `App/Sources/MoleUI/Views/HistoryView.swift`
- Test: `App/Tests/MoleUITests/NavigationTests.swift`

**Interfaces:**
- Consumes: `MoleCoordinator`, `AdaptiveGlassContainer`, `StorageGaugeBar`
- Produces: Complete native macOS app window view hierarchy with 6 distinct workflows and segmented Clean/Analyze dual-view.

- [ ] **Step 1: Write failing test for navigation item selection and view routing**

```swift
// App/Tests/MoleUITests/NavigationTests.swift
import XCTest
@testable import MoleUI

final class NavigationTests: XCTestCase {
    func testNavigationWorkflowItems() {
        let items = NavigationWorkflow.allCases
        XCTAssertEqual(items.count, 6)
        XCTAssertEqual(items[0], .clean)
        XCTAssertEqual(items[1], .analyze)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --package-path App --filter NavigationTests`
Expected: FAIL.

- [ ] **Step 3: Implement Views in `App/Sources/MoleUI/Views/`**

- `SidebarView`: Vibrancy navigation sidebar with live storage pill.
- `CleanView`: Dual-mode segmented control (Category Breakdown cards + Reclaimable Treemap) with 1-click safe cleanup.
- `AnalyzeTreemapView`: Interactive nested-block treemap explorer with drilldown navigation.
- `SoftwareView`: App inventory and leftover container hunter.
- `OptimizeView`: One-tap maintenance tasks (RAM purge, DNS flush, Spotlight index).
- `StatusView`: Live hardware dashboard (CPU, GPU, RAM, Battery, Thermals).
- `HistoryView`: Operations audit log.

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --package-path App --filter NavigationTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add App/Sources/MoleUI/Views/ App/Tests/MoleUITests/NavigationTests.swift
git commit -m "feat(views): implement sidebar suite with dual-mode clean and interactive treemap"
```

---

### Task 8: Sparkle 2 In-App Updates & Guided Onboarding

**Files:**
- Create: `App/Sources/MoleCore/Updates/UpdateManager.swift`
- Create: `App/Sources/MoleUI/Views/OnboardingView.swift`
- Test: `App/Tests/MoleCoreTests/UpdateManagerTests.swift`

**Interfaces:**
- Consumes: Sparkle 2 framework (`SPUStandardUpdaterController`, `SPUUpdaterDelegate`), `SMAppService`, `FullDiskAccess`
- Produces:
  - `UpdateManager`: Sparkle controller with `updater(_:willInstallUpdateOnQuit:immediateRelaunch:)` graceful helper shutdown
  - `OnboardingView`: Guided sheet directing user to grant FDA and authorize helper daemon once

- [ ] **Step 1: Write failing test for update manager delegate lifecycle**

```swift
// App/Tests/MoleCoreTests/UpdateManagerTests.swift
import XCTest
@testable import MoleCore

final class UpdateManagerTests: XCTestCase {
    func testUpdateManagerInitialization() {
        let manager = UpdateManager(feedURL: URL(string: "https://mole.fit/appcast.xml")!)
        XCTAssertNotNil(manager)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --package-path App --filter UpdateManagerTests`
Expected: FAIL.

- [ ] **Step 3: Implement `UpdateManager` and `OnboardingView`**

Wire up Sparkle 2 delegates to request helper shutdown prior to bundle swap. Implement `OnboardingView` with deep links to System Settings.

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --package-path App --filter UpdateManagerTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add App/Sources/MoleCore/Updates/ App/Sources/MoleUI/Views/OnboardingView.swift App/Tests/MoleCoreTests/UpdateManagerTests.swift
git commit -m "feat(updates): integrate Sparkle 2 with graceful helper exit and onboarding flow"
```

---

### Task 9: Automated Upstream Sync & Weekly Release CI Pipeline

**Files:**
- Create: `.github/workflows/upstream-sync.yml`
- Create: `scripts/preflight_check.sh`
- Test: `tests/upstream_sync_contract.bats`

**Interfaces:**
- Consumes: GitHub Actions cron (`0 0 * * 1`), `git merge --no-ff`, `./scripts/check.sh`, Bats, Go, `xcodebuild test`
- Produces: Weekly automated upstream sync, green CI validation gate, and release artifact generation

- [ ] **Step 1: Write failing test verifying preflight check script existence and execution**

```bash
# tests/upstream_sync_contract.bats
setup() {
  load 'test_helper/bats-support/load' || true
}

@test "preflight_check script exists and is executable" {
  [ -x "scripts/preflight_check.sh" ]
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bats tests/upstream_sync_contract.bats`
Expected: FAIL.

- [ ] **Step 3: Implement `.github/workflows/upstream-sync.yml` and `scripts/preflight_check.sh`**

Implement the 4-tier verification suite (CLI audits, Bats tests, Go tests, Swift tests) and the weekly cron workflow.

- [ ] **Step 4: Run test to verify it passes**

Run: `chmod +x scripts/preflight_check.sh && bats tests/upstream_sync_contract.bats`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add .github/workflows/upstream-sync.yml scripts/preflight_check.sh tests/upstream_sync_contract.bats
git commit -m "ci: add automated weekly upstream sync workflow and local preflight runner"
```

---

### Task 10: End-to-End Verification, Decisions Ledger & Principal Review

**Files:**
- Create: `DECISIONS_LEDGER.md`
- Modify: `README.md`
- Test: `scripts/preflight_check.sh`

**Interfaces:**
- Consumes: All completed components from Tasks 1–9
- Produces: A complete, fully verified macOS native application, documented decisions ledger, and final Principal Architect sign-off.

- [ ] **Step 1: Run comprehensive local test preflight**

Run: `./scripts/preflight_check.sh`
Expected: All CLI audits, Bats tests, Go tests, and Swift test suites PASS with code 0.

- [ ] **Step 2: Compile `DECISIONS_LEDGER.md`**

Document all architectural choices made on behalf of the user, their trade-offs, and estimated costs (e.g. `SMAppService.daemon` vs `osascript`, pristine adapters vs modifying upstream CLI, Swift `@Observable` vs Combine).

- [ ] **Step 3: Dispatch Principal macOS Systems Architect subagent for final full-branch review**

Verify all security boundaries, XPC audit tokens, APFS safety, and Liquid Glass HIG conformance.

- [ ] **Step 4: Commit**

```bash
git add DECISIONS_LEDGER.md README.md
git commit -m "docs: compile decisions ledger and finalize release candidate"
```
