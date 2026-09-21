# §5 The read path

Memory that is not read is not memory. The read path puts the files in front of the agent
before its first turn, at no cost in tool calls, and it is the same at startup, resume,
`/clear` and compaction.

## 5.1 Session start

`hooks/session-start.sh` runs on the harness's `SessionStart` event and prints, in order:

1. the budget report, if any budget is over (§6) — with the instruction to say it to the user
   in one line before the first answer;
2. recent git state — the last five commits and the short status;
3. the memory index, with HTML comments stripped (§5.3);
4. the last handoff — the first forty lines of the session-state file — with a warning when
   it is two or more days old, because commits made since are not reflected in it;
5. the instruction to run `/catchup`.

Before printing, it prunes merged agent worktrees (§7.4) and snapshots the repository state to
`.claude/hooks/.session-baseline` (gitignored) so the Stop hook can later tell whether real
work happened (§7.3).

## 5.2 Catch-up

`/catchup` (`skills/catchup.md`) is the manual read after `/clear` or a resume: the index, the
state file, ten commits of log, the files changed in the last three — then a one-line report of
done / in progress / next, and the question "Confirm next task or redirect me." When the
handoff is days old the agent MUST trust `git log` over it.

## 5.3 What is stripped at injection

HTML comments in the index are omitted at injection: `awk '/<!--/{c=1} !c{print} /-->/{c=0}'`.
The file on disk is unchanged. The rule exists because an index that has grown session-history
comments would otherwise be injected whole at every start, `/clear` and compaction — on the
estate measured, one such index cost an estimated 25.8k tokens per start, against roughly 10k
for the index beneath the comments (the hook author's estimate, not a measurement). Stripping
moves the injection cost; it does not fix the index, and the budget check (§6) still reports
the file's true length.

## 5.4 What the read path cannot do

It cannot make the agent read what it injected, and it cannot tell a stale sentence from a true
one. Both limits are stated in §8.
