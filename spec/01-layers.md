# §1 Layers

The protocol keeps two memory layers with one source of truth, and one file that belongs to
neither.

## 1.1 The shared layer — `memory/`

The repository's own `memory/` directory. It is committed and merged like code and it is the
**single source of truth for project facts**. It MUST contain an index, `memory/MEMORY.md`
(§3), and MAY contain any number of topic files beside it (§2). It is injected at session start
(§5) and written at consolidation (§4).

Everything durable ends up here. A fact that matters to the next person to touch the project —
a decision, a correction, a path, a gotcha — is not durable until it is in the shared layer.

## 1.2 The machine-local layer

The harness's own per-project memory directory. In Claude Code this is
`~/.claude/projects/<encoded-project-path>/memory/`, where the encoded path is the project's
absolute path with every `/` replaced by `-`; it is loaded automatically when present.

This layer is a scratch layer on top of the shared one. Consolidation (§4.2) MUST promote
durable project facts from it into `memory/`. Nothing durable is allowed to end its life
machine-local: a fact that exists only here is lost with the machine.

## 1.3 The session-state file — `.claude/session-state.md`

Per developer, gitignored, and REPLACED at every handoff (§4.1). It holds current state only —
what is in flight, what was just changed, what is next, what is blocked — under roughly eighty
lines. It is a developer's own continuity across `/clear`, not a record, and it MUST NOT be the
only place a team-wide fact lives.

A fresh clone has no session-state file. That is expected; the read path tolerates its absence.

## 1.4 What each layer is for

| | Shared `memory/` | Machine-local | Session state |
|---|---|---|---|
| Committed | yes | no | no (gitignored) |
| Written by | `/dream` — merged | the harness, and the agent | `/handoff` — replaced |
| Read at | session start (index) + on demand (topics) | session start, by the harness | session start |
| Holds | durable project knowledge | scratch and candidates for promotion | what is in flight now |
| Lifetime | the project's | the machine's | until the next handoff |
