Quick project health check.

1. Run: `git status` and `git log --oneline -5`
2. Read: `memory/MEMORY.md` (the Active Context section, if the project keeps one)
3. Read: `.claude/session-state.md` (first 20 lines) if present
4. Run the project's gate command (whatever `CLAUDE.md` names as the gate — lint, typecheck, tests)
5. Report: branch, last commits, working state, gate status, what is in flight.
