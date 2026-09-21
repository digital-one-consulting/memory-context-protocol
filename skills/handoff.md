Persist session state before /clear or ending a session.

AUTOMATIC TRIGGER: the Stop hook (`.claude/hooks/stop-handoff.sh`) invokes this when work
happened and the session-state file is stale. When hook-triggered: run autonomously and briefly,
do NOT ask the user anything, and run /dream immediately after.

TWO FILES, TWO AUDIENCES: `.claude/session-state.md` is **per-developer and gitignored** — your own
continuity, never shared or committed, and REPLACED on every handoff. Durable, shareable knowledge
goes to `memory/` via /dream (committed, MERGED). Never put a team-wide fact only in session state.

1. Summarize all work completed this session.
2. List every file modified — one line per file describing the change.
3. Document every significant decision made, with reasoning.
4. Note surprises, gotchas, discoveries.
5. List next steps in priority order.
6. Note anything blocked or waiting for input.

Write the above to `.claude/session-state.md` (REPLACE the file — current state only, not
history; keep under ~80 lines; durable knowledge goes to /dream):

## Handoff: [output of `date`]
## Working On
[current task]
## Modified Files
[list]
## Decisions Made
[decisions + reasoning]
## Gotchas Discovered
[anything that would waste time if forgotten]
## Next Steps
[ordered list]
## Blocked On
[anything waiting for external input]

If invoked manually: confirm "Handoff written. Now run /dream, then safe to /clear."
If hook-triggered: proceed straight to /dream, then report one line: "Auto-handoff + dream complete."
