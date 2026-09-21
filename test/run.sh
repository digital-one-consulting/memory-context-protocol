#!/usr/bin/env bash
# test/run.sh — proves every check can fail, and that it stays silent when it should.
#
# No framework, no dependencies beyond bash, git and coreutils. Every fixture
# is built in a temporary directory at run time, so the repository carries no
# large files. Run it as `test/run.sh`; exit status is the number of failures.
#
# A check that has never been seen to fire is not a check. Each hook here is
# driven once into its healthy state (must print nothing / exit 0) and once
# into each of its failure states (must print the specific warning / block).
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOKS="$ROOT/hooks"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/mcp-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
ok()   { pass=$((pass + 1)); printf '  ok    %s\n' "$1"; }
bad()  { fail=$((fail + 1)); printf '  FAIL  %s\n        %s\n' "$1" "$2"; }
# assert_contains <label> <haystack> <needle>
assert_contains() { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1" "expected to contain: $3"$'\n'"        got: $(printf '%s' "$2" | head -c 300)" ;; esac; }
assert_empty()    { if [ -z "$2" ]; then ok "$1"; else bad "$1" "expected silence, got: $(printf '%s' "$2" | head -c 300)"; fi; }
assert_eq()       { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected '$3', got '$2'"; fi; }
assert_dir()      { if [ -d "$2" ]; then ok "$1"; else bad "$1" "directory missing: $2"; fi; }
assert_no_dir()   { if [ ! -d "$2" ]; then ok "$1"; else bad "$1" "still on disk: $2"; fi; }
assert_file()     { if [ -s "$2" ]; then ok "$1"; else bad "$1" "missing or empty: $2"; fi; }
mkfile() { # mkfile <path> <bytes>  — exact byte count, no sparse tricks (du must see it)
  head -c "$2" /dev/zero | tr '\0' 'x' > "$1"
}
fresh_project() { # a minimal project directory with a healthy index and instruction file
  local d="$TMP/$1"; rm -rf "$d"; mkdir -p "$d/memory" "$d/.claude/hooks"
  printf '# Project Memory Index\n- [Topic](topic.md) — one line per topic\n' > "$d/memory/MEMORY.md"
  printf '# Project\nShort instructions.\n' > "$d/CLAUDE.md"
  echo "$d"
}

echo "context-budget.sh"
P=$(fresh_project healthy)
out=$(cd "$P" && CLAUDE_PROJECT_DIR="$P" MCP_PROJECTS_DIR="$TMP/no-projects" "$HOOKS/context-budget.sh"); rc=$?
assert_empty "silent when every budget holds" "$out"
assert_eq    "exit 0 when healthy" "$rc" "0"

P=$(fresh_project over-index)
for i in $(seq 1 120); do echo "- line $i"; done > "$P/memory/MEMORY.md"
out=$(cd "$P" && CLAUDE_PROJECT_DIR="$P" MCP_PROJECTS_DIR="$TMP/no-projects" "$HOOKS/context-budget.sh"); rc=$?
assert_contains "fires on a 120-line index" "$out" "memory/MEMORY.md is 120 lines (budget 80)"
assert_contains "reports the count of points" "$out" "over on 1 point(s)"
assert_eq       "still exits 0 when over budget" "$rc" "0"

P=$(fresh_project claude-boundary)
mkfile "$P/CLAUDE.md" 9215
out=$(cd "$P" && CLAUDE_PROJECT_DIR="$P" MCP_PROJECTS_DIR="$TMP/no-projects" "$HOOKS/context-budget.sh")
assert_empty "CLAUDE.md at 9,215 bytes is silent (integer division: 8 KB is not over 8)" "$out"
mkfile "$P/CLAUDE.md" 9216
out=$(cd "$P" && CLAUDE_PROJECT_DIR="$P" MCP_PROJECTS_DIR="$TMP/no-projects" "$HOOKS/context-budget.sh")
assert_contains "CLAUDE.md at 9,216 bytes fires — the real threshold is what the arithmetic computes" "$out" "CLAUDE.md is 9 KB (budget 8 KB)"

P=$(fresh_project transcript)
enc="$(cd "$P" && pwd | sed 's#/#-#g')"
mkdir -p "$TMP/projects/$enc"
mkfile "$TMP/projects/$enc/old.jsonl" $((5 * 1024 * 1024)); touch -t 202001010000 "$TMP/projects/$enc/old.jsonl"
mkfile "$TMP/projects/$enc/live.jsonl" $((2 * 1024 * 1024))
out=$(cd "$P" && CLAUDE_PROJECT_DIR="$P" MCP_PROJECTS_DIR="$TMP/projects" MCP_TRANSCRIPT_MB=1 "$HOOKS/context-budget.sh")
assert_contains "fires on the live transcript over budget" "$out" "live transcript is 2 MB"
assert_contains "the warning names the exit" "$out" "/handoff, then /clear"
mkfile "$TMP/projects/$enc/live.jsonl" 100   # the live one is now tiny; the old 5 MB one must not count
out=$(cd "$P" && CLAUDE_PROJECT_DIR="$P" MCP_PROJECTS_DIR="$TMP/projects" MCP_TRANSCRIPT_MB=1 "$HOOKS/context-budget.sh")
assert_empty "silent when only an OLD transcript is over budget (only the newest counts)" "$out"

P=$(fresh_project worktrees)
mkdir -p "$P/.claude/worktrees/agent-a"; mkfile "$P/.claude/worktrees/agent-a/blob" $((2 * 1024 * 1024))
out=$(cd "$P" && CLAUDE_PROJECT_DIR="$P" MCP_PROJECTS_DIR="$TMP/no-projects" MCP_WORKTREE_MB=1 "$HOOKS/context-budget.sh")
assert_contains "fires on oversized agent worktrees" "$out" ".claude/worktrees is 2 MB"

P=$(fresh_project two-points)
for i in $(seq 1 90); do echo "- line $i"; done > "$P/memory/MEMORY.md"; mkfile "$P/CLAUDE.md" 20000
out=$(cd "$P" && CLAUDE_PROJECT_DIR="$P" MCP_PROJECTS_DIR="$TMP/no-projects" "$HOOKS/context-budget.sh")
assert_contains "counts two broken budgets as two points" "$out" "over on 2 point(s)"

out=$(CLAUDE_PROJECT_DIR="$TMP/does-not-exist" "$HOOKS/context-budget.sh"); rc=$?
assert_eq "exits 0 when the project directory is missing (a hook must never take the session down)" "$rc" "0"

echo "prune-worktrees.sh"
R="$TMP/repo"; rm -rf "$R"; mkdir -p "$R"
( cd "$R" && git init -q -b main && git config user.email t@example.com && git config user.name t \
  && echo a > a && git add a && git commit -qm init \
  && git branch merged && git worktree add -q .claude/worktrees/merged merged \
  && ( cd .claude/worktrees/merged && echo b > b && git add b && git commit -qm merged-work ) \
  && git merge -q merged \
  && git branch unmerged && git worktree add -q .claude/worktrees/unmerged unmerged \
  && ( cd .claude/worktrees/unmerged && echo c > c && git add c && git commit -qm unmerged-work ) \
  && git branch locked && git worktree add -q .claude/worktrees/locked locked \
  && ( cd .claude/worktrees/locked && echo d > d && git add d && git commit -qm locked-work ) \
  && git merge -q locked && git worktree lock .claude/worktrees/locked ) 2>/dev/null
out=$(cd "$R" && CLAUDE_PROJECT_DIR="$R" "$HOOKS/prune-worktrees.sh"); rc=$?
assert_contains "removes exactly the merged, unlocked worktree" "$out" "pruned 1 merged agent worktree(s)"
assert_no_dir "merged worktree gone" "$R/.claude/worktrees/merged"
assert_dir "unmerged worktree kept (nothing unmerged is ever discarded)" "$R/.claude/worktrees/unmerged"
assert_dir "locked worktree kept (a running agent holds its own)" "$R/.claude/worktrees/locked"
assert_eq "exit 0" "$rc" "0"
out=$(cd "$TMP" && CLAUDE_PROJECT_DIR="$TMP" "$HOOKS/prune-worktrees.sh"); rc=$?
assert_eq "silent and exit 0 outside a git repository" "$out|$rc" "|0"

echo "stop-handoff.sh"
S="$TMP/stop"; rm -rf "$S"; mkdir -p "$S/.claude/hooks"
( cd "$S" && git init -q -b main && git config user.email t@example.com && git config user.name t && echo a > a && git add a && git commit -qm init ) 2>/dev/null
rc=0; err=$(cd "$S" && printf '{"stop_hook_active":true}' | CLAUDE_PROJECT_DIR="$S" "$HOOKS/stop-handoff.sh" 2>&1) || rc=$?
assert_eq "exit 0 when stop_hook_active (no recursion)" "$rc" "0"
printf '## Handoff\n' > "$S/.claude/session-state.md"
rc=0; err=$(cd "$S" && printf '{}' | CLAUDE_PROJECT_DIR="$S" "$HOOKS/stop-handoff.sh" 2>&1) || rc=$?
assert_eq "exit 0 when the state file is fresh (throttle)" "$rc" "0"
touch -t 202001010000 "$S/.claude/session-state.md"
( cd "$S" && CLAUDE_PROJECT_DIR="$S" "$HOOKS/session-start.sh" >/dev/null 2>&1 )   # writes the baseline
rc=0; err=$(cd "$S" && printf '{}' | CLAUDE_PROJECT_DIR="$S" "$HOOKS/stop-handoff.sh" 2>&1) || rc=$?
assert_eq "exit 0 when stale but nothing changed since session start" "$rc" "0"
echo change > "$S/a"
rc=0; err=$(cd "$S" && printf '{}' | CLAUDE_PROJECT_DIR="$S" "$HOOKS/stop-handoff.sh" 2>&1) || rc=$?
assert_eq       "exit 2 (block) when stale AND the repository changed" "$rc" "2"
assert_contains "the block names /handoff" "$err" "/handoff"
assert_contains "the block names /dream" "$err" "/dream"
rc=0; err=$(cd "$S" && printf '{}' | CLAUDE_PROJECT_DIR="$S" "$HOOKS/stop-handoff.sh" 2>&1) || rc=$?
assert_eq "exit 0 on the very next stop (the baseline was advanced; no loop)" "$rc" "0"

echo "session-start.sh"
P=$(fresh_project start)
( cd "$P" && git init -q -b main && git config user.email t@example.com && git config user.name t && git add -A && git commit -qm init ) 2>/dev/null
printf '# Index\n<!-- Session 41: private history\nmore history -->\n- [Topic](topic.md) — the pointer\n' > "$P/memory/MEMORY.md"
printf '## Handoff: 2026-01-01\nWorking on X\n' > "$P/.claude/session-state.md"; touch -t 202001010000 "$P/.claude/session-state.md"
out=$(cd "$P" && CLAUDE_PROJECT_DIR="$P" MCP_PROJECTS_DIR="$TMP/no-projects" "$HOOKS/session-start.sh")
assert_contains "injects the memory index" "$out" "- [Topic](topic.md) — the pointer"
case "$out" in *"private history"*) bad "strips HTML-comment history at injection" "comment text was injected" ;; *) ok "strips HTML-comment history at injection" ;; esac
assert_contains "injects the last handoff" "$out" "Working on X"
assert_contains "warns when the handoff is old" "$out" "days old"
assert_contains "asks for /catchup" "$out" "/catchup"
assert_file "writes the baseline for the Stop hook" "$P/.claude/hooks/.session-baseline"
case "$out" in *"Context budget"*) bad "no budget section when healthy" "budget section present" ;; *) ok "no budget section when healthy" ;; esac
for i in $(seq 1 100); do echo "- line $i"; done > "$P/memory/MEMORY.md"
out=$(cd "$P" && CLAUDE_PROJECT_DIR="$P" MCP_PROJECTS_DIR="$TMP/no-projects" "$HOOKS/session-start.sh")
assert_contains "surfaces the budget report before the first turn" "$out" "over on 1 point(s)"
assert_contains "tells the agent to say it in one line" "$out" "in one line before the first answer"

echo
echo "$pass passed, $fail failed"
exit "$fail"
