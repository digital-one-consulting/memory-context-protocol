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
cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0
H="$(cd "$(dirname "$0")" && pwd)"

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
