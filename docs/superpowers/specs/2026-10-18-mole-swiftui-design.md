# Mole for Mac (Open-Source Native Edition) — Architectural Specification

**Document Path:** `docs/superpowers/specs/2026-10-18-mole-swiftui-design.md`  
**Date:** 2026-10-18  
**Minimum Target:** macOS 14.0+ (Sonoma, Sequoia, and future macOS releases)  
**Status:** Hardened Specification (Post-Principal Architect Review)  

---

## 1. Intent & Purpose
A high-performance, open-source native macOS utility that helps users reclaim disk space, manage software, optimize system performance, and monitor hardware telemetry safely, transparently, and with an exquisite macOS user experience.

The app pairs the proven, safety-hardened cleanup and optimization engine of `tw93/Mole` and `Mole1085` with an ultra-polished, forward-compatible SwiftUI application built to the latest Apple Liquid Glass design language.

---

## 2. Goals, Non-Goals, and Anti-Goals

### Goals
* **Frictionless, Native Privilege Architecture:** Zero repetitive admin password prompts. Use a modern Apple `SMAppService.daemon` privileged helper installed once with user consent at initial setup, communicating over typed XPC, that persists and survives Sparkle 2 app updates seamlessly.
* **Liquid Glass Aesthetic & Modern macOS Design:** Cutting-edge macOS design using native materials (`.ultraThinMaterial`, vibrancy sidebars, SF Symbols 6, smooth depth, dynamic light/dark theming, and responsive spring animations) built on macOS 14+ `@Observable` architecture.
* **Bulletproof Safety & Accidental Deletion Immunity:** Multi-layered defense preventing any accidental data loss:
  1. Mandatory pre-clean calculation & dry-run simulation mode.
  2. Granular confirmation sheets with clear path listings.
  3. All deletions routed through macOS `FileManager.default.trashItem` with automatic APFS cross-volume resolution and recovery capability.
  4. Immutable path protection guarding Apple SIP directories, user documents, active developer state, running application caches, and SQLite WAL/SHM sidecars.
  5. Dataless/iCloud eviction protection (`SF_DATALESS` check) ensuring scans never trigger unwanted multi-gigabyte cloud downloads.
* **Forward-Compatible Decoupled Architecture:** Clean boundary between the SwiftUI presentation layer, the Swift engine coordinator, and the underlying `Mole1085` shell/Go engines. Upstream CLI files remain pristine in `lib/`, with dedicated adapters in `lib/adapters/`, so weekly upstream merges from `tw93/Mole` drop in without merge conflicts.
* **Hybrid Storage Discovery (A + C):**
  * **Clean View:** High-level storage pulse meter, safe reclaimable estimate, categorized review cards (Developer, App Caches, Logs, Leftovers), and one-tap safe clean.
  * **Analyze View:** Interactive, fluid DaisyDisk-style nested treemap explorer with drilldown navigation and large file filtering.
* **Continuous Upstream Sync & Weekly Automated Builds:** Automated weekly GitHub Actions checking upstream `tw93/Mole`, running comprehensive regression tests, compiling universal binaries, and publishing updates via Sparkle 2.
* **Strict Quality Gates:** Enforce local test-runner preflights, 100% green CI before merge, and strict merge push (`git merge --no-ff`).

### Non-Goals
* **No Closed-Source Restrictions / Paid Licences:** 100% open-source software under MIT / GPLv3.
* **No Unsolicited Telemetry:** All telemetry and operation logs remain strictly local on the user's Mac.
* **No Kernel Extensions or Invasive System Hooks:** Operates strictly within modern userland and standard privileged helper daemon APIs.

### Anti-Goals
* **Never Guess on Cleanup Targets:** No generic wildcard deletions (`rm -rf *`). Every item deleted must be backed by exact bundle IDs, verified rebuildable paths, or explicit user intent.
* **Never Disrupt In-Use Databases:** Never vacuum, touch, or unlink live SQLite databases (e.g., CoreDuet, PowerLog) while connections are active.
* **Never Degrade User Trust with Surprise Password Prompts:** Privilege elevation must be settled once at onboarding and maintained transparently.

