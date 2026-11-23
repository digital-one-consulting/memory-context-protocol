#!/usr/bin/env bash
# prune-worktrees.sh — remove agent worktrees whose branch has already landed on the base branch.
#
#   prune-worktrees.sh            prune, print what it did
#   prune-worktrees.sh --report   prune nothing; print "<class>\t<name>\t<MB>\t<why>" for each agent
#                                 worktree, class prunable, held (merged, kept for now) or unmerged
#
# Each agent worktree is a full second checkout, most of it dependencies. Four
# of them once held 1.7 GB inside one repository — not mainly a disk problem:
# every tool that walked the tree walked five copies of it, and a linter once
# descended into one and failed THIS tree on another branch's code. The branch
# is the artefact; the checkout is scratch.
#
# Safe by construction, and it never guesses:
#   - a worktree LOCKED by a live agent is skipped: Claude Code's lock names its process
#     ("claude agent <name> (pid N start ...)"), and while that pid lives the worktree stays. A
#     lock that names no pid is kept too (a person locked it). A lock whose pid is dead is stale:
#     the rules below then judge the worktree as unlocked, and it is unlocked before its removal;
#   - a lock alone is not enough (F3638). 2026-11-16 18:55: a hand agent's lock named the claude
#     process that died in serve's 18:44 restart; the resumed session ran the agent on, but a
#     later Claude Code session took the lock for stale (its pid was dead) and let it go, and the
#     next session start pruned the live worktree: clean, and its branch had no commits, so main
#     "contained" it. So a worktree is also kept while a process has its cwd in it, and while it
#     is YOUNG: its folder or its git admin files changed in the last MCP_PRUNE_MIN_AGE_MIN
#     minutes (default 360). A finished agent's scratch goes at a session start after that;
#     a few hours of disk is cheap, a live agent's lost folder is not;
#   - GENERATED files do not hold a merged worktree (WP1). 2026-11-23, desk artemis-frontend-demo:
#     13 merged worktrees, 5.8 GB, were held for "a change" that was only build and test output
#     (`M TODO.md`, `M test/report.json`, 450 untracked files in dist/ and output/). A change whose
#     path matches the generated list goes with the worktree: dist/**, output/**,
#     test/report.json, **/*.log, TODO.md and todo/*.md (a to-do checkpoint the base already
#     has), plus one glob per line of the workspace's .builds/worktree-ignore (MCP_WORKTREE_IGNORE;
#     "#" starts a comment). A glob without "/" matches at any depth; ** spans folders;
#   - a deletion of a tracked file in a merged worktree goes too: every deleted file is still in
#     the branch's commit, which the base contains. A removal that stopped half-way leaves exactly
#     that ("D" lines only);
#   - other UNTRACKED files of a merged worktree are moved, not lost (F3675). 2026-11-17: 13 of one
#     desk's 63 worktrees held only screenshots and reports an agent left in docs/, so none of them
#     ever went. They now move to .claude/worktree-archive/<name>/ (same paths inside), then the
#     worktree goes. Ignored files (node_modules) go with the worktree;
#   - other changes to TRACKED files hold a merged worktree for MCP_PRUNE_DIRTY_AGE_H hours
#     (default 24) after the last one: a branch with no commits of its own sits at the base's tip
#     and counts as merged, and that is what a finished agent leaves behind, its work unstaged.
#     After that (WP2) `git diff HEAD` with its untracked, non-generated files is saved as
#     .claude/worktree-archive/<name>.patch, the patch is checked to undo exactly to HEAD from what
#     is on disk (git apply --check -R), and only then does the worktree go;
#   - an UNMERGED worktree with no live agent whose branch has had no commit for MCP_PRUNE_IDLE_DAYS
#     days (default 7), and no change for MCP_PRUNE_DIRTY_AGE_H hours, loses its folder, never its
#     branch (WP3): its changes are saved and checked as a patch the same way first. 2026-11-23:
#     7 unmerged worktrees (3 GB) of ended hand agents, the oldest from 11-15. A detached HEAD has
#     no branch to keep, so it stays;
#   - the archive empties itself (F3678): a .claude/worktree-archive/<name> folder older than
#     MCP_ARCHIVE_KEEP_DAYS days (default 30, by its own mtime: the day it was filled) is deleted;
#     a younger one stays. The count is in the line it prints. Patches are small and stay;
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
#   - it reads status with --no-optional-locks: a plain `git status` rewrites the index, and the
#     hourly --report then kept every worktree young forever;
#   - --report gives each worktree its own `du -sk` (WP4: the budget line once said 50 MB for
#     5.8 GB) and says why it stays: the live agent's pid, the lock, the changed files and their
#     age, the last commit's age;
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
IGNORE_FILE="${MCP_WORKTREE_IGNORE:-.builds/worktree-ignore}"
REMOTE="${MCP_BASE_REMOTE:-origin}"

