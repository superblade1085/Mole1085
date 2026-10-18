---
paths:
  - "bin/optimize.sh"
  - "lib/optimize/*.sh"
  - "tests/optimize*.bats"
---

# `mo optimize`

- `lib/optimize/tasks.sh` owns optimize task registration and system maintenance actions. Run `MOLE_TEST_NO_AUTH=1 bats tests/optimize.bats tests/optimize_db.bats tests/optimize_removal_outcomes.bats tests/optimize_catalog.bats`.
- No optimize task rebuilds LaunchServices, because re-registering every app made a running Network Extension VPN read as reinstalled; `default optimize never rebuilds LaunchServices` in `tests/optimize_catalog.bats` refuses a registered `launch_services_rebuild` task and any `lsregister -r` call under `lib` or `bin`.
- Preference repair and optimize cleanup must skip protected and whitelisted plists before attempting removal.
- Spotlight orphan-rule optimization must parse a complete typed snapshot before resolving apps and recheck the snapshot immediately before writing. A failed indexed plist read is not evidence that the array ended. Locked by `tests/optimize.bats`.
- The CoreDuet WAL/SHM rule is a Critical Safety Rule in `AGENTS.md`.
