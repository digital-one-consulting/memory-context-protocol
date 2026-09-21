#!/usr/bin/env bash
# init/sync-hooks.sh — rewrite the init prompt's inline hook blocks from hooks/.
#
# The prompt carries the four hooks verbatim so it can be pasted standalone. A copy drifts, so
# the copy is generated: after any change under hooks/, run this, then test/run.sh (which diffs
# the blocks against the files and fails if they differ).
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INIT="$ROOT/init/claude-context-init.md"
TMP="$(mktemp "${TMPDIR:-/tmp}/sync-hooks.XXXXXX")"
trap 'rm -f "$TMP"' EXIT
cp "$INIT" "$TMP"
for h in context-budget.sh prune-worktrees.sh session-start.sh stop-handoff.sh; do
  awk -v name="$h" -v src="$ROOT/hooks/$h" '
    $0 == "Create `.claude/hooks/" name "` (chmod +x):" { print; want = 1; next }
    want && /^```bash$/ { print; while ((getline line < src) > 0) print line; close(src); skip = 1; want = 0; next }
    skip && /^```$/ { skip = 0 }
    skip { next }
    { print }
  ' "$TMP" > "$TMP.next" && mv "$TMP.next" "$TMP"
done
if cmp -s "$TMP" "$INIT"; then echo "init prompt already in sync"; else cp "$TMP" "$INIT"; echo "init prompt updated from hooks/"; fi
