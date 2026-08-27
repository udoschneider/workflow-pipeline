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
npx opkg install gh@udoschneider/workflow-pipeline
```

Installs the skills into whichever agent platforms are detected, and copies `root/` into the workspace root. OpenPackage does not map agent hooks, so nothing auto-refreshes on this path — which costs less than it sounds like, because the skills regenerate the indexes themselves before reading. See [Keeping the indexes fresh](#keeping-the-indexes-fresh).

### By hand

```sh
git clone https://github.com/udoschneider/workflow-pipeline /tmp/wfp
/tmp/wfp/install.sh /path/to/your/repo                                 # Claude Code
/tmp/wfp/install.sh --skills-dir .opencode/skills /path/to/your/repo   # OpenCode
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

## What it expects you to supply

The spec describes obligations at **close-out** — walking each acceptance criterion before an item may move to `completed/`, and recording an intervention level per closure. It does not say what performs them, because that is a tool that wraps your quality gate and your instrumentation, and shipping ours would be shipping an opinion about your gate.

So: no close-out skill and no commit skill ship here. Every stage move in the spec can be performed by hand, and the close-out obligations are stated as rules you can satisfy however you like. If you want them enforced rather than remembered, that is the one piece you write yourself.

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
  project/scrap.md       Shape only
  project/lessons.md     Shape only
```

`root/` serves both delivery paths: OpenPackage copies it to the workspace root, and the plugin's init command copies the same tree. One source, two channels.

## Status

**0.1.0 — unproven.** Extracted from a working private codebase where it has run for months, then genericized. The generator is pinned byte-for-byte against the original implementation over a 300+ item corpus, so the port is faithful; what is *not* yet proven is the install experience in a repository that didn't grow up with it. Expect rough edges and please report them.
