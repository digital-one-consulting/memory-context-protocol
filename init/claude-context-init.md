# Memory Context Protocol — the init prompt

Paste the whole fenced block below into a Claude Code session opened at the root of a
project. Run it once in a new project (INIT MODE); run it again after a major change or about
every three months (UPDATE MODE). It discovers the project — it does not assume a stack.

This prompt is the descendant of the "Claude Code Context & Memory System" init prompt first
written in April 2026 and made hook-automated in June 2026 (see README, Lineage). Phase 8
carries the hooks from this repository verbatim; `test/run.sh` fails if the copies below drift
from `hooks/`.

```
You are setting up (or updating) a permanent, token-efficient context and memory
system for this project. You discover everything — do not assume any tech stack.

First, determine mode:

- If `.claude/` does not exist → INIT MODE (run all phases)
- If `.claude/` exists → UPDATE MODE (jump to UPDATE PHASES at the bottom)

---

# ═══════════════════════════════════════════
# INIT MODE
# ═══════════════════════════════════════════

Work through each phase in order. Confirm phase output before proceeding.
Do not create any files until Phase 5.

---

## PHASE 1 — Repository Inventory

Map what exists without reading file contents.

```
find . -maxdepth 1 -type f | sort
find . -maxdepth 1 -type d | grep -v "^\.$" | sort
find . -maxdepth 3 -name "README*" -o -name "*.md" 2>/dev/null | grep -v node_modules | grep -v ".claude" | grep -v ".agents" | head -20
```

Detect tech stack by marker files:
```
find . -maxdepth 3 \( \
  -name "*.csproj" -o -name "*.sln" \
  -o -name "package.json" -o -name "tsconfig.json" \
  -o -name "pyproject.toml" -o -name "requirements.txt" -o -name "setup.py" \
  -o -name "go.mod" -o -name "Cargo.toml" \
  -o -name "pom.xml" -o -name "build.gradle" \
  -o -name "Gemfile" -o -name "composer.json" \
  -o -name "Dockerfile" -o -name "docker-compose*.yml" \
\) 2>/dev/null | grep -v node_modules | grep -v ".git" | sort
```

Check config and infra:
```
find . -maxdepth 3 \( \
  -name "*.env.example" -o -name ".env.example" \
  -o -name "*.tf" -o -name "*.bicep" \
\) 2>/dev/null | grep -v node_modules | grep -v ".git" | head -20
```

Output: structured inventory — directories, detected stack, detected infra. No files yet.

---

## PHASE 2 — Component Deep-Map

For each top-level directory that is a major component:
1. List its internal structure (one level deep)
2. Read its entry point / main config file (appropriate for detected stack)
3. Classify: deployable service / library / tool / frontend / infra

Read any existing README or markdown docs fully.

Output:
- Component inventory: name → type → one-line purpose
- Data flow hypothesis: how do components connect?
- Which are core vs. supporting?

---

## PHASE 3 — Domain & Business Logic Extraction

Search for domain constants, enums, types that reveal business logic:
```
grep -rn "enum \|const \|readonly \|CONSTANT\|CONFIG" \
  --include="*.cs" --include="*.py" --include="*.ts" \
  --include="*.go" --include="*.rs" --include="*.rb" \
  2>/dev/null | grep -v node_modules | grep -v ".git" | head -50
```

Read the top 3-5 most domain-rich source files.

Output:
- Core domain entities and their meaning
- Key business rules visible in code
- Internal terminology (may differ from industry standard)
- External systems integrated with

---

## PHASE 4 — Convention Detection

Read 2-3 representative source files per detected language from core business logic areas.

Check for existing config:
```
find . -name ".editorconfig" -o -name ".eslintrc*" -o -name "pylintrc" \
  -o -name ".rubocop*" -o -name "golangci*" 2>/dev/null | head -10
```

Detect:
- Naming conventions, error handling patterns, logging approach
- DI / service patterns, async patterns
- Test file location and naming
- Config loading approach
- Non-obvious repeated patterns

Output: only conventions that deviate from language defaults or Claude would get wrong.

---

## PHASE 5 — Create Root CLAUDE.md

Create `./CLAUDE.md`.

**Hard limit: 200 lines. Every line must earn its place.**
**Exclude: linting rules, formatting preferences, obvious language idioms.**
**Include: everything Claude would get wrong or need to ask about.**
**If content won't fit: move topic-specific rules to `.claude/rules/<topic>.md` with
path-scoped frontmatter (`paths: ["**/*.test.ts"]`) — they load only when matching files
are touched. Use `@path/to/doc.md` imports instead of duplicating existing docs.**

```markdown
# [PROJECT NAME] — Claude Code Context

## What This Is
[2-3 sentences: what the system does, who uses it, what problem it solves]

## Component Map
[One line per component. Format: `path/name` — what it does — type]

## Tech Stack
[Compact: language/framework/runtime per component. DB, queues, cloud if any.]

## External Integrations
[System name — what this project does with it — connection type]

## Domain Glossary
[10-20 terms Claude must know without asking.
Format: TERM — one-line definition]

## Key Conventions
[8-12 bullets. Only non-obvious project-specific architectural decisions.]

## Commands
[Exact runnable commands: build, test, run dev, docker if applicable.
Note which directory to run from if it varies.]

## Progressive Context Loading
Load skills only when the task requires it — not proactively:
- Architecture / component interaction → `.claude/skills/architecture/SKILL.md`
- Domain / business logic → `.claude/skills/domain/SKILL.md`
- Project memory (what was learned across sessions) → `memory/MEMORY.md`

## Session Protocol

Automated by hooks (see `.claude/settings.json`):
- SessionStart hook injects memory index + session state + git status automatically
- Stop hook triggers /handoff + /dream automatically when work happened and state is stale (>45 min)

Manual overrides: `/handoff` for an immediate checkpoint before /clear, `/dream` after major
learnings, `/catchup` for an explicit spoken summary.

If hook context shows the last handoff is old: trust `git log` over remembered context.

## Do Not
[5-7 specific anti-patterns for THIS codebase. Derived from what was found.]

<!-- Last context update: [date] — initial setup -->
```

---

## PHASE 6 — Module CLAUDE.md Files

For each major component with meaningful internal complexity, create `[component]/CLAUDE.md`.

**Hard limit: 80 lines. Never repeat root CLAUDE.md content.**

```markdown
# [Component Name]

