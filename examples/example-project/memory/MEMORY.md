# Project Memory Index — example service
<!-- Last dream: 2026-09-21 -->

## Active Context
- `/quote` returns a cached value; the cache TTL is being moved from code to config. Next: the config schema.

## Decisions
- [Decisions](decisions.md) — 2026-09-14: cache lives in process memory, not Redis, until traffic proves otherwise

## Gotchas
- [Gotchas](gotchas.md) — the dev server binds IPv6 first; `localhost` can resolve to the wrong one on some machines

## Feedback from the owner
- [Verify live before claiming live](feedback_verify-live-before-claiming-live.md) — never write "deployed" without fetching the URL and comparing bytes
