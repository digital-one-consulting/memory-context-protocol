#!/usr/bin/env bash
# prune-worktrees.sh — remove agent worktrees whose branch has already landed on the base branch.
#
#   prune-worktrees.sh            prune, print what it did
#   prune-worktrees.sh --report   prune nothing; print "<class>\t<name>" for each agent worktree,
#                                 class prunable, held (merged, kept for now) or unmerged
#
# Each agent worktree is a full second checkout, most of it dependencies. Four
# of them once held 1.7 GB inside one repository — not mainly a disk problem:
# every tool that walked the tree walked five copies of it, and a linter once
# descended into one and failed THIS tree on another branch's code. The branch
# is the artefact; the checkout is scratch.
#
# Safe by construction, and it never guesses:
#   - a LOCKED worktree is skipped, which is how a running agent holds its own;
#   - a lock alone is not enough (F3638). 2026-11-16 18:55: a hand agent's lock named the claude
#     process that died in serve's 18:44 restart; the resumed session ran the agent on, but a
#     later Claude Code session took the lock for stale (its pid was dead) and let it go, and the
#     next session start pruned the live worktree: clean, and its branch had no commits, so main
#     "contained" it. So a worktree is also kept while a process has its cwd in it, and while it
#     is YOUNG: its folder or its git admin files changed in the last MCP_PRUNE_MIN_AGE_MIN
#     minutes (default 360). A finished agent's scratch goes at a session start after that;
#     a few hours of disk is cheap, a live agent's lost folder is not;
#   - a worktree with changes to TRACKED files is skipped: a branch with no commits
#     of its own sits at the base branch's tip and counts as merged, and that
#     is exactly what a finished agent leaves behind — its work still unstaged;
#   - the one exception is a worktree whose only changes are DELETIONS of
#     tracked files and whose branch is merged: every deleted file is still in
#     the branch's commit, which the base contains, so removing it loses
#     nothing. A removal that stopped half-way leaves exactly that ("D" lines
#     only); git refuses it as dirty, so it alone is removed with --force;
#   - UNTRACKED files of a merged worktree are moved, not lost (F3675). 2026-11-17: 13 of one
#     desk's 63 worktrees held only screenshots and reports an agent left in output/ and docs/,
#     so none of them ever went. They now move to .claude/worktree-archive/<name>/ (same paths
#     inside), then the worktree goes. Ignored files (node_modules) go with the worktree;
#   - the archive empties itself (F3678): a .claude/worktree-archive/<name> folder older than
#     MCP_ARCHIVE_KEEP_DAYS days (default 30, by its own mtime: the day it was filled) is deleted;
#     a younger one stays. The count is in the line it prints;
#   - the BASE is the desk's, not "main" (F3675). The same desk merges into dev/simulator and
#     reaches main only by release PRs days later: 48 merged worktrees, 16 GB, were kept because
#     none was in main. A branch is merged when any of these contains it: MCP_BASE_BRANCH (a
#     space-separated list, when set), the branch the main checkout works on and its upstream,
#     the remote's HEAD, main and master, and the remote's integration branches (dev, dev/*,
#     develop) — each local and as its remote-tracking ref (MCP_BASE_REMOTE, default origin).
#     A local main can sit 80+ commits behind, never pulled (2026-11-06: 21 merged worktrees,
#     31 GB kept), so the remote refs count too. The hook never fetches (session start has 15 s):
#     it reads the refs the last fetch left;
#   - "contains" is ancestry; or `git cherry` with no "+" line: every commit of the branch has
#     an equal patch in the base (a rebase or cherry-pick merge); or, for a squash merge (where
#     cherry says "+"), every file the branch changed since it left the base has the same content
#     in the base (2026-09-30: a squash-landed worktree held 1.3 GB and was pruned by hand);
#   - a worktree on one of the base branches themselves is never touched, nor its branch;
#   - a branch not merged into any base is left alone, so nothing unmerged is ever discarded;
#   - otherwise it removes without --force, so git's own refusals stand, and
#     a locked worktree needs --force twice, which it never gives;
#   - it reads status with --no-optional-locks: a plain `git status` rewrites the index, and the
#     hourly --report then kept every worktree young forever;
#   - it stops starting new removals after MCP_PRUNE_BUDGET_S seconds (default 10: a
#     session-start hook has 15 s); the rest wait for the next run;
#   - it prints what it did and always exits 0, because a hook that fails must
#     not take the session down with it.
set -u
cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0
command -v git >/dev/null 2>&1 || exit 0
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

REPORT=0
[ "${1:-}" = "--report" ] && REPORT=1
WORKTREE_DIR="${MCP_WORKTREE_DIR:-.claude/worktrees}"
ARCHIVE_DIR="${MCP_WORKTREE_ARCHIVE:-.claude/worktree-archive}"
REMOTE="${MCP_BASE_REMOTE:-origin}"

