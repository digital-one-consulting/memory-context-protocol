# Changelog

All notable changes to this project are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow
[Semantic Versioning](https://semver.org/).

## [0.1.1] — 2026-09-21

### Added
- `init/claude-context-init.md` — the init prompt: ten INIT phases (inventory → verification)
  and five UPDATE phases, stack-agnostic, carrying the four hooks verbatim. Descended from the
  April/June 2026 system guide the protocol began as (README, Lineage).
- `templates/skills/{architecture,domain}/SKILL.md`, `templates/module-CLAUDE.md`,
  `templates/claudeignore` — the on-demand context layer and the ignore file the init prompt
  creates.
- `test/run.sh` pins the init prompt's inline hook copies to `hooks/` (four assertions).
- `install.sh --project` writes `.claudeignore` when absent and, inside a git repository, sets
  the executable bit in the index (`git update-index --chmod=+x`), because a hook committed as
  `100644` is silently dead on every fresh clone.

### Fixed
- The worktree fixture in `test/run.sh` was 2 MiB; `du -m` rounds up and counts the directory's
  own block on ext4, so Linux reported 3 MB and the assertion failed there while passing on
  APFS. The fixture is 1.5 MiB, which rounds to 2 on both.

## [0.1.0] — 2026-09-21

First public release: the protocol as measured in *The First Layer*
(<https://digital1.foundation/articles/the-first-layer/>).

### Added
- `spec/` — the protocol: layers, file format, index rules, write path, read path, budgets,
  hook contract, limits.
- `hooks/context-budget.sh` — four budgets (index 80 lines, instruction file 8 KB, live
  transcript 60 MB, agent worktrees 100 MB), silent when healthy, always exit 0, thresholds
  overridable through `MCP_*` environment variables.
- `hooks/prune-worktrees.sh` — removes agent worktrees whose branch is fully merged; skips
  locked worktrees and unmerged branches.
- `hooks/session-start.sh` — the read path: prune, weigh, snapshot the baseline, inject the
  index (HTML-comment history stripped at injection), the last handoff and recent git state.
- `hooks/stop-handoff.sh` — the write guard: blocks a stop only when repository state changed
  since session start and the session-state file is older than 45 minutes.
- `skills/` — `/handoff`, `/dream`, `/catchup`, `/status`, `/update-context`.
- `templates/` — the `CLAUDE.md` section, index, topic, feedback and session-state templates,
  the gitignore lines.
- `test/run.sh` — 35 assertions, no dependencies; every check driven into its failure state.
- `install.sh` — `--project`, `--global`, `--check`.

### Changed from the estate it was measured on
- The budget check is installed in the repository's own `SessionStart` chain. On the estate
  the papers measured it ran only in parent workspace folders, and every budget found broken
  sat in a repository the check did not cover (Paper 003). *A budget binds where it is checked.*
- The comment about request cost no longer says the transcript is re-sent per request; the
  honest statement is accumulation and a session pinned at its context ceiling (Paper 001, §2).
- Thresholds and paths are environment-overridable so the suite can prove the checks fire
  without a sixty-megabyte fixture.

[0.1.1]: https://github.com/digital-one-consulting/memory-context-protocol/releases/tag/v0.1.1
[0.1.0]: https://github.com/digital-one-consulting/memory-context-protocol/releases/tag/v0.1.0
