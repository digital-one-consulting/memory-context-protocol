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