MIN_AGE="${MCP_PRUNE_MIN_AGE_MIN:-360}"
case "$MIN_AGE" in ''|*[!0-9]*) MIN_AGE=360 ;; esac
KEEP_DAYS="${MCP_ARCHIVE_KEEP_DAYS:-30}"
case "$KEEP_DAYS" in ''|*[!0-9]*) KEEP_DAYS=30 ;; esac
BUDGET="${MCP_PRUNE_BUDGET_S:-10}"
case "$BUDGET" in ''|*[!0-9]*) BUDGET=10 ;; esac
# Every process's cwd, read once (lsof takes ~0.1 s here); empty when lsof is missing.
CWDS="$(lsof -a -d cwd -Fn 2>/dev/null | sed -n 's/^n//p')"

# The worktrees, one "<locked>\t<branch>\t<path>" line each, the main checkout first. The path is
# taken whole — it may contain spaces.
TREES="$(git worktree list --porcelain 2>/dev/null | awk '
  function flush() { if (p != "") printf "%s\t%s\t%s\n", l, b, p; p = ""; b = ""; l = 0 }
  /^worktree / { flush(); p = substr($0, 10); next }
  /^branch /   { b = substr($0, 8); sub(/^refs\/heads\//, "", b); next }
  /^locked/    { l = 1; next }
  /^$/         { flush(); next }
  END          { flush() }')"
MAIN_BRANCH="$(printf '%s\n' "$TREES" | head -n 1 | cut -f2)"
MAIN_PATH="$(printf '%s\n' "$TREES" | head -n 1 | cut -f3-)"
[ -d "$MAIN_PATH" ] || MAIN_PATH="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# The base names (local short names), then the refs that exist, one per commit.
BASE_NAMES="$(
  for b in ${MCP_BASE_BRANCH:-}; do echo "$b"; done
  [ -n "$MAIN_BRANCH" ] && echo "$MAIN_BRANCH"
  up="$(git -C "$MAIN_PATH" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null)" \
    && echo "${up#"$REMOTE"/}"
  h="$(git symbolic-ref --quiet --short "refs/remotes/$REMOTE/HEAD" 2>/dev/null)" && echo "${h#"$REMOTE"/}"
  echo main; echo master
  git for-each-ref --format='%(refname)' "refs/remotes/$REMOTE/dev" "refs/remotes/$REMOTE/develop" 2>/dev/null \
    | sed "s#^refs/remotes/$REMOTE/##"
)"
BASES="$(printf '%s\n' "$BASE_NAMES" | awk 'NF && !seen[$0]++' | while IFS= read -r b; do
  for r in "refs/heads/$b" "refs/remotes/$REMOTE/$b"; do
    s="$(git rev-parse --verify --quiet "$r^{commit}" 2>/dev/null)" && printf '%s %s\n' "$s" "$r"
  done
done | awk '!seen[$1]++ { print $2 }')"

# is_base <branch>: the branch is one of the bases itself.
is_base() { printf '%s\n' "$BASE_NAMES" | grep -qxF -- "$1"; }

# busy <path>: a process works in it (its cwd is the folder or below it).
busy() {
  [ -n "$CWDS" ] || return 1
  printf '%s\n' "$CWDS" | awk -v p="$1" 'index($0, p) == 1 && (length($0) == length(p) || substr($0, length(p) + 1, 1) == "/") { f = 1 } END { exit !f }'
}

# young <path>: the folder or its admin files (HEAD, index, logs/HEAD, gitdir) changed recently.
young() {
  [ "$MIN_AGE" -gt 0 ] || return 1
  local admin f
  admin="$(git -C "$1" rev-parse --absolute-git-dir 2>/dev/null)"
  for f in "$1" "$admin/HEAD" "$admin/index" "$admin/logs/HEAD" "$admin/gitdir"; do
    [ -e "$f" ] || continue
    [ -n "$(find "$f" -maxdepth 0 -mmin "-$MIN_AGE" 2>/dev/null)" ] && return 0
  done
  return 1
}

# merged <branch>: a base contains it, by ancestry, by patch (git cherry, no "+" line) or by content.
merged() {
  local b out mb
  [ -n "$BASES" ] || return 1
  while IFS= read -r b; do
    git merge-base --is-ancestor "$1" "$b" 2>/dev/null && return 0
  done <<EOF
$BASES
EOF
  while IFS= read -r b; do
    out="$(git cherry "$b" "$1" 2>/dev/null)" || continue
    [ -n "$out" ] && ! printf '%s\n' "$out" | grep -q '^+' && return 0
  done <<EOF
$BASES
EOF
  # a squash merge: git cherry says "+" (one new commit, another patch), so compare the files the
  # branch changed since it left the base: the same content in the base means nothing is lost.
  while IFS= read -r b; do
    mb="$(git merge-base "$b" "$1" 2>/dev/null)" || continue
    git diff --quiet "$mb" "$1" 2>/dev/null && continue
    git diff --name-only -z "$mb" "$1" 2>/dev/null | xargs -0 git diff --quiet "$1" "$b" -- 2>/dev/null && return 0
  done <<EOF
$BASES
EOF
  return 1
}

