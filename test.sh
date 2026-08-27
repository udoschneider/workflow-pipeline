#!/usr/bin/env bash
#
# Self-test for the package. No framework, no install: bash and python3, the
# same floor the package itself claims.
#
#   ./test.sh
#
# Three properties, each of which failed silently in an earlier attempt at
# this extraction:
#
#   identity    Nothing shipped names the codebase this was extracted from.
#               A leaked term tells a reader the document was written about a
#               codebase they do not have, and they stop trusting it. The terms
#               live in `.identity-denylist`, which is local and uncommitted --
#               see `.identity-denylist.example` for why.
#
#   portability Nothing shipped assumes a specific coding agent or language
#               toolchain, and nothing names a tool this package does not ship.
#               The package's claim is that it runs anywhere; a reference to a
#               `mix` task or a Claude-only tool name quietly makes that false.
#
#   behaviour   The generator produces the indexes it promises, computes
#               dependency pull and blocked-state correctly, and rejects a
#               thought missing the one field it cannot derive.
#
# A check with no way to run reports as SKIPPED and is counted separately. It
# is never folded into the pass count -- a vacuous run that reads as a clean
# one is the failure mode this whole package exists because of.

set -uo pipefail

PKG="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DENYLIST="$PKG/.identity-denylist"

failures=0
skipped=0

fail() { printf '  ✗ %s\n' "$1"; failures=$((failures + 1)); }
pass() { printf '  ✓ %s\n' "$1"; }
skip() { printf '  ⊘ SKIPPED — %s\n' "$1"; skipped=$((skipped + 1)); }

shipped_files() {
  # `find` sees dotfiles; `git ls-files` would too, but this must work in a
  # tarball. `skills/`, `root/`, `commands/`, `hooks/` all reach a consumer, and
  # so does the root AGENTS.md -- OpenPackage composites it into the consumer's
  # own agent instructions file. This repo's README/LICENSE/test.sh do not.
  find "$PKG/skills" "$PKG/root" "$PKG/commands" "$PKG/hooks" -type f 2>/dev/null
  [ -f "$PKG/AGENTS.md" ] && echo "$PKG/AGENTS.md"
}

echo "identity"
if [ ! -f "$DENYLIST" ]; then
  skip "no .identity-denylist. Nothing checked that shipped files avoid the
              names of the codebase this was extracted from. If you maintain
              this package, run: cp .identity-denylist.example .identity-denylist
              and fill it in. If you only consume it, this check is not yours
              to run — you have nothing to leak."
else
  before=$failures
  terms=0
  while IFS= read -r term; do
    case "$term" in ""|\#*) continue ;; esac
    terms=$((terms + 1))
    hits="$(grep -rl -- "$term" $(shipped_files) 2>/dev/null || true)"
    [ -z "$hits" ] || fail "'$term' appears in: $(echo "$hits" | tr '\n' ' ')"
  done < "$DENYLIST"

  if [ "$terms" -eq 0 ]; then
    # An empty list passes trivially. Say so rather than printing a tick.
    skip ".identity-denylist exists but lists no terms."
  elif [ "$failures" -eq "$before" ]; then
    pass "no shipped file names the source codebase ($terms terms checked)"
  fi
fi

echo "portability"
before=$failures
# A `mix` invocation means the generator got re-coupled to an Elixir project.
hits="$(grep -rn 'mix ' $(shipped_files) 2>/dev/null || true)"
[ -z "$hits" ] || fail "shipped file references a mix task: $hits"
# `AskUserQuestion` is fine as a named parenthetical, not as an instruction.
hits="$(grep -rln 'Use `AskUserQuestion`' $(shipped_files) 2>/dev/null || true)"
[ -z "$hits" ] || fail "skill instructs a Claude-only tool: $hits"
# Cross-references must use invocation names, which are stable across agents.
hits="$(grep -rln '\.claude/skills/' $(shipped_files) 2>/dev/null || true)"
[ -z "$hits" ] || fail "shipped file hardcodes a Claude skills path: $hits"

# The dependency runs one way: a close-out or commit skill reads the spec to
# learn what it must do. The spec naming those skills back inverts it, and
# turns a rule that belongs to the pipeline into something that looks like one
# project's tooling -- so a reader without that tooling concludes the rule is
# not theirs. Only skills shipped in this package may be named.
hits="$(grep -rln '/finalize\|/commit\|/handoff' $(shipped_files) 2>/dev/null || true)"
[ -z "$hits" ] || fail "spec names a tool this package does not ship: $hits"
[ "$failures" -eq "$before" ] && pass "no shipped file assumes an agent or toolchain"

