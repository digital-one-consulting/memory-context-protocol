# Changelog

All notable changes to this project are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Fixed
- **`prune-worktrees.sh` judged every desk against `main`.** A desk that merges into
  `dev/simulator` (and reaches `main` only by release PRs, days later) kept 48 merged agent
  worktrees of 63, 21.5 GB in all (2026-11-17). The bases are now the desk's own: the main
  checkout's branch and its upstream, the remote's `HEAD`, `main`/`master` and the integration
  branches (`dev`, `dev/*`, `develop`), local and remote-tracking; `MCP_BASE_BRANCH` takes a list.
  A branch also counts as merged when `git cherry` shows no `+` line, or when every file it
  changed has the same content in the base (a squash merge). The untracked files of a
  merged worktree (screenshots, reports) no longer keep it: they move to
  `.claude/worktree-archive/<name>/` first. A worktree on a base branch is never touched. The
  lock/live/young guards (a process's cwd, `MCP_PRUNE_MIN_AGE_MIN`) join the protocol, status is
  read with `--no-optional-locks`, and removals stop after `MCP_PRUNE_BUDGET_S` (10 s). New
  `--report` mode.
- **`context-budget.sh` called merged worktrees "unmerged".** Its line now counts them by the
  prune hook's rule, with sizes: "N merged (X MB) can be pruned now, H merged but held (Y MB),
  U unmerged (Z MB)".
- **`context-budget.sh` could time out the session-start hook.** `du -sm .claude/worktrees/` took
  20 s over 31 GB of agent worktrees (2026-11-06), past `session-start.sh`'s 15 s timeout, so the
  memory index never loaded. The check now reads the last measure from `.claude/.worktrees-mb`
  and refreshes it in the background when it is older than 60 minutes; the hook ran in 0.0 s on
  the same tree. The first session after install has no measure and says nothing. The cache is
  in `templates/gitignore-snippet`; two new assertions pin the cold and cached runs.
- **`prune-worktrees.sh` kept merged worktrees when the local base branch was behind.** It
  tested only the local `main`, which on one desk sat 80+ commits behind `origin/main` and was
  never pulled; 21 merged agent worktrees (31 GB) built up by 2026-11-06. A branch now also
  counts as merged when the base's remote-tracking ref (`MCP_BASE_REMOTE`, default `origin`)
  contains it. The hook never fetches. A merged worktree whose only changes are deletions (a
  half-finished removal) is now removed with `--force`; any other change still keeps it.

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
- **`prune-worktrees.sh` could discard uncommitted agent work.** A worktree whose branch has no
  commits of its own sits at the base branch's tip and counts as merged; `git worktree remove
  --force` then removed it with every unstaged file in it — exactly what a finished agent leaves
  behind. It now skips any worktree with uncommitted changes and removes without `--force`, so
  git's own refusals stand; the lock check reads the porcelain `locked` line rather than a
  basename; paths with spaces are read whole. Three new assertions pin each.
- **The transcript budget looked in the wrong place.** The harness encodes a project path by
  replacing every character that is not a letter or digit with `-`, not only `/`, so any path
  with a dot, underscore or space was silently never measured; and at a fresh startup the
  newest transcript on disk is the previous session's. `session-start.sh` now reads the
  harness's stdin JSON and passes `transcript_path` to the check; the check measures that file,
  says nothing when it does not exist yet, and falls back to the corrected encoding when run
  standalone. The spec, the template and the fixtures said `/` too; corrected.
- CI's fresh-install assertions were `A && echo`, which cannot fail under `bash -e`; they now
  exit 1 on the wrong outcome.
- The security contact was an address that bounces; reports go through GitHub's advisory form
  to the maintainers in CODEOWNERS.
- Minor: a non-numeric `MCP_*` override falls back to the default instead of skipping the
  check; a symlinked `.claude/worktrees` is measured, not the link; the Stop hook never blocks
  outside a git repository; `install.sh` resolves a symlinked invocation and honours
  `CLAUDE_CONFIG_DIR`; the `.gitignore` idempotence check matches the marker line, not the
  project name; spec §4 cited a section of Paper 002 that does not exist (§5 → §4); spec §7 no
  longer claims the very next stop always passes.
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
