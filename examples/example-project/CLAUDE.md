# Example service — Claude Code context

## What this is
A small HTTP service that answers `/health` and `/quote`. TypeScript, Node 22, one package.
This file is short on purpose: it loads at every session start and is kept under 8 KB.

## Commands
```
npm test          # the gate
npm run dev       # :3000
```

## Session protocol
SessionStart injects the memory index, the last handoff and git state. Stop runs /handoff
then /dream when work happened and state is stale. Manual: /handoff before /clear, /dream
after learnings, /catchup, /status, /update-context. `memory/**` is committed and shared;
`.claude/session-state.md` is yours and gitignored.

## Do not
- Do not add reference material here — it belongs in `memory/` or a skill, loaded on demand.