echo "scaffold"
before=$failures
# Every concrete `project/...` path a shipped file names must be something the
# scaffold actually creates. Three skills once routed lessons into
# `project/reference/`, a directory the scaffold did not ship -- so the skills
# described a destination that did not exist, and the spec cited a document
# nobody outside the source codebase had. Both read as instructions right up
# until someone follows them.
#
# Skipped, because they are not claims about a file: globs and angle-bracket
# metavariables (`*.md`, `<topic>.md`), the caps-style placeholders this doc set
# uses (`YYYYMMDD_slug.md`, `TOPIC.md`), and the two indexes generated on first
# run rather than shipped.
#
# The skip list is enumerated rather than inferred by pattern. A regex clever
# enough to recognise "looks like a placeholder" would also swallow `_INDEX.md`,
# which is a real shipped file and worth checking. Enumerating means a new
# placeholder style trips the gate until someone adds it — noisy, which is the
# right failure direction for a check whose job is catching dangling paths.
for path in $(grep -rhoE 'project/[A-Za-z0-9_./-]+\.md' $(shipped_files) 2>/dev/null | sort -u); do
  case "$path" in
    *'<'*|*'*'*) continue ;;
    *YYYYMMDD*|*TOPIC*) continue ;;
    *_MAP.md|*_DEPS.md) continue ;;
  esac
  [ -e "$PKG/root/$path" ] || fail "shipped file names $path, which the scaffold does not create"
done
[ "$failures" -eq "$before" ] && pass "every path the docs name is one the scaffold creates"

before=$failures
# The installer enumerates what it copies, so a file added to root/ does not
# reach a consumer until install.sh is told about it. OpenPackage and the
# plugin's init command both take root/ wholesale and would not notice the
# difference -- meaning the same package installs differently depending on the
# path taken, which is the worst kind of inconsistency to debug.
for file in $(cd "$PKG/root" && find . -type f | sed 's|^\./||'); do
  case "$file" in
    project/workflow/*/.gitkeep) continue ;;  # covered by the stage loop
    .claude/skills/*) continue ;;             # covered by the skills loop
  esac
  grep -q -- "$file" "$PKG/install.sh" || fail "install.sh does not copy root/$file"
done
[ "$failures" -eq "$before" ] && pass "install.sh copies every file in the scaffold"

before=$failures
# Claude Code exposes a skill as /name by itself; OpenCode reads
# .opencode/commands/ and does not. A skill without a command file installs
# correctly there and is simply unreachable -- and every skill's own
# description says "Invoke with /name", so the gap turns the package's own
# text into a false promise.
for skill_dir in "$PKG"/skills/*/; do
  name="$(basename "$skill_dir")"
  cmd="$PKG/commands/$name.md"
  if [ ! -f "$cmd" ]; then
    fail "skill '$name' has no commands/$name.md, so it is unreachable on agents that only expose commands"
    continue
  fi
  # Both are listed side by side on some agents; a drifted description means
  # the same thing described two ways.
  skill_desc="$(grep -m1 '^description:' "$skill_dir/SKILL.md")"
  cmd_desc="$(grep -m1 '^description:' "$cmd")"
  [ "$skill_desc" = "$cmd_desc" ] \
    || fail "commands/$name.md description has drifted from the skill's"
  # The command must point at the skill, never restate it -- two copies of a
  # procedure one edit apart is worse than one copy in an awkward place.
  grep -q "skills/$name/SKILL.md" "$cmd" \
    || fail "commands/$name.md does not point at the skill"
done
[ "$failures" -eq "$before" ] && pass "every skill is reachable as a slash command"

echo "behaviour"
before=$failures
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/project/workflow/thoughts" "$T/project/workflow/backlog"

cat > "$T/project/workflow/thoughts/20260101_upstream.md" <<'MD'
---
type: code
refinement_state: raw
summary: |
  An upstream thought that something else depends on.
---
MD
cat > "$T/project/workflow/backlog/20260101_downstream.md" <<'MD'
---
type: code
priority: Should Have
band: mvp
gates: [when-evidence]
depends_on: [upstream]
---
MD

