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