---

## 3. UI/UX Architecture & Liquid Glass Design

### Visual Language
* **Window Hierarchy:** Modern split-view window with native macOS vibrancy and blurred translucency (`NSVisualEffectView`, SwiftUI `.background(.ultraThinMaterial)`).
* **Typography & Iconography:** Apple SF Pro display typography with hierarchical weight scales; SF Symbols 6 with multicolor and variable rendering states.
* **Liquid Glass Accents:** Subtle ambient specular borders (`LinearGradient` with subtle opacity), contextual status pills, and interactive hover highlights that react fluidly to pointer movements.
* **Accessibility Overrides (HIG Mandate):** Automatic fallback styling reacting to `@Environment(\.accessibilityReduceTransparency)` and `@Environment(\.accessibilityIncreaseContrast)` to ensure 100% legibility under all user visual configurations.

### Navigation Hierarchy
* **Sidebar (Left, 220px):**
  * 🐹 **Mole Mac** (Header with system badge and storage gauge).
  * 🧹 **Clean** (Default view): Dual-mode (Category Cards & Reclaim Summary).
  * 📊 **Analyze**: Full disk interactive treemap & largest files explorer.
  * 📦 **Software**: Complete App Uninstaller, leftover file scanner, and startup Launch Agent manager.
  * ⚡ **Optimize**: Safe one-tap maintenance tasks (RAM purge, DNS flush, Spotlight index, LaunchServices rebuild).
  * 📈 **Status**: Real-time hardware dashboard (CPU, GPU, RAM, Disk I/O, Network, Battery health, Thermals).
  * 📜 **History**: Interactive audit log viewer backed by `operations.log`.

### Dual-Mode Storage Explorer
* Inside the **Clean** tab, a top segmented switch allows toggling between:
  1. **Category Breakdown:** Grouped by Developer Tools (Xcode, Homebrew, Cargo, Docker, npm), System & User Caches, App Leftovers, and System Logs. Each card displays an explicit safety guarantee tag (*Guaranteed Safe*, *Rebuildable*, *Dead Leftover*).
  2. **Reclaimable Treemap:** Shows a color-coded visual proportional treemap of the cleanable junk files, allowing visual selection of which categories to purge.

---

## 4. Technical Architecture & Component Design

```
┌────────────────────────────────────────────────────────┐
│              SwiftUI Presentation Layer                │
│    (Observation @Observable · Liquid Glass · Views)    │
└───────────────────────────┬────────────────────────────┘
                            │ Swift Concurrency (AsyncStream / Coalesced 60Hz)
┌───────────────────────────▼────────────────────────────┐
│              MoleEngine Coordinator (Swift)            │
│   (Data Contracts · JSON Parsing · Process Groups)     │
└─────────────┬────────────────────────────┬─────────────┘
              │ Unprivileged User IPC      │ Secure XPC (Audit Token Validated)
┌─────────────▼──────────────┐ ┌───────────▼──────────────────────────┐
│  Unprivileged CLI Workers  │ │  Privileged Helper Daemon            │
│  - cmd/analyze (Go --json) │ │  (SMAppService.daemon · KeepAlive:0) │
│  - cmd/status (Go --json)  │ │  - SecRequirementRef Peer Validation │
│  - lib/clean/ (User scan)  │ │  - Root cache purge (/Library/Caches)│
│  - lib/uninstall/          │ │  - Kernel RAM purge (/usr/sbin/purge)│
│  - Full Disk Access (FDA)  │ │  - Graceful exit for Sparkle updates │
└────────────────────────────┘ └──────────────────────────────────────┘
```

### 4.1 Privileged Helper Tool (`SMAppService.daemon`) & XPC Security
* **Lifecycle & Placement:**
  * Utilizes Apple's modern `SMAppService.daemon(plistName:)` API (macOS 13+).
  * Launchd property list installed in `<AppBundle>/Contents/Library/LaunchDaemons/com.mole.helper.plist`.
  * `KeepAlive: false` with `MachServices` socket activation, ensuring zero background memory footprint when idle.
