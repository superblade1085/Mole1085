# Design Specification: Simulation Engine, Safety Insurance & Neutral macOS Design Language

**Date:** 2026-10-18  
**Target:** Mole for Mac (Open-Source Edition)  
**Status:** Approved by Principal Architect Review (Ready for User Sign-Off)  
**Location:** `docs/superpowers/specs/2026-10-18-simulation-engine-and-neutral-ui-design.md`

---

## 1. Intent & The Why

Users running system cleanup and clutter reclamation utilities face inherent anxiety: *"What if this deletes something important, breaks my apps, or cannot be undone?"*

Standard cleanup tools often present either an opaque "Clean" button with no advance clarity, or a bewildering list of technical file paths. Mole for Mac solves this by introducing a **Simulation Engine ("Clean Preview")** paired with an **Insurance Policy ("Undo & Rollback Safety Net")**, wrapped in a calm, restrained, **neutral Apple design language** inspired by MacSpace and native macOS System Settings.

The user must always be able to:
1. See clearly what they currently have and what they will achieve before touching disk state.
2. Receive a plain-English preview of planned actions with automated confirmation that no active databases, locks, or iCloud files are at risk.
3. Enjoy an ironclad insurance policy: every clean operation is reversible with One-Click Trash Restore, supplemented by an instant APFS local system snapshot.
4. Experience a cohesive, quiet, professional macOS interface that avoids candy-colored visual noise, relying on crisp typography, neutral slates, subtle Liquid Glass materials, and symbols with hover tooltips.

---

## 2. Goals, Non-Goals & Anti-Goals

### Goals
- **Deterministic Clean Preview (Dry Run):** Execute `adapters/json_stream.sh` in non-destructive simulation mode (`MOLE_DRY_RUN=1`) to project exact reclaimable bytes, category breakdowns, and safety levels without moving or modifying a single byte.
- **Before & After Visual Impact:** Show current storage vs. projected reclaimed storage in a calm, neutral storage gauge bar.
- **Transparent Risk Verification:** Pre-flight inspection confirming 0 active database locks (`DatabaseGuard`), 0 dataless iCloud stub downloads (`DatalessGuard`), and 0 system file touches (`SafeTrash`).
- **Two-Tier Undo & Insurance Safety Net:**
  - **Tier 1 (One-Click Trash Restore):** An atomic JSON session manifest recording `(originalPath, trashedURL, size, timestamp)` for every moved item. An "Undo Last Cleanup" button immediately puts files back to their exact origin.
  - **Tier 2 (APFS Instant Local Snapshot):** Instantaneous Darwin APFS volume snapshot created right before cleanup, providing a zero-cost whole-volume rollback anchor.
- **App-Wide Neutral Design Language:**
  - Refactor `GlassTheme.swift` to replace rainbow accents with an elegant, monochromatic slate/graphite palette and Apple system blue.
  - Replace text-heavy buttons with native SF Symbols paired with hover tooltips (`.help(...)`).
  - Isolate theme toggles (Day / Night / OS Sync) strictly in the Settings workflow, allowing all views and sheets to inherit the theme smoothly.

### Non-Goals
- **Replacing Time Machine or External Backups:** The APFS snapshot is an instant local anchor for recent cleans, not a replacement for full off-site backups.
- **Modifying Upstream CLI Code:** All simulation and dry-run adapters must remain in `adapters/` and `App/`, preserving pristine upstream `bin/`, `cmd/`, and `lib/` files.
- **Custom Window Decorators:** No non-standard window frames. Use standard AppKit / SwiftUI sheets, windows, and system vibrancy.

### Anti-Goals
- **No Candy / Rainbow Clutter:** No garish, competing neon colors that distract or confuse the user.
- **No Developer Jargon in Primary UI:** No raw POSIX error codes, regex strings, or UNIX terms in top-level dialogs. Deep technical paths remain accessible only under secondary disclosure or hover tooltips.
- **No Irreversible Actions:** Zero permanent deletions (`rm -rf` / unlinking is strictly forbidden); all operations route via APFS Cocoa trashing with manifest logging.

---

## 3. Constraints & Technical Foundation

