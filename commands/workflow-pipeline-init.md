---
description: Scaffold the workflow pipeline into this repository — directories, the spec, the index generator, and the agent-instructions pointer.
---

# Initialize the workflow pipeline in this repository

A plugin lives in `~/.claude/plugins/` and cannot write into the user's project. This command is the bridge: it copies the repository-resident half of the pipeline from `${CLAUDE_PLUGIN_ROOT}/root/` into the working tree.

Everything you copy already exists at `${CLAUDE_PLUGIN_ROOT}/root/`, laid out exactly as it should land. Do not author these files from memory — copy them.

## Two classes of file, and the distinction is load-bearing

**Overwrite every time** — the user does not own these, and an edit here is reverted by the next update:

- `bin/workflow-index`
- `project/workflow/README.md`

**Create only if absent** — the user owns these the moment they exist, and they accumulate real content:

- `project/scrap.md`
- `project/lessons.md`
- `project/reference/_INDEX.md`
- `project/workflow/config.json.example`
- `project/workflow/.gitignore`
- `project/workflow/{thoughts,backlog,active,completed,rejected,inbox}/.gitkeep`

**Never silently overwrite a file in the second group.** `lessons.md` and `scrap.md` are exactly the files a user has been writing into for months. If one exists, leave it and say so.

## Steps

### 1. Check what's already there

Look for `project/workflow/` first. If it exists, this is a re-run or an upgrade — report what you find before changing anything, and only refresh the overwrite-group files.

### 2. Copy

Copy from `${CLAUDE_PLUGIN_ROOT}/root/` into the repository root, preserving the tree. Set the executable bit on `bin/workflow-index`.

### 3. Confirm the ignore rules landed

The ignore rules are a **file the pipeline owns**, `project/workflow/.gitignore`, copied along with everything else in step 2 — not an edit to the user's root `.gitignore`. Nothing to ask permission for.

It is a dotfile, though, and dotfiles get dropped by tools that copy with a `**/*` glob. So verify rather than assume:

```sh
git check-ignore -q project/workflow/config.json && echo ok
```

If that fails, run `bin/workflow-index` — it writes the file when absent. Do **not** hand-author the rules into the root `.gitignore` instead; the whole point of the nested file is that it is committed once and inherited by everyone who clones, rather than wired per-person at install time.

What it covers, and why each matters: `config.json` holds an absolute path to the user's knowledge vault, meaningless on any other machine; the three index files are regenerated whole on every run, so two branches touching any item conflict across the entire file.

### 4. Verify

```sh
bin/workflow-index --check   # validates the sources
bin/workflow-index           # writes the three indexes
```

On a fresh install the indexes are empty tables. That is correct, not a failure.

If `--check` reports `missing_summary`, a thought lacks the `summary:` frontmatter field that sources its `_MAP.md` row. That is the one editorial input the generator cannot derive.

### 5. Point the agent instructions at the spec — the step that makes the rest work

**This is the one step that decides whether anything else here does anything.** Without a pointer, the cue words never fire, the agent never reads the spec, and the pipeline sits inert while looking correctly installed. A first user hit exactly this: they typed "thought" and "spar", nothing happened, and reasonably concluded the sparring workflow had not been extracted at all. It had — it was just unreachable.

So do not treat this as optional cleanup. If the user declines, say plainly that the pipeline will not activate on cue words until it is done.

Append the contents of `${CLAUDE_PLUGIN_ROOT}/AGENTS.md` to the project's agent instructions file — `CLAUDE.md` for Claude Code, `AGENTS.md` for most others; use whichever already exists. **Ask before writing**: that file is the user's, and it is the file they are most protective of.

Append, never rewrite, and skip entirely if a pointer to `project/workflow/README.md` is already present — re-running this command must not produce a second copy of the section.

### 6. Report

State plainly: what was copied, what was left alone because it already existed, whether the ignore rules are in force, and whether the indexes generated. If the user declined a step, say which one — a half-installed pipeline that looks complete is worse than one that reports its gaps.

## Prerequisites

`python3` (3.2 or newer — the generator is stdlib-only) and `git`. Nothing else. If `python3` is missing, stop and say so rather than installing anything.