MIN_AGE="${MCP_PRUNE_MIN_AGE_MIN:-360}"
case "$MIN_AGE" in ''|*[!0-9]*) MIN_AGE=360 ;; esac
DIRTY_H="${MCP_PRUNE_DIRTY_AGE_H:-24}"
case "$DIRTY_H" in ''|*[!0-9]*) DIRTY_H=24 ;; esac
IDLE_DAYS="${MCP_PRUNE_IDLE_DAYS:-7}"
case "$IDLE_DAYS" in ''|*[!0-9]*) IDLE_DAYS=7 ;; esac
KEEP_DAYS="${MCP_ARCHIVE_KEEP_DAYS:-30}"
case "$KEEP_DAYS" in ''|*[!0-9]*) KEEP_DAYS=30 ;; esac
BUDGET="${MCP_PRUNE_BUDGET_S:-10}"
case "$BUDGET" in ''|*[!0-9]*) BUDGET=10 ;; esac
NOW="$(date +%s)"
# Every process's cwd, read once (lsof takes ~0.1 s here); empty when lsof is missing.
CWDS="$(lsof -a -d cwd -Fn 2>/dev/null | sed -n 's/^n//p')"
TMPD="$(mktemp -d "${TMPDIR:-/tmp}/prune-wt.XXXXXX" 2>/dev/null)" || exit 0
trap 'rm -rf "$TMPD"' EXIT

