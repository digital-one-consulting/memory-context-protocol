# The Memory Context Protocol — specification

Version 0.1.0 · 2026-09-21 · CC BY 4.0

This is the normative description of the protocol implemented in `hooks/`, `skills/` and
`templates/`. Where this text and the implementation disagree, the implementation is the bug
and the test that catches it is the fix. The argument for each rule, with the measurements
that produced it, is in the papers: <https://digital1.foundation/articles/the-first-layer/>.

The key words MUST, SHOULD and MAY are used as in RFC 2119.

| § | Section | What it fixes |
|---|---|---|
| 1 | [Layers](01-layers.md) | two memory layers with one source of truth, and a third file that is neither |
| 2 | [File format](02-file-format.md) | the shape of a memory file and of a feedback file |
| 3 | [The index](03-index.md) | one line per topic, under eighty lines, never a store |
| 4 | [The write path](04-write-path.md) | handoff replaces; dream merges |
| 5 | [The read path](05-read-path.md) | injection before the first turn, and what is stripped |
| 6 | [Budgets](06-budgets.md) | the four limits, their arithmetic, and where they are checked |
| 7 | [Hook contract](07-hooks.md) | what a hook may do, what it must never do |
| 8 | [Limits](08-limits.md) | what the protocol cannot carry |

## The claim, in one paragraph

A session transcript is an accumulation surface, not a memory. What a session learned MUST be
extracted into files that load at the next session's start, or it is either lost at `/clear`
or paid for at the context ceiling for as long as the session lives. The files are a per-project
directory of Markdown: an index that points, topic files that hold, a state file that is
replaced, a knowledge store that is merged. Hooks make the loop non-optional at its two ends —
injection at start, a guarded handoff at stop — and a budget check at the door keeps the
always-loaded files small enough to load always. The one phase no hook can see into is
consolidation, and that is where the protocol decays if it decays.