out="$(cd "$T" && python3 "$PKG/root/bin/workflow-index" --check 2>&1)"
[ $? -eq 0 ] || fail "--check rejected valid sources: $out"

(cd "$T" && python3 "$PKG/root/bin/workflow-index" >/dev/null 2>&1) || fail "generator failed"

for f in thoughts/_MAP.md thoughts/_DEPS.md backlog/_DEPS.md; do
  [ -f "$T/project/workflow/$f" ] || fail "did not write $f"
done

grep -q '| 20260101_upstream.md | raw | 1 |' "$T/project/workflow/thoughts/_DEPS.md" \
  || fail "downstream pull not counted (expected 1 for upstream)"

grep -q '`upstream` (thoughts)' "$T/project/workflow/backlog/_DEPS.md" \
  || fail "blocked item does not name what it waits on"

grep -q 'when-evidence' "$T/project/workflow/backlog/_DEPS.md" \
  || fail "gates not rendered"

# The one editorial input the indexes cannot derive. Inventing an empty summary
# would mask an author forgetting it.
printf -- '---\ntype: code\n---\n' > "$T/project/workflow/thoughts/20260102_nosummary.md"
out="$(cd "$T" && python3 "$PKG/root/bin/workflow-index" --check 2>&1)"
status=$?
[ "$status" -eq 1 ] || fail "--check accepted a thought with no summary (exit $status)"
echo "$out" | grep -q missing_summary || fail "--check did not name the problem"

[ "$failures" -eq "$before" ] && pass "generator computes pull, blocking, gates, and validation"

before=$failures
# Simulate an install that dropped the .gitkeep dotfiles -- which is what a
# packager using a `**/*` glob actually does, observed in the wild. The
# generator must rebuild the scaffold rather than quietly operating on a tree
# with no stage directories in it.
S="$(mktemp -d)"
mkdir -p "$S/project/workflow"
cp "$PKG/root/project/workflow/README.md" "$S/project/workflow/"
(cd "$S" && python3 "$PKG/root/bin/workflow-index" >/dev/null 2>&1) || fail "generator failed on a scaffold-less tree"
for stage in thoughts backlog active completed rejected inbox; do
  [ -d "$S/project/workflow/$stage" ] || fail "generator did not create project/workflow/$stage"
done
# --check must stay read-only: it runs in CI, where creating directories is a
# side effect nobody asked for.
C="$(mktemp -d)"
mkdir -p "$C/project/workflow"
(cd "$C" && python3 "$PKG/root/bin/workflow-index" --check >/dev/null 2>&1)
[ -d "$C/project/workflow/thoughts" ] && fail "--check created directories; it must be read-only"
rm -rf "$S" "$C"
[ "$failures" -eq "$before" ] && pass "generator rebuilds a scaffold a packager dropped"

before=$failures
# The README states the indexes and the local config are gitignored. Assert it
# by asking git, in a real repository, rather than by checking a file exists --
# a .gitignore with the wrong relative paths exists and ignores nothing, and
# the first symptom is a committed vault path.
G="$(mktemp -d)"
git -C "$G" init -q
mkdir -p "$G/project/workflow"
cp "$PKG/root/project/workflow/README.md" "$G/project/workflow/"
(cd "$G" && python3 "$PKG/root/bin/workflow-index" >/dev/null 2>&1)
printf '{}' > "$G/project/workflow/config.json"
for f in project/workflow/config.json \
         project/workflow/thoughts/_MAP.md \
         project/workflow/thoughts/_DEPS.md \
         project/workflow/backlog/_DEPS.md; do
  git -C "$G" check-ignore -q "$f" || fail "git does not ignore $f"
done
# The rules file itself must be committed, or nobody who clones inherits them.
git -C "$G" check-ignore -q project/workflow/.gitignore \
  && fail "project/workflow/.gitignore ignores itself; a clone would not get the rules"
rm -rf "$G"
[ "$failures" -eq "$before" ] && pass "git actually ignores the config and the generated indexes"

echo
if [ "$failures" -gt 0 ]; then
  echo "$failures check(s) failed"
  exit 1
fi
if [ "$skipped" -gt 0 ]; then
  # Deliberately not "all checks passed": something went unverified, and the
  # summary line is the only place a reader is guaranteed to look.
  echo "checks passed, $skipped skipped — see above for what went unverified"
  exit 0
fi
echo "all checks passed"
exit 0
