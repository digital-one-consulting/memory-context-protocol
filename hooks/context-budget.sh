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
