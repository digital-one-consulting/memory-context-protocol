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
#   - the one exception is a worktree whose only changes are DELETIONS of
#     tracked files and whose branch is merged: every deleted file is still in
#     the branch's commit, which the base contains, so removing it loses
#     nothing. A removal that stopped half-way leaves exactly that ("D" lines
#     only); git refuses it as dirty, so it alone is removed with --force.
#     A modified, added, renamed or untracked file still keeps the worktree;
#   - "merged" means contained in the local base branch OR in its
#     remote-tracking ref (origin/main). A local main can sit 80+ commits
#     behind, never pulled, and 2026-11-06 found 21 merged worktrees, 31 GB,
#     that the local-only test had kept. The hook never fetches (session
#     start has 15 s): it reads the ref the last fetch left, when there is one;
#   - a branch not fully merged into either is left alone, so nothing
#     unmerged is ever discarded;
#   - otherwise it removes without --force, so git's own refusals stand, and
#     a locked worktree needs --force twice, which it never gives;
#   - it prints what it did and always exits 0, because a hook that fails must
#     not take the session down with it.
set -u
cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0
command -v git >/dev/null 2>&1 || exit 0
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

BASE="${MCP_BASE_BRANCH:-main}"
WORKTREE_DIR="${MCP_WORKTREE_DIR:-.claude/worktrees}"
REMOTE_BASE="refs/remotes/${MCP_BASE_REMOTE:-origin}/$BASE"
git rev-parse --verify --quiet "$REMOTE_BASE" >/dev/null 2>&1 || REMOTE_BASE=""

merged() {
  git merge-base --is-ancestor "$1" "$BASE" 2>/dev/null && return 0
  [ -n "$REMOTE_BASE" ] && git merge-base --is-ancestor "$1" "$REMOTE_BASE" 2>/dev/null
}

removed=0
# --porcelain prints one block per worktree: "worktree <path>", "branch refs/heads/<name>",
# and "locked" when held. The path is taken whole — it may contain spaces.
while IFS=$'\t' read -r locked branch path; do
  [ -n "$path" ] || continue
  case "$path" in *"/$WORKTREE_DIR/"*) ;; *) continue ;; esac
  [ "$locked" = "1" ] && continue                                   # a live agent holds its own
  [ -n "$branch" ] || continue                                      # detached HEAD: not ours to judge
  [ -d "$path" ] || continue
  changes="$(git -C "$path" status --porcelain 2>/dev/null)" || continue
  force=""
  if [ -n "$changes" ]; then
    # only deletions ("D" in either column, nothing else) may go; see the header
    printf '%s\n' "$changes" | grep -qv '^[D ][D ] ' && continue    # uncommitted work stays
    force="--force"
  fi
  merged "$branch" || continue                                      # only what the base contains
  git worktree remove $force "$path" >/dev/null 2>&1 || continue
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