- **Platform:** macOS 14.0+ (Sonoma & Sequoia), Swift 5.10+, Universal 2 (`arm64` & `x86_64`).
- **State Management:** Swift 5.9+ Observation framework (`@Observable`, `@MainActor`).
- **Safety Layer:** Strict enforcement of existing `SafeTrash.swift`, `DatalessGuard.swift`, and `DatabaseGuard.swift`.
- **Theme Support:** Native Light, Dark, and System appearance dynamically honoring `colorScheme` and `accessibilityReduceTransparency`.
- **Testing:** 100% synthetic/isolated unit tests (zero TCC permission popups during test execution).

---

## 4. Human Decisions & Visual Specifications

During the brainstorming dialogue, the user made four explicit design mandates:

1. **Theme Controls Belong Exclusively in Settings:**
   - The theme toggle (Light / Dark / System) must NOT appear on the Clean Preview sheet or main clean view.
   - It is housed in `SettingsView`, and the preview sheet silently inherits the active appearance.
2. **Symbols Over Text Clutter:**
   - Secondary controls, diagnostics, and toggles use native SF Symbols.
   - Descriptive text appears on hover via native macOS tooltips.
3. **Calm, Neutral Color Palette Across the Entire App:**
   - The app must use neutral slate, graphite, and Apple system blue tones, taking direct inspiration from MacSpace and macOS System Settings.
   - The storage gauge uses Apple blue for apps/system, neutral slate for cleanable space, and translucent track for free space.
4. **Insurance Policy Model (Hybrid Dual-Shield):**
   - Routine cleanups provide One-Click Trash Restore via a session manifest.
   - Major cleans automatically offer an APFS snapshot anchor for total peace of mind.

---

## 5. Architectural Components

### 5.1 Domain Models (`MoleEngine`)
```swift
public enum SafetyTier: String, Codable, Sendable {
    case safe = "Safe to Clean"
    case rebuildable = "Can Rebuild"
    case protected = "Protected"
}

public struct SimulationCandidate: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let path: String
    public let sizeBytes: Int64
    public let categoryGroup: CleanCategoryGroup
    public let safetyTier: SafetyTier
    public let riskReason: String?
    public var isSelected: Bool

    public init(
        id: UUID = UUID(),
        path: String,
        sizeBytes: Int64,
        categoryGroup: CleanCategoryGroup,
        safetyTier: SafetyTier,
        riskReason: String? = nil,
        isSelected: Bool = true
    ) {
        self.id = id
        self.path = path
        self.sizeBytes = sizeBytes
        self.categoryGroup = categoryGroup
        self.safetyTier = safetyTier
        self.riskReason = riskReason
        self.isSelected = isSelected
    }
}

public struct SimulationReport: Sendable, Equatable {
    public let diskBefore: DiskSpaceInfo
    public var candidates: [SimulationCandidate]
    public let totalReclaimableBytes: Int64
    public let protectedItemCount: Int
    public let generatedAt: Date

    public var effectiveReclaimableBytes: Int64 {
        candidates.filter { $0.isSelected && $0.safetyTier != .protected }
                  .reduce(0) { $0 + $1.sizeBytes }
    }
}

public struct CleanupSessionManifest: Codable, Sendable {
    public let sessionId: UUID
    public let timestamp: Date
    public let apfsSnapshotName: String?
    public let items: [TrashedItemRecord]
}

public struct TrashedItemRecord: Codable, Sendable {
    public let originalPath: String
    public let trashedURL: URL
    public let sizeBytes: Int64
}

public struct UndoResult: Sendable, Equatable {
    public let restoredCount: Int
    public let restoredBytes: Int64
    public let skippedCollisions: [String]
    public let missingItems: [String]
    public let errors: [String]
}
```

### 5.2 Simulation & Rollback Coordinator (`MoleCoordinator`)
- `simulateCleanup(groups: [CleanCategoryGroup]) async throws -> SimulationReport`:
  Executes `adapters/json_stream.sh` with `DRY_RUN=true` and parses targets without invoking `SafeTrash`.
