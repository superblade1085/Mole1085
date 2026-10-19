# Mole for Mac (Open-Source Edition) — Development Rules & Memory

## 1. Principal Developer & Architect Mandate (Zero Junior Developer Policy)
For ALL future developments, implementations, architectures, workflows, and changes across all projects:
* **All development work MUST strictly be executed with the mindset, rigor, and depth of a Principal Developer or Principal Architect** with decades of specialized, hands-on experience in that specific language, runtime, domain, operating system, and architecture (backend, frontend, UI/UX, database, systems, networking, or API).
* **Under no circumstances should any development or implementation ever be delegated to, treated as, or executed with the mindset of a junior developer.**
* **Zero-Tolerance for Shortcuts:** No mock data, synthetic stubs, simulated sleeps (`Task.sleep`, `time.sleep`, `Thread.sleep`), placeholder shortcuts, surface-only mockups, or unverified assumptions are permitted in production or deployable code.
* **Production vs Test Isolation:** Mock modes (e.g., `isMock: Bool`, `useTestData: Bool`) must **NEVER** be embedded inside production domain models, coordinators, or view layers. Mocks belong strictly inside isolated test targets, test doubles, or test fixtures—never shipped in production code.

## 2. End-to-End Backend Wiring & Real Execution Mandate
* **No Orphaned or Hollow UIs:** Any user interface, presentation view, or wrapper component MUST be fully wired end-to-end to real domain logic, real APIs, real CLI tools, or real database pipelines from inception.
* **Backend-First Rule:** If a backend API, CLI command, engine adapter, or system capability does not yet exist or is not yet exposed, the developer MUST implement, expose, and test the real backend/engine interface **BEFORE** building or claiming the UI is complete.
* Faking UI state with hardcoded local arrays (e.g., `@State private var items = [FakeData]`) or fake timers to simulate working features is strictly prohibited. If a dependency blocks completion, it must be flagged as a blocker immediately rather than faked.

## 3. Engineering Integrity & Honest Reporting Mandate
* Task reports, commit messages, PR descriptions, and agent progress updates MUST reflect the literal, verified reality of the code.
* Never report or document that an underlying command, system tool, or API has been implemented (e.g., claiming tools like `/usr/sbin/purge`, `dscacheutil`, or `gh` are invoked) when the code in fact executes a stub, sleep, or simulated delay. Falsifying operational capability violates core engineering integrity.

## 4. Senior/Principal Reviewer & Anti-Myopia Mandate
For all code reviews, architectural validations, plan audits, and pre-merge checks:
* Every reviewer agent dispatched for code reviews, architectural validations, plan audits, or pre-merge checks MUST always be prompted and configured as a **Senior or Principal Architect / Engineer** with decades of specialized, hands-on experience in that specific field, domain, operating system, technology, runtime, or cloud architecture applicable to the scenario.
* **Anti-Myopia Rule:** Reviewers must NEVER restrict their evaluation to narrow prompt questions, superficial aesthetics, or basic compilation checks. Reviewers MUST audit the complete diff and actively search for:
  1. **Authentic Logic vs Simulation:** Actively grep and inspect for `sleep`, hardcoded test collections, unlinked buttons, stubbed callbacks, or disconnected data bindings.
  2. **End-to-End Tracing:** Trace every user action (button click, toggle, command execution) down through the engine/coordinator to the actual system, network, or CLI execution call.
  3. **Real Error & Failure Handling:** Verify how failures, timeouts, and process terminations are handled in real environments.
* Any diff containing simulated sleeps, hardcoded dummy arrays in views, or disconnected UI actions MUST be immediately **REJECTED**.

## 5. Rigorous Integration Testing & Evidence-First Verification
* **Beyond Shallow Schema Tests:** Unit tests that merely verify enum case counts, string labels, or static metadata (e.g., `XCTAssertEqual(items.count, 6)`) provide zero evidence of working system behavior.
* **Contract & Integration Tests Required:** Every user-facing workflow and backend routine must be verified by integration or contract tests exercising real execution paths, real subprocess execution, real schema serialization/deserialization, and real error states.
* **Evidence Before Completion:** Before claiming any feature or bugfix is complete, actual command output, test runs, and system logs must be inspected and verified.

## 6. Senior Designer & Quality Check Mandate
* Never present any UI, mockup, visual artifact, or design deliverable without first performing an exhaustive, hands-on quality check (layout integrity, zero overlapping symbols/icons, zero truncated/wrapping badges, correct responsive bounds, and precise color harmony).
* When designing, reviewing, or validating UI deliverables, always configure and dispatch a **Senior or Principal Design Architect / Lead Apple HIG Designer** to audit layouts, typography, spacing, and interaction before presenting to the user.

## 7. Superpowers Framework Mandate
* For any future build, design, architectural, UI/UX, logic, database, or workflow changes to any app, user interface, or system: you MUST strictly use the **Superpowers framework of skills** (e.g. `using-superpowers`, `verification-before-completion`, `release-flow`, `test-driven-development`, `systematic-debugging`, `executing-plans`, etc.).
* Always invoke the relevant skills from the framework before any response or action, follow their protocols and checklists meticulously, and maintain task tracking artifacts for multi-step progress tracking.

## 8. CLI Application Logic Sovereignty Mandate
* **All application logic, intelligence, discovery heuristics, analysis routines, and cleanup/deletion execution MUST strictly originate from and delegate to the `mole` CLI (the upstream engine).**
* The native Swift/SwiftUI application serves **exclusively** as a presentation and orchestration layer (subprocess lifecycle, async streaming, display throttling, observation state, Liquid Glass UI, and user interaction).
* Under no circumstances should cleaning logic, path selection, safety heuristics, or deletion routines be reimplemented natively in Swift. Whenever an action is performed (analyze, clean, preview, uninstall, optimize, status, history), the Swift engine must invoke the corresponding `mole` CLI command or machine-readable adapter.

## 9. Project Architecture & Engineering Mandates
* **Stack:** Native macOS Swift / SwiftUI targeting macOS 14.0+ (Sonoma/Sequoia) using modern `@Observable` state management and Apple Liquid Glass design standards (`.ultraThinMaterial`, SF Symbols 6, vibrancy).
* **Privilege Architecture:** Use Apple's modern `SMAppService.daemon` with zero-trust XPC peer audit token verification (`SecCodeCopyGuestWithAttributes`). Minimize admin prompts; helper persists and survives Sparkle 2 updates seamlessly.
* **Deletion Safety:** Never use generic wildcards. Deletions route strictly through native `FileManager.default.trashItem(at:resultingItemURL:)` for APFS cross-volume awareness. Prohibit unlinking live SQLite WAL/SHM companion files, and guard against dataless/iCloud stubs (`SF_DATALESS`).
* **Upstream Synchronization:** Upstream CLI files in `bin/`, `cmd/`, and `lib/` must remain pristine. Adapters live in `adapters/`. Weekly automated sync with `tw93/Mole` must run comprehensive checks (`check.sh`, Bats, Go, and Swift tests).
* **Git Protocol:** Always use merge commits (`git merge --no-ff`) and verify green local and CI test suites before pushing.
