#!/usr/bin/env bash
# prune-worktrees.sh — remove agent worktrees whose branch has already landed on main.
#
# Each agent worktree is a full second checkout, most of it dependencies. Four
# of them once held 1.7 GB inside one repository — not mainly a disk problem:
# every tool that walked the tree walked five copies of it, and a linter once
# descended into one and failed THIS tree on another branch's code. The branch
# is the artefact; the checkout is scratch.
#
# Safe by construction, and it never guesses:
#   - a LOCKED worktree is skipped, which is how a running agent holds its own;
#   - a branch not fully merged into the base branch is left alone, so nothing
#     unmerged is ever discarded;
#   - it prints what it did and always exits 0, because a hook that fails must
#     not take the session down with it.
set -u
cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0
command -v git >/dev/null 2>&1 || exit 0
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

BASE="${MCP_BASE_BRANCH:-main}"
WORKTREE_DIR="${MCP_WORKTREE_DIR:-.claude/worktrees}"

removed=0
# --porcelain gives one "worktree <path>" line per entry
while IFS= read -r path; do
  case "$path" in *"$WORKTREE_DIR/"*) ;; *) continue ;; esac
  # a locked worktree belongs to a live agent
  [ -f "$(git rev-parse --git-dir)/worktrees/$(basename "$path")/locked" ] && continue
  branch=$(git -C "$path" rev-parse --abbrev-ref HEAD 2>/dev/null) || continue
  if [ -z "$branch" ] || [ "$branch" = "HEAD" ]; then continue; fi
  # only what the base branch already contains
  git merge-base --is-ancestor "$branch" "$BASE" 2>/dev/null || continue
  git worktree remove --force "$path" >/dev/null 2>&1 || continue
  git branch -D "$branch" >/dev/null 2>&1
  removed=$((removed + 1))
done < <(git worktree list --porcelain 2>/dev/null | awk '/^worktree /{print $2}')

git worktree prune >/dev/null 2>&1
[ "$removed" -gt 0 ] && echo "pruned $removed merged agent worktree(s)"
exit 0
