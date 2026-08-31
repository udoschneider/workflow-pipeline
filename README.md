# workflow-pipeline

An idea-lifecycle pipeline for coding agents: `thoughts/ → backlog/ → active/ → completed/`, with `rejected/` reachable from any stage.

Ideas arrive faster than they can be worked. Left in a flat TODO list they rot invisibly — nothing records how refined an idea is, what is waiting on it, or whether it already shipped. This pipeline gives each idea a stage, gives the metadata a schema, and derives the navigation indexes from that schema so they cannot drift from the truth.

**Language-agnostic.** The runtime is `python3` and `git`. Nothing here assumes a language, framework, or build tool.

## What you get

| Piece               | What it is                                                                                             |
| ------------------- | ------------------------------------------------------------------------------------------------------ |
| `project/workflow/README.md` | The spec — stage semantics, the frontmatter schema, promotion rules, sparring stances, acceptance criteria |
| `bin/workflow-index`| Generates `_MAP.md` and the two `_DEPS.md` indexes from frontmatter. Stdlib-only Python, no install     |
| Six skills          | `/process-scrap`, `/process-inbox`, `/what-next`, `/audit-thoughts`, `/prune-completed`, `/prune-lessons` — each shipped twice, as a skill *and* as a slash command, because agents disagree about which one a `/name` invocation reads |
| Hooks               | Keep the generated indexes fresh after every workflow edit                                              |
| Scaffold            | The six stage directories, plus `scrap.md` and `lessons.md` shapes                                       |

The indexes are **generated and gitignored** — never hand-edited. To change a row you change the item's frontmatter and the table regenerates. That is what lets several worktrees touch the pipeline without fighting over a committed index file.

The ignore rules ship as `project/workflow/.gitignore`, written on first run if absent and never overwritten. They live there rather than in your root `.gitignore` so that nothing has to merge into a file you own, and so that the rules are committed once and inherited by everyone who clones — rather than each person wiring them at install time and one person forgetting.

## What isn't included

Everything listed above works as installed. There is nothing you have to supply to start using the pipeline.

One piece is deliberately left to you. The spec says that when an item is finished, someone should confirm its `## Acceptance criteria` are genuinely met before filing it under `completed/`. Nothing here enforces that, because enforcing it means running your tests and reading your build — and a package that guessed at those would be wrong for most projects. If you want that confirmation enforced rather than remembered, write it as a skill or a script of your own, and note what it is in `project/workflow/README.local.md`.

The same applies to anything that wraps your commit or quality gate. Moving an item between stages is a plain file move; you can do every one of them by hand.

## Install

Three paths, all public and anonymous — no account, no key.

### As a Claude Code plugin

```
/plugin marketplace add https://github.com/udoschneider/workflow-pipeline
/plugin install workflow-pipeline@workflow-pipeline
/workflow-pipeline-init
```

The plugin gives you the skills and the index-refresh hooks. `/workflow-pipeline-init` then scaffolds the repository-resident half — a plugin lives outside your project and cannot write into it, so that step is a command rather than magic.

### With OpenPackage

```sh
npx opkg install gh@udoschneider/workflow-pipeline --conflicts overwrite
```

**`--conflicts overwrite` is not optional here.** OpenPackage defaults to `namespace`, which on a collision installs `project/workflow/workflow-pipeline-README.md` beside your existing `project/workflow/README.md` rather than replacing it — and renames every skill and the generator to match. Every reference inside this package is by path, so all of them break at once.

The failure is silent and worse than a no-op. Observed on a real consumer: the install reported success, appended a section to `CLAUDE.md` saying *"read `project/workflow/README.md`"*, and left that file as the reader's own outdated copy — with the current spec sitting unread next to it under a different name. A greenfield install has no collisions and never shows this; the consumer it hurts is the one migrating from an older copy, which is the common case for adopting this at all.

Your own files are not at risk from `overwrite`: everything you write into lives in `seeds/`, which OpenPackage does not copy, and which `bin/workflow-index` creates only when absent.