# The worktrees, one "<lock>\t<branch>\t<path>" line each, the main checkout first; <lock> is "-"
# when unlocked, else the lock's reason. The path is taken whole — it may contain spaces.
TREES="$(git worktree list --porcelain 2>/dev/null | awk '
  function flush() { if (p != "") printf "%s\t%s\t%s\n", l, (b == "" ? "-" : b), p; p = ""; b = ""; l = "-" }
  BEGIN        { l = "-" }
  /^worktree / { flush(); p = substr($0, 10); next }
  /^branch /   { b = substr($0, 8); sub(/^refs\/heads\//, "", b); next }
  /^locked/    { l = substr($0, 8); gsub(/\t/, " ", l); if (l == "") l = "(no reason given)"; next }
  /^$/         { flush(); next }
  END          { flush() }')"
MAIN_BRANCH="$(printf '%s\n' "$TREES" | head -n 1 | cut -f2)"
[ "$MAIN_BRANCH" = "-" ] && MAIN_BRANCH=""
MAIN_PATH="$(printf '%s\n' "$TREES" | head -n 1 | cut -f3-)"
[ -d "$MAIN_PATH" ] || MAIN_PATH="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# WP1: the generated-file globs, the defaults and the workspace's own list.
GENERATED="$(
  printf '%s\n' 'dist/**' 'output/**' 'test/report.json' '**/*.log' 'TODO.md' 'todo/*.md'
  [ -f "$MAIN_PATH/$IGNORE_FILE" ] \
    && sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' "$MAIN_PATH/$IGNORE_FILE" 2>/dev/null \
    | grep -v '^!'
)"

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

# lock_pid <reason>: the pid a Claude Code lock names ("... (pid 46371 start ...)"), or nothing.
lock_pid() { printf '%s\n' "$1" | sed -n 's/.*(pid \([0-9][0-9]*\).*/\1/p' | head -n 1; }

# alive <pid>: the process exists (kill -0 fails on another user's process, ps does not).
alive() { kill -0 "$1" 2>/dev/null || ps -p "$1" >/dev/null 2>&1; }

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

# scan <path>: sort the worktree's changes (git status, every untracked file one by one). Writes
#   $TMPD/patch.z  the paths a patch must carry (NUL): every tracked change, untracked non-generated
#   $TMPD/move.z   the untracked non-generated files (NUL), the F3675 archive's
#   $TMPD/real     the non-generated, non-deletion changes, "<XY> <path>" per line
# and sets N_ALL, N_GEN, N_REAL, N_REAL_TRACKED, N_PATCH. Fails when git cannot say, or a path holds
# a tab or a newline (then nothing is judged: the worktree stays).
scan() {
  local e xy p o
  : > "$TMPD/rows"; : > "$TMPD/patch.z"; : > "$TMPD/move.z"; : > "$TMPD/real"
  git --no-optional-locks -C "$1" status --porcelain=v1 -z -uall > "$TMPD/status.z" 2>/dev/null || return 1
  while IFS= read -r -d '' e; do
    xy="${e:0:2}"; p="${e:3}"; o=""
    case "$xy" in *R*|*C*) IFS= read -r -d '' o || return 1 ;; esac
    case "$p$o" in *$'\t'*|*$'\n'*) return 1 ;; esac
    printf '%s\t%s\t%s\n' "$xy" "$p" "$o" >> "$TMPD/rows"
  done < "$TMPD/status.z"
  # one awk pass sorts every row: gen (generated), del (a deletion only) or real
  GENERATED="$GENERATED" awk -F '\t' '
    function g2r(p,   r, i, c, n, any) {
      sub(/^\/+/, "", p); if (p ~ /\/$/) p = p "**"
      any = (index(p, "/") == 0); r = ""; n = length(p)
      for (i = 1; i <= n; i++) {
        c = substr(p, i, 1)
        if (c == "*") {
          if (substr(p, i + 1, 1) == "*") {
            if (substr(p, i + 2, 1) == "/") { r = r "(.*/)?"; i += 2 } else { r = r ".*"; i++ }
          } else r = r "[^/]*"
        } else if (c == "?") r = r "[^/]"
        else if (index(".+()|^${}[]\\", c)) r = r "\\" c
        else r = r c
      }
      return "^" (any ? "(.*/)?" : "") r "$"
    }
    function gen(path,   i) { for (i = 1; i <= ng; i++) if (path ~ re[i]) return 1; return 0 }
    BEGIN { n = split(ENVIRON["GENERATED"], g, "\n"); for (i = 1; i <= n; i++) if (g[i] != "") re[++ng] = g2r(g[i]) }
    {
      x = $1; cls = "real"
      if (gen($2) && ($3 == "" || gen($3))) cls = "gen"
      else if (x != "??" && x ~ /D/ && x !~ /[MARCTU]/) cls = "del"
      print cls "\t" $0
    }' "$TMPD/rows" > "$TMPD/sorted"
  N_ALL=0; N_GEN=0; N_REAL=0; N_REAL_TRACKED=0; N_PATCH=0
  local cls
  while IFS=$'\t' read -r cls xy p o; do
    N_ALL=$((N_ALL + 1))
    [ "$cls" = gen ] && N_GEN=$((N_GEN + 1))
    if [ "$xy" != "??" ]; then
      printf '%s\0' "$p" >> "$TMPD/patch.z"; N_PATCH=$((N_PATCH + 1))
      [ -n "$o" ] && printf '%s\0' "$o" >> "$TMPD/patch.z"
    elif [ "$cls" != gen ]; then
      printf '%s\0' "$p" >> "$TMPD/patch.z"; N_PATCH=$((N_PATCH + 1))
      printf '%s\0' "$p" >> "$TMPD/move.z"
    fi
    if [ "$cls" = real ]; then
      N_REAL=$((N_REAL + 1))
      [ "$xy" != "??" ] && N_REAL_TRACKED=$((N_REAL_TRACKED + 1))
      printf '%s %s\n' "$xy" "$p" >> "$TMPD/real"
    fi
  done < "$TMPD/sorted"
  return 0
}

# newest_change <path>: epoch seconds of the newest real change on disk (a deleted file says
# nothing; at most 500 files are read), or 0.
newest_change() {
  local newest=0 rel t n=0
  while IFS= read -r rel; do
    rel="${rel#?? }"
    [ -e "$1/$rel" ] || continue
    t="$(date -r "$1/$rel" +%s 2>/dev/null)" || continue
    [ "$t" -gt "$newest" ] 2>/dev/null && newest="$t"
    n=$((n + 1)); [ "$n" -ge 500 ] && break
  done < "$TMPD/real"
  echo "$newest"
}

# shown: the first changed files, "a, b, c (+N more)".
shown() {
  local list more
  list="$(head -n 3 "$TMPD/real" | sed 's/^.. //' | paste -sd, - | sed 's/,/, /g')"
  more=$((N_REAL - 3))
  [ "$more" -gt 0 ] && list="$list (+$more more)"
  printf '%s' "$list"
}