* **Cryptographic XPC Peer Validation (Zero-Trust):**
  * In the daemon's `NSXPCListenerDelegate`, validate client connections using `audit_token_t`:
  * Extracts calling code via `SecCodeCopyGuestWithAttributes`.
  * Verifies caller matches the Designated Requirement:
    ```
    anchor apple generic and identifier "com.mole.MoleApp" and
    (certificate leaf[field.1.2.840.113635.100.6.1.9] /* Developer ID */ or
     certificate 1[field.1.2.840.113635.100.6.2.6] /* Apple Development */) and
    certificate leaf[subject.OU] == "$DEVELOPMENT_TEAM_ID"
    ```
  * Rejects any non-conforming callers immediately, completely preventing Local Privilege Escalation (LPE) vulnerabilities.
* **Principle of Least Privilege:**
  * 90% of user-space cleanups (user caches, dev toolchains, user uninstalls) run as the unprivileged user.
  * The root daemon is restricted exclusively to tasks strictly requiring `uid=0` (system logs in `/private/var`, `/usr/sbin/purge`, global daemons).
* **Sparkle 2 Seamless Bundle Swap:**
  * Implements `getHelperVersion(reply:)` and `requestGracefulShutdown(reply:)`.
  * In `SPUUpdaterDelegate.updater(_:willInstallUpdateOnQuit:immediateRelaunch:)`, the main app signals the daemon to exit cleanly before Sparkle swaps the application bundle, preventing busy-file lock errors.
  * Survives app updates without re-registering: `SMAppService` registrations bind to the bundle identifier and team ID, so no redundant authorization prompts occur.

### 4.2 Security, Entitlements & TCC Full Disk Access (FDA)
* **Hardened Runtime Entitlements (`MoleApp.entitlements`):**
  * App Sandbox is **omitted** (mandatory for deep system maintenance, package receipts, and volume inspection).
  * Hardened Runtime enabled with `com.apple.security.network.client` (for Sparkle updates).
* **The Root TCC Paradox & Process Lineage:**
  * `root` does **not** bypass macOS TCC (SystemPolicyAllFiles).
  * TCC permissions are granted to the App Bundle ID (`com.mole.MoleApp`), not to independent launchd daemons.
  * **All TCC-governed filesystem scans (Safari caches, Mail containers, CloudTabs) must execute within the main app's user process space**, never delegated to the launchd helper.
* **Non-Prompting Heuristic FDA Detection:**
  * Detect FDA status without triggering false permission dialogs by testing access to an existing TCC-gated path:
    ```swift
    func checkFullDiskAccess() -> Bool {
        let safariPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Safari").path
        guard let dir = opendir(safariPath) else {
            return errno != EPERM && errno != EACCES
        }
        closedir(dir)
        return true
    }
    ```
  * Deep link directly to macOS System Settings:
    `x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles`
    and `SMAppService.openSystemSettings_LoginItems()`.

### 4.3 Filesystem, APFS & Bulletproof Deletion Safety
* **Cross-Volume Native Trashing:**
  * Replaces shell `mv` with native Cocoa `FileManager.default.trashItem(at:resultingItemURL:)`.
  * Automatically moves files to local `.Trashes/<uid>/` on external or secondary APFS volumes, eliminating multi-gigabyte cross-volume copies.
  * Inspects `volumeSupportsTrashKey` before deletion; alerts user if volume requires explicit permanent deletion.
* **Dataless File (`SF_DATALESS`) & iCloud Eviction Protection:**
  * Checks `NSURLIsUbiquitousItemKey` and `st_flags & SF_DATALESS`.
  * Prevents scanners from opening dataless file descriptors, avoiding accidental multi-gigabyte background iCloud file downloads.
* **APFS Clone Awareness:**
  * Queries `NSURLTotalFileAllocatedSizeKey` to distinguish logical size from physical storage extent savings.
