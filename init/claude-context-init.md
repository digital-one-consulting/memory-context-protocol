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
  if [ "${mb:-0}" -gt "$TRANSCRIPT_MB" ]; then
    add "- This project's live transcript is ${mb} MB. A session this long sits at its context ceiling, so every question is paying the ceiling regardless of size. **Finish with /handoff, then /clear.** The memory files are the continuity, not the transcript."
  fi
fi

if [ -d .claude/worktrees ]; then
  # the trailing slash follows a symlinked worktrees directory instead of measuring the link
  mb=$(du -sm .claude/worktrees/ 2>/dev/null | cut -f1)
  [ "${mb:-0}" -gt "$WORKTREE_MB" ] && add "- .claude/worktrees is ${mb} MB. Each agent worktree is a full checkout; merged ones are pruned at session start by prune-worktrees.sh, so anything left is unmerged and holding real work."
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
# Each agent worktree is a full second checkout, most of it dependencies. Four
# of them once held 1.7 GB inside one repository — not mainly a disk problem:
# every tool that walked the tree walked five copies of it, and a linter once
# descended into one and failed THIS tree on another branch's code. The branch
# is the artefact; the checkout is scratch.
#
# Safe by construction, and it never guesses:
#   - a LOCKED worktree is skipped, which is how a running agent holds its own;
#   - a worktree with UNCOMMITTED changes is skipped: a branch with no commits
#     of its own sits at the base branch's tip and counts as merged, and that
#     is exactly what a finished agent leaves behind — its work still unstaged;
#   - a branch not fully merged into the base branch is left alone, so nothing
#     unmerged is ever discarded;
#   - it removes without --force, so git's own refusals (dirty, locked) stand;
#   - it prints what it did and always exits 0, because a hook that fails must
#     not take the session down with it.
set -u
cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0
command -v git >/dev/null 2>&1 || exit 0
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

BASE="${MCP_BASE_BRANCH:-main}"
WORKTREE_DIR="${MCP_WORKTREE_DIR:-.claude/worktrees}"

removed=0
# --porcelain prints one block per worktree: "worktree <path>", "branch refs/heads/<name>",
# and "locked" when held. The path is taken whole — it may contain spaces.
while IFS=$'\t' read -r locked branch path; do
  [ -n "$path" ] || continue
  case "$path" in *"/$WORKTREE_DIR/"*) ;; *) continue ;; esac
  [ "$locked" = "1" ] && continue                                   # a live agent holds its own
  [ -n "$branch" ] || continue                                      # detached HEAD: not ours to judge
  [ -d "$path" ] || continue
  [ -z "$(git -C "$path" status --porcelain 2>/dev/null)" ] || continue   # uncommitted work stays
  git merge-base --is-ancestor "$branch" "$BASE" 2>/dev/null || continue  # only what the base contains
  git worktree remove "$path" >/dev/null 2>&1 || continue
  git branch -D "$branch" >/dev/null 2>&1                           # merged, so the branch is history
  removed=$((removed + 1))
done < <(git worktree list --porcelain 2>/dev/null | awk '
  function flush() { if (p != "") printf "%s\t%s\t%s\n", l, b, p; p = ""; b = ""; l = 0 }
  /^worktree / { flush(); p = substr($0, 10); next }
  /^branch /   { b = substr($0, 8); sub(/^refs\/heads\//, "", b); next }
  /^locked/    { l = 1; next }
  /^$/         { flush(); next }
  END          { flush() }')

git worktree prune >/dev/null 2>&1
[ "$removed" -gt 0 ] && echo "pruned $removed merged agent worktree(s)"
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
#   1. prune merged agent worktrees (scratch that would otherwise accumulate);
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

[ -x "$H/prune-worktrees.sh" ] && "$H/prune-worktrees.sh" >/dev/null 2>&1
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