## Purpose
[2-3 sentences specific to this component's role]

## Key Entry Points
[Top 5-8 files/classes/modules. Format: name — what it does]

## Local Conventions
[Only what differs from root CLAUDE.md]

## Owns These Integrations
[External systems this component connects to]

## Common Tasks
[3-5 frequent tasks with correct approach for this component]
```

Skip: pure config dirs, generated code, thin wrappers with no business logic.

---

## PHASE 7 — Skills, commands and the memory index

Create the tree below. The five command files are `skills/*.md` in the memory-context-protocol
repository — copy them verbatim (or run `install.sh --project .`), do not retype them. The two
skill files are written by you from Phases 2 and 3; their skeletons are `templates/skills/`.

```
.claude/
  settings.json          ← hook registration (Phase 8)
  hooks/                 ← the four hooks (Phase 8)
  skills/
    architecture/SKILL.md
    domain/SKILL.md
  commands/
    catchup.md  handoff.md  dream.md  status.md  update-context.md   ← from skills/ in the repository
  session-state.md
memory/
  MEMORY.md
```

### `.claude/skills/architecture/SKILL.md`

Deep architecture — loaded on demand, not every session. Target: 250–350 lines, dense,
reference-style. Write from the Phase 2 discoveries: component interaction and data flow (an
ASCII diagram if it helps), the key abstractions and contracts, integration patterns (retry,
idempotency, error propagation), storage entities and non-obvious schema decisions, deployment
topology, known constraints and why they cannot change, and where the complexity lives.

### `.claude/skills/domain/SKILL.md`

Business domain — loaded when working on domain logic. Target: 200–300 lines. Write from the
Phase 3 discoveries: what the business does and why the software exists, the core domain model
with lifecycle states, the non-obvious business rules that appear in code, external context
(industry terms, regulatory constraints, market mechanics), known edge cases, and a terminology
map from internal names to industry names where they differ.

### `.claude/session-state.md` (initial content)

```markdown
# Session State

No active session. Run /catchup after starting work.
```

### `memory/MEMORY.md` (initial content)

```markdown
# Project Memory Index
<!-- Last dream: [date of setup] -->
<!-- An INDEX: one line per topic, under 80 lines. Detail lives in the topic file. -->

## Active Context
- Project context system initialized. No sessions completed yet.

## Decisions
- [Decisions](decisions.md) — created after the first /dream

## Gotchas
- [Gotchas](gotchas.md) — created after the first /dream
```

---

## PHASE 8 — Automation Hooks

Make the session protocol zero-discipline: catchup at start and handoff at stop must not depend
on the user remembering to run commands — and the context budgets must be checked where the
session starts, because a budget binds where it is checked.

If the memory-context-protocol repository is at hand, `install.sh --project .` writes all four
hooks, the commands, the settings and the index template, and you can skip to Verify. Otherwise
create the files below exactly as printed.

Create `.claude/hooks/context-budget.sh` (chmod +x):

```bash
#!/usr/bin/env bash
# context-budget.sh — what this session will cost before it has done anything.
#
# The API beneath a coding agent is stateless: every request carries the turns
# still in context, and a session that never ends sits at its context ceiling
# permanently — a one-line question then costs what a hard one does. That is
# invisible from inside the session that has it, which is why it is measured
# here, at the door, where it costs no tool call and no turn.
#
# SILENT WHEN HEALTHY. It prints only what is over budget, so a well-kept
# project pays nothing for this check. Always exits 0: a hook that fails must
# not take the session down with it.
#
# A budget binds where it is checked. Install this in the SessionStart chain of
# the repository where sessions actually start — not only in a parent folder.
#
# Budgets are environment-overridable so a test can prove the check fires
# (see test/run.sh) without a sixty-megabyte fixture.
set -u
H="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"   # resolved before the cd: $0 may be relative
cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0

# num <value> <default>: an override that is not a whole number falls back to the default.
num() { case "$1" in ''|*[!0-9]*) echo "$2" ;; *) echo "$1" ;; esac; }

# Each threshold is a line that was crossed in a long-running project before
# this check existed. They are scars, not science; tune them to your estate.
MEM_LINES=$(num "${MCP_MEM_LINES:-}" 80)          # memory/MEMORY.md is an INDEX; it loads at every session start
CLAUDE_KB=$(num "${MCP_CLAUDE_KB:-}" 8)           # the root CLAUDE.md, likewise
TRANSCRIPT_MB=$(num "${MCP_TRANSCRIPT_MB:-}" 60)  # past this, /clear buys more than any trimming can
WORKTREE_MB=$(num "${MCP_WORKTREE_MB:-}" 100)     # agent checkouts are scratch and should not accumulate
MEMORY_INDEX="${MCP_MEMORY_INDEX:-memory/MEMORY.md}"
PROJECTS_DIR="${MCP_PROJECTS_DIR:-$HOME/.claude/projects}"

warn=""
add() { warn="${warn}$1"$'\n'; }

# What an engine that runs this project's sessions did by itself (F3736, 2026-11-22). Builds
# prunes merged worktrees at idle and every hour, and compacts a session whose context passed its
# window, then writes one line per action here:
#   <epoch seconds> TAB prune|compact TAB <session id, or -> TAB <what it did>
# The owner asked why the line still told him to prune and /clear when Builds already did both.
# With no record (no engine, or an engine that does not write one) the old advice stands.
TRIM="${MCP_AUTO_TRIM:-.claude/.auto-trim}"
TRIM_FRESH_S=$(num "${MCP_TRIM_FRESH_S:-}" 10800)  # three hourly runs missed: the engine has stopped
now_s=$(date +%s)
# at <epoch>: "21:04" today, "11-21 21:04" before (BSD date -r, else GNU date -d @)
at() {
  local d fmt
  d=$(date -r "$1" +%F 2>/dev/null || date -d "@$1" +%F 2>/dev/null) || return 0
  if [ "$d" = "$(date +%F)" ]; then fmt=%H:%M; else fmt='%m-%d %H:%M'; fi
  date -r "$1" "+$fmt" 2>/dev/null || date -d "@$1" "+$fmt" 2>/dev/null
}
# trim_last <awk condition>: the last record that meets it, "<epoch> TAB <kind> TAB <session> TAB <text>"
trim_last() {
  [ -f "$TRIM" ] || return 0
  awk -F '\t' "\$1 ~ /^[0-9]+\$/ && ($1)" "$TRIM" 2>/dev/null | tail -1
}

if [ -f "$MEMORY_INDEX" ]; then
  # wc -l counts newline characters: an index whose last line has no newline counts one fewer.
  n=$(wc -l < "$MEMORY_INDEX" | tr -d ' ')
  [ "$n" -gt "$MEM_LINES" ] && add "- $MEMORY_INDEX is ${n} lines (budget ${MEM_LINES}). It is an INDEX and loads at every session start: one line per topic, detail in the topic file. Fix it in /dream."
fi

if [ -f CLAUDE.md ]; then
  # integer division: the check first fires at (CLAUDE_KB + 1) * 1024 bytes.
  # A check's real threshold is what its arithmetic computes, not what its name says.
  kb=$(( $(wc -c < CLAUDE.md) / 1024 ))
  [ "$kb" -gt "$CLAUDE_KB" ] && add "- CLAUDE.md is ${kb} KB (budget ${CLAUDE_KB} KB) and loads at every session start. Move reference material into a skill or memory/ and keep only what must govern every answer."
fi

# The LIVE transcript. The harness hands SessionStart its path on stdin and
# session-start.sh passes it on as MCP_TRANSCRIPT_PATH; at a fresh startup the
# file does not exist yet, and then there is nothing to measure and nothing is
# said. Run standalone, fall back to the newest transcript in the project's
# directory under the harness's projects directory, whose name is the project
# path with every character that is not a letter or digit replaced by "-".
# Older transcripts there are sessions already left behind by /clear: they sit
# on disk and are not loaded again unless a session is explicitly resumed, so
# counting them would keep warning after the fix was applied.
live=""
if [ -n "${MCP_TRANSCRIPT_PATH:-}" ]; then
  [ -f "$MCP_TRANSCRIPT_PATH" ] && live="$MCP_TRANSCRIPT_PATH"
else
  enc="$(pwd -P | sed 's#[^A-Za-z0-9]#-#g')"
  tdir="$PROJECTS_DIR/$enc"
  if [ -d "$tdir" ]; then
    # ls -t is the portable newest-first; transcript names are UUIDs, so SC2012 does not apply.
    # shellcheck disable=SC2012
    live=$(ls -t "$tdir"/*.jsonl 2>/dev/null | head -1)
  fi
fi
if [ -n "$live" ]; then
  mb=$(du -sm "$live" 2>/dev/null | cut -f1)
  # The transcript's name is its session id; a compaction the engine recorded for that session
  # means the context sent with each request is the summary and the turns since, not the file.
  sid=$(basename "$live" .jsonl)
  comp=""
  [ "${mb:-0}" -gt "$TRANSCRIPT_MB" ] && comp=$(SID="$sid" trim_last '$2 == "compact" && $3 == ENVIRON["SID"]')
  if [ -n "$comp" ]; then
    IFS=$'\t' read -r ct _ _ cw <<EOF
$comp
EOF
    add "- This project's live transcript is ${mb} MB on disk, but the engine compacted this session by itself at $(at "$ct")${cw:+ (${cw})}: each request now carries that summary and the turns since, not the whole file. Nothing to do."
  elif [ "${mb:-0}" -gt "$TRANSCRIPT_MB" ]; then
    add "- This project's live transcript is ${mb} MB. A session this long sits at its context ceiling, so every question is paying the ceiling regardless of size. **Finish with /handoff, then /clear.** The memory files are the continuity, not the transcript."
  fi
fi

if [ -d .claude/worktrees ]; then
  # du over the worktrees took 20 s at 31 GB (2026-11-06) and pushed session-start.sh past its 15 s
  # hook timeout, so the project's memory did not load. The hook now reads the last measure and
  # starts the next one in the background; a stale number for one session is harmless.
  # F3675 (2026-11-17): the line said "anything left is unmerged" while 48 of one desk's 63
  # worktrees were merged (into its own base, not main). The measure now also sorts them, by the
  # prune hook's own rule (prune-worktrees.sh --report), into prunable, held and unmerged, with sizes.
  cache=.claude/.worktrees-mb
  state=.claude/.worktrees-state
  mb=0
  if [ -f "$cache" ]; then mb=$(tr -cd '0-9' < "$cache"); fi
  if [ -z "$(find "$cache" -mmin -60 2>/dev/null)" ]; then
    (
      # the trailing slash follows a symlinked worktrees directory instead of measuring the link
      du -sm .claude/worktrees/ 2>/dev/null | cut -f1 > "$cache.tmp" && mv "$cache.tmp" "$cache"
      # WP4 (2026-11-23): one desk's line said "9 merged (50 MB)" for 5.8 GB, and "0 held" while its
      # status listed 19 held: the sizes came from a separate du joined by name, and the sort from the
      # desk's own copy of the prune hook, not the one the engine runs. The engine's last report
      # (.claude/worktrees/.prune-report, under 3 h old) is read first; each line carries the hook's own
      # du of that worktree. An older hook's two-field lines still get a du per folder.
      report=""
      if [ -n "$(find .claude/worktrees/.prune-report -mmin -180 2>/dev/null)" ]; then
        report="$(cat .claude/worktrees/.prune-report 2>/dev/null)"
      elif [ -x "$H/prune-worktrees.sh" ]; then
        report="$(CLAUDE_PROJECT_DIR="$PWD" "$H/prune-worktrees.sh" --report 2>/dev/null)"
      fi
      if [ -n "$report" ] || [ -x "$H/prune-worktrees.sh" ]; then
        sizes=""
        printf '%s\n' "$report" | awk -F '\t' 'NF && $3 !~ /^[0-9]+$/ { f = 1 } END { exit !f }' \
          && sizes="$(for d in .claude/worktrees/*/; do du -sm "$d" 2>/dev/null; done)"
        printf '%s\n' "$report" \
          | SIZES="$sizes" awk -F '\t' '
              BEGIN { n = split(ENVIRON["SIZES"], l, "\n"); for (i = 1; i <= n; i++) { split(l[i], f, "\t"); p = f[2]; sub(/\/+$/, "", p); sub(/.*\//, "", p); mb[p] = f[1] } }
              NF < 2 { next }
              { c[$1]++; s[$1] += ($3 ~ /^[0-9]+$/ ? $3 : mb[$2]) }
              END { printf "prunable %d %d\nheld %d %d\nunmerged %d %d\n", c["prunable"], s["prunable"], c["held"], s["held"], c["unmerged"], s["unmerged"] }' \
          > "$state.tmp"
        # F3678: the archive the prune hook fills (and empties after 30 days), counted the same way
        an=0; am=0; ap=0
        if [ -d .claude/worktree-archive ]; then
          an=$(find .claude/worktree-archive/ -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -cd '0-9')
          am=$(du -sm .claude/worktree-archive/ 2>/dev/null | cut -f1)
          # WP2/WP3: the changes of pruned worktrees, one .patch each
          ap=$(find .claude/worktree-archive/ -mindepth 1 -maxdepth 1 -type f -name '*.patch' 2>/dev/null | wc -l | tr -cd '0-9')
        fi
        printf 'archive %d %d %d\n' "${an:-0}" "${am:-0}" "${ap:-0}" >> "$state.tmp" && mv "$state.tmp" "$state"
      fi
    ) </dev/null >/dev/null 2>&1 &
  fi
  # The engine's own prune: its last run, and its last run that removed something.
  ran=""; did=""
  if [ "${mb:-0}" -gt "$WORKTREE_MB" ]; then
    ran=$(trim_last '$2 == "prune"')
    did=$(trim_last '$2 == "prune" && $4 != "nothing to remove"')
    rt=${ran%%$'\t'*}
    [ -n "$ran" ] && [ $((now_s - rt)) -gt "$TRIM_FRESH_S" ] && ran=""
  fi
  if [ "${mb:-0}" -gt "$WORKTREE_MB" ] && [ -n "$ran" ]; then
    eng="The engine prunes it by itself (last run $(at "$rt"))"
    if [ -n "$did" ]; then
      IFS=$'\t' read -r dt _ _ dw <<EOF
$did
EOF
      eng="${eng}: ${dw} at $(at "$dt")"
    else
      eng="${eng}: nothing to remove yet"
    fi
    left=""; arch=""
    if [ -f "$state" ]; then
      read -r _ pn pm _ hn hm _ un um _ an am ap <<EOF
$(tr '\n' ' ' < "$state")
EOF
      left=" Left: ${pn:-0} merged (${pm:-0} MB) for its next run, ${hn:-0} merged but held (${hm:-0} MB), ${un:-0} unmerged (${um:-0} MB)."
      { [ "${an:-0}" -gt 0 ] || [ "${ap:-0}" -gt 0 ]; } 2>/dev/null && arch=" .claude/worktree-archive holds ${an:-0} folder(s) (${am:-0} MB) of untracked files$([ "${ap:-0}" -gt 0 ] 2>/dev/null && echo " and ${ap} patch(es) of changes") from pruned worktrees; prune-worktrees.sh deletes the folders older than 30 days."
    fi
    add "- .claude/worktrees is ${mb} MB. ${eng}.${left} Nothing to do: a held worktree has a live agent, a lock or a change from the last 24 h, and an unmerged one holds real work.${arch}"
  elif [ "${mb:-0}" -gt "$WORKTREE_MB" ]; then
    if [ -f "$state" ]; then
      # "<class> <count> <MB>" per line
      read -r _ pn pm _ hn hm _ un um _ an am ap <<EOF
$(tr '\n' ' ' < "$state")
EOF
      arch=""
      { [ "${an:-0}" -gt 0 ] || [ "${ap:-0}" -gt 0 ]; } 2>/dev/null && arch=" .claude/worktree-archive holds ${an:-0} folder(s) (${am:-0} MB) of untracked files$([ "${ap:-0}" -gt 0 ] 2>/dev/null && echo " and ${ap} patch(es) of changes") from pruned worktrees; prune-worktrees.sh deletes the folders older than 30 days."
      add "- .claude/worktrees is ${mb} MB: ${pn:-0} merged (${pm:-0} MB) can be pruned now, ${hn:-0} merged but held (${hm:-0} MB), ${un:-0} unmerged (${um:-0} MB). Each agent worktree is a full checkout; prune-worktrees.sh removes the merged ones (a live agent's, or one with real changes from the last 24 h, is held) and the folders of unmerged ones idle 7 days (branch and a patch kept); the rest hold real work.${arch}"
    else
      add "- .claude/worktrees is ${mb} MB. Each agent worktree is a full checkout; merged and unmerged are not counted yet (the next measure sorts them)."
    fi
  fi
fi

if [ -n "$warn" ]; then
  printf '## Context budget — over on %d point(s)\n%s' "$(printf '%s' "$warn" | grep -c '^- ')" "$warn"
fi
exit 0
```

Create `.claude/hooks/prune-worktrees.sh` (chmod +x):

```bash
#!/usr/bin/env bash
# prune-worktrees.sh — remove agent worktrees whose branch has already landed on the base branch.
#
#   prune-worktrees.sh            prune, print what it did
#   prune-worktrees.sh --report   prune nothing; print "<class>\t<name>\t<MB>\t<why>" for each agent
#                                 worktree, class prunable, held (merged, kept for now) or unmerged
#
# Each agent worktree is a full second checkout, most of it dependencies. Four
# of them once held 1.7 GB inside one repository — not mainly a disk problem:
# every tool that walked the tree walked five copies of it, and a linter once
# descended into one and failed THIS tree on another branch's code. The branch
# is the artefact; the checkout is scratch.
#
# Safe by construction, and it never guesses:
#   - a worktree LOCKED by a live agent is skipped: Claude Code's lock names its process
#     ("claude agent <name> (pid N start ...)"), and while that pid lives the worktree stays. A
#     lock that names no pid is kept too (a person locked it). A lock whose pid is dead is stale:
#     the rules below then judge the worktree as unlocked, and it is unlocked before its removal;
#   - a lock alone is not enough (F3638). 2026-11-16 18:55: a hand agent's lock named the claude
#     process that died in serve's 18:44 restart; the resumed session ran the agent on, but a
#     later Claude Code session took the lock for stale (its pid was dead) and let it go, and the
#     next session start pruned the live worktree: clean, and its branch had no commits, so main
#     "contained" it. So a worktree is also kept while a process has its cwd in it, and while it
#     is YOUNG: its folder or its git admin files changed in the last MCP_PRUNE_MIN_AGE_MIN
#     minutes (default 360). A finished agent's scratch goes at a session start after that;
#     a few hours of disk is cheap, a live agent's lost folder is not;
#   - GENERATED files do not hold a merged worktree (WP1). 2026-11-23, desk artemis-frontend-demo:
#     13 merged worktrees, 5.8 GB, were held for "a change" that was only build and test output
#     (`M TODO.md`, `M test/report.json`, 450 untracked files in dist/ and output/). A change whose
#     path matches the generated list goes with the worktree: dist/**, output/**,
#     test/report.json, **/*.log, TODO.md and todo/*.md (a to-do checkpoint the base already
#     has), plus one glob per line of the workspace's .builds/worktree-ignore (MCP_WORKTREE_IGNORE;
#     "#" starts a comment). A glob without "/" matches at any depth; ** spans folders;
#   - a deletion of a tracked file in a merged worktree goes too: every deleted file is still in
#     the branch's commit, which the base contains. A removal that stopped half-way leaves exactly
#     that ("D" lines only);
#   - other UNTRACKED files of a merged worktree are moved, not lost (F3675). 2026-11-17: 13 of one
#     desk's 63 worktrees held only screenshots and reports an agent left in docs/, so none of them
#     ever went. They now move to .claude/worktree-archive/<name>/ (same paths inside), then the
#     worktree goes. Ignored files (node_modules) go with the worktree;
#   - other changes to TRACKED files hold a merged worktree for MCP_PRUNE_DIRTY_AGE_H hours
#     (default 24) after the last one: a branch with no commits of its own sits at the base's tip
#     and counts as merged, and that is what a finished agent leaves behind, its work unstaged.
#     After that (WP2) `git diff HEAD` with its untracked, non-generated files is saved as
#     .claude/worktree-archive/<name>.patch, the patch is checked to undo exactly to HEAD from what
#     is on disk (git apply --check -R), and only then does the worktree go;
#   - an UNMERGED worktree with no live agent whose branch has had no commit for MCP_PRUNE_IDLE_DAYS
#     days (default 7), and no change for MCP_PRUNE_DIRTY_AGE_H hours, loses its folder, never its
#     branch (WP3): its changes are saved and checked as a patch the same way first. 2026-11-23:
#     7 unmerged worktrees (3 GB) of ended hand agents, the oldest from 11-15. A detached HEAD has
#     no branch to keep, so it stays;
#   - the archive empties itself (F3678): a .claude/worktree-archive/<name> folder older than
#     MCP_ARCHIVE_KEEP_DAYS days (default 30, by its own mtime: the day it was filled) is deleted;
#     a younger one stays. The count is in the line it prints. Patches are small and stay;
#   - the BASE is the desk's, not "main" (F3675). The same desk merges into dev/simulator and
#     reaches main only by release PRs days later: 48 merged worktrees, 16 GB, were kept because
#     none was in main. A branch is merged when any of these contains it: MCP_BASE_BRANCH (a
#     space-separated list, when set), the branch the main checkout works on and its upstream,
#     the remote's HEAD, main and master, and the remote's integration branches (dev, dev/*,
#     develop) — each local and as its remote-tracking ref (MCP_BASE_REMOTE, default origin).
#     A local main can sit 80+ commits behind, never pulled (2026-11-06: 21 merged worktrees,
#     31 GB kept), so the remote refs count too. The hook never fetches (session start has 15 s):
#     it reads the refs the last fetch left;
#   - "contains" is ancestry; or `git cherry` with no "+" line: every commit of the branch has
#     an equal patch in the base (a rebase or cherry-pick merge); or, for a squash merge (where
#     cherry says "+"), every file the branch changed since it left the base has the same content
#     in the base (2026-09-30: a squash-landed worktree held 1.3 GB and was pruned by hand);
#   - a worktree on one of the base branches themselves is never touched, nor its branch;
#   - it reads status with --no-optional-locks: a plain `git status` rewrites the index, and the
#     hourly --report then kept every worktree young forever;
#   - --report gives each worktree its own `du -sk` (WP4: the budget line once said 50 MB for
#     5.8 GB) and says why it stays: the live agent's pid, the lock, the changed files and their
#     age, the last commit's age;
#   - it stops starting new removals after MCP_PRUNE_BUDGET_S seconds (default 10: a
#     session-start hook has 15 s); the rest wait for the next run;
#   - it prints what it did and always exits 0, because a hook that fails must
#     not take the session down with it.
set -u
cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0
command -v git >/dev/null 2>&1 || exit 0
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

REPORT=0
[ "${1:-}" = "--report" ] && REPORT=1
WORKTREE_DIR="${MCP_WORKTREE_DIR:-.claude/worktrees}"
ARCHIVE_DIR="${MCP_WORKTREE_ARCHIVE:-.claude/worktree-archive}"
IGNORE_FILE="${MCP_WORKTREE_IGNORE:-.builds/worktree-ignore}"
REMOTE="${MCP_BASE_REMOTE:-origin}"

MIN_AGE="${MCP_PRUNE_MIN_AGE_MIN:-360}"
case "$MIN_AGE" in ''|*[!0-9]*) MIN_AGE=360 ;; esac
DIRTY_H="${MCP_PRUNE_DIRTY_AGE_H:-24}"
case "$DIRTY_H" in ''|*[!0-9]*) DIRTY_H=24 ;; esac
IDLE_DAYS="${MCP_PRUNE_IDLE_DAYS:-7}"
case "$IDLE_DAYS" in ''|*[!0-9]*) IDLE_DAYS=7 ;; esac
KEEP_DAYS="${MCP_ARCHIVE_KEEP_DAYS:-30}"
case "$KEEP_DAYS" in ''|*[!0-9]*) KEEP_DAYS=30 ;; esac
BUDGET="${MCP_PRUNE_BUDGET_S:-10}"
case "$BUDGET" in ''|*[!0-9]*) BUDGET=10 ;; esac
NOW="$(date +%s)"
# Every process's cwd, read once (lsof takes ~0.1 s here); empty when lsof is missing.
CWDS="$(lsof -a -d cwd -Fn 2>/dev/null | sed -n 's/^n//p')"
TMPD="$(mktemp -d "${TMPDIR:-/tmp}/prune-wt.XXXXXX" 2>/dev/null)" || exit 0
trap 'rm -rf "$TMPD"' EXIT

