# §6 Budgets

Every request carries the turns still in context. A session that never ends sits at its
context ceiling permanently, and a one-line question then costs what a hard one does. That
cannot be seen from inside the session that has it, so it is measured at the door.

## 6.1 The four limits

`hooks/context-budget.sh` checks four budgets at every session start:

| Budget | Variable | Default | What it measures |
|---|---|---|---|
| index | `MCP_MEM_LINES` | 80 | `wc -l memory/MEMORY.md` |
| instruction file | `MCP_CLAUDE_KB` | 8 | `wc -c CLAUDE.md` / 1024, integer division |
| live transcript | `MCP_TRANSCRIPT_MB` | 60 | `du -sm` of the transcript the harness names on the hook's stdin; standalone, the newest `.jsonl` in the project's transcript directory |
| agent worktrees | `MCP_WORKTREE_MB` | 100 | `du -sm .claude/worktrees` |

The first two are files that load at every session start; the budget bounds the standing cost.
The third is the accumulation surface itself; past the line, `/handoff` then `/clear` buys more
than any trimming can. The fourth is scratch that should not accumulate; merged worktrees are
pruned automatically (§7.4), so anything over the line is unmerged and holding real work.

## 6.2 Arithmetic

A check's real threshold is what its arithmetic computes, not what its name says. The
instruction-file check divides bytes by 1,024 and warns above 8, so it first fires at 9,216
bytes, not 8,193. The suite pins both sides of that line (`test/run.sh`). `wc -l` counts newline
characters, so an index whose last line has no newline counts one fewer than an editor shows.

The transcript check measures the file the harness names as `transcript_path` on the
`SessionStart` hook's stdin (§7.2). At a fresh startup that file does not exist yet, and the
check says nothing rather than measuring the previous session. Run standalone, it falls back to
the newest transcript in the project's directory under `~/.claude/projects/` — named after the
project path with every character that is not a letter or digit replaced by `-` — and counts
only the newest: older ones are sessions already left behind by `/clear`, not loaded again
unless a session is explicitly resumed, and counting them would keep warning after the fix was
applied.

## 6.3 Silent when healthy

The check MUST print nothing when every budget holds and MUST always exit 0. A well-kept
project pays nothing for it, and a hook that fails must not take the session down with it.
When something is over, it prints one heading with the count of points and one line per point,
each naming the file, the measured value, the budget and the repair.

## 6.4 A budget binds where it is checked

The check MUST run in the `SessionStart` chain of the repository where sessions start. A check
installed only in a parent workspace folder does not cover a session started one directory
below — and on the estate the protocol was measured on, every budget found broken sat in a
repository the check did not cover, unflagged, while the parent folder's own files passed
(Paper 003). Declared anywhere else, a budget is a preference.

## 6.5 The thresholds

Each default is a line that was crossed in a long-running project before the check existed.
They are scars, not science, and this specification does not argue they are right. What the
measurement supports is narrower: wherever a line had a check standing on it, at the folder
where the check was measured, the line held; wherever it had only prose, it did not. Tune them
to your estate; change the defaults here with a measurement.
