# Mole for Mac (Open-Source Edition) — Development Rules & Memory

## Senior / Principal Reviewer Mandate
For all future developments, changes, refactors, and updates:
* Every reviewer agent dispatched for code reviews, architectural validations, plan audits, or pre-merge checks MUST always be prompted and configured as a **Senior or Principal Architect / Engineer** with decades of specialized, hands-on experience in that specific field, domain, operating system, technology, runtime, or cloud architecture applicable to the scenario.
* Reviewers must evaluate changes against production realities: security, binary lifecycles, memory safety, IPC, APFS behavior, TCC/Full Disk Access, Sparkle updates, and upstream synchronization.

## Senior Designer & Quality Check Mandate
* Never present any UI, mockup, visual artifact, or design deliverable without first performing an exhaustive, hands-on quality check (layout integrity, zero overlapping symbols/icons, zero truncated/wrapping badges, correct responsive bounds, and precise color harmony).
* When designing, reviewing, or validating UI deliverables, always configure and dispatch a **Senior or Principal Design Architect / Lead Apple HIG Designer** to audit layouts, typography, spacing, and interaction before presenting to the user.

## Project Architecture & Engineering Mandates
* **Stack:** Native macOS Swift / SwiftUI targeting macOS 14.0+ (Sonoma/Sequoia) using modern `@Observable` state management and Apple Liquid Glass design standards (`.ultraThinMaterial`, SF Symbols 6, vibrancy).
* **Privilege Architecture:** Use Apple's modern `SMAppService.daemon` with zero-trust XPC peer audit token verification (`SecCodeCopyGuestWithAttributes`). Minimize admin prompts; helper persists and survives Sparkle 2 updates seamlessly.
* **Deletion Safety:** Never use generic wildcards. Deletions route strictly through native `FileManager.default.trashItem(at:resultingItemURL:)` for APFS cross-volume awareness. Prohibit unlinking live SQLite WAL/SHM companion files, and guard against dataless/iCloud stubs (`SF_DATALESS`).
* **Upstream Synchronization:** Upstream CLI files in `bin/`, `cmd/`, and `lib/` must remain pristine. Adapters live in `adapters/`. Weekly automated sync with `tw93/Mole` must run comprehensive checks (`check.sh`, Bats, Go, and Swift tests).
* **Git Protocol:** Always use merge commits (`git merge --no-ff`) and verify green local and CI test suites before pushing.