# The worktrees, one "<lock>\t<branch>\t<path>" line each, the main checkout first; <lock> is "-"
# when unlocked, else the lock's reason. The path is taken whole — it may contain spaces.
TREES="$(git worktree list --porcelain 2>/dev/null | awk '
  function flush() { if (p != "") printf "%s\t%s\t%s\n", l, (b == "" ? "-" : b), p; p = ""; b = ""; l = "-" }
  BEGIN        { l = "-" }
  /^worktree / { flush(); p = substr($0, 10); next }
  /^branch /   { b = substr($0, 8); sub(/^refs\/heads\//, "", b); next }
  /^locked/    { l = substr($0, 8); gsub(/\t/, " ", l); if (l == "") l = "(no reason given)"; next }
  /^$/         { flush(); next }
  END          { flush() }')"
MAIN_BRANCH="$(printf '%s\n' "$TREES" | head -n 1 | cut -f2)"
[ "$MAIN_BRANCH" = "-" ] && MAIN_BRANCH=""
MAIN_PATH="$(printf '%s\n' "$TREES" | head -n 1 | cut -f3-)"
[ -d "$MAIN_PATH" ] || MAIN_PATH="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# WP1: the generated-file globs, the defaults and the workspace's own list.
GENERATED="$(
  printf '%s\n' 'dist/**' 'output/**' 'test/report.json' '**/*.log' 'TODO.md' 'todo/*.md'
  [ -f "$MAIN_PATH/$IGNORE_FILE" ] \
    && sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' "$MAIN_PATH/$IGNORE_FILE" 2>/dev/null \
    | grep -v '^!'
)"

# The base names (local short names), then the refs that exist, one per commit.
BASE_NAMES="$(
  for b in ${MCP_BASE_BRANCH:-}; do echo "$b"; done
  [ -n "$MAIN_BRANCH" ] && echo "$MAIN_BRANCH"
  up="$(git -C "$MAIN_PATH" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null)" \
    && echo "${up#"$REMOTE"/}"
  h="$(git symbolic-ref --quiet --short "refs/remotes/$REMOTE/HEAD" 2>/dev/null)" && echo "${h#"$REMOTE"/}"
  echo main; echo master
  git for-each-ref --format='%(refname)' "refs/remotes/$REMOTE/dev" "refs/remotes/$REMOTE/develop" 2>/dev/null \
    | sed "s#^refs/remotes/$REMOTE/##"
)"
BASES="$(printf '%s\n' "$BASE_NAMES" | awk 'NF && !seen[$0]++' | while IFS= read -r b; do
  for r in "refs/heads/$b" "refs/remotes/$REMOTE/$b"; do
    s="$(git rev-parse --verify --quiet "$r^{commit}" 2>/dev/null)" && printf '%s %s\n' "$s" "$r"
  done
