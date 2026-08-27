# Workflow Pipeline — local overlay

Project-specific mechanics for this repository. Read alongside `README.md`; **this file wins on conflict.**

`README.md` is installed from the `workflow-pipeline` package and replaced wholesale on every update. This file is never touched by it, so anything true only of *this* project belongs here — and nothing else does.

**The test for whether something belongs here:** would it be true in a different project using the same pipeline? If yes, it belongs upstream in the package, not in this file. An overlay that accumulates general rules is just a slower fork.

Delete any heading below that doesn't apply. An empty overlay is a perfectly good overlay.

## Commands

The spec refers to regenerating the indexes and resolving the sparring vault without naming how, because that differs per project. Name it here if yours differs from the default:

- **Regenerate indexes:** `bin/workflow-index`
- **Resolve the vault root:** `bin/workflow-index vault`

## Close-out

The spec states the obligations at close-out — walk each `## Acceptance criteria` bullet before an item may move to `completed/`, and record an intervention level per closure — but names nothing that performs them. Name yours here: the skill or command, what it walks, and where the intervention record is written.

## Instrumentation

If you keep a durable record of closures, cadences, or intervention levels, say where it lives and what reads it. The pipeline works without any of this.

## Domain vocabulary

The spec's examples are deliberately generic. If your domain has canonical terms that a sparring stance should reason in — the "domain canonicality" stance in particular — name them here so a spar can be held to them.

## Anything else this project does differently

Worktree conventions, symlinked machine-local config, extra stages, house rules on filenames. Keep each entry short and say *why*, not just *what* — the why is what survives contact with a change.
