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
enc="$(cd "$P" && pwd -P | sed 's#[^A-Za-z0-9]#-#g')"
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
# 1.5 MiB, not 2: du -m rounds UP and counts the directory's own block on ext4, so a 2 MiB file
# in a directory reports 3 MB on Linux and 2 MB on APFS. 1.5 MiB rounds to 2 on both.
mkdir -p "$P/.claude/worktrees/agent-a"; mkfile "$P/.claude/worktrees/agent-a/blob" $((3 * 512 * 1024))
out=$(cd "$P" && CLAUDE_PROJECT_DIR="$P" MCP_PROJECTS_DIR="$TMP/no-projects" MCP_WORKTREE_MB=1 "$HOOKS/context-budget.sh")
# du runs in the background (20 s at 31 GB timed the session-start hook out), so the first
# session has no measure yet and says nothing; the next one reads the cached size.
assert_empty "the first run is silent and measures in the background" "$out"
for _ in $(seq 1 50); do [ -s "$P/.claude/.worktrees-mb" ] && break; sleep 0.1; done
assert_file "the background measure writes its cache" "$P/.claude/.worktrees-mb"
out=$(cd "$P" && CLAUDE_PROJECT_DIR="$P" MCP_PROJECTS_DIR="$TMP/no-projects" MCP_WORKTREE_MB=1 "$HOOKS/context-budget.sh")
assert_contains "fires on oversized agent worktrees" "$out" ".claude/worktrees is 2 MB"

P="$TMP/enc test.dir_x"; rm -rf "$P"; mkdir -p "$P/memory"   # a dot, an underscore, a space
printf '# Index\n' > "$P/memory/MEMORY.md"
enc="$(cd "$P" && pwd -P | sed 's#[^A-Za-z0-9]#-#g')"
mkdir -p "$TMP/projects/$enc"; mkfile "$TMP/projects/$enc/live.jsonl" $((2 * 1024 * 1024))
out=$(cd "$P" && CLAUDE_PROJECT_DIR="$P" MCP_PROJECTS_DIR="$TMP/projects" MCP_TRANSCRIPT_MB=1 "$HOOKS/context-budget.sh")
assert_contains "finds the transcript of a path with a dot, an underscore and a space (every non-alphanumeric → -)" "$out" "live transcript is 2 MB"
out=$(cd "$P" && CLAUDE_PROJECT_DIR="$P" MCP_PROJECTS_DIR="$TMP/projects" MCP_TRANSCRIPT_MB=1 MCP_TRANSCRIPT_PATH="$TMP/projects/$enc/live.jsonl" "$HOOKS/context-budget.sh")
assert_contains "measures the transcript the harness names" "$out" "live transcript is 2 MB"
out=$(cd "$P" && CLAUDE_PROJECT_DIR="$P" MCP_PROJECTS_DIR="$TMP/projects" MCP_TRANSCRIPT_MB=1 MCP_TRANSCRIPT_PATH="$TMP/projects/$enc/not-yet.jsonl" "$HOOKS/context-budget.sh")
assert_empty "says nothing at a fresh startup (the named transcript does not exist yet; the old 2 MB one is not measured)" "$out"

P=$(fresh_project non-numeric)
for i in $(seq 1 120); do echo "- line $i"; done > "$P/memory/MEMORY.md"
out=$(cd "$P" && CLAUDE_PROJECT_DIR="$P" MCP_PROJECTS_DIR="$TMP/no-projects" MCP_MEM_LINES=eighty "$HOOKS/context-budget.sh")
assert_contains "a non-numeric override falls back to the default instead of skipping the check" "$out" "(budget 80)"

P=$(fresh_project two-points)
for i in $(seq 1 90); do echo "- line $i"; done > "$P/memory/MEMORY.md"; mkfile "$P/CLAUDE.md" 20000
out=$(cd "$P" && CLAUDE_PROJECT_DIR="$P" MCP_PROJECTS_DIR="$TMP/no-projects" "$HOOKS/context-budget.sh")
assert_contains "counts two broken budgets as two points" "$out" "over on 2 point(s)"

