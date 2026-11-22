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
      if [ -x "$H/prune-worktrees.sh" ]; then
        sizes="$(du -sm .claude/worktrees/*/ 2>/dev/null)"
        CLAUDE_PROJECT_DIR="$PWD" "$H/prune-worktrees.sh" --report 2>/dev/null \
          | SIZES="$sizes" awk -F '\t' '
              BEGIN { n = split(ENVIRON["SIZES"], l, "\n"); for (i = 1; i <= n; i++) { split(l[i], f, "\t"); p = f[2]; sub(/\/+$/, "", p); sub(/.*\//, "", p); mb[p] = f[1] } }
              { c[$1]++; s[$1] += mb[$2] }
              END { printf "prunable %d %d\nheld %d %d\nunmerged %d %d\n", c["prunable"], s["prunable"], c["held"], s["held"], c["unmerged"], s["unmerged"] }' \
          > "$state.tmp"
        # F3678: the archive the prune hook fills (and empties after 30 days), counted the same way
        an=0; am=0
        if [ -d .claude/worktree-archive ]; then
          an=$(find .claude/worktree-archive/ -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -cd '0-9')
          am=$(du -sm .claude/worktree-archive/ 2>/dev/null | cut -f1)
        fi
        printf 'archive %d %d\n' "${an:-0}" "${am:-0}" >> "$state.tmp" && mv "$state.tmp" "$state"
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
      read -r _ pn pm _ hn hm _ un um _ an am <<EOF
$(tr '\n' ' ' < "$state")
EOF
      left=" Left: ${pn:-0} merged (${pm:-0} MB) for its next run, ${hn:-0} merged but held (${hm:-0} MB), ${un:-0} unmerged (${um:-0} MB)."
      [ "${an:-0}" -gt 0 ] 2>/dev/null && arch=" .claude/worktree-archive holds ${an} folder(s) (${am:-0} MB) of untracked files from pruned worktrees; prune-worktrees.sh deletes those older than 30 days."
    fi
    add "- .claude/worktrees is ${mb} MB. ${eng}.${left} Nothing to do: a held worktree has a live agent, a lock or a change, and an unmerged one holds real work.${arch}"
  elif [ "${mb:-0}" -gt "$WORKTREE_MB" ]; then
    if [ -f "$state" ]; then
      # "<class> <count> <MB>" per line
      read -r _ pn pm _ hn hm _ un um _ an am <<EOF
$(tr '\n' ' ' < "$state")
EOF
      arch=""
      [ "${an:-0}" -gt 0 ] 2>/dev/null && arch=" .claude/worktree-archive holds ${an} folder(s) (${am:-0} MB) of untracked files from pruned worktrees; prune-worktrees.sh deletes those older than 30 days."
      add "- .claude/worktrees is ${mb} MB: ${pn:-0} merged (${pm:-0} MB) can be pruned now, ${hn:-0} merged but held (${hm:-0} MB), ${un:-0} unmerged (${um:-0} MB). Each agent worktree is a full checkout; prune-worktrees.sh removes the merged ones (locked, live or with tracked changes are held); the unmerged ones hold real work.${arch}"
    else
      add "- .claude/worktrees is ${mb} MB. Each agent worktree is a full checkout; merged and unmerged are not counted yet (the next measure sorts them)."
    fi
  fi
fi

if [ -n "$warn" ]; then
  printf '## Context budget — over on %d point(s)\n%s' "$(printf '%s' "$warn" | grep -c '^- ')" "$warn"
fi
exit 0
