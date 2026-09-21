Rebuild working context after /clear or a session resume.

1. Read `memory/MEMORY.md` — report the accumulated project knowledge in a few lines.
2. Read `.claude/session-state.md` if present (local, per-developer) — report what was in progress.
3. Run: `git log --oneline -10`
4. Run: `git diff --name-only HEAD~3` — read the changed files briefly.
5. Report: what is done, what is in progress, what is next.
6. Ask: "Confirm next task or redirect me."

`session-state.md` is per-developer and gitignored, so a fresh clone may not have one — that is
expected. The shared, durable knowledge lives in `memory/**` (committed). If the handoff is days
old, trust `git log` over it.