out=$(CLAUDE_PROJECT_DIR="$TMP/does-not-exist" "$HOOKS/context-budget.sh"); rc=$?
assert_eq "exits 0 when the project directory is missing (a hook must never take the session down)" "$rc" "0"

echo "prune-worktrees.sh"
export MCP_PRUNE_MIN_AGE_MIN=0   # every fixture is seconds old; the young guard has its own case below
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

R="$TMP/re po"; rm -rf "$R"; mkdir -p "$R"   # a path with a space, and a worktree left dirty
( cd "$R" && git init -q -b main && git config user.email t@example.com && git config user.name t \
  && echo a > a && git add a && git commit -qm init \
  && git branch clean && git worktree add -q .claude/worktrees/clean clean \
  && git branch dirty && git worktree add -q .claude/worktrees/dirty dirty \
  && echo result > .claude/worktrees/dirty/result.txt ) 2>/dev/null
out=$(cd "$R" && CLAUDE_PROJECT_DIR="$R" "$HOOKS/prune-worktrees.sh")
assert_contains "prunes in a repository whose path contains a space" "$out" "pruned 2 merged agent worktree(s); untracked files of 1 kept in .claude/worktree-archive/"
assert_no_dir "a clean worktree at the base tip is removed" "$R/.claude/worktrees/clean"
assert_no_dir "a merged worktree with only an untracked file is removed" "$R/.claude/worktrees/dirty"
assert_file "its untracked file moved to the archive, same path inside" "$R/.claude/worktree-archive/dirty/result.txt"

# A local main far behind origin/main (never pulled): merged means "in origin/main" too, read from
# the remote-tracking ref without a fetch. A deletion-only worktree on a merged branch goes too.
O="$TMP/origin.git"; R="$TMP/behind"; rm -rf "$O" "$R"; mkdir -p "$R"
( git init -q --bare -b main "$O" && cd "$R" && git init -q -b main && git config user.email t@example.com \
  && git config user.name t && echo a > a && git add a && git commit -qm init \
  && git remote add origin "$O" && git push -q origin main \
  && for w in landed deleted touched untracked open; do
       git branch "$w" && git worktree add -q ".claude/worktrees/$w" "$w" \
       && ( cd ".claude/worktrees/$w" && echo "$w" > "$w" && git add "$w" && git commit -qm "$w" ) || exit 1
     done \
  && git checkout -q -b up && git merge -q --no-edit landed deleted touched untracked \
  && git push -q origin up:main && git checkout -q main && git branch -q -D up \
  && git fetch -q origin \
  && rm .claude/worktrees/deleted/a && ( cd .claude/worktrees/deleted && git rm -q --cached deleted && rm deleted ) \
  && rm .claude/worktrees/touched/a && echo edit > .claude/worktrees/touched/touched \
  && rm .claude/worktrees/untracked/a && echo new > .claude/worktrees/untracked/new.txt \
  && rm .claude/worktrees/open/a \
  && git remote set-url origin "$TMP/gone.git" ) 2>/dev/null
assert_eq "fixture: local main is behind origin/main" "$(git -C "$R" rev-list --count main..origin/main)" "5"
out=$(cd "$R" && CLAUDE_PROJECT_DIR="$R" "$HOOKS/prune-worktrees.sh"); rc=$?
assert_contains "prunes branches merged into origin/main, not the local main, with no fetch" "$out" "pruned 3 merged agent worktree(s)"
assert_no_dir "a clean worktree merged only into origin/main is removed" "$R/.claude/worktrees/landed"
assert_no_dir "a merged worktree with only deletions (staged and unstaged) is removed" "$R/.claude/worktrees/deleted"
assert_dir "a deletion beside a modified file keeps the worktree" "$R/.claude/worktrees/touched"
assert_no_dir "a deletion beside an untracked file goes, the untracked file archived" "$R/.claude/worktrees/untracked"
assert_file "the untracked file is in the archive" "$R/.claude/worktree-archive/untracked/new.txt"
assert_dir "a deletion-only worktree whose branch is in neither main nor origin/main is kept" "$R/.claude/worktrees/open"
assert_eq "exit 0" "$rc" "0"

