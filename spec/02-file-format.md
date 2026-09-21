# §2 File format

Memory files are Markdown. Nothing in the format needs a parser beyond a person and an agent.

## 2.1 Topic file

```markdown
# <Topic>
<!-- Last updated: YYYY-MM-DD -->

<Concise, factual content. No conversation. No "we decided". Just the knowledge.>
```

- One topic per file; the filename is a kebab-case slug of the topic.
- The first line is the title; the second is the `Last updated` comment with an ISO date.
- Content states facts, dated where the date matters, with the paths and names as they are
  today and — where one exists — the command that reproduces the fact.
- Relative dates ("last week", "yesterday") MUST be converted to ISO dates before they are
  written. A relative date is wrong the day after it is written.

## 2.2 Feedback file — one fact per file

The owner's corrections and stated preferences are the most valuable and the most volatile
facts a project has. They go one per file, named `feedback_<slug>.md`, so a teammate can grep
the rules and a merge never has two people editing the same fact:

```markdown
# <The rule, as a clause>
<!-- Last updated: YYYY-MM-DD -->

**The lesson.** <What happened, with the failing input if there was one.>

**Why:** <the reason the owner gave, or the cost the mistake had.>

**How to apply:** <the concrete behaviour next time.>
```

A feedback file without its **why** is a rule nobody will keep; without its **how to apply** it
is a complaint.

## 2.3 What earns a memory

A memory records something **non-obvious that cost something to learn**. Not what the repository
already says. Not what git history shows. The test: would a competent person repeating this work
fall into the same hole without it?

Write the memory even when — especially when — the lesson is that the earlier analysis was
wrong. The paper is the artefact; the memory is the lesson.

## 2.4 What does not belong

Secrets, credentials, keys and tokens — never, not even fingerprints of them unless the project
has a stated fingerprint convention. Session narration. Anything the code, the README or the git
log already states. Numbers that will be re-measured: record the command, not the value, unless
the value is the lesson (in which case record its date beside it).
