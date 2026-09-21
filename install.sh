#!/usr/bin/env bash
# install.sh — put the protocol into a project, into your global instructions, or just run the check.
#
#   install.sh --project <dir>   copy hooks, commands, settings and templates into <dir>
#   install.sh --global          append the protocol section to ~/.claude/CLAUDE.md, once
#   install.sh --check <dir>     run the budget check against <dir> (installs nothing)
#   install.sh --force ...       overwrite files that already exist (project mode)
#
# Never overwrites an existing file unless --force is given; prints what it did.
set -eu
SRC="$(cd "$(dirname "$0")" && pwd)"
force=0; mode=""; target=""
for a in "$@"; do
  case "$a" in
    --force) force=1 ;;
    --project|--global|--check) mode="$a" ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    *) target="$a" ;;
  esac
done
[ -n "$mode" ] || { sed -n '2,10p' "$0"; exit 1; }

put() { # put <src> <dst>  — copy unless dst exists (or --force)
  if [ -e "$2" ] && [ "$force" -eq 0 ]; then printf '  keep  %s (exists; --force to overwrite)\n' "$2"; return; fi
  mkdir -p "$(dirname "$2")"; cp "$1" "$2"; printf '  wrote %s\n' "$2"
}

case "$mode" in
  --check)
    d="${target:-.}"
    [ -d "$d" ] || { echo "not a directory: $d"; exit 1; }
    CLAUDE_PROJECT_DIR="$(cd "$d" && pwd)" "$SRC/hooks/context-budget.sh"
    ;;

  --project)
    d="${target:?--project needs a directory}"
    [ -d "$d" ] || { echo "not a directory: $d"; exit 1; }
    d="$(cd "$d" && pwd)"
    echo "installing into $d"
    for h in context-budget.sh prune-worktrees.sh session-start.sh stop-handoff.sh; do
      put "$SRC/hooks/$h" "$d/.claude/hooks/$h"; chmod +x "$d/.claude/hooks/$h"
    done
    for s in handoff dream catchup status update-context; do
      put "$SRC/skills/$s.md" "$d/.claude/commands/$s.md"
    done
    put "$SRC/hooks/settings.example.json" "$d/.claude/settings.json"
    put "$SRC/templates/MEMORY.md" "$d/memory/MEMORY.md"
    if [ -f "$d/.gitignore" ] && grep -q 'memory-context-protocol' "$d/.gitignore"; then
      printf '  keep  %s (protocol lines present)\n' "$d/.gitignore"
    else
      nl=""; [ -f "$d/.gitignore" ] && [ -n "$(tail -c1 "$d/.gitignore")" ] && nl=$'\n'
      { printf '%s' "$nl"; cat "$SRC/templates/gitignore-snippet"; } >> "$d/.gitignore"
      printf '  wrote %s (appended the local-only lines)\n' "$d/.gitignore"
    fi
    if [ -f "$d/.claude/settings.json" ] && ! grep -q 'session-start.sh' "$d/.claude/settings.json"; then
      echo "  NOTE  $d/.claude/settings.json exists without the hooks — merge hooks/settings.example.json into it by hand."
    fi
    echo "done. Next: read templates/CLAUDE.md-section.md and add the protocol section to $d/CLAUDE.md (or run --global)."
    ;;

  --global)
    f="${CLAUDE_HOME:-$HOME/.claude}/CLAUDE.md"
    mkdir -p "$(dirname "$f")"
    if [ -f "$f" ] && grep -q 'memory-context-protocol: begin' "$f"; then
      echo "  keep  $f (protocol section present)"
    else
      nl=""; [ -f "$f" ] && [ -n "$(tail -c1 "$f")" ] && nl=$'\n'
      [ -f "$f" ] && nl="$nl"$'\n'
      { printf '%s' "$nl"; cat "$SRC/templates/CLAUDE.md-section.md"; } >> "$f"
      echo "  wrote $f (appended the protocol section between markers)"
    fi
    ;;
esac
exit 0