# archive <path> <name>: move the worktree's untracked files to the archive, same paths inside.
archive() {
  local dest="$MAIN_PATH/$ARCHIVE_DIR/$2" e rel
  [ -e "$dest" ] && dest="$dest-$(date +%Y%m%d%H%M%S)"
  while IFS= read -r -d '' e; do
    case "$e" in '?? '*) ;; *) continue ;; esac
    rel="${e#?? }"; rel="${rel%/}"
    [ -n "$rel" ] && [ -e "$1/$rel" ] || continue
    mkdir -p "$dest/$(dirname "$rel")" && mv "$1/$rel" "$dest/$rel" || return 1
  done < <(git --no-optional-locks -C "$1" status --porcelain -z 2>/dev/null)
  return 0
}

removed=0
archived=0
while IFS=$'\t' read -r -u 3 locked branch path; do
  [ -n "$path" ] || continue
  case "$path" in *"/$WORKTREE_DIR/"*) ;; *) continue ;; esac
  [ -d "$path" ] || continue
  name="$(basename "$path")"
  [ -n "$branch" ] || { [ "$REPORT" = 1 ] && printf 'unmerged\t%s\n' "$name"; continue; }  # detached HEAD: not ours to judge
  is_base "$branch" && continue                                     # a base branch itself
  if ! merged "$branch"; then                                       # only what a base contains
    [ "$REPORT" = 1 ] && printf 'unmerged\t%s\n' "$name"
    continue
  fi
  held=0
  [ "$locked" = "1" ] && held=1                                     # a live agent holds its own
  [ "$held" = 0 ] && busy "$path" && held=1                         # a process works in it (F3638)
  [ "$held" = 0 ] && young "$path" && held=1                        # touched lately: maybe live (F3638)
  changes=""
  if [ "$held" = 0 ]; then
    changes="$(git --no-optional-locks -C "$path" status --porcelain 2>/dev/null)" || held=1
    # only deletions ("D" in either column) and untracked files ("??") may go; see the header
    [ -n "$changes" ] && printf '%s\n' "$changes" | grep -Eqv '^([D ][D ] |\?\? )' && held=1
  fi
  if [ "$REPORT" = 1 ]; then
    [ "$held" = 1 ] && printf 'held\t%s\n' "$name" || printf 'prunable\t%s\n' "$name"
    continue
  fi
  [ "$held" = 1 ] && continue
  [ "$SECONDS" -ge "$BUDGET" ] && break                             # the rest wait for the next run
  force=""
  printf '%s\n' "$changes" | grep -q '^[D ][D ] ' && force="--force"
  if printf '%s\n' "$changes" | grep -q '^?? '; then
    archive "$path" "$name" || continue
    archived=$((archived + 1))
  fi
  git worktree remove $force "$path" >/dev/null 2>&1 || continue
  git branch -D "$branch" >/dev/null 2>&1                           # merged, so the branch is history
  removed=$((removed + 1))
done 3<<EOF
$TREES
EOF

[ "$REPORT" = 1 ] && exit 0
git worktree prune >/dev/null 2>&1

# F3678: the archive is emptied by age, its direct folders only (rm -rf removes a symlink inside
# as a link, never its target). MCP_ARCHIVE_KEEP_DAYS=0 keeps them all.
expired=0
if [ "$KEEP_DAYS" -gt 0 ] && [ -d "$MAIN_PATH/$ARCHIVE_DIR" ]; then
  while IFS= read -r -d '' old; do
    rm -rf -- "$old" 2>/dev/null && expired=$((expired + 1))
  done < <(find "$MAIN_PATH/$ARCHIVE_DIR/" -mindepth 1 -maxdepth 1 -type d -mmin "+$((KEEP_DAYS * 1440))" -print0 2>/dev/null)
fi

line=""
if [ "$removed" -gt 0 ]; then
  line="pruned $removed merged agent worktree(s)"
  [ "$archived" -gt 0 ] && line="$line; untracked files of $archived kept in $ARCHIVE_DIR/"
fi
if [ "$expired" -gt 0 ]; then
  [ -n "$line" ] && line="$line; "
  line="${line}deleted $expired archived folder(s) older than $KEEP_DAYS days from $ARCHIVE_DIR/"
fi
[ -n "$line" ] && echo "$line"
exit 0
