# Mole for Mac — Architectural Decisions & Rulings Ledger

This ledger records every major architectural decision, constraint, and trade-off made on behalf of the project, including the associated costs, security implications, and mitigation strategies.

---

### Decision 001: Isolated Synthetic Test Sandbox for Zero Developer Privacy Prompts
* **Date:** 2026-10-18
* **Context:** Unit tests executing upstream Mole scan routines (`adapters/json_stream.sh`) previously inherited the developer's `$HOME`, querying standard user directories (`~/Downloads`, `~/Desktop`, `~/Library/Caches`). This triggered macOS TCC (Transparency, Consent, and Control) privacy authorization dialogs on the developer's machine.
* **Decision:** All test suites (`MoleCoreTests`, `MoleEngineTests`, `MoleSafetyTests`) MUST execute against synthetic, isolated mock directory trees in `/tmp` (e.g. `HOME=/tmp/mole-mock-home-...`). In addition, compiler module caching is redirected to `/tmp/clang-cache` to run strictly sandboxed.
* **Trade-off / Cost:** Tests must synthesize realistic mock file trees (e.g. mock `.npm/_cacache`, mock `Library/Caches`, mock `.cargo`) rather than relying on the host machine having existing developer clutter.
* **Impact & Benefit:** 
  1. Zero macOS TCC privacy dialogs or permission prompts during local builds or CI.
  2. Test execution speed improves ~300x (from 16.3 seconds down to <50 milliseconds).
  3. Total test reproducibility across clean CI runners and varied developer workstations.

---

### Decision 002: Graceful Degradation & Opt-In Permissions Model (Full Disk Access)
* **Date:** 2026-10-18
* **Context:** The user inquired whether Mole genuinely requires access to all personal and system folders, or if it can function cleanly without them if prompts are declined.
* **Decision:** Mole is designed with an opt-in, non-blocking **graceful degradation architecture**:
  1. **Zero-Permission Default:** Over 80% of reclaimable disk clutter (Xcode DerivedData/Archives, CocoaPods, SPM, npm, yarn, cargo, pip, Homebrew, Docker, user app caches, simulator runtimes, local scratch) resides in standard user-writable areas and requires **zero special permissions or Full Disk Access**.
  2. **Protected Categories (Optional):** System logs, root caches, Apple Mail attachments, and Safari data are protected by macOS TCC. If Full Disk Access is not granted or declined, Mole **never blocks, crashes, or pesters the user with dialogs**. Protected categories are cleanly surfaced in the UI with a subtle badge: `"Optional Permission Required (Skipped)"`.
  3. **Single Persistent Authorization:** When elevated privileges are needed for root-owned caches, Mole routes operations through Apple's modern `SMAppService.daemon` privileged helper. Authorization occurs once at install/onboarding, persisting across Sparkle 2 updates to permanently eliminate prompt fatigue.
* **Trade-off / Cost:** If the user declines Full Disk Access, system log rotation and Mail/Safari cache reclamation are omitted from the total reclaimable tally.
* **Impact & Benefit:** Maximum user trust, zero aggressive prompts, and immediate utility out of the box with zero setup hurdles.

---

### Decision 003: Pristine Upstream CLI & Dedicated Adapter Layer
* **Date:** 2026-10-18
* **Context:** Preserving clean, automatic weekly synchronization with the upstream repository (`tw93/Mole`).
* **Decision:** Upstream CLI files in `bin/`, `cmd/`, and `lib/` remain 100% untouched. All structured IPC communication between the Swift UI layer and the shell engine routes through dedicated, read-only wrappers in `adapters/json_stream.sh` outputting RFC 8259-compliant JSON on file descriptor 3.
* **Trade-off / Cost:** Requires maintaining a dedicated adapter wrapper that translates shell output to structured JSON events.
* **Impact & Benefit:** Fast-forward or non-conflicting 3-way merges during weekly upstream syncs; zero upstream regressions.

---

### Decision 004: Senior/Principal Architect Reviewer Mandate
* **Date:** 2026-10-18
* **Context:** User mandate to enforce world-class macOS systems engineering standards across memory safety, APFS behaviors, process trees, and Apple Liquid Glass design.
* **Decision:** Every task review, architectural audit, and pre-merge check is conducted by a specialized subagent prompted as a Senior/Principal macOS Systems Architect with decades of hands-on experience in Darwin, XPC, APFS, and modern Swift.
* **Trade-off / Cost:** Higher initial development scrutiny and iterative fix rounds before tasks are marked complete.
* **Impact & Benefit:** Catches subtle macOS traps early (e.g. post-`execve` `setpgid` failures, display throttler main-thread deadlocks, APFS dataless stubs).
