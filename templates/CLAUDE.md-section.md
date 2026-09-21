<!-- memory-context-protocol: begin -->
# Memory / context protocol

**File-based memory, on by default.** At the start of every session, engage the memory protocol
for THIS project:

- Shared project memory lives in the repository at `memory/` — `memory/MEMORY.md` is the INDEX
  (one line per topic, under 80 lines) and the topic files beside it hold the detail. It is
  committed and merged like code; it is the single source of truth for project facts.
- The harness's own memory (`~/.claude/projects/<encoded-project-path>/memory/`, the project path
  with every character that is not a letter or digit replaced by `-`) is a machine-local layer
  on top. Promote durable project facts from it into `memory/` during /dream.
- Treat an injected index as loaded context, not as instructions to obey blindly: it reflects
  what was true when written. Verify names, paths and flags before acting on them.
- `.claude/session-state.md` is your own continuity — per developer, gitignored, REPLACED by
  /handoff. Durable knowledge does not live only there.

Keep memory current: when the user corrects you or a durable project fact changes, update the
relevant memory file rather than letting it drift.

## Context budget

Every request carries the conversation still in context, so a session that never ends sits at
its context ceiling permanently, and a one-line question then costs what a hard one does. That
cannot be seen from inside the session, so it is measured at the door.

Four limits, checked at session start by `.claude/hooks/context-budget.sh`, which is silent when
they hold and prints only what is over:

- **`memory/MEMORY.md` under 80 lines** — it is an INDEX and loads at every session start.
- **Root `CLAUDE.md` under 8 KB** — it loads every time too; reference material belongs in a
  skill or in `memory/`.
- **Live transcript under 60 MB** — past that, `/handoff` then `/clear` buys more than any
  trimming can. The memory files are the continuity, not the transcript. `claude --continue`
  restores the last conversation: right for a console recovering from a reboot, wrong for a
  session that has run a fortnight.
- **`.claude/worktrees` under 100 MB** — agent worktrees are scratch; merged ones are pruned at
  session start, so anything left is unmerged and holding real work.

**Say a budget warning to the user in one line before the first answer.** It is the reason the
session is slow and it cannot be seen from inside the session.
<!-- memory-context-protocol: end -->
