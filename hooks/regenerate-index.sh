#!/usr/bin/env bash
#
# Regenerate the three workflow indexes for the current project.
#
#   regenerate-index.sh                  quiet; used by edit/read hooks
#   regenerate-index.sh --announce       report failures; used at session start
#
# Resolution order for the generator is deliberate: the project's own copy wins
# over the one inside the plugin. A repository that has run the init command
# owns `bin/workflow-index`, and that copy is what its CI, its pre-commit hook,
# and a human at a shell will run. If the hook silently used a different build,
# the indexes an agent sees could disagree with the ones everyone else sees --
# and a wrong index is worse than a missing one, because it reads as current.

set -uo pipefail

cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0

# Not every project using this plugin has the pipeline installed. Say nothing
# and exit clean rather than nagging in an unrelated repository.
[ -d "project/workflow" ] || exit 0

if [ -x "bin/workflow-index" ]; then
  generator=(./bin/workflow-index)
elif [ -f "bin/workflow-index" ]; then
  generator=(python3 bin/workflow-index)
elif [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -f "$CLAUDE_PLUGIN_ROOT/root/bin/workflow-index" ]; then
  generator=(python3 "$CLAUDE_PLUGIN_ROOT/root/bin/workflow-index")
else
  exit 0
fi

if out=$("${generator[@]}" 2>&1); then
  exit 0
fi

if [ "${1:-}" = "--announce" ]; then
  printf '⚠️  Workflow index regeneration FAILED — _MAP.md / _DEPS.md may be missing or stale.\n'
  printf 'Run the generator directly to see the error before relying on them.\n\n%s\n' "$out"
fi

# Never fail the hook itself: a broken index must not block the tool call that
# triggered it. The announce path is how the failure becomes visible.
exit 0