# ago <seconds>: "N h" under two days, else "N d".
ago() { [ "$1" -lt 172800 ] && echo "$(($1 / 3600)) h" || echo "$(($1 / 86400)) d"; }

# save_patch <path> <name> <branch>: write $TMPD/patch.z's changes, against HEAD, to
# <archive>/<name>.patch (a new name when one is there), and check that it undoes exactly to HEAD
# from what is on disk. Nothing to save is a success; any doubt is a failure, and the worktree stays.
save_patch() {
  [ -s "$TMPD/patch.z" ] || return 0
  local dir="$MAIN_PATH/$ARCHIVE_DIR" file admin head idx="$TMPD/index"
  admin="$(git -C "$1" rev-parse --absolute-git-dir 2>/dev/null)" || return 1
  head="$(git -C "$1" rev-parse --verify HEAD 2>/dev/null)" || return 1
  mkdir -p "$dir" || return 1
  file="$dir/$2.patch"
  [ -e "$file" ] && file="$dir/$2-$(date +%Y%m%d%H%M%S).patch"
  rm -f "$idx"
  if [ -f "$admin/index" ]; then cp "$admin/index" "$idx" || return 1; fi
  # a scratch index: the worktree's own is never touched
  GIT_INDEX_FILE="$idx" GIT_LITERAL_PATHSPECS=1 git -C "$1" add -A \
    --pathspec-from-file="$TMPD/patch.z" --pathspec-file-nul >/dev/null 2>&1 || return 1
  (
    printf '# prune-worktrees.sh saved worktree %s (branch %s) at %s, %s\n' "$2" "$3" "$head" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf '# restore: git worktree add <dir> %s && git -C <dir> apply --binary <this file>\n' "$head"
    GIT_INDEX_FILE="$idx" git -C "$1" diff --cached --binary HEAD
  ) > "$file.tmp" 2>/dev/null || { rm -f "$file.tmp"; return 1; }
  if ! grep -q '^diff --git ' "$file.tmp" \
    || ! git -C "$1" apply --check -R --binary "$file.tmp" >/dev/null 2>&1; then
    rm -f "$file.tmp"
    return 1
  fi
  mv "$file.tmp" "$file" || return 1
  return 0
}

# archive <path> <name>: move $TMPD/move.z's untracked files to the archive, same paths inside.
archive() {
  local dest="$MAIN_PATH/$ARCHIVE_DIR/$2" rel
  [ -e "$dest" ] && dest="$dest-$(date +%Y%m%d%H%M%S)"
  while IFS= read -r -d '' rel; do
    [ -n "$rel" ] && [ -e "$1/$rel" ] || continue
    mkdir -p "$dest/$(dirname "$rel")" && mv "$1/$rel" "$dest/$rel" || return 1
  done < "$TMPD/move.z"
  return 0
}

# drop <path> <lock reason> <stale>: remove the worktree (--force: every change in it was judged
# above). A stale lock is let go first and put back when the removal fails.
drop() {
  local path="$1"
  [ "$3" = 1 ] && { git worktree unlock "$path" >/dev/null 2>&1 || return 1; }
  if ! git worktree remove --force "$path" >/dev/null 2>&1; then
    [ "$3" = 1 ] && git worktree lock --reason "$2" "$path" >/dev/null 2>&1
    return 1
  fi
  return 0
}