- `executeCleanupWithInsurance(report: SimulationReport, createSnapshot: Bool) async throws -> CleanupSessionManifest`:
  Takes an optional APFS local snapshot via helper/Darwin APFS APIs, executes `SafeTrash`, writes `CleanupSessionManifest` to `~/Library/Application Support/Mole/Sessions/`.
- `undoCleanup(session: CleanupSessionManifest) async throws -> UndoResult`:
  Restores files from macOS Trash back to `originalPath` with collision safety.

### 5.3 UI Components (`MoleUI`)
- `CleanPreviewSheet`: The modal sheet displaying estimated space savings, neutral storage gauge, risk summary cards, and undo safety options.
- `StorageGaugeBar`: Neutralized color scheme matching MacSpace (Apple system blue, neutral slate, subtle borders).
- `GlassTheme`: Neutralized token definitions (`dev = .secondary`, `systemCaches = .secondary`, `accent = .blue`).
- `SettingsView`: Appearance section offering SegmentedControl (`Light`, `Dark`, `System`) and default undo preference.

---

## 6. What Is Left to the Builder

The builder has full engineering discretion over:
- Concrete APFS snapshot invocation implementation (fallback from `fs_snapshot_create` / `/sbin/mknod` to helper or standard APFS user APIs).
- Display formatting thresholds (e.g. dynamic formatting `GB` vs `MB` in tooltips).
- Coalescing debounce intervals for the simulation progress bar.
- Test fixture synthesis in `/tmp` for simulating trashing and restoration.

---

## 7. Resolution of Principal Architect Invariants

Following the Principal Systems Architect audit, the following engineering decisions have been codified:

### 7.1 APFS Snapshot Lifecycle & Storage Reclamation
1. **Retention & Pruning:** Mole manages local snapshots cooperatively with macOS. Mole tags created snapshots with `com.mole.snapshot.<timestamp>`. Mole automatically purges snapshots older than 24 hours. A "Prune Older Snapshots" action is exposed in History/Status to allow immediate block reclamation when disk space is tight.
2. **Rollback Role:** Tier 1 (One-Click Trash Restore) is Mole's primary in-app restore mechanism. Tier 2 (APFS Snapshot) functions as the system-level insurance anchor; Mole stores the snapshot name in the manifest and provides clear guidance for rolling back via macOS Recovery / Disk Utility if a whole-system revert is needed.

### 7.2 Trash Restoration Conflict Resolution
1. **Collision Safety:** When restoring from Trash, if the target destination already exists (e.g. an application regenerated its cache directory), Mole does **not** clobber or overwrite the live folder. It flags the item as a collision, preserves the current live state, and returns a detailed `UndoResult` summary.
2. **Partial Trash Empties:** If the user or macOS emptied parts of the Trash, `undoCleanup` performs a best-effort restoration of remaining items, cataloging any missing files in `missingItems`.

### 7.3 Major Clean Thresholds & Settings Schema
1. **Major Clean Trigger:** Cleanups projected to reclaim **> 10.0 GB** or touching developer scratch hierarchies automatically pre-select the "Trash + Instant APFS Snapshot" option on the preview sheet.
2. **Settings Schema:** In `SettingsView`, the user can configure `undoPreference: .trashOnly | .hybrid` (defaulting to `.hybrid`).

### 7.4 CleanPreviewSheet Workflow Integration & Selection Mutability
1. **Sheet Presentation:** `CleanPreviewSheet` replaces the legacy confirmation dialog entirely. Clicking "Clean Selected" in `CleanView` presents `CleanPreviewSheet`, which runs the pre-flight simulation and displays the live before/after gauges.
2. **Candidate Mutability:** The preview sheet is interactive. While it defaults to cleaning all selected safe items, the user can uncheck individual items or categories in the preview sheet before clicking "Clean X GB".

### 7.5 Pre-Flight Guardrail Violation Policy (Adherence to Decision 002)
1. **Graceful Exclusion:** Guardrail violations (`DatabaseGuard` SQLite locks, `DatalessGuard` iCloud stubs, `SafeTrash` system path invariants) do **not** block the entire cleanup.
2. **Automatic Protection:** Flagged items are automatically classified as `.protected` with a plain-English `riskReason`, incrementing `protectedItemCount` and being safely bypassed during execution while safe items proceed smoothly.