# F3675: a desk that merges into dev/simulator, not main. The main checkout works on dev/simulator;
# origin/main has none of it. Merged there (ancestry), merged by patch only (a cherry-pick: git
# cherry has no "+"), unmerged, a merged one with a tracked edit, and a young one.
O="$TMP/sim.git"; R="$TMP/sim"; rm -rf "$O" "$R"; mkdir -p "$R"
( git init -q --bare -b main "$O" && cd "$R" && git init -q -b main && git config user.email t@example.com \
  && git config user.name t && echo a > a && git add a && git commit -qm init \
  && git remote add origin "$O" && git push -q origin main \
  && git checkout -q -b dev/simulator \
  && for w in landed picked squashed open edited young; do
       git branch "$w" && git worktree add -q ".claude/worktrees/$w" "$w" \
       && ( cd ".claude/worktrees/$w" && echo "$w" > "$w" && git add "$w" && git commit -qm "$w" ) || exit 1
     done \
  && git merge -q --no-edit landed edited young && git cherry-pick picked >/dev/null \
  && ( cd .claude/worktrees/squashed && echo more >> squashed && git commit -qam squashed-2 ) \
  && git merge -q --squash squashed >/dev/null && git commit -qm "squashed (#1)" \
  && git push -q origin dev/simulator \
  && echo edit > .claude/worktrees/edited/edited \
  && mkdir -p .claude/worktrees/landed/output && echo shot > .claude/worktrees/landed/output/s.png ) 2>/dev/null
touch -t 202001010000 "$R/.claude/worktrees/landed" "$R/.claude/worktrees/picked" "$R/.claude/worktrees/squashed" "$R/.claude/worktrees/edited"
for f in HEAD index logs/HEAD gitdir; do
  for w in landed picked squashed edited; do [ -e "$R/.git/worktrees/$w/$f" ] && touch -t 202001010000 "$R/.git/worktrees/$w/$f"; done
done
export MCP_PRUNE_MIN_AGE_MIN=60
out=$(cd "$R" && CLAUDE_PROJECT_DIR="$R" "$HOOKS/prune-worktrees.sh" --report | sort | tr '\t\n' ': ')
assert_eq "report: the desk's base, not main; a tracked edit and a young one are held" "$out" "held:edited held:young prunable:landed prunable:picked prunable:squashed unmerged:open "
assert_dir "report removes nothing" "$R/.claude/worktrees/landed"
out=$(cd "$R" && CLAUDE_PROJECT_DIR="$R" "$HOOKS/prune-worktrees.sh"); rc=$?
assert_contains "prunes what dev/simulator contains, by ancestry, by patch and by content" "$out" "pruned 3 merged agent worktree(s)"
assert_no_dir "squash-merged into dev/simulator (cherry says +, the content is there): removed" "$R/.claude/worktrees/squashed"
assert_no_dir "merged into dev/simulator: removed" "$R/.claude/worktrees/landed"
assert_no_dir "cherry-picked into dev/simulator (git cherry, no +): removed" "$R/.claude/worktrees/picked"
assert_file "the untracked screenshot is archived" "$R/.claude/worktree-archive/landed/output/s.png"
assert_dir "unmerged: kept" "$R/.claude/worktrees/open"
assert_dir "merged with a tracked edit: kept" "$R/.claude/worktrees/edited"
assert_dir "merged but young (touched within MCP_PRUNE_MIN_AGE_MIN): kept" "$R/.claude/worktrees/young"
assert_eq "the base branch itself is never deleted" "$(git -C "$R" branch --list dev/simulator | tr -d ' *')" "dev/simulator"
assert_eq "exit 0" "$rc" "0"
# the budget line counts them by the same rule, with sizes
P="$R"; mkdir -p "$P/memory"; printf '# Index\n' > "$P/memory/MEMORY.md"
rm -f "$P/.claude/.worktrees-mb" "$P/.claude/.worktrees-state"
( cd "$P" && CLAUDE_PROJECT_DIR="$P" MCP_PROJECTS_DIR="$TMP/no-projects" MCP_WORKTREE_MB=0 "$HOOKS/context-budget.sh" >/dev/null )
for _ in $(seq 1 100); do [ -s "$P/.claude/.worktrees-state" ] && break; sleep 0.1; done
out=$(cd "$P" && CLAUDE_PROJECT_DIR="$P" MCP_PROJECTS_DIR="$TMP/no-projects" MCP_WORKTREE_MB=0 "$HOOKS/context-budget.sh")
assert_contains "the budget line counts merged and unmerged, with sizes" "$out" "0 merged (0 MB) can be pruned now, 2 merged but held ("
assert_contains "the budget line counts the unmerged one" "$out" "1 unmerged ("
unset MCP_PRUNE_MIN_AGE_MIN