removed=0
archived=0
patched=0
idle=0
while IFS=$'\t' read -r -u 3 lock branch path; do
  [ -n "$path" ] || continue
  case "$path" in *"/$WORKTREE_DIR/"*) ;; *) continue ;; esac
  [ -d "$path" ] || continue
  name="$(basename "$path")"
  mb=""
  if [ "$REPORT" = 1 ]; then
    kb="$(du -sk "$path" 2>/dev/null | cut -f1)"
    case "$kb" in ''|*[!0-9]*) mb="?" ;; *) mb=$(((kb + 512) / 1024)) ;; esac
  fi
  say() { [ "$REPORT" = 1 ] && printf '%s\t%s\t%s\t%s\n' "$1" "$name" "$mb" "$2"; return 0; }
  if [ "$branch" = "-" ]; then say unmerged "detached HEAD: no branch to judge or keep"; continue; fi
  is_base "$branch" && continue                                     # a base branch itself

  # what holds it whatever its branch: a live agent, a lock without a pid, a process, a young folder
  why=""; stale=0
  if [ "$lock" != "-" ]; then
    pid="$(lock_pid "$lock")"
    if [ -z "$pid" ]; then why="locked: $lock"
    elif alive "$pid"; then why="live agent: lock pid $pid lives ($lock)"
    else stale=1
    fi
  fi
  [ -z "$why" ] && busy "$path" && why="a process works in it"      # F3638
  [ -z "$why" ] && young "$path" && why="touched in the last $MIN_AGE min"
  stale_note=""
  [ "$stale" = 1 ] && stale_note=" (stale lock: pid $pid is gone)"

  if merged "$branch"; then
    act=""
    if [ -z "$why" ]; then
      if ! scan "$path"; then why="git status cannot list its changes plainly"
      elif [ "$N_REAL_TRACKED" -gt 0 ]; then
        t="$(newest_change "$path")"; age=$((NOW - t))
        if [ "$age" -ge $((DIRTY_H * 3600)) ]; then
          act=patch; note="real changes ($N_REAL), last $(ago "$age") ago: saved as a patch, then removed"
        else
          why="changed: $(shown), last $(ago "$age") ago (saved as a patch and removed $DIRTY_H h after the last change)"
        fi
      elif [ "$N_REAL" -gt 0 ]; then
        act=move; note="$N_REAL untracked file(s) move to $ARCHIVE_DIR/$name/"
      elif [ "$N_GEN" -gt 0 ]; then
        act=remove; note="only generated files changed ($N_GEN)"
      else
        act=remove; note="clean"
      fi
    fi
    if [ -n "$why" ]; then say held "$why"; continue; fi
    if [ "$REPORT" = 1 ]; then say prunable "merged; $note$stale_note"; continue; fi
    [ "$SECONDS" -ge "$BUDGET" ] && break                           # the rest wait for the next run
    case "$act" in
      move) archive "$path" "$name" || continue ;;
      patch) save_patch "$path" "$name" "$branch" || continue ;;
    esac
    drop "$path" "$lock" "$stale" || continue
    git branch -D "$branch" >/dev/null 2>&1                         # merged, so the branch is history
    removed=$((removed + 1))
    [ "$act" = move ] && archived=$((archived + 1))
    [ "$act" = patch ] && patched=$((patched + 1))
    continue
  fi

  # WP3: unmerged. Its folder goes only when no agent lives and nothing moved for days; the branch stays.
  if [ -z "$why" ]; then
    ct="$(git -C "$path" log -1 --format=%ct HEAD 2>/dev/null)"
    case "$ct" in ''|*[!0-9]*) why="no commit date" ;; esac
  fi
  if [ -z "$why" ] && [ $((NOW - ct)) -lt $((IDLE_DAYS * 86400)) ]; then
    why="last commit $(ago $((NOW - ct))) ago (its folder goes after $IDLE_DAYS d idle; the branch stays)"
  fi
  if [ -z "$why" ]; then
    if ! scan "$path"; then why="git status cannot list its changes plainly"
    elif [ "$N_REAL" -gt 0 ]; then
      t="$(newest_change "$path")"; age=$((NOW - t))
      [ "$age" -lt $((DIRTY_H * 3600)) ] && why="changed: $(shown), last $(ago "$age") ago"
    fi
  fi
  if [ -n "$why" ]; then say unmerged "$why"; continue; fi
  if [ "$REPORT" = 1 ]; then
    say unmerged "idle: last commit $(ago $((NOW - ct))) ago, no live agent$stale_note; its folder goes on the next run (changes saved as a patch, branch $branch kept)"
    continue
  fi
  [ "$SECONDS" -ge "$BUDGET" ] && break
  save_patch "$path" "$name" "$branch" || continue
  drop "$path" "$lock" "$stale" || continue
  idle=$((idle + 1))
  [ "$N_PATCH" -gt 0 ] && patched=$((patched + 1))
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
add() { [ -n "$line" ] && line="$line; "; line="$line$1"; }
if [ "$removed" -gt 0 ]; then
  add "pruned $removed merged agent worktree(s)"
  [ "$archived" -gt 0 ] && line="$line; untracked files of $archived kept in $ARCHIVE_DIR/"
fi
[ "$idle" -gt 0 ] && add "removed the folders of $idle idle unmerged worktree(s), branches kept"
[ "$patched" -gt 0 ] && add "changes of $patched saved as patches in $ARCHIVE_DIR/"
[ "$expired" -gt 0 ] && add "deleted $expired archived folder(s) older than $KEEP_DAYS days from $ARCHIVE_DIR/"
[ -n "$line" ] && echo "$line"
exit 0