Installs the skills into whichever agent platforms are detected, and copies `root/` into the workspace root. OpenPackage does not map agent hooks, so nothing auto-refreshes on this path — which costs less than it sounds like, because the skills regenerate the indexes themselves before reading. See [Keeping the indexes fresh](#keeping-the-indexes-fresh).

### By hand

```sh
git clone https://github.com/udoschneider/workflow-pipeline /tmp/wfp
/tmp/wfp/install.sh /path/to/your/repo   # Claude Code

# OpenCode, or any agent that resolves /name from a commands directory:
/tmp/wfp/install.sh --skills-dir .opencode/skills \
                    --commands-dir .opencode/commands /path/to/your/repo
```

Needs neither a package manager nor a coding agent. It is also the only path that enforces, per file and on every run, which files you own — re-running never overwrites your `lessons.md` or `scrap.md`. Add `--dry-run` to see what it would change first.

## Wiring — the step that decides whether any of this runs

The pipeline activates on **cue words**: *thought*, *backlog*, *promote*, *spar*, *reject this*, *active*, *completed*, *scrap*. Those only fire if your agent instructions file tells the agent to read the spec when it sees them. Without that pointer everything installs correctly and then does nothing — and the failure is silent, because a pipeline that never activates looks exactly like one that isn't there.

The section to add is this repo's [`AGENTS.md`](AGENTS.md). How it gets there depends on the path:

| Path | Wiring |
| --- | --- |
| **OpenPackage** | Automatic — `AGENTS.md` is composited into your `AGENTS.md`, or into `CLAUDE.md` for Claude Code |
| **Plugin** | `/workflow-pipeline-init` offers it as its final step |
| **install.sh** | Pass `--wire-agents` (add `--agents-file CLAUDE.md` to target that instead); without the flag it prints the block for you to paste |

All three are append-only and skip when a pointer is already present, so re-running never duplicates the section.

## After installing

1. `cp project/workflow/config.json.example project/workflow/config.json` and set `vault_root` if you spar against a local knowledge vault. Verify with `bin/workflow-index vault`. Skip if you don't.
2. Write your first thought. Give it `type:` and a `summary:` block scalar — `bin/workflow-index --check` fails without the summary, deliberately.
3. Say "let's spar on X" and check the agent runs a Socratic round *and* an adversarial one. If it just agrees with you, the wiring above didn't take.

## Keeping the indexes fresh

The three index files are derived projections. Anything written since the last regeneration is not in them, and a stale index is worse than a missing one — it is a complete, well-formed table that reads as current.

Three mechanisms, and only the first is load-bearing:

| Mechanism | Covers | Available |
| --- | --- | --- |
| **Skills regenerate before reading** | Everything an agent does | Everywhere — it is an instruction, not a hook |
| **Git `post-checkout` / `post-merge`** | The tree moving under you: branch switch, pull, rebase | Any git repo |
| **Agent file-write hooks** | Refresh the instant an item is edited | Claude Code here; not installed by OpenPackage |

Correctness comes from the first row, which is why the absence of agent hooks on the OpenPackage path is a latency difference rather than a correctness one.

The second row is worth installing **even where agent hooks work**, because it covers a case none of them can: a checkout replaces the whole corpus at once, and no agent is watching.

```sh
git-hooks/install-git-hooks.sh /path/to/your/repo
```

Copies rather than setting `core.hooksPath` — that setting is repo-global and would silently disable any hook manager you already use. An existing foreign hook is reported and left alone, never overwritten. Git hooks are per-clone and not version-controlled, so everyone cloning runs this themselves.

## Repository layout

```
openpackage.yml          OpenPackage manifest
.claude-plugin/          Claude Code plugin + marketplace manifests
skills/                  The six triage skills (universal layout)
commands/                Slash-command entry points — one per skill, plus init
hooks/                   Claude Code agent hooks (not git hooks)
git-hooks/               Optional git post-checkout / post-merge, + installer
root/                    Copied 1:1 into the consuming repository root
  bin/workflow-index
  project/workflow/…     The spec, config example, and stage scaffold
seeds/                   Files YOU own — created if absent, never overwritten
  project/scrap.md, lessons.md, reference/_INDEX.md, workflow/README.local.md
```

`root/` serves both delivery paths: OpenPackage copies it to the workspace root, and the plugin's init command copies the same tree. One source, two channels.

**`seeds/` is deliberately not inside `root/`.** Everything in `root/` gets copied *over* whatever is already there, on every update — so a file you write into cannot live there. A consumer lost three notes from `scrap.md` that way. The four files you own sit outside the copied payload, and `bin/workflow-index` writes each one **only when it is absent**, so they still arrive on install paths that never see `install.sh` and are never replaced once they hold your content.

## Developing this package

Fixes go **here**, never into a consumer — an installed copy is replaced by the next update, so a local edit vanishes silently. See [CONTRIBUTING.md](CONTRIBUTING.md) for the loop, which repository to open a session in, and the traps that keep recurring.

## License

MIT — see [LICENSE](LICENSE). Use it, fork it, ship it in commercial work; keep the copyright notice.

## Status

**0.1.0 — unproven.** Extracted from a working private codebase where it has run for months, then genericized. The generator is pinned byte-for-byte against the original implementation over a 300+ item corpus, so the port is faithful; what is *not* yet proven is the install experience in a repository that didn't grow up with it. Expect rough edges and please report them.
