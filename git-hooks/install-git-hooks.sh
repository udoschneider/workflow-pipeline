#!/usr/bin/env bash
#
# Install the optional git hooks into a repository that has the pipeline.
#
#   ./install-git-hooks.sh /path/to/target-repo
#
# What these buy you, and what they don't:
#
# Git hooks fire on git operations. That covers exactly one staleness case,
# and it is a case no coding agent covers: `git checkout`, `git pull`, and
# `git rebase` replace the corpus wholesale, leaving a complete, well-formed
# index describing a branch you are no longer on.
#
# They do NOT cover the common case. When an agent writes a thought and then
# reads `_MAP.md` in the same session, no git operation happens in between, so
# no git hook fires. That gap is closed in the skills themselves -- each one
# that reads an index regenerates first -- which works on every agent and
# needs no hooks at all.
#
# So the layering is: skills handle correctness, git hooks handle the tree
# moving under you, and agent hooks (Claude Code only) are a latency
# optimisation on top of both. Only the first is load-bearing.
#
# These are installed by copy, not by `core.hooksPath`, because setting
# hooksPath is global to the repository and would silently disable any hook
# manager the project already uses.

set -euo pipefail

HOOKS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${1:-}"

if [ -z "$TARGET" ]; then
  echo "usage: install-git-hooks.sh /path/to/target-repo" >&2
  exit 2
fi

GIT_DIR="$(git -C "$TARGET" rev-parse --git-dir 2>/dev/null)" || {
  echo "error: $TARGET is not a git repository." >&2
  exit 1
}
# rev-parse may return a relative path; resolve it against the target.
case "$GIT_DIR" in
  /*) ;;
  *) GIT_DIR="$TARGET/$GIT_DIR" ;;
esac

configured="$(git -C "$TARGET" config --get core.hooksPath || true)"
if [ -n "$configured" ]; then
  echo "note: this repo sets core.hooksPath=$configured, so hooks in"
  echo "      $GIT_DIR/hooks are ignored. Install into $configured instead," >&2
  echo "      or fold the body of post-checkout into your existing hook." >&2
  exit 1
fi

for hook in post-checkout post-merge; do
  dest="$GIT_DIR/hooks/$hook"
  if [ -e "$dest" ] && ! grep -q "workflow-index" "$dest" 2>/dev/null; then
    echo "  ✗ $hook already exists and is not ours — left alone."
    echo "      Add this line to it by hand:"
    echo "        bin/workflow-index >/dev/null 2>&1 || true"
    continue
  fi
  cp "$HOOKS_DIR/post-checkout" "$dest"
  chmod +x "$dest"
  echo "  ✓ installed $hook"
done

echo
echo "Git hooks are local to this clone and are not version-controlled."
echo "Anyone else cloning this repository has to run this script too."