* **Active Application & Database Protection:**
  * Queries `NSRunningApplication.runningApplications(withBundleIdentifier:)` before cleaning application caches.
  * Atomically groups `.db`, `.db-wal`, and `.db-shm` files; never unlinks SQLite companions individually.
  * Explains APFS Time Machine snapshot space pinning if free space does not immediately reflect deleted bytes (`tmutil listlocalsnapshots /`).

### 4.4 IPC Performance & High-Frequency UI Streaming
* **Subprocess Output Streaming:**
  * Wraps CLI child processes in `AsyncThrowingStream` over `Pipe` reading.
* **Temporal Coalescing / Display Throttler (60 Hz):**
  * Decouples raw scanner line processing (up to 20,000 files/sec) from UI state mutation.
  * Accumulators flush to SwiftUI `@Observable` models at 60 Hz (every 16ms), guaranteeing 120 fps ProMotion rendering without CPU starvation.
* **Process Group Cleanup:**
  * Spawns child processes in their own process group (`setpgid`).
  * On cancellation, signals the entire process group (`kill(-pgid, SIGTERM)`) to prevent orphaned zombie workers.

---

## 5. Upstream Synchronization & Weekly Automation Pipeline

### Repository Topology & Decoupled Adapters
* **Monorepo Layout:**
  ```
  Mole1085/
  ├── bin/                 # Upstream Mole CLI entrypoints (Pristine)
  ├── cmd/                 # Upstream Go modules (analyze, status - Pristine)
  ├── lib/                 # Upstream shell engines (Pristine)
  ├── adapters/            # Dedicated JSON streaming adapters for UI
  ├── App/                 # Native macOS SwiftUI Application
  │   ├── MoleApp/         # SwiftUI Views, Liquid Glass ViewModels
  │   ├── MoleEngine/      # Swift IPC Coordinator & Process Streamer
  │   ├── MoleHelper/      # SMAppService Privileged Helper Daemon
  │   └── MoleApp.xcodeproj
  ├── .github/workflows/   # CI/CD, Upstream Sync, Weekly Builds
  └── scripts/             # Safety audits, formatters, test runners
  ```

### Weekly Upstream Sync & Build Cron (GitHub Actions)
* Runs weekly (every Monday at 00:00 UTC).
* **Step 1: Upstream Sync (Pristine Merge):**
  ```bash
  git remote add upstream https://github.com/tw93/Mole.git || true
  git fetch upstream main
  git merge --no-ff upstream/main -m "chore(sync): automated weekly merge from upstream tw93/Mole"
  ```
* **Step 2: Automated Verification Gate:**
  * Run CLI audits: `./scripts/check.sh --no-format`
  * Run Bats test suite: `MOLE_TEST_NO_AUTH=1 ./scripts/test.sh`
  * Run Go test suite: `go test ./...`
  * Run Swift unit & UI test suite: `xcodebuild test -scheme MoleApp`
* **Step 3: Build & Release Packaging:**
  * If all tests pass: compile Universal 2 (Apple Silicon + Intel) app bundle.
  * Sign with Developer ID and notarize with Apple.
  * Generate Sparkle 2 EdDSA delta updates and update the appcast XML feed.
  * Create a GitHub Release with automated changelog.
* **Step 4: Safe Failure Handling:**
  * If tests fail or merge conflicts arise: halts, pushes no tags, and automatically logs a detailed triage issue.

---

## 6. Local Development & Merge Protocol
* **Strict Pre-Commit Verification:** Developers must run local validation before pushing:
  ```bash
  ./scripts/check.sh --no-format
  MOLE_TEST_NO_AUTH=1 ./scripts/test.sh
  go test ./...
  swift test
  ```
* **Git Protocol:** Strict merge push policy (`git merge --no-ff`, no force pushes to `main`).

---

## 7. What Is Left to the Builder
* Final SwiftUI layout spacing and color token selections matching Apple Human Interface Guidelines.
* Iconography and custom vector illustrations for categories and status meters.
