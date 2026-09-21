# Decisions
<!-- Last updated: 2026-09-14 -->

- 2026-09-14 — The `/quote` cache is an in-process map with a TTL, not Redis. Reason: one
  instance, under 50 requests a minute; a second process is a cost without a benefit until
  traffic shows otherwise. Revisit when a second instance is deployed.
- 2026-09-02 — Health is `/health` returning `{ok:true}` with no dependency checks, so a
  degraded dependency never takes the process out of the load balancer.