done | awk '!seen[$1]++ { print $2 }')"

# is_base <branch>: the branch is one of the bases itself.
is_base() { printf '%s\n' "$BASE_NAMES" | grep -qxF -- "$1"; }

# busy <path>: a process works in it (its cwd is the folder or below it).
busy() {
  [ -n "$CWDS" ] || return 1
  printf '%s\n' "$CWDS" | awk -v p="$1" 'index($0, p) == 1 && (length($0) == length(p) || substr($0, length(p) + 1, 1) == "/") { f = 1 } END { exit !f }'
}

# young <path>: the folder or its admin files (HEAD, index, logs/HEAD, gitdir) changed recently.
young() {
  [ "$MIN_AGE" -gt 0 ] || return 1
  local admin f
  admin="$(git -C "$1" rev-parse --absolute-git-dir 2>/dev/null)"
  for f in "$1" "$admin/HEAD" "$admin/index" "$admin/logs/HEAD" "$admin/gitdir"; do
    [ -e "$f" ] || continue
    [ -n "$(find "$f" -maxdepth 0 -mmin "-$MIN_AGE" 2>/dev/null)" ] && return 0
  done
  return 1
}

# lock_pid <reason>: the pid a Claude Code lock names ("... (pid 46371 start ...)"), or nothing.
lock_pid() { printf '%s\n' "$1" | sed -n 's/.*(pid \([0-9][0-9]*\).*/\1/p' | head -n 1; }

