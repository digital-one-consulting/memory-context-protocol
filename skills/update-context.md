Update `CLAUDE.md`, the project's reference skill and memory to reflect codebase changes.
Run when: new components are added, the stack changes, a major refactor completes, a milestone
lands, or about three months have elapsed.

1. Read the current `CLAUDE.md`, the project's reference skill (if any) and `memory/MEMORY.md`.
2. Run `git log --oneline --since="90 days ago"`.
3. Run `git diff --name-only HEAD~20`.
4. Read the changed files that affect architecture, domain or milestone status.
5. Check new dependencies: diff the package manifests.
6. Identify what is outdated or missing — pay special attention to **status drift** between
   documents that are supposed to agree.
7. Propose specific edits — do NOT auto-apply.
8. Wait for approval, then apply the confirmed changes.
9. Update the timestamp: `<!-- Last context update: [date] — [summary] -->`

Keep `CLAUDE.md` under the budget the hook checks (8 KB by default): it loads at every session
start. Reference material belongs in a skill or in `memory/`, loaded on demand.
