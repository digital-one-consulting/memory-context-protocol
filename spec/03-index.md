# §3 The index — `memory/MEMORY.md`

The index is the one memory file that loads at every session start. Its whole design follows
from that: whatever sits in it is paid for every time, so it MUST be small and the detail MUST
load on demand.

## 3.1 Shape

```markdown
# Project Memory Index
<!-- Last dream: YYYY-MM-DD -->

## Active Context
- one or two lines: what is being worked on, and the next step

## <Section>
- [Title](file.md) — the hook, in one clause
```

One line per topic: a link to the topic file and a clause that says when to open it. A date,
the fact and enough of a hook to know when to read further; nothing in the line argues or
narrates.

## 3.2 Rules

1. **Under 80 lines.** This is the first budget (§6) and it is checked at every session start.
2. **A pointer file, not a content dump.** If a line needs a second sentence, the second
   sentence belongs in the topic file.
3. **No session history.** An index that accumulates `<!-- Session NN … -->` comments is a
   transcript with a better filename; the read path strips HTML comments at injection (§5.3)
   precisely so that a decayed index does not cost the session, but the decay is still the
   defect. The `Last dream` comment is the one comment the index keeps.
4. **Rewritten, not appended, at consolidation** (§4.2). The whole file is re-emitted from the
   current set of topic files each time, which is what keeps it an index.
5. **Loaded context, not instructions.** An injected index reflects what was true when written.
   The agent MUST verify names, paths and flags before acting on them.

## 3.3 Why eighty

Eighty lines is not derived; it is the line that was crossed. Two indexes on the estate the
protocol was measured on stood at 539 and 978 lines on 21 September 2026, against this rule,
in the two repositories where the check that would have said so was not installed. The number
is a scar. Change it with a measurement (see GOVERNANCE).