# alive <pid>: the process exists (kill -0 fails on another user's process, ps does not).
alive() { kill -0 "$1" 2>/dev/null || ps -p "$1" >/dev/null 2>&1; }

# merged <branch>: a base contains it, by ancestry, by patch (git cherry, no "+" line) or by content.
merged() {
  local b out mb
  [ -n "$BASES" ] || return 1
  while IFS= read -r b; do
    git merge-base --is-ancestor "$1" "$b" 2>/dev/null && return 0
  done <<EOF
$BASES
EOF
  while IFS= read -r b; do
    out="$(git cherry "$b" "$1" 2>/dev/null)" || continue
    [ -n "$out" ] && ! printf '%s\n' "$out" | grep -q '^+' && return 0
  done <<EOF
$BASES
EOF
  # a squash merge: git cherry says "+" (one new commit, another patch), so compare the files the
  # branch changed since it left the base: the same content in the base means nothing is lost.
  while IFS= read -r b; do
    mb="$(git merge-base "$b" "$1" 2>/dev/null)" || continue
    git diff --quiet "$mb" "$1" 2>/dev/null && continue
    git diff --name-only -z "$mb" "$1" 2>/dev/null | xargs -0 git diff --quiet "$1" "$b" -- 2>/dev/null && return 0
  done <<EOF
$BASES
EOF
  return 1
}

# scan <path>: sort the worktree's changes (git status, every untracked file one by one). Writes
#   $TMPD/patch.z  the paths a patch must carry (NUL): every tracked change, untracked non-generated
#   $TMPD/move.z   the untracked non-generated files (NUL), the F3675 archive's
#   $TMPD/real     the non-generated, non-deletion changes, "<XY> <path>" per line
# and sets N_ALL, N_GEN, N_REAL, N_REAL_TRACKED, N_PATCH. Fails when git cannot say, or a path holds
# a tab or a newline (then nothing is judged: the worktree stays).
scan() {
  local e xy p o
  : > "$TMPD/rows"; : > "$TMPD/patch.z"; : > "$TMPD/move.z"; : > "$TMPD/real"
  git --no-optional-locks -C "$1" status --porcelain=v1 -z -uall > "$TMPD/status.z" 2>/dev/null || return 1
  while IFS= read -r -d '' e; do
    xy="${e:0:2}"; p="${e:3}"; o=""
    case "$xy" in *R*|*C*) IFS= read -r -d '' o || return 1 ;; esac
    case "$p$o" in *$'\t'*|*$'\n'*) return 1 ;; esac
    printf '%s\t%s\t%s\n' "$xy" "$p" "$o" >> "$TMPD/rows"
  done < "$TMPD/status.z"
  # one awk pass sorts every row: gen (generated), del (a deletion only) or real
  GENERATED="$GENERATED" awk -F '\t' '
    function g2r(p,   r, i, c, n, any) {
      sub(/^\/+/, "", p); if (p ~ /\/$/) p = p "**"
      any = (index(p, "/") == 0); r = ""; n = length(p)
      for (i = 1; i <= n; i++) {
        c = substr(p, i, 1)
        if (c == "*") {
          if (substr(p, i + 1, 1) == "*") {
            if (substr(p, i + 2, 1) == "/") { r = r "(.*/)?"; i += 2 } else { r = r ".*"; i++ }
          } else r = r "[^/]*"
        } else if (c == "?") r = r "[^/]"
        else if (index(".+()|^${}[]\\", c)) r = r "\\" c
        else r = r c
      }
      return "^" (any ? "(.*/)?" : "") r "$"
    }
    function gen(path,   i) { for (i = 1; i <= ng; i++) if (path ~ re[i]) return 1; return 0 }
    BEGIN { n = split(ENVIRON["GENERATED"], g, "\n"); for (i = 1; i <= n; i++) if (g[i] != "") re[++ng] = g2r(g[i]) }
    {
      x = $1; cls = "real"
      if (gen($2) && ($3 == "" || gen($3))) cls = "gen"
      else if (x != "??" && x ~ /D/ && x !~ /[MARCTU]/) cls = "del"
      print cls "\t" $0
    }' "$TMPD/rows" > "$TMPD/sorted"
  N_ALL=0; N_GEN=0; N_REAL=0; N_REAL_TRACKED=0; N_PATCH=0
  local cls
  while IFS=$'\t' read -r cls xy p o; do
    N_ALL=$((N_ALL + 1))
    [ "$cls" = gen ] && N_GEN=$((N_GEN + 1))
    if [ "$xy" != "??" ]; then
      printf '%s\0' "$p" >> "$TMPD/patch.z"; N_PATCH=$((N_PATCH + 1))
      [ -n "$o" ] && printf '%s\0' "$o" >> "$TMPD/patch.z"
    elif [ "$cls" != gen ]; then
      printf '%s\0' "$p" >> "$TMPD/patch.z"; N_PATCH=$((N_PATCH + 1))
      printf '%s\0' "$p" >> "$TMPD/move.z"
    fi
    if [ "$cls" = real ]; then
      N_REAL=$((N_REAL + 1))
      [ "$xy" != "??" ] && N_REAL_TRACKED=$((N_REAL_TRACKED + 1))
      printf '%s %s\n' "$xy" "$p" >> "$TMPD/real"
    fi
  done < "$TMPD/sorted"
  return 0
}

# newest_change <path>: epoch seconds of the newest real change on disk (a deleted file says
# nothing; at most 500 files are read), or 0.
newest_change() {
  local newest=0 rel t n=0
  while IFS= read -r rel; do
    rel="${rel#?? }"
    [ -e "$1/$rel" ] || continue
    t="$(date -r "$1/$rel" +%s 2>/dev/null)" || continue
    [ "$t" -gt "$newest" ] 2>/dev/null && newest="$t"
    n=$((n + 1)); [ "$n" -ge 500 ] && break
  done < "$TMPD/real"
  echo "$newest"
}

