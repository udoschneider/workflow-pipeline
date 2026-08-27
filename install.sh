#!/usr/bin/env bash
#
# Install or update the workflow pipeline in a target repository, with no
# package manager and no coding agent involved.
#
#   ./install.sh /path/to/target-repo                  apply
#   ./install.sh --dry-run /path/to/target             show what would change
#   ./install.sh --skills-dir .opencode/skills /path   non-Claude agent
#   ./install.sh --wire-agents /path                   also append the pipeline
#                                                      section to AGENTS.md
#   ./install.sh --agents-file CLAUDE.md /path         wire into CLAUDE.md instead
#
# This is the fallback path. `opkg install` and the Claude Code plugin are
# both nicer; this one exists because the package's whole claim is that it
# needs nothing, and a bash script that copies files is the honest floor.
#
# It also does one thing the others do not: distinguish files you own from
# files you don't, per file, every time -- see below.
#
# Exit codes: 0 installed (wiring may still be pending), 1 error, 2 usage.

set -euo pipefail

PKG="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DRY_RUN=0
TARGET=""
SKILLS_DIR=".claude/skills"
WIRE_AGENTS=0
AGENTS_TARGET="AGENTS.md"

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --skills-dir) shift; SKILLS_DIR="${1:?--skills-dir needs a value}" ;;
    --wire-agents) WIRE_AGENTS=1 ;;
    --agents-file) shift; AGENTS_TARGET="${1:?--agents-file needs a value}" ;;
    -h|--help) sed -n '2,20p' "${BASH_SOURCE[0]}"; exit 0 ;;
    -*) echo "unknown flag: $1" >&2; exit 2 ;;
    *) TARGET="$1" ;;
  esac
  shift
done

if [ -z "$TARGET" ]; then
  echo "usage: install.sh [--dry-run] [--skills-dir DIR] /path/to/target-repo" >&2
  exit 2
fi

if [ ! -d "$TARGET/.git" ]; then
  echo "error: $TARGET is not a git repository." >&2
  echo "  The installer only writes into version-controlled trees, so that an" >&2
  echo "  update is reviewable as a diff before it is kept." >&2
  exit 1
fi

TARGET="$(cd "$TARGET" && pwd)"

echo "workflow-pipeline $(grep '^version:' "$PKG/openpackage.yml" | awk '{print $2}')"
echo "  from: $PKG"
echo "  into: $TARGET"
echo "  skills → $SKILLS_DIR"
[ "$DRY_RUN" -eq 1 ] && echo "  mode: dry run (nothing will be written)"
echo

synced=0; seeded=0; kept=0

# sync: you do not own this file. It is overwritten on every install, so an
# edit here is silently reverted by the next update. This is what makes an
# update a copy rather than a merge.
sync_file() {
  local src="$1" rel="$2" dst="$TARGET/$2"
  if [ -f "$dst" ] && cmp -s "$src" "$dst"; then
    kept=$((kept + 1)); return
  fi
  echo "  sync  $rel"
  if [ "$DRY_RUN" -eq 0 ]; then
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
  fi
  synced=$((synced + 1))
}

# seed: you own this file from the moment it exists. It carries a shape, never
# content. `lessons.md` and `scrap.md` are exactly the files someone has been
# writing into for months -- overwriting one on update would destroy real work,
# so an existing file is never touched.
seed_file() {
  local src="$1" rel="$2" dst="$TARGET/$2"
  if [ -e "$dst" ]; then
    kept=$((kept + 1)); return
  fi
  echo "  seed  $rel"
  if [ "$DRY_RUN" -eq 0 ]; then
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
  fi
  seeded=$((seeded + 1))
}

sync_file "$PKG/root/bin/workflow-index" "bin/workflow-index"
sync_file "$PKG/root/project/workflow/README.md" "project/workflow/README.md"

for skill in "$PKG"/skills/*/; do
  name="$(basename "$skill")"
  sync_file "$skill/SKILL.md" "$SKILLS_DIR/$name/SKILL.md"
done

seed_file "$PKG/root/project/workflow/.gitignore" "project/workflow/.gitignore"
# Seeded, emphatically not synced: this is the one file in the pipeline the
# consumer owns outright, and overwriting it would delete the only record of
# how their project differs.
seed_file "$PKG/root/project/workflow/README.local.md" "project/workflow/README.local.md"
seed_file "$PKG/root/project/workflow/config.json.example" "project/workflow/config.json.example"
seed_file "$PKG/root/project/scrap.md" "project/scrap.md"
seed_file "$PKG/root/project/lessons.md" "project/lessons.md"
# The third memory tier. Seeded, not synced: once it has entries the consumer
# owns it, and re-installing must never blank someone's reference index.
seed_file "$PKG/root/project/reference/_INDEX.md" "project/reference/_INDEX.md"

for stage in thoughts backlog active completed rejected inbox; do
  seed_file "$PKG/root/project/workflow/$stage/.gitkeep" "project/workflow/$stage/.gitkeep"
done

[ "$DRY_RUN" -eq 0 ] && chmod +x "$TARGET/bin/workflow-index"

echo
echo "  $synced synced, $seeded seeded, $kept already current"

# --- wiring ------------------------------------------------------------
#
# These edit files the target owns. Rewriting someone's .gitignore from a
# package is how an installer earns a reputation for eating hand edits, so
# this reports rather than writes.

echo
echo "Wiring (not written by this installer -- apply by hand):"

# Ignore rules ship as project/workflow/.gitignore rather than as edits to the
# repository root .gitignore, so this is a seeded file rather than a wiring
# step. It is verified here because it is a dotfile, and a packager that drops
# dotfiles would leave the local vault path and the generated indexes
# committable while the docs said otherwise.
if [ -f "$TARGET/project/workflow/.gitignore" ]; then
  echo "  ✓ project/workflow/.gitignore ignores the local config and the indexes"
else
  echo "  ✗ project/workflow/.gitignore is missing — the local config and the"
  echo "      generated indexes would be committable. Running bin/workflow-index"
  echo "      writes it."
fi

# This is the one wiring step that decides whether the pipeline exists at all.
# Everything else can be installed perfectly and still do nothing: with no
# pointer, the cue words never fire, the agent never reads the spec, and the
# whole package sits inert while looking correctly installed. So unlike the
# .gitignore lines, this one is offered rather than merely reported.
if grep -rqs "project/workflow/README.md" "$TARGET"/AGENTS.md "$TARGET"/CLAUDE.md 2>/dev/null; then
  echo "  ✓ agent instructions point at the pipeline spec"
elif [ "$WIRE_AGENTS" -eq 1 ]; then
  agents_file="$TARGET/${AGENTS_TARGET}"
  if [ "$DRY_RUN" -eq 0 ]; then
    { [ -s "$agents_file" ] && printf '\n'; cat "$PKG/AGENTS.md"; } >> "$agents_file"
  fi
  echo "  ✓ appended the pipeline section to ${AGENTS_TARGET}"
else
  echo "  ✗ no agent instructions file points at project/workflow/README.md."
  echo "      Without this the cue words never fire and nothing else here runs:"
  echo "      the pipeline is installed but inert. Re-run with --wire-agents to"
  echo "      append the section below, or paste it in yourself."
  echo
  sed 's/^/        /' "$PKG/AGENTS.md"
fi

echo
echo "Verify:"
echo "  cd $TARGET && bin/workflow-index --check && bin/workflow-index"