echo "stop-handoff.sh"
S="$TMP/stop"; rm -rf "$S"; mkdir -p "$S/.claude/hooks"
( cd "$S" && git init -q -b main && git config user.email t@example.com && git config user.name t && echo a > a && git add a && git commit -qm init ) 2>/dev/null
rc=0; err=$(cd "$S" && printf '{"stop_hook_active":true}' | CLAUDE_PROJECT_DIR="$S" "$HOOKS/stop-handoff.sh" 2>&1) || rc=$?
assert_eq "exit 0 when stop_hook_active (no recursion)" "$rc" "0"
N="$TMP/nogit"; rm -rf "$N"; mkdir -p "$N/.claude"; printf 'old\n' > "$N/.claude/session-state.md"; touch -t 202001010000 "$N/.claude/session-state.md"
rc=0; err=$(cd "$N" && printf '{}' | CLAUDE_PROJECT_DIR="$N" "$HOOKS/stop-handoff.sh" 2>&1) || rc=$?
assert_eq "exit 0 outside a git repository (no baseline to compare, so never a false block)" "$rc" "0"
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
mkfile "$TMP/live-from-stdin.jsonl" $((2 * 1024 * 1024))
out=$(cd "$P" && printf '{"session_id":"x","transcript_path":"%s","cwd":"%s","hook_event_name":"SessionStart","source":"resume"}' "$TMP/live-from-stdin.jsonl" "$P" | CLAUDE_PROJECT_DIR="$P" MCP_PROJECTS_DIR="$TMP/no-projects" MCP_TRANSCRIPT_MB=1 "$HOOKS/session-start.sh")
assert_contains "reads transcript_path from the harness's stdin and measures that file" "$out" "live transcript is 2 MB"

echo "init/claude-context-init.md"
# The init prompt carries the four hooks inline so it can be pasted standalone. A copy drifts;
# this pins each fenced block to the file it claims to be.
INIT="$ROOT/init/claude-context-init.md"
for h in context-budget.sh prune-worktrees.sh session-start.sh stop-handoff.sh; do
  awk -v name="$h" '
    $0 == "Create `.claude/hooks/" name "` (chmod +x):" { want = 1; next }
    want && /^```bash$/ { inblk = 1; next }
    inblk && /^```$/ { exit }
    inblk { print }
  ' "$INIT" > "$TMP/init-$h"
  if [ -s "$TMP/init-$h" ] && diff -q "$TMP/init-$h" "$HOOKS/$h" >/dev/null; then ok "inline copy of $h matches hooks/$h"
  else bad "inline copy of $h matches hooks/$h" "the init prompt's fenced block differs from the file (rebuild the prompt)"; fi
done

echo
echo "$pass passed, $fail failed"
exit "$fail"