# shown: the first changed files, "a, b, c (+N more)".
shown() {
  local list more
  list="$(head -n 3 "$TMPD/real" | sed 's/^.. //' | paste -sd, - | sed 's/,/, /g')"
  more=$((N_REAL - 3))
  [ "$more" -gt 0 ] && list="$list (+$more more)"
  printf '%s' "$list"
}

# ago <seconds>: "N h" under two days, else "N d".
ago() { [ "$1" -lt 172800 ] && echo "$(($1 / 3600)) h" || echo "$(($1 / 86400)) d"; }

# save_patch <path> <name> <branch>: write $TMPD/patch.z's changes, against HEAD, to
# <archive>/<name>.patch (a new name when one is there), and check that it undoes exactly to HEAD
# from what is on disk. Nothing to save is a success; any doubt is a failure, and the worktree stays.
save_patch() {
  [ -s "$TMPD/patch.z" ] || return 0
  local dir="$MAIN_PATH/$ARCHIVE_DIR" file admin head idx="$TMPD/index"
  admin="$(git -C "$1" rev-parse --absolute-git-dir 2>/dev/null)" || return 1
  head="$(git -C "$1" rev-parse --verify HEAD 2>/dev/null)" || return 1
  mkdir -p "$dir" || return 1
  file="$dir/$2.patch"
  [ -e "$file" ] && file="$dir/$2-$(date +%Y%m%d%H%M%S).patch"
  rm -f "$idx"
  if [ -f "$admin/index" ]; then cp "$admin/index" "$idx" || return 1; fi
  # a scratch index: the worktree's own is never touched
  GIT_INDEX_FILE="$idx" GIT_LITERAL_PATHSPECS=1 git -C "$1" add -A \
    --pathspec-from-file="$TMPD/patch.z" --pathspec-file-nul >/dev/null 2>&1 || return 1
  (
    printf '# prune-worktrees.sh saved worktree %s (branch %s) at %s, %s\n' "$2" "$3" "$head" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf '# restore: git worktree add <dir> %s && git -C <dir> apply --binary <this file>\n' "$head"
    GIT_INDEX_FILE="$idx" git -C "$1" diff --cached --binary HEAD
  ) > "$file.tmp" 2>/dev/null || { rm -f "$file.tmp"; return 1; }
  if ! grep -q '^diff --git ' "$file.tmp" \
    || ! git -C "$1" apply --check -R --binary "$file.tmp" >/dev/null 2>&1; then
    rm -f "$file.tmp"
    return 1
  fi
  mv "$file.tmp" "$file" || return 1
  return 0
}

# archive <path> <name>: move $TMPD/move.z's untracked files to the archive, same paths inside.
archive() {
  local dest="$MAIN_PATH/$ARCHIVE_DIR/$2" rel
  [ -e "$dest" ] && dest="$dest-$(date +%Y%m%d%H%M%S)"
  while IFS= read -r -d '' rel; do
    [ -n "$rel" ] && [ -e "$1/$rel" ] || continue
    mkdir -p "$dest/$(dirname "$rel")" && mv "$1/$rel" "$dest/$rel" || return 1
  done < "$TMPD/move.z"
  return 0
}

# drop <path> <lock reason> <stale>: remove the worktree (--force: every change in it was judged
# above). A stale lock is let go first and put back when the removal fails.
drop() {
  local path="$1"
  [ "$3" = 1 ] && { git worktree unlock "$path" >/dev/null 2>&1 || return 1; }
  if ! git worktree remove --force "$path" >/dev/null 2>&1; then
    [ "$3" = 1 ] && git worktree lock --reason "$2" "$path" >/dev/null 2>&1
    return 1
  fi
  return 0
}

removed=0
archived=0
patched=0
idle=0
while IFS=$'\t' read -r -u 3 lock branch path; do
  [ -n "$path" ] || continue
  case "$path" in *"/$WORKTREE_DIR/"*) ;; *) continue ;; esac
  [ -d "$path" ] || continue
  name="$(basename "$path")"
  mb=""
  if [ "$REPORT" = 1 ]; then
    kb="$(du -sk "$path" 2>/dev/null | cut -f1)"
    case "$kb" in ''|*[!0-9]*) mb="?" ;; *) mb=$(((kb + 512) / 1024)) ;; esac
  fi
  say() { [ "$REPORT" = 1 ] && printf '%s\t%s\t%s\t%s\n' "$1" "$name" "$mb" "$2"; return 0; }
  if [ "$branch" = "-" ]; then say unmerged "detached HEAD: no branch to judge or keep"; continue; fi
  is_base "$branch" && continue                                     # a base branch itself

  # what holds it whatever its branch: a live agent, a lock without a pid, a process, a young folder
  why=""; stale=0
  if [ "$lock" != "-" ]; then
    pid="$(lock_pid "$lock")"
    if [ -z "$pid" ]; then why="locked: $lock"
    elif alive "$pid"; then why="live agent: lock pid $pid lives ($lock)"
    else stale=1
    fi
  fi
  [ -z "$why" ] && busy "$path" && why="a process works in it"      # F3638
  [ -z "$why" ] && young "$path" && why="touched in the last $MIN_AGE min"
  stale_note=""
  [ "$stale" = 1 ] && stale_note=" (stale lock: pid $pid is gone)"

  if merged "$branch"; then
    act=""
    if [ -z "$why" ]; then
      if ! scan "$path"; then why="git status cannot list its changes plainly"
      elif [ "$N_REAL_TRACKED" -gt 0 ]; then
        t="$(newest_change "$path")"; age=$((NOW - t))
        if [ "$age" -ge $((DIRTY_H * 3600)) ]; then
          act=patch; note="real changes ($N_REAL), last $(ago "$age") ago: saved as a patch, then removed"
        else
          why="changed: $(shown), last $(ago "$age") ago (saved as a patch and removed $DIRTY_H h after the last change)"
        fi
      elif [ "$N_REAL" -gt 0 ]; then
        act=move; note="$N_REAL untracked file(s) move to $ARCHIVE_DIR/$name/"
      elif [ "$N_GEN" -gt 0 ]; then
        act=remove; note="only generated files changed ($N_GEN)"
      else
        act=remove; note="clean"
      fi
    fi
    if [ -n "$why" ]; then say held "$why"; continue; fi
    if [ "$REPORT" = 1 ]; then say prunable "merged; $note$stale_note"; continue; fi
    [ "$SECONDS" -ge "$BUDGET" ] && break                           # the rest wait for the next run
    case "$act" in
      move) archive "$path" "$name" || continue ;;
      patch) save_patch "$path" "$name" "$branch" || continue ;;
    esac
    drop "$path" "$lock" "$stale" || continue
    git branch -D "$branch" >/dev/null 2>&1                         # merged, so the branch is history
    removed=$((removed + 1))
    [ "$act" = move ] && archived=$((archived + 1))
    [ "$act" = patch ] && patched=$((patched + 1))
    continue
  fi

  # WP3: unmerged. Its folder goes only when no agent lives and nothing moved for days; the branch stays.
  if [ -z "$why" ]; then
    ct="$(git -C "$path" log -1 --format=%ct HEAD 2>/dev/null)"
    case "$ct" in ''|*[!0-9]*) why="no commit date" ;; esac
  fi
  if [ -z "$why" ] && [ $((NOW - ct)) -lt $((IDLE_DAYS * 86400)) ]; then
    why="last commit $(ago $((NOW - ct))) ago (its folder goes after $IDLE_DAYS d idle; the branch stays)"
  fi
  if [ -z "$why" ]; then
    if ! scan "$path"; then why="git status cannot list its changes plainly"
    elif [ "$N_REAL" -gt 0 ]; then
      t="$(newest_change "$path")"; age=$((NOW - t))
      [ "$age" -lt $((DIRTY_H * 3600)) ] && why="changed: $(shown), last $(ago "$age") ago"
    fi
  fi
  if [ -n "$why" ]; then say unmerged "$why"; continue; fi
  if [ "$REPORT" = 1 ]; then
    say unmerged "idle: last commit $(ago $((NOW - ct))) ago, no live agent$stale_note; its folder goes on the next run (changes saved as a patch, branch $branch kept)"
    continue
  fi
  [ "$SECONDS" -ge "$BUDGET" ] && break
  save_patch "$path" "$name" "$branch" || continue
  drop "$path" "$lock" "$stale" || continue
  idle=$((idle + 1))
  [ "$N_PATCH" -gt 0 ] && patched=$((patched + 1))
