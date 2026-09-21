# §7 Hook contract

Hooks are what make the loop non-optional. They run at the two ends of a session, cost no tool
call and no turn, and are held to a contract stricter than the rest of the protocol because a
misbehaving hook takes every session down with it.

## 7.1 Rules for every hook

1. **Always exit 0** — except `stop-handoff.sh`, which exits 2 deliberately to block a stop.
   No `set -e` in a hook.
2. **Tolerate absence.** A missing project directory, a missing `git`, a missing file — each is
   a reason to print nothing and exit, never to fail.
3. **Portable.** macOS, Linux and git-bash on Windows: GNU `stat -c` before BSD `stat -f`
   (on GNU, `stat -f` means the filesystem and succeeds with a dump, so the order matters);
   `shasum` → `sha1sum` → `md5sum` → `cksum`; `awk`, not `perl`.
4. **Print for the agent, not for a log.** Whatever a `SessionStart` hook prints is in context
   before the first turn. Every printed line must be worth its place there.
5. **Configurable by environment**, never by editing the file: `MCP_*` variables override every
   threshold and path.

## 7.2 `SessionStart` — `session-start.sh`

Order: prune worktrees → weigh budgets → write the baseline → inject. See §5.1. Wired in
`.claude/settings.json` (`hooks/settings.example.json`) with a 15-second timeout.

## 7.3 `Stop` — `stop-handoff.sh`

Blocks the stop (exit 2, instructions on stderr) only when BOTH hold:

1. the session-state file is older than `MCP_THROTTLE_MIN` (default 45 minutes), AND
2. the repository state — `HEAD` plus a hash of `git status --porcelain` — differs from the
   baseline written at session start.

It reads the harness's JSON on stdin and exits 0 immediately when `stop_hook_active` is true,
which ends the recursion the harness would otherwise allow. When it blocks it advances the
baseline, so the very next stop passes: a session that changed nothing owes nothing, and the
throttle is load-bearing — a loop that interrupts every stop gets disabled, and a disabled loop
is no loop.

## 7.4 Worktree pruning — `prune-worktrees.sh`

Removes agent worktrees under `.claude/worktrees/` whose branch is fully merged into the base
branch (`MCP_BASE_BRANCH`, default `main`). It MUST skip a locked worktree (a running agent
holds its own) and MUST leave any unmerged branch alone. It prints what it did and exits 0.
Each agent worktree is a full second checkout; four once held 1.7 GB inside one repository,
and a linter walked into one and failed the main tree on another branch's code.

## 7.5 Events the protocol does not use

The protocol uses two events only. It does not hook tool calls, prompts or compaction beyond
what `SessionStart` already covers. A port to a harness with different events keeps the two
roles — inject before the first turn, guard the stop — and maps them to whatever the harness
provides.
