Memory consolidation pass. Run at the end of every productive session, after /handoff.
Synthesizes what was learned into durable memory files so future sessions — yours and your
teammates' — orient instantly without re-reading transcripts.

Also trigger when the user says: "consolidate memory", "update your memory", "sync what you
learned", "remember what we did". When triggered by the Stop hook (via /handoff), run
autonomously — no questions, no narration.

SHARED STORE — `memory/**` is COMMITTED and shared across the team. Treat it as a knowledge base:
- **Merge, never overwrite.** Add and refine facts; do not clobber teammates' entries.
- Keep changes **additive and atomic** so git merges stay trivial. For a single volatile fact
  prefer one fact per file (`memory/feedback_<slug>.md`) over editing a shared topic file.
- State **facts**, not "we decided" or first-person narration. Convert relative dates to ISO.
- If a fact contradicts an existing one, replace the stale fact and note the date.
- Keep memory changes in their own small commit so they are easy to review and rebase.

WHAT EARNS A MEMORY: something non-obvious that cost something to learn. Not what the repository
already says, not what git history shows. The test: would a competent person repeating this work
fall into the same hole without it? Write the memory even when — especially when — the lesson is
that the earlier analysis was wrong.

## Phase 1 — Orient
1. Run `ls memory/` to see the existing topic files.
2. Read `memory/MEMORY.md` — the current index.
3. Skim the one or two topic files closest to what was just worked on.

## Phase 2 — Gather recent signal
In priority order:
1. This conversation — what was accomplished, decided, discovered?
2. `.claude/session-state.md` — extract the durable parts (the file itself is local and ephemeral).
3. User feedback — corrections, preferences, "always/never do X" → `memory/feedback_*.md`
   (one fact per file; include WHY and HOW TO APPLY).
4. Drifted facts — does anything contradict current memory? (status, conventions, names, paths)
5. The harness's machine-local auto-memory (`~/.claude/projects/<encoded-project-path>/memory/`) —
   promote durable PROJECT facts into `memory/`; the in-repo `memory/` is the single source of
   truth for shared project knowledge.

## Phase 3 — Consolidate
For each thing worth remembering:
- Prefer merging into an existing topic file over creating a new one.
- Convert relative dates to ISO dates.
- Delete contradicted facts.
- A new topic file only when nothing existing fits.

Topic file format (`memory/<topic>.md`):
```markdown
# <Topic>
<!-- Last updated: YYYY-MM-DD -->

<Concise, factual content. No conversation. No "we decided". Just the knowledge.>
```

## Phase 4 — Update the index
Rewrite `memory/MEMORY.md` — keep it under 80 lines. It is a pointer file, not a content dump:
one line per topic, `- [Title](file.md) — the hook, in one clause`. Never add session history
to the index; that is what the topic files and git log are for.

Confirm: "Dream complete. Memory updated. [N] files written, [M] facts updated."
