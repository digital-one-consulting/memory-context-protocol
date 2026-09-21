# §4 The write path

Two write disciplines, deliberately different, keep a memory from becoming a transcript.

## 4.1 Handoff — state is replaced

`/handoff` (`skills/handoff.md`) rewrites `.claude/session-state.md` from scratch: what was
completed, every file modified, decisions with reasoning, gotchas, next steps in order, what is
blocked. Current state only, under roughly eighty lines. The previous handoff is gone; that is
the point. A state file that appends is a second transcript.

Handoff is invoked manually before `/clear`, or by the Stop hook when the guard fires (§7.3).
When hook-triggered it MUST run autonomously — no questions to the user — and MUST proceed
straight to `/dream`.

## 4.2 Dream — knowledge is merged

`/dream` (`skills/dream.md`) is consolidation, in four phases:

1. **Orient** — list `memory/`, read the index, skim the topic files closest to the work.
2. **Gather signal** — this conversation; the durable parts of the state file; the owner's
   corrections (→ feedback files, §2.2); facts that now contradict memory; durable project
   facts sitting in the machine-local layer (§1.2), to be promoted.
3. **Consolidate** — merge into existing topic files by preference; ISO dates; delete a
   contradicted fact and note the date; a new file only when nothing fits.
4. **Update the index** — rewrite `memory/MEMORY.md` from the topic files, under eighty lines.

Its write rule is the opposite of handoff's: **merge, never overwrite.** Changes MUST be additive
and atomic so git merges between teammates stay trivial; facts are stated as facts, not "we
decided"; deletion is part of the discipline, not a violation of it. Memory changes SHOULD go in
their own small commit.

## 4.3 The phase no hook can see

Phases 1–3 are inside the agent. The hooks can force *that* a dream runs (§7.3) and can measure
the index's length afterwards (§6), but nothing mechanical checks that a lesson was written
rather than a summary, or that Phase 4 produced a pointer file rather than a store. This is the
protocol's known weak point, stated in Paper 002 §5 and Paper 004: the originating repository's
index decayed to session history while every hook around it kept running. The budget check
(§6) is the tripwire that turns that decay into a printed line; it does not prevent it.