done 3<<EOF
$TREES
EOF

[ "$REPORT" = 1 ] && exit 0
git worktree prune >/dev/null 2>&1

# F3678: the archive is emptied by age, its direct folders only (rm -rf removes a symlink inside
# as a link, never its target). MCP_ARCHIVE_KEEP_DAYS=0 keeps them all.
expired=0
if [ "$KEEP_DAYS" -gt 0 ] && [ -d "$MAIN_PATH/$ARCHIVE_DIR" ]; then
  while IFS= read -r -d '' old; do
    rm -rf -- "$old" 2>/dev/null && expired=$((expired + 1))
  done < <(find "$MAIN_PATH/$ARCHIVE_DIR/" -mindepth 1 -maxdepth 1 -type d -mmin "+$((KEEP_DAYS * 1440))" -print0 2>/dev/null)
fi

line=""
add() { [ -n "$line" ] && line="$line; "; line="$line$1"; }
if [ "$removed" -gt 0 ]; then
  add "pruned $removed merged agent worktree(s)"
  [ "$archived" -gt 0 ] && line="$line; untracked files of $archived kept in $ARCHIVE_DIR/"
fi
[ "$idle" -gt 0 ] && add "removed the folders of $idle idle unmerged worktree(s), branches kept"
[ "$patched" -gt 0 ] && add "changes of $patched saved as patches in $ARCHIVE_DIR/"
[ "$expired" -gt 0 ] && add "deleted $expired archived folder(s) older than $KEEP_DAYS days from $ARCHIVE_DIR/"
[ -n "$line" ] && echo "$line"
exit 0
```

Create `.claude/hooks/session-start.sh` (chmod +x):

```bash
#!/usr/bin/env bash
# session-start.sh — the read path. Runs at SessionStart (startup, resume,
# /clear, compaction). Whatever it prints is in context before the first turn:
# it costs no tool call and no turn.
#
# In order:
#   1. start a prune of merged agent worktrees, in the background (scratch that
#      would otherwise accumulate);
#   2. weigh the context budgets — silent when they hold;
#   3. snapshot repository state, so the Stop hook can tell later whether real
#      work happened;
#   4. inject the memory index, the last handoff and recent git state.
#
# The budget check runs HERE, in the repository where the session starts,
# because a budget binds where it is checked and a check in a parent folder
# does not cover a session started one directory below.
H="$(cd "$(dirname "$0")" && pwd)"   # resolved before the cd: $0 may be relative
cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0

# The harness writes a JSON object on stdin ({"session_id", "transcript_path", "cwd",
# "hook_event_name", "source"}). The transcript path is the one file the budget check
# cannot find reliably on its own, so it is read here and passed on. Read only when stdin
# is not a terminal, and never wait more than two seconds for an EOF that a harness
# always sends — a hook that hangs is worse than one that guesses.
INPUT=""
if [ ! -t 0 ]; then IFS= read -r -t 2 -d '' INPUT || true; fi
TRANSCRIPT="$(printf '%s' "$INPUT" | sed -n 's/.*"transcript_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
[ -n "$TRANSCRIPT" ] && export MCP_TRANSCRIPT_PATH="$TRANSCRIPT"

MEMORY_INDEX="${MCP_MEMORY_INDEX:-memory/MEMORY.md}"
STATE="${MCP_SESSION_STATE:-.claude/session-state.md}"
BASELINE="${MCP_BASELINE:-.claude/hooks/.session-baseline}"

# Portable mtime in epoch seconds. GNU coreutils `-c %Y` FIRST (git-bash on
# Windows, Linux), then BSD/macOS `-f %m`; sanitised to an integer so the
# arithmetic never breaks. On GNU, `stat -f` means --file-system and SUCCEEDS
# with a dump, so GNU must be tried first.
mtime() {
  local m
  m=$(stat -c %Y "$1" 2>/dev/null) || m=$(stat -f %m "$1" 2>/dev/null) || m=0
  case "$m" in ''|*[!0-9]*) m=0 ;; esac
  echo "$m"
}
# Portable hash: shasum (macOS) → sha1sum (Linux) → md5sum → cksum. git-bash
# on Windows ships sha1sum/md5sum, not always shasum — never assume one.
hashcmd() {
  if command -v shasum >/dev/null 2>&1; then shasum
  elif command -v sha1sum >/dev/null 2>&1; then sha1sum
  elif command -v md5sum >/dev/null 2>&1; then md5sum
  else cksum; fi
}

# The prune runs DETACHED: this hook never waits for it. Measured 2026-11-22 on a desk with 33
# agent worktrees and six base branches: judging each unmerged branch (git cherry and a content
# diff against every base) took about 18 s, the whole prune minutes. The harness gives this hook
# 15 s, so from 11-18 every session start there timed out with no output and nothing loaded:
# no budget, no index, no handoff. One prune at a time: a lock folder, taken for stale after
# 30 minutes, so four session starts in ten minutes do not start four prunes.
PRUNE_LOCK="${MCP_PRUNE_LOCK:-.claude/hooks/.prune-running}"
if [ -x "$H/prune-worktrees.sh" ]; then
  [ -d "$PRUNE_LOCK" ] && [ -n "$(find "$PRUNE_LOCK" -maxdepth 0 -mmin +30 2>/dev/null)" ] \
    && rmdir "$PRUNE_LOCK" 2>/dev/null
  if mkdir -p "$(dirname "$PRUNE_LOCK")" 2>/dev/null && mkdir "$PRUNE_LOCK" 2>/dev/null; then
    ( "$H/prune-worktrees.sh" >/dev/null 2>&1; rmdir "$PRUNE_LOCK" 2>/dev/null ) </dev/null >/dev/null 2>&1 &
  fi
fi
BUDGET="$([ -x "$H/context-budget.sh" ] && "$H/context-budget.sh" 2>/dev/null)"

# Snapshot repository state for the Stop hook. Per-machine and gitignored —
# never shared between developers.
mkdir -p "$(dirname "$BASELINE")"
{
  git rev-parse HEAD 2>/dev/null
  git status --porcelain 2>/dev/null | hashcmd | cut -d' ' -f1
} > "$BASELINE"

echo "<auto-catchup source=\"SessionStart hook\">"
if [ -n "$BUDGET" ]; then
  echo "$BUDGET"
  echo ""
  echo "Say the budget report above to the user in one line before the first answer. A context problem is the reason a session is slow, and it cannot be seen from inside the session."
  echo ""
fi

echo "## Git"
git log --oneline -5 2>/dev/null
git status --short 2>/dev/null | head -15

if [ -f "$MEMORY_INDEX" ]; then
  echo ""
  echo "## Memory index ($MEMORY_INDEX — shared, committed; HTML comments omitted)"
  # An index that has grown session-history comments would be injected whole at
  # every start, /clear and compaction. The comments are stripped at injection;
  # the file itself is unchanged. awk, not perl, so git-bash on Windows runs it.
  awk '/<!--/{c=1} !c{print} /-->/{c=0}' "$MEMORY_INDEX"
fi

if [ -f "$STATE" ]; then
  echo ""
  echo "## Last handoff ($STATE — your local state, first 40 lines)"
  head -40 "$STATE"
  age_days=$(( ( $(date +%s) - $(mtime "$STATE") ) / 86400 ))
  if [ "$age_days" -ge 2 ]; then
    echo ""
    echo "WARNING: the handoff above is ${age_days} days old. Commits made since then are NOT reflected in memory or session state. Trust 'git log' over remembered context."
  fi
