---
paths:
  - "bin/purge.sh"
  - "bin/installer.sh"
  - "lib/clean/project.sh"
  - "lib/clean/purge_shared.sh"
  - "lib/manage/purge_paths.sh"
  - "tests/purge*.bats"
  - "tests/purge_menu_pty.py"
  - "tests/installer*.bats"
---

# `mo purge` and `mo installer`

## Purge (`lib/clean/project.sh`)

- `lib/clean/project.sh` owns purge discovery, project artifact filtering, purge menus, and purge config. Run `MOLE_TEST_NO_AUTH=1 bats tests/purge.bats tests/purge_config_paths.bats`.
- **Git worktree staleness is not decidable.** Clean only whitelisted rebuildable artifacts inside a worktree, never the worktree itself, and never emit a "safe to delete" verdict. Branch/remote heuristics fail on detached worktrees, ordinary status hides ignored files, and ignored entries may be the only copy of private state. A status surface may report blockers only: dirty, unpushed, locked, or ignored entries outside `MOLE_PURGE_TARGETS`.
- Purge discovery skips dot-directory containers by design. Add each supported container, such as `~/.codex/worktrees`, explicitly to `MOLE_PURGE_DEFAULT_SEARCH_PATHS`; do not broaden discovery to all dot directories. The scan layer already handles hidden descendants once their parent container is known, while project roots deeper than the existing two-level probe remain intentionally out of scope.
- **A purge target is never a container.** `is_project_container` rejects any basename in `MOLE_PURGE_TARGETS`, not a separately maintained list of package directories, so a stray `~/node_modules`, `vendor/`, or `Pods/` is never scanned as a set of project roots whose internal `dist/` and `build/` reach the delete list. A directory that legitimately shares an artifact name stays reachable by listing it in `~/.config/mole/purge_paths`, which bypasses discovery; do not add a flag for it. This one probe is the whole surface: the other three scan-root entry points in `lib/clean/project.sh` are the maintainer default list, the user config file, and the consumer of discovery. Locked by the two `#1459` tests in `tests/purge.bats`; the story is in `.claude/skills/bugs/references/deletion-evidence-and-final-sink.md` section 13.
- **Purge candidate protection.** Purge candidates with deployment keypair files, nested Git repositories, or Git-tracked content are protected at discovery and immediately before deletion.
  - Use physical Git ancestry, a full-path `:(top,literal,icase)` pathspec from `mole_git_path_spec` (literal so glob characters match nothing else, case-blind because the default volume is case-insensitive and the index may keep another spelling of a renamed folder), inherited pathspec switches unset, and disabled fsmonitor hooks.
  - The content walk runs on the tree-walk budget (`MOLE_TIMEOUT_HINT_SCAN_SEC`), and a probe that times out or fails is status 2, not evidence: the candidate is kept, discovery passes it through, the review step prints `Could not inspect X; kept` and marks the run incomplete, and the sink still refuses it. Signals remain cancellation statuses through Git/find probes, protection predicates, workers, review, and the final sink; never collapse them into status 2 or a normal protected result. Never fold that state into a silent drop.
  - Discovery runs these probes in a pool of at most four per root and publishes them in input order only after every probe finished; a missing result counts as unverified, and a scan cancelled during its last probes makes the filter return 130 with nothing written. `scan_purge_targets` writes the verified sidecar only when its caller names one as a third argument, and that caller removes it. The review before the menu reuses discovery's clean verdict from the same run and walks again only candidates without one; the recheck before removal and the final sink guard always probe afresh.
  - Non-interactive purge requires explicit `--yes`; `--dry-run` remains read-only without it.
  - Locked in `tests/purge.bats` by `purge content probes never run more than four at a time and keep input order past the pool`, `purge content probe signal inside a full pool stops the filter with nothing published`, `purge content probe filter publishes nothing when the sentinel goes away during the last probes`, `scan_purge_targets leaves a verified sidecar only for the caller that names one` and, for the pathspec, `purge protects tracked source under a folder renamed only in case`.

## Installer (`bin/installer.sh`)

- `bin/installer.sh` owns installer discovery, immutable delete-plan validation, the paginated selection flow, and incomplete-cleanup exit semantics. Run `MOLE_TEST_NO_AUTH=1 bats tests/installer.bats tests/installer_fd.bats tests/installer_zip.bats`.
