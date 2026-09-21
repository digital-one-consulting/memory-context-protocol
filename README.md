# Memory Context Protocol

**A working memory for a coding agent, made of files — and the budgets that keep it loadable.**

A coding agent's conversation accumulates until it is the most expensive thing about the
session, and what the session learned dies with the next `/clear` unless something cheaper
carries it. This repository is that carrier: a per-project memory made of plain Markdown files,
a fixed write discipline (state is *replaced* at handoff, knowledge is *merged* at
consolidation), a read path that injects the memory before the first turn, and four context
budgets checked at the door — silent when they hold, loud when they don't.

It is the reference implementation behind **The First Layer**, a four-paper series published by
the Digital One Foundation: <https://digital1.foundation/articles/the-first-layer/>. The papers
are the argument, with the measurements; this repository is the artefact. A browser demo that
runs this repository's checks against the same fixtures is beside the papers:
<https://digital1.foundation/articles/the-first-layer/demo.html>.

Stewarded by the Digital One Foundation (in formation). Code is Apache-2.0; the specification
text is CC BY 4.0. Contributions take a DCO sign-off. See [GOVERNANCE.md](GOVERNANCE.md).

## What it is, in one screen

```
your-project/
├── CLAUDE.md                     ← always loaded; kept under 8 KB (budget)
├── memory/                       ← SHARED: committed and merged like code
│   ├── MEMORY.md                 ← the INDEX: one line per topic, under 80 lines (budget)
│   ├── decisions.md              ← topic files hold the detail, dated
│   └── feedback_<rule>.md        ← one fact per file: the owner's corrections, with why
└── .claude/
    ├── settings.json             ← wires the two hooks
    ├── hooks/
    │   ├── session-start.sh      ← READ PATH: prune, weigh budgets, inject index + last handoff
    │   ├── context-budget.sh     ← the four budgets; prints only what is over; always exits 0
    │   ├── prune-worktrees.sh    ← removes agent checkouts whose branch already landed
    │   └── stop-handoff.sh       ← WRITE GUARD: blocks a stop only when work happened AND state is stale
    ├── commands/                 ← /handoff  /dream  /catchup  /status  /update-context
    └── session-state.md          ← LOCAL: per developer, gitignored, REPLACED at every handoff
```

Two layers, one source of truth. The **shared layer** (`memory/`) is the repository's own and is
committed. The **machine-local layer** is the harness's auto-memory directory for the project;
durable facts are promoted from it into `memory/` at consolidation. Nothing durable is allowed
to end its life machine-local.

Two write disciplines, deliberately different. `/handoff` **replaces** the session-state file:
current state only, under eighty lines. `/dream` **merges** into `memory/`: additive and atomic,
facts not narration, relative dates converted to ISO, a contradicted fact replaced with the
date noted. A memory that only appends is a transcript with a better filename.

Four budgets, checked where the session starts. The check is engineered to cost nothing when
healthy: it prints only what is over budget and always exits 0.

| Budget | Default | Why |
|---|---|---|
| `memory/MEMORY.md` | 80 lines | it is an index and loads at every session start |
| root `CLAUDE.md` | 8 KB | it loads at every session start too |
| live transcript | 60 MB | past this, `/handoff` then `/clear` buys more than any trimming |
| `.claude/worktrees` | 100 MB | agent checkouts are scratch; merged ones are pruned automatically |

The thresholds are scars, not science: each is a line that was crossed in a long-running
project before the check existed. Override them with `MCP_MEM_LINES`, `MCP_CLAUDE_KB`,
`MCP_TRANSCRIPT_MB`, `MCP_WORKTREE_MB`.

## Install

Into one project (copies hooks, commands, settings and templates; never overwrites an existing file):

```sh
git clone https://github.com/digital-one-consulting/memory-context-protocol.git
memory-context-protocol/install.sh --project /path/to/your/repo
```

Into your global instructions (appends the protocol section to `~/.claude/CLAUDE.md` once,
between markers, so it applies in every project):

```sh
memory-context-protocol/install.sh --global
```

Check any directory's budgets without installing anything:

```sh
memory-context-protocol/install.sh --check /path/to/your/repo
```

Requirements: bash, git, coreutils. Tested on macOS and Linux; the hooks are written to run
under git-bash on Windows as well (portable `stat`, portable hashing, `awk` not `perl`).

## Harness

This is **Claude Code-first**: the hook events (`SessionStart`, `Stop`), the `CLAUDE.md`
instruction file, slash commands under `.claude/commands/` and the auto-memory path under
`~/.claude/projects/` are that harness's. The *file format* — an index of pointers, topic files
holding one fact each, dated, merged never overwritten — is harness-agnostic, and the budget
check reads only the filesystem. Ports to other harnesses are welcome; see CONTRIBUTING.

## Test

```sh
test/run.sh
```

No framework, no dependencies. Every fixture is built in a temporary directory at run time.
The suite drives each hook into its healthy state (must be silent) and into every failure
state (must print the specific warning or block). A check that has never been seen to fire is
not a check — so the suite includes the boundary that surprised its authors: the instruction
file check divides bytes by 1,024 and warns above 8, so it first fires at 9,216 bytes, and the
test pins both sides of that line.

## Limits

Stated in the fourth paper and repeated here so they are not discovered in production:

- **A note can be loaded and wrong.** Memory records write-time truth; nothing in the layer
  verifies a note at read time. Take lessons from memory, take numbers from the artefact.
- **A transcript restore can be the wrong continuity.** `claude --continue` restores the last
  conversation — right for a console recovering from a reboot, wrong for a session that has
  run a fortnight. The memory files are the durable baseline beneath both.
- **No hook can force the unwritten lesson.** The consolidation phase is the one no mechanism
  sees into; the index in the originating repository decayed to session history while every
  hook around it kept running.
- **Nothing crosses the project boundary.** A per-project memory is per project. What an
  organisation shares across repositories is a second layer, with its own paper series.

## Layout

| Path | What |
|---|---|
| `spec/` | the protocol, normative, section by section |
| `hooks/` | the four hooks and an example `settings.json` |
| `skills/` | the five slash commands |
| `templates/` | the `CLAUDE.md` section, index, topic, feedback and session-state templates, the gitignore lines |
| `examples/example-project/` | a small synthetic project with the protocol installed |
| `test/run.sh` | the suite |
| `install.sh` | project, global and check modes |

## Provenance

The protocol was built and measured on one practitioner's estate over three months and the
failures that shaped it are printed, with dates and failing inputs, in the papers. The estate's
paths, names and memory contents are not in this repository; only the mechanism is.