fi
echo ""
echo "Start by running /catchup to rebuild working context before answering the first prompt."
echo "</auto-catchup>"
exit 0
```

Create `.claude/hooks/stop-handoff.sh` (chmod +x):

```bash
#!/usr/bin/env bash
# stop-handoff.sh — the write path's guard. Runs at Stop. Blocks the stop
# (exit 2, with instructions on stderr) only when BOTH:
#   1. the session-state file is stale (older than THROTTLE_MIN), AND
#   2. repository state changed since session start (baseline written by
#      session-start.sh).
#
# The throttle is load-bearing: a loop that interrupts every stop gets
# disabled, and a disabled loop is no loop. /handoff rewrites the state file,
# so the mtime guard limits itself; the harness's stop_hook_active flag ends
# the recursion.
cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0
git rev-parse --git-dir >/dev/null 2>&1 || exit 0   # no repository, no baseline to compare: never block

INPUT=$(cat)
case "$INPUT" in
  *'"stop_hook_active":true'* | *'"stop_hook_active": true'*) exit 0 ;;
esac

STATE="${MCP_SESSION_STATE:-.claude/session-state.md}"
BASELINE="${MCP_BASELINE:-.claude/hooks/.session-baseline}"
THROTTLE_MIN="${MCP_THROTTLE_MIN:-45}"

mtime() {
  local m
  m=$(stat -c %Y "$1" 2>/dev/null) || m=$(stat -f %m "$1" 2>/dev/null) || m=0
  case "$m" in ''|*[!0-9]*) m=0 ;; esac
  echo "$m"
}
hashcmd() {
  if command -v shasum >/dev/null 2>&1; then shasum
  elif command -v sha1sum >/dev/null 2>&1; then sha1sum
  elif command -v md5sum >/dev/null 2>&1; then md5sum
  else cksum; fi
}

if [ -f "$STATE" ]; then
  age_min=$(( ( $(date +%s) - $(mtime "$STATE") ) / 60 ))
  [ "$age_min" -lt "$THROTTLE_MIN" ] && exit 0
fi

current="$(git rev-parse HEAD 2>/dev/null)
$(git status --porcelain 2>/dev/null | hashcmd | cut -d' ' -f1)"
if [ -f "$BASELINE" ] && [ "$current" = "$(cat "$BASELINE")" ]; then
  exit 0
fi

mkdir -p "$(dirname "$BASELINE")"
printf '%s\n' "$current" > "$BASELINE"

cat >&2 <<'EOF'
[auto-handoff hook] Repository state changed this session and the session-state file is stale.
Before stopping, persist the session — autonomously, without asking the user:
1. Run /handoff: rewrite .claude/session-state.md (local, per-developer; replaced, not appended).
2. Run /dream: consolidate durable learnings into memory/ (shared, committed; merged, never overwritten).
Keep both passes brief and factual. If you already completed handoff and dream in this very turn, just stop.
EOF
exit 2
```

Merge into `.claude/settings.json` (create if missing; NEVER overwrite existing keys):

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/session-start.sh",
            "timeout": 15,
            "statusMessage": "Memory context: budgets, index, last handoff, git"
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/stop-handoff.sh",
            "timeout": 15,
            "statusMessage": "Checking session persistence"
          }
        ]
      }
    ]
  }
}
```

Verify:
1. `chmod +x .claude/hooks/*.sh`
2. **Persist the exec bit INTO git** — `chmod` alone is lost on a fresh clone. Git stores the
   file mode; a hook committed as `100644` silently fails with `exit 126: permission denied`
   when the harness invokes it as a bare command, so every hook goes dead the moment someone
   clones the repository — the number-one way this system breaks:
   `git update-index --chmod=+x .claude/hooks/*.sh`
   Then confirm `git ls-files -s .claude/hooks/` shows mode `100755`, NOT `100644`, and commit it.
3. Pipe-test each hook **as a command**, NOT via `bash script.sh` (running it through `bash`
   ignores the exec bit and hides exactly this failure):
   `echo '{}' | .claude/hooks/session-start.sh` → catchup output, exit 0 (NOT 126)
4. Pipe-test all Stop guards: `stop_hook_active:true` → 0, unchanged baseline → 0, tampered
   baseline + stale state → 2
5. Run the budget check once: `.claude/hooks/context-budget.sh` — silence means every budget holds;
   anything printed is a real finding about this project, and it will print again at every start.
6. `jq -e '.hooks' .claude/settings.json` — valid JSON
7. Tell the user: if `.claude/settings.json` was just created, open `/hooks` once or restart
   Claude Code so the settings watcher picks it up.

---

## PHASE 9 — .claudeignore

Create `.claudeignore` at repo root.

Always include:
```
.git/
**/bin/
**/obj/
**/dist/
**/build/
**/.next/
**/out/
**/__pycache__/
**/*.pyc
**/target/
**/node_modules/
**/.venv/
**/venv/
**/.env/
**/vendor/
**/.vs/
**/.idea/
**/.vscode/
**/*.user
**/.DS_Store
**/*.log
**/*.pid
**/logs/
**/*.min.js
**/*.min.css
**/*.map
```

Add project-specific exclusions based on what was found: large data files, generated code, raw exports, binary assets.

---

## PHASE 10 — Verification

1. Run `/context` — report token breakdown for fresh session
2. List every file created with line count
3. Check: root CLAUDE.md ≤ 200 lines and under 8 KB? Module files ≤ 80 lines? `memory/MEMORY.md` under 80 lines?
4. Verify hooks: scripts executable, pipe-tests pass, settings.json valid (Phase 8 checklist)
5. Simulate session start: what does the SessionStart hook inject?
6. Simulate session end: walk through the Stop hook guards → handoff → dream flow
7. Flag anything that couldn't be captured — recommend manual follow-up

---

# ═══════════════════════════════════════════
# UPDATE MODE
# (runs when .claude/ already exists)
# ═══════════════════════════════════════════

---

## UPDATE PHASE 1 — Establish What Changed

```
grep "Last context update" CLAUDE.md
git log --oneline --since="90 days ago"
git diff --name-only HEAD~30 2>/dev/null | head -40
```

Group changed files:
- New directories (potential new components)
- Deleted files (removed components)
- Modified core business logic
- Modified config/infra
- Already manually updated CLAUDE.md or skills?

---

## UPDATE PHASE 2 — Read Current Context System

Read in full:
- `./CLAUDE.md` and all `**/CLAUDE.md`
- `.claude/skills/architecture/SKILL.md`
- `.claude/skills/domain/SKILL.md`
- `memory/MEMORY.md`
- Any other `.claude/skills/*/SKILL.md`
- `.claude/settings.json` and `.claude/hooks/*.sh` — do the automation hooks exist, AND are
  they tracked executable in git? Run `git ls-files -s .claude/hooks/` — mode must be `100755`.
  If missing, propose adding them (run Phase 8 from INIT MODE). If present but tracked as
  `100644`, they are silently dead (`exit 126` when the harness runs them) — fix with
  `git update-index --chmod=+x .claude/hooks/*.sh` and commit.

Identify: what looks outdated based on the git diff?

---

## UPDATE PHASE 3 — Investigate Changed Areas

For each significantly changed file/directory:
- New directory: run a mini Phase 1+2 on it
- New file in existing component: does it change the component's purpose?
- Deleted component: verify gone, not moved
- Modified core logic: read the relevant diff sections

Check for new external dependencies:
```
git diff HEAD~20 -- "*.csproj" "requirements*.txt" "package.json" \
  "go.mod" "Cargo.toml" "Gemfile" 2>/dev/null \
  | grep "^[+-]" | grep -v "^---\|^+++" | head -40
```

---

## UPDATE PHASE 4 — Produce Change Proposals

For each outdated or missing item, produce a proposal:

### PROPOSAL [N]: [Short title]
**File:** `path/to/file.md`
**Type:** Add / Edit / Remove / New file
**Reason:** [What changed in the codebase]
**Current:** [quote current text if editing]
**Proposed:** [exact replacement]
**Impact:** [what improves]

Do NOT apply anything yet.

Ask: "I found [N] updates needed. Apply all, or review one by one?"

---

## UPDATE PHASE 5 — Apply & Stamp

Apply only approved changes. Confirm each one.

After all edits:
- Re-check line counts (root ≤ 200, modules ≤ 80)
- If a file now exceeds limit, propose what to move to skills instead

Update the timestamp:
```
<!-- Last context update: [date] — [one-line summary of what changed] -->
```

Final summary:
- Files modified
- Proposals applied vs. skipped
- Manual follow-up items
- Recommended next update trigger
```
