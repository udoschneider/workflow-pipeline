## Workflow Pipeline

Cue words: **thought**, **backlog**, **promote**, **spar**, **reject this**, **active**, **completed**, **scrap**, `project/workflow/...`, `_MAP.md`, `_DEPS.md`.

When any of those fire, **read `project/workflow/README.md` before acting** — it holds the full pipeline mechanics: stage semantics, the frontmatter schema, the Socratic + adversarial sparring rounds, promotion questions, sparring stances, acceptance criteria, and file-move rules. Do not invent procedure from memory.

The lifecycle is `thoughts/ → backlog/ → active/ → completed/`, with `rejected/` reachable from any stage.

Two things that are easy to get wrong and expensive to undo:

- **Sparring is not optional at promotion.** A rough idea gets a Socratic round *and* an adversarial round before it becomes a backlog item — be blunt, name specific weaknesses, and concede to a strong counter-argument rather than being contrarian. A second pass under a different stance is recommended at promotion, and strongly recommended at both priority extremes. The spec's "Sparring stances" section has the menu.
- **Never overwrite history in a pipeline file.** Append a new dated `## YYYY-MM-DD: <topic>` section instead. A stage move rewrites the filename's date prefix only on the way into `completed/`.

`_MAP.md` and `_DEPS.md` are generated and gitignored — never hand-edit them. Run `bin/workflow-index` before reading any index, and change a row by editing the item's frontmatter.
