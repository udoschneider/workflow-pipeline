# Workflow Pipeline

Full mechanics for the idea lifecycle used in this repo: `thoughts/ → backlog/ → active/ → completed/`, with `rejected/` reachable from any stage.

Your agent instructions file (`AGENTS.md`, `CLAUDE.md`, or your agent's equivalent) points here via cue words (**thought**, **backlog**, **promote**, **reject this**, **active**, **completed**, workflow paths, `_MAP.md`, `_DEPS.md`). When any of those fire, read this file before acting — do not invent procedure from memory.

> **This file is not yours to edit.** It is installed from the `workflow-pipeline` package and replaced wholesale on every update, so a local change here is reverted the next time someone installs — silently, and usually not by the person who made it.
>
> **Project-specific mechanics go in `project/workflow/README.local.md`**, which the package never touches. If that file exists, **read it too, and let it win on any conflict** — it is where a project names the command that regenerates its indexes, the close-out skill that walks acceptance criteria, its instrumentation, and anything else this document deliberately leaves unnamed. This file describes the pipeline; the local one describes how *this* project runs it.
>
> A rule that would be true in any project belongs upstream in the package, not in the local file. When you find yourself writing something general there, send it up instead.

## Where things are remembered

The pipeline moves *ideas*. Alongside it sit three places for things you need to **remember**, distinguished by how long the content stays useful — not by what it is about. Sorting by lifetime is what stops all three collapsing into one growing file nobody reads.

| Place                       | Holds                                                                       | Lifetime                                            | Drained by         |
| --------------------------- | --------------------------------------------------------------------------- | --------------------------------------------------- | ------------------ |
| `project/scrap.md`          | Unfiled notes, caught mid-flow so they don't interrupt                       | Until the next triage — hours or days                | `/process-scrap`   |
| `project/lessons.md`        | Individual lessons: a gotcha, a mistake, a debugging story worth not repeating | Until enough related ones accumulate to synthesize | `/prune-lessons`   |
| `project/reference/`        | Synthesized topical docs, indexed in `_INDEX.md`                              | Indefinite — read during future work                 | Pruned when stale  |

The flow is one-directional and each hop is a **promotion on evidence**: a scrap note earns a place in `lessons.md` by surviving triage; a cluster of lessons earns a reference doc by being several instances of one underlying principle. A reference written before there is anything to synthesize is a lesson with more ceremony, which is why `project/reference/` ships empty and `_INDEX.md` starts with no rows.

**`project/reference/` is a role, not a mandate.** If your project already keeps durable topical knowledge somewhere else — a wiki, an ADR directory, a docs site — point the promotion there instead and leave this directory unused. What matters is that the destination is *indexed*, so the agent can rule a document out without opening it. An unindexed pile is not a reference tier; it is a second scrap file.

Note the asymmetry with the idea pipeline: an idea moves through stages **one file at a time**, keeping its identity. Memory content is **synthesized** on promotion — several lessons become one document that states the principle, with the lessons as supporting detail. Idea files move; memory content merges.

## Configuration

Machine-specific paths that the agent consumes (currently just the maintainer's Obsidian vault) live in `project/workflow/config.json`. This file is **gitignored** — copy the committed `config.json.example` template and set the values for your machine:

```bash
cp project/workflow/config.json.example project/workflow/config.json
# then edit vault_root to point at your local Obsidian vault
bin/workflow-index vault    # verify: prints the root, or the exact fix
```

| Key          | Meaning                                                                        |
| ------------ | ------------------------------------------------------------------------------ |
| `vault_root` | Absolute path to the local Obsidian knowledge vault consulted during sparring. |

**Read it through `bin/workflow-index vault`, never by opening the JSON.** (`bin/workflow-index sweep` resolves it the same way and reports the same three errors.) The command distinguishes the three failure modes — no config file, missing/empty `vault_root`, or a `vault_root` naming a directory that doesn't exist — and each error carries its fix. Reading the file directly can't detect the third case at all, which is the one that turns a moved vault into a permanently silent sparring step.

**If your project uses git worktrees, symlink this file from the primary checkout** rather than copying it per worktree. Because it's a link, editing `vault_root` anywhere updates it everywhere; a copy silently goes stale in whichever tree you edited last.

**The `<vault_root>` token.** Throughout the workflow docs (thoughts, backlog, reference docs), vault file references are written as `<vault_root>/Knowledge/...` rather than a hardcoded absolute path. Resolve `<vault_root>` to the value in `config.json` when following such a reference. This keeps the vault location single-sourced: if the vault moves, only `config.json` changes, not every citation.

## Frontmatter schema — canonical metadata location

**All file-level metadata lives in YAML frontmatter at the top of the file.** Inline-prose forms (`**Type:** code`, `**Priority:** Should Have`, `**Depends on:** …`, and the equivalent unbolded `Type: …` / `Priority: …` variants) are **deprecated** and must not be added to new files. When touching a legacy file that still carries inline-prose metadata, lift it into frontmatter.

The schema:

```yaml
---
type: code | initiative          # required
priority: Must Have | Should Have | Nice to Have   # required from backlog/ onward; optional in thoughts/
band: mvp | v1.0 | later         # optional in thoughts/, recommended from backlog/ onward
gates: [when-enterprise, when-evidence]   # optional, can stack
depends_on: [slug_a, slug_b]     # optional; YAML list of bare slugs (no `.md`, no date prefix)
refinement_state: raw | refined | promotion-ready   # thoughts/ only; optional, set by maintainer
cluster: agents                  # thoughts/ only; optional; bare slug of the cluster coordination doc
summary: |                       # thoughts/ only; required; 2–3 lines; the _MAP.md row text
  One-paragraph navigation summary of this thought.
---
```

Rules:

- **Required fields by stage.** `thoughts/` need `type` and `summary`. `backlog/`, `active/`, `completed/`, and `rejected/` need `type` and `priority` at minimum.
- **`summary` is the source of the `_MAP.md` row** (`thoughts/`-only). It's the one editorial, non-derivable index input — written/updated on the thought itself, never in `_MAP.md` directly. Keep it to 2–3 lines per the [Thought Map](#thought-map-projectworkflowthoughts_mapmd) rules; store it as a YAML block scalar (`summary: |`). `bin/workflow-index --check` fails if a thought lacks it.
- **`depends_on` is a list of bare slugs** — `[ai_wizards, ingest_document_import]`, not full filenames or paths. The slug is the filename minus the date prefix and `.md` extension.
- **Omit empty fields.** Don't write `depends_on: []` or `depends_on: —` to indicate "no dependencies" — leave the key out. Same for `gates`, `cluster`, and `refinement_state`.
- **Single source of truth.** Never duplicate a metadata field in both frontmatter and inline prose. If you find both, frontmatter wins.
- **`refinement_state` and `cluster` are `thoughts/`-only.** They feed the [Thoughts Dependency Index](#thoughts-dependency-index-projectworkflowthoughts_depsmd). Strip both at promotion to `backlog/` — see also the [Cluster coordination docs](#cluster-coordination-docs) section for the cluster lifecycle.

The `band`/`gates` axes are detailed in the [Bands and gates](#bands-and-gates--temporal-and-conditional-triage-signals) section below.

## Design Docs (`project/workflow/active/` and `project/workflow/completed/`)

- Planning/design happens in `project/workflow/backlog/` — items are promoted to `active/` when work starts
- Files use `YYYYMMDD_slug.md` naming (date is the origin date from when the thought was first raised)
- Each file has a `type` in frontmatter: `code` (features, fixes, refactors) or `initiative` (marketing, partnerships, docs)
- A file in `active/` means work is **currently in progress** — `active` is a commitment, not a holding state for "next up"
- **Active typically holds one item.** Occasionally 2-3 thematically similar items. An empty `active/` while backlog has actionable items is normal — backlog stewing is fine, and an item moving from backlog to active is a deliberate commitment event, not an automatic promotion when dependencies clear.
- A file in `completed/` means the item is **done** — the design doc serves as historical reference
- **Pruning policy**: `completed/` is pruned weekly to reduce noise. Use `/prune-completed` to automate this checklist. Before removing a doc:
  1. **Verify tests exist** — confirm the completed item has test coverage for its features, fixes, or behavior changes. If tests are missing, write them before pruning.
  2. **Extract "why" to code** — verify key design rationale is in module/function doc comments or inline comments (see your project's documentation rules)
  3. **Extract lessons and reference** — gotchas, mistakes, and debugging stories go to `project/lessons.md`; domain knowledge too detailed for code comments goes to `project/reference/`
  4. **Promote specific lessons into code** — check `project/lessons.md` for entries specific to the completed item. If a lesson is tightly coupled to a particular module or function, move it into that code as a comment or doc-comment note (keeping `lessons.md` for cross-cutting patterns).
  5. **Then delete** — the full history remains recoverable via `git log -- project/workflow/completed/`

### Close-out preparation: spawn out before moving to `completed/`

**The move itself is unconditional.** When the work ships (committed to main, gates green), move `active/ → completed/` as part of the same close-out that ships it. Don't park shipped work in `active/` waiting on anything — `active/` means *in progress*, and once it isn't, the file belongs in `completed/`.

This section is about what to spawn out *if applicable* before the move — not a precondition that gates it. If there are no spawn-outs to do, the move is cheaper, not deferred.

The pruning policy above runs *later*, sometimes weeks after the move to `completed/`. A completed-doc may be heavily compressed or removed before its load-bearing content is harvested. To avoid information loss, **plan any close-out spawn-outs deliberately** before the `active/ → completed/` move, not as deferred extraction work for the future pruner.

Three categories of content that should leave the active doc when present:

1. **Cross-cutting lessons → `project/lessons.md`** under an appropriate section heading. Distil the *generalizable* patterns (e.g. "split agent judgment from deterministic execution"), not project-specific findings (e.g. "Run 5 produced 32 measures").
2. **Operationally consulted material → `project/reference/<topic>.md`** with an `_INDEX.md` entry. This is for content actively read during future work — prompt directives, runbooks, decision trees — not historical record.
3. **Future-work seeds → `project/workflow/thoughts/YYYYMMDD_slug.md`** with `band` (and `gates` if relevant) per the band/gate system, plus a `summary:` field so the seed surfaces in `_MAP.md` (which regenerates from it). Reference the originating active doc so the trail is recoverable.

When spawn-outs happen, append a dated section to the active doc enumerating each one (where the lesson/reference/thought now lives) before the move. This serves two purposes: it's the user's review surface for catching over-aggressive cleanup, and it leaves a recoverable trail in git history pointing from the eventual pruned doc to the surviving artifacts. When no spawn-outs are needed, this dated section is unnecessary — just move.

The `/prune-completed` checklist above remains the safety net — it explicitly checks for lesson/reference extraction — but the work is cheaper, less error-prone, and higher-fidelity when done at close-out time while the context is fresh, rather than weeks later when the pruner has to reconstruct it from a stale doc.

### Stale active signal

Items in `active/` for more than ~1 month with no recent commit touching them are a code smell. The load-bearing measure is **age × last-touch**, not age alone — an item with weekly commits at 6 weeks is healthy; an item idle for 2 weeks is the actual signal, regardless of start date.

**Cluster coordination docs are exempt by design** — they outlive any single member (see [Cluster coordination docs](#cluster-coordination-docs)). The rule applies only to *non-cluster items in `active/`*.

When a stale-active item surfaces (typically via `/what-next` or a workflow retro), three good triage outcomes — all three beat letting the item rot:

1. **Bump back to `backlog/`** — honest de-prioritization. Use "Moving files between stages" mechanics; add a `## YYYY-MM-DD: Demoted from active` section explaining why.
2. **Reject** — decided not to do (move to `rejected/`).
3. **Annotate with a dated `## YYYY-MM-DD: Why slow` section** — kept moving, with explicit acknowledgment of the friction.

## Thought Refinement (`project/workflow/thoughts/` → `project/workflow/backlog/`)

A Socratic workflow for refining rough ideas into actionable items.

**Rules:**

- Never overwrite history in thought/backlog files — always append new dated sections
- All items (code and non-code) follow the same pipeline — use `type: code` or `type: initiative` in the frontmatter to distinguish
- **One question at a time** — ask a single question per message and wait for the answer before asking the next.

**Lifecycle — all items follow the same pipeline:**

```
project/workflow/thoughts/YYYYMMDD_slug.md
  ↘ rejected/                                    (deliberately declined)
  → project/workflow/backlog/YYYYMMDD_slug.md
    ↘ rejected/                                  (deliberately declined)
    → project/workflow/active/YYYYMMDD_slug.md   (in progress)
      ↘ rejected/                                (deliberately declined)
      → project/workflow/completed/YYYYMMDD_slug.md (done)
```

The date in the filename is the **origin date** (when the thought was first raised) and stays constant across moves — **except** when moving to `completed/`, where the date slug is replaced with the **completion date**. The document content retains the full history with all original dates.

Items can be **rejected** from any stage. See "Rejecting items" below.

**When sparring on a rough idea** (initial thought, escalated scrap item, mid-pipeline reconsideration — wherever non-trivial back-and-forth begins):

1. **Sweep the prior art** — run `bin/workflow-index sweep <token> ...` before the first round. It searches four corpora and reports each one separately, because each answers a different question:

   | Corpus | Answers |
   | --- | --- |
   | `project/workflow/` | has this project already decided this? |
   | `project/reference/` | has it already been written down as settled? |
   | `project/lessons.md` | has this bitten us before? |
   | the vault | has the maintainer already read about this? |

   **One command rather than four greps, because the failure mode is substitution, not omission.** Searching the pipeline *feels* like checking for prior art, and quietly discharges the instinct to check the other three — so the sweep that gets run is a partial one, and nothing about its output says so. The reference tree is the one most often lost that way: the pipeline holds decisions *in flight* while `reference/` holds decisions *already made*, and presenting a settled, documented requirement as a fresh insight costs more credibility than missing a thought costs work.

   **Choosing tokens is the part the command cannot do for you.** Derive them from what the thing *does* and what it would replace — not from the words in the request. A vendor name, a library, a repo link, or a phrase you coined one sentence ago is new to the corpus by construction, so its clean result reads exactly like "no prior art" while carrying no information; the sweep names such tokens in its output, but only you can replace them. Worth a second pass on three axes: the topic's domain nouns, the solution's *mechanism* (gate, oracle, validator, importer, cache), and the bare name of any existing tool the idea extends — the strongest prior art is usually filed under the tool's name, not the enhancement's concept words.

   Treat every hit as *"open and read it,"* never as a pass/fail signal — index summaries are terse enough that relevance often only shows on open. Surface what you find during the dialogue, and capture the useful pointers in the thought file's `## References` section. Skip the whole step only for trivial decisions and mechanical refactors. The trigger is *engagement*, not source directory: a scrap item that escalates from one-line triage into real sparring gets the same treatment as a fresh thought, and a session that *opens* as a read-only question but turns into "how should we change it?" needs the sweep at that turn.

   **If a corpus could not be searched, say so in the dialogue before continuing** — one line naming the error, e.g. *"heads-up: the vault isn't reachable (`vault_root` points at a directory that doesn't exist), so this spar has no prior-notes check."* The sweep exits non-zero and prints `!! NOT SEARCHED` for exactly this reason: an unreachable vault otherwise looks identical to a vault with nothing in it, which is how the step went skipped unnoticed before. The command makes it loud; only repeating it here makes the user able to act on it.
2. **Socratic dialogue** — Ask probing questions one at a time (2–4 rounds). Each message should contain exactly one question. Wait for the user's answer before asking the next. Cover these areas across rounds: clarify intent, surface assumptions, explore implications, identify edge cases, relate to existing architecture.
3. **Adversarial sparring** — Once the idea is understood, actively challenge it. Push back on assumptions, question economics, probe competitive positioning, identify risks, and name specific weaknesses. Be direct and blunt — "this is BS because X" is preferred over diplomatic hedging. Frame challenges as specific, actionable questions. Concede when the user makes a strong counter-argument; don't be contrarian for its own sake. This phase typically runs 2–4 rounds and may overlap with the Socratic dialogue. **Note:** This round runs against the same model that helped formalize the thought — same training data, same priors. For a *genuinely different* perspective, see the [Sparring stances](#sparring-stances--second-pass-review-under-different-perspectives) section; a second-pass round under a different stance is recommended at promotion (step 5 below).
4. **Create thought file** — Write `project/workflow/thoughts/YYYYMMDD_slug.md` with this structure:
   ```markdown
   ---
   type: code
   summary: |
     One-paragraph (2–3 line) navigation summary — becomes this thought's _MAP.md row.
   ---

   # Title

   | Stage   | Date       |
   | ------- | ---------- |
   | Thought | YYYY-MM-DD |

   ## YYYY-MM-DD: Initial thought

   Refined description from the dialogue.
   ```

   Pre-promotion thoughts carry `type:` and `summary:` in frontmatter (the `summary:` feeds the generated `_MAP.md`). `priority:` (and optionally `band:` / `gates:` / `depends_on:`) are added when the thought is promoted to backlog. See the [Frontmatter schema](#frontmatter-schema--canonical-metadata-location) section for the full schema.
5. **Ask about promotion** — At the end of refinement, ask these questions sequentially (one per message, wait for the answer before asking the next):
   1. Is this ready to promote to backlog?
   2. *(If yes)* What type? **code** or **initiative** (non-code: marketing, partnerships, docs)?
   3. What priority tier? **Must Have** / **Should Have** / **Nice to Have**
   4. What are the acceptance criteria? (2–5 binary-checkable behaviors; see [Acceptance criteria](#acceptance-criteria--what-done-means-per-item) section). If the answer is unclear, spar to derive them — priority can't be set honestly without knowing what done means.
   5. *(Recommended)* Should we run a second-pass sparring round under a different stance? See [Sparring stances](#sparring-stances--second-pass-review-under-different-perspectives) for the menu and when to escalate. For `Must Have` items and for `Should Have` / `Nice to Have` items, the recommendation strengthens — see "Stronger nudge at priority extremes." Maintainer's judgment is final; declining is one keystroke.
6. **If promoted** — Re-run the sweep with implementation-shaping tokens in mind (constraints, prior decisions, the mechanism you're about to build) before writing the backlog file. Capture findings inline in the plan or under `## References`. Write the `## Acceptance criteria` section (and `## Out of scope` if relevant) into the backlog file. Then perform the move (see "Moving files between stages" below).

**When updating an existing file:**

- Add a new `## YYYY-MM-DD: <topic>` section (never modify existing sections)
- Update the history table if the stage changes

**When a backlog item is promoted to active:**

- Display the `## Acceptance criteria` (and `## Out of scope` if present) to the maintainer.
- Ask: *"Are these still accurate?"*
  - **Yes** → proceed with the move.
  - **Partially** → prompt for the specific revision; append a `## YYYY-MM-DD: Criteria revision` section to the file with the revised bullets and reason; update the live `## Acceptance criteria` section to match; then proceed with the move.
  - **No** → consider whether the item should be demoted back to backlog for re-sparring rather than activated with broken criteria. See [Acceptance criteria § Demote back to backlog when revisions accumulate](#demote-back-to-backlog-when-revisions-accumulate).
- Perform the move (see "Moving files between stages" below).

**When an active item is completed:**

- Move the file from `active/` to `completed/`, adding a `Completed` row to the history table. Rename the date slug to the completion date.
- **Write tests** — before considering the item fully done, write extensive tests covering the features it added, bugs it fixed, or behavior it changed. Tests should cover happy paths, edge cases, and regression scenarios. This ensures completed work stays working and prevents regressions from future changes.

## Inbox — pre-thoughts integration buffer (`project/workflow/inbox/`)

`project/workflow/inbox/` is a capture buffer **upstream** of `thoughts/`, for multi-paragraph sparring outputs that don't fit cleanly as scrap one-liners but aren't yet thought-shaped enough for the refinement workflow.

**Why it exists.** A capture buffer for multi-paragraph sparring output that's too big for a `scrap.md` one-liner but not yet thought-shaped (no `summary:`, no refinement). `scrap.md` is too small (single file, one-liners only); a real `thoughts/` file expects a `summary:` and a refined disposition. `inbox/` holds the in-between. (Historically this also dodged hand-maintained-index merge collisions across parallel sessions; the indexes are now generated + gitignored — see [Thought Map](#thought-map-projectworkflowthoughts_mapmd) — so that pressure is gone, but the capture-shape gap remains.)

**Mechanics.**

- Files: `YYYYMMDD_slug.md` like the rest of the pipeline. No required frontmatter; raw captures.
- **Not indexed.** No `_MAP.md`, no `_DEPS.md`, no entries elsewhere pointing into `inbox/`. Adding a file doesn't trigger any regeneration.
- **Normally untracked.** Files show in `git status` as `??` — the visibility is the passive triage nudge. Time Machine covers local durability. *Could* be committed (e.g., for cross-machine handoff) but normally isn't, mirroring the `scrap.md` habit.

**Lifecycle: capture → triage → graduate or die.**

1. **Capture.** Any sparring session can drop a file into `inbox/`. No ceremony, no format requirement.
2. **Triage.** Run `/process-inbox`. For each file, the skill proposes one of: `discard`, `shrink-to-scrap`, `existing` (cite the dup), `done` (cite the code), `thought` (with optional re-spar), or `backlog` (rare, with re-spar). Default disposition is `discard` — most captures are session-bound and shouldn't graduate.
3. **Graduate or die.** Files either become committed artifacts (entries in `thoughts/`, `backlog/`, or appended lines in `scrap.md`) or are `rm`'d. Items lingering >2 weeks should surface during the workflow retro.

**Triage discipline.**

- Drain `inbox/` at the end of any session that produced items, or at the start of the next close-out. Don't let `inbox/` items sit for weeks — the visibility-in-`git status` nudge only works if you act on it.
- **Default to discard.** `inbox/` is a capture buffer, not a deferred backlog. If the close-rate to discard isn't meaningful (>30% over time), the buffer isn't earning its keep — revisit.
- **Re-spar before promotion.** Most `inbox/` items as-written aren't promotion-ready; the re-spar round produces a properly-shaped thought or backlog entry. The skill offers re-spar by default at the `thought` and `backlog` dispositions.

**Cross-references.**

- Skill mechanics: the `/process-inbox` skill.
- Adjacent integration buffer for one-liners: `project/scrap.md` + `/process-scrap`.
- Frontmatter and date rules apply to destination files only — `inbox/` itself is unstructured. See § "Frontmatter schema" and § "Moving files between stages."

## Thought Map (`project/workflow/thoughts/_MAP.md`)

An auto-generated summary index of all thought files. Prevents the need to read every thought file — scan the map to identify which thoughts are relevant, then read only those in detail.

**Format:** A flat table with columns: File (full filename including date slug, e.g. `20260321_some_slug.md`), Summary. Sorted alphabetically by filename — date prefixes ensure chronological ordering and stable git diffs.

**Header:** A single line under the title stating purpose, e.g. `> Auto-generated summary index of all thoughts. Rebuild when thoughts are added, modified, or removed/promoted.` **Do not maintain a running `Last updated:` changelog** — git history (`git log -- project/workflow/thoughts/`) and the dated `## YYYY-MM-DD:` sections inside each thought already capture that. The header stays one line.

**Summary cell — hard rules:**

- **2–3 lines, ~250 chars max.** The cell is a navigation aid, not a content store. The full reasoning lives in the thought file.
- **Include:** core thesis (what the thought is about), current disposition (band/gate if set, or stage signal like "promoted to backlog as X / sub-thought of Y"), one cross-cutting tension or composition with other items if non-obvious.
- **Exclude:** sparring-round history, decision trails, vault citations, full lists of open questions, multi-paragraph design sketches, dated update logs. All of that belongs in the thought file's `## YYYY-MM-DD:` sections.
- If a summary needs more than 3 lines to make sense, **the thought is the right place** — link to it via the filename and let the reader open it.

**Generated, not hand-maintained.** `_MAP.md` is gitignored and regenerated from the `summary:` frontmatter field of each thought by `bin/workflow-index`. **Never edit `_MAP.md` directly.** To change a row, edit the thought's `summary:` field; the table regenerates (rows sorted alphabetically by slug). Being gitignored and regenerable is what lets several worktrees touch the pipeline at once without fighting over a committed index file.

**Freshness is the reader's job, not a hook's.** Anything written since the last regeneration is not in the table yet, so **run `bin/workflow-index` before reading any index** — it is cheap and idempotent, and the skills that consume the indexes do it as their first step. Automation on top of that is welcome but is an optimisation, never the guarantee:

| Mechanism                       | Covers                                                    | Available |
| ------------------------------- | --------------------------------------------------------- | ---------- |
| Regenerate-before-read          | Everything. This is the load-bearing one                  | Everywhere |
| Git `post-checkout` / `post-merge` | The tree moving under you — branch switch, pull, rebase | Any git repo |
| Agent file-write hooks          | Refresh the moment an item is edited                       | Agent-dependent |

The middle row is worth having even where agent hooks exist: a checkout swaps the whole corpus at once and no agent hook sees it, which leaves a complete, well-formed index describing a branch you are no longer on.

**Summary discipline:** when a sparring round adds context, rewrite the thought's `summary:` to stay within the 2–3 line cap — don't let it grow. Don't append "**2026-MM-DD (cont.):** ..." segments; update the thought file with a new dated section, and let `summary:` reflect only the *current* disposition.

## Backlog Dependency Index (`project/workflow/backlog/_DEPS.md`)

An auto-generated advisory view of dependencies between backlog/active items. Helps identify which items are actionable vs. blocked.

**Source of truth:** Each backlog/active item declares its dependencies via the `depends_on:` key in YAML frontmatter (see the [Frontmatter schema](#frontmatter-schema--canonical-metadata-location) section):

```yaml
---
type: code
priority: Must Have
depends_on: [mcp_api_authentication, rbac_policy_gate]
---
```

**Header:** A single line under the title stating purpose, e.g. `> Auto-generated advisory view of dependencies between backlog/active items. Rebuild when items are added, modified, or promoted.` **Do not maintain a running `Last updated:` changelog** — git history (`git log -- project/workflow/backlog/`) and the dated `## YYYY-MM-DD:` sections inside each backlog/active file already capture promotion rationale and disposition history. The header stays one line.

**Generated, not hand-maintained.** Like `_MAP.md`, `backlog/_DEPS.md` is gitignored and regenerated by `bin/workflow-index` (same hook + pre-commit triggers). **Never edit it directly** — change the relevant item's `depends_on:` / `priority:` / `band:` / `gates:` frontmatter and the tables regenerate. The generator implements this logic:

1. Parse YAML frontmatter for every file in `backlog/` and `active/`; collect `depends_on:` values
2. Resolve each dep slug against all stages. A dep is **met** when it resolves to an item in `active/` or `completed/`, **or** when it resolves nowhere (a loose/renamed/conceptual slug with no tracked file — the pipeline has nothing concrete to wait on). A dep is **unmet** only when it resolves to a still-pending item in `backlog/` or `thoughts/`.
3. Output two sections: **Actionable** (no unmet deps) and **Blocked** (with a "Waiting on" column annotating each unmet dep's current stage). Full filename is the first column, each section sorted alphabetically — date prefixes ensure stable git diffs.

## Thoughts Dependency Index (`project/workflow/thoughts/_DEPS.md`)

A second auto-generated index over `thoughts/`, paired with `_MAP.md` (summaries). Where `backlog/_DEPS.md` answers *"what can I pick up now?"*, this index answers **"what could I promote now?"**.

**Schema — deliberately different from `backlog/_DEPS.md`:**

- **No `priority` / `band` / `gates` columns.** Those get *decided* at promotion via the Socratic questions in the [Thought Refinement](#thought-refinement-projectworkflowthoughts--projectworkflowbacklog) section. Pre-filling them in `thoughts/` would tempt the maintainer to skip the promotion conversation and treat thoughts as a stealth backlog.
- **Lead with `downstream_pull`** — count of items in `backlog/` and `active/` that name this thought in their `depends_on:`. **Direct mentions only — no transitive walk through other thoughts.** A Must-Have item waiting on thought X makes X implicitly hot even when its own internals look raw, which is the strongest promotion signal.
- **`refinement_state` column** — surfaces the `refinement_state:` frontmatter field (see [Frontmatter schema](#frontmatter-schema--canonical-metadata-location)). Maintainer-set, not inferred from structure (length, presence of acceptance-shaped sections) — inference is brittle, maintainer-set is honest.
- **`cluster` column** — surfaces the `cluster:` frontmatter field so cluster members group naturally rather than scattering across the table. See [Cluster coordination docs](#cluster-coordination-docs) for the cluster lifecycle.

**Header:** A single line stating purpose, e.g. `> Auto-generated advisory view of thoughts ranked by promotion signal. Rebuild when thoughts are added, modified, or promoted/rejected.` Same header discipline as the other indexes — no running changelog.

**Generated, not hand-maintained.** Gitignored and regenerated by `bin/workflow-index` (same hook + pre-commit triggers). **Never edit it directly** — to change a thought's promotion signal, update its `refinement_state:` / `cluster:` frontmatter. The generator implements this logic:

1. Parse YAML frontmatter for every file in `thoughts/`
2. For each thought, count direct `depends_on:` mentions across all files in `backlog/` and `active/` to compute `downstream_pull` (direct mentions only — no transitive walk)
3. Output: File | Refinement | Downstream Pull | Cluster | Type — sorted by `downstream_pull` descending, then alphabetically by filename (stable git diffs for ties)

## Cluster coordination docs

Big topics (agents, observability, a cross-cutting data-mapping family) are correctly split across multiple thoughts due to complexity (see [Splitting bloated thoughts](#splitting-bloated-thoughts) below). The split honors thought-level focus but creates a coordination gap: no single child thought is independently promotable, and the cluster as a whole has no first-class representation. **Cluster coordination docs** formalize the pattern.

### Identifying a cluster

A cluster exists when 3+ thoughts share a common spine (e.g., the `agent_*.md` siblings spun out of `agent_architecture.md`). For 2 closely-related thoughts, `depends_on:` is sufficient ceremony — don't manufacture a cluster doc for two members.

**Backlog-child variant.** A cluster also exists when 3+ *backlog children* are spawned from a single umbrella thought via the audit-first decomposition pattern (e.g., the targets spun out of `extract_code_interfaces_refactor.md` on 2026-06-05). The umbrella functions identically — coordination hub, no implementable surface of its own. Two differences from the thought-sibling variant: (1) members live in `backlog/` (and later `active/` / `completed/`), not `thoughts/`, so they don't carry the `cluster:` frontmatter field (which is `thoughts/`-only per the [Frontmatter schema](#frontmatter-schema--canonical-metadata-location)); (2) membership is tracked in the umbrella's own dated decomposition section instead. The lifecycle (origin → active → closes when all members terminal) and the "multiple items in `active/` is fine for clusters" carve-out apply unchanged.

### Lifecycle

1. **Origin** — starts as a thought (`type: code`). The cluster doc's slug is the canonical cluster name; member thoughts reference it via `cluster: <slug>` in their frontmatter. The cluster doc itself does *not* carry a `cluster:` field — it *is* the cluster.
2. **Promotion path — skip `backlog/`.** A cluster doc has no implementable surface of its own; it's pure coordination. Promotion goes `thoughts/ → active/` directly when the first cluster member is promoted to backlog or active.
3. **Lives in `active/` as a coordination hub.** **Multiple items in `active/` is fine for clusters** — explicit carve-out from the "active typically holds one item" convention. Cluster docs and their member items co-exist in `active/`.
4. **Closes when all members are terminal** — when every member is in `completed/` *or* `rejected/`, the cluster doc moves to `completed/`. Both terminal states count; a cluster with 3 completed + 2 rejected = closed cluster.
5. **Append-only member history.** Scope shifts mid-flight (members added, removed, deferred). The cluster doc carries a member-history table with dated entries:

   ```markdown
   ## Member history

   | Date       | Member              | Change  | Reason                            |
   | ---------- | ------------------- | ------- | --------------------------------- |
   | 2026-05-30 | agent_hitl_approval | added   | spin-out from §5.13               |
   | 2026-06-12 | agent_observability | removed | folded into observability cluster |
   ```

   Without this trail, "why three of six original members never shipped" is lost.

### Pruning

`/prune-completed` skips cluster member files in `completed/` while the cluster doc itself is not yet in `completed/`. Once the cluster closes, its members become eligible for pruning per the standard 5-step checklist.

### Cluster docs vs. spine thoughts

A *spine thought* (per [Splitting bloated thoughts](#splitting-bloated-thoughts)) still carries design content — its stubs point to siblings, but the spine describes the overall design. A *cluster coordination doc* carries *no* design content — only member tracking, coordination notes, and rollup history. Most spine thoughts could evolve into cluster docs if their design content fully harvests into siblings; until then they remain spines.

### Cardinality

A thought belongs to **at most one** cluster (v1 single-home rule). Revisit if real multi-home cases emerge — until then, single-home keeps the "cluster closes when all members terminal" rule tractable.

## Bands and gates — temporal and conditional triage signals

Thoughts and backlog items carry two cross-cutting attributes that capture *when* an item's importance binds, orthogonal to the existing `priority` field (which captures *how* important it is).

Both `band` and `gates` live in the YAML frontmatter alongside `type`/`priority`/`depends_on` — see the [Frontmatter schema](#frontmatter-schema--canonical-metadata-location) section for the full schema.

### Band — temporal axis (exactly one per item)

- **`mvp`** — needed for first ship; scope is roughly known.
- **`v1.0`** — near-term-after-MVP; scope is partially known.
- **`later`** — beyond v1.0; no temporal commitment. Replaces "v2.0" / "Someday" — pretending to split those would be false precision given current visibility.

The bands are *rough horizons*, not pinned milestones. "v1.0" doesn't refer to a defined release-scope bundle; it means "near-term after MVP, in the visible future." When MVP and v1.0 scope eventually get pinned, the bands sharpen automatically without a relabeling pass.

### Gates — conditional axis (optional, can stack)

- **`when-enterprise`** — gated on enterprise positioning materializing (e.g., first qualified Strategic-tier customer in pipeline per `thoughts/20260421_vendor_outbound_positioning_and_pricing.md`).
- **`when-evidence`** — gated on evidence accumulating that the simpler shape has hit a wall the cheap levers can't fix. Particularly applicable to architectural-complexity thoughts where the case rests on prediction rather than observation.

Add new gate kinds only when a new gate-shape genuinely shows up in a real spar — don't speculate gate kinds in advance.

### How band and gate compose

An item can be `band: later, gates: [when-enterprise, when-evidence]` — meaning: no temporal commitment AND won't even be reconsidered until both gates fire. Gate failure is *blocking*, not advisory: a `later` item with unfired gates does not enter promotion consideration regardless of priority.

An item with `band: mvp` and no gates is "needed now, no preconditions." That's the default for routine MVP-scope work.

### Application scope

- **Thoughts** — band/gate signals where an idea sits if/when promoted. A `band: later` thought survives indefinitely without forcing a promotion conversation.
- **Backlog** — band/gate signals when the item enters active consideration. A `band: later` backlog item with `priority: Must Have` is not self-contradictory: it's must-have *eventually*, not must-have *now*.
- **Active** — inherits band/gate from backlog provenance. If band changes mid-implementation (e.g., a deferred item gets pulled into MVP), update via a dated section.
- **Completed** — no band/gate (already shipped).
- **Rejected** — no band/gate (rejection supersedes).

### Indexes summarize band and gate

`_MAP.md` and `_DEPS.md` should surface band and gates so triage is one-glance. Recommended column order in `_DEPS.md` Actionable / Blocked tables: File | Priority | Band | Gates | Type. (Adopt incrementally — backfill is a separate sweep.)

### Rollout — going forward, not retroactive

The system applies to **new** thoughts and backlog items going forward. Backfilling existing items is a separate batch operation (likely a `/triage-bands` skill at some point) — do not retroactively tag during normal work.

When updating an existing thought or backlog item that lacks band/gate, add them only if the update is itself a sparring round that produces band/gate as an outcome. Don't sprinkle bands onto items just because you're touching the file.

### Cross-reference

`thoughts/20260426_scope_discipline.md` — the meta-thought this band/gate system materializes from. Band/gate adoption front-runs that thought's own sparring (which is deferred 4–8 weeks for evidence) — the lever was obvious enough to adopt without waiting. If `scope_discipline` later sparring rejects band/gate, the system gets removed; until then it stands.

## Sparring stances — second-pass review under different perspectives

Solo development means sparring is structurally single-perspective. The Socratic + adversarial round in "Thought Refinement" runs against the same model that helped formalize the thought — same training data, same priors, same blind spots. RFC review in healthy team cultures has 2-3 human reviewers from different parts of the org, which catches what a single perspective can't. This section adds a recoverable approximation of that discipline for solo dev.

### The stance menu

When sparring, run a second-pass round under a deliberately-different perspective. The stances below are a recognized vocabulary, not a required checklist — pick the one (or two) most relevant to what the thought is vulnerable to.

- **Customer adoption** — *"Would a new user understand this? Would an existing user be alarmed by the change? Is the win visible from outside the codebase?"* Catches features that satisfy internal consistency but confuse or alarm actual users.
- **On-call / operations** — *"What does this look like during an incident? How do I observe it? How do I undo it? What runs at 3 a.m. and could break?"* Catches designs elegant on paper but pessimizing for incident response, observability, or migration.
- **Security / compliance auditor** — *"Where does data flow? What's the attribution chain? What trust boundaries does this cross? What's the worst-case if this is misused?"* Catches implicit data-flow issues, attribution gaps, or trust-boundary violations invisible from a feature-quality lens.
- **Cost owner** — *"What does this cost at 10× tenants? At 100× requests? What's the per-tenant marginal cost? Are we trading complexity for negligible value?"* Catches token/storage/compute scaling implications not surfaced by design-quality discussion.
- **Domain canonicality** — *"Does this match how practitioners in this product's domain actually think and work? Are we polishing for our own model rather than the domain's?"* Catches deviations from domain practice that an outsider would notice immediately.
- **Future-self in 6 months** — *"If I hadn't been part of this conversation, would I understand why we chose this? What's the briefest rationale summary I'd need?"* Catches rationale gaps that the conversation-fresh-now setting obscures.

### Menu evolves, don't speculate

This is a *starting menu*, not a closed set. Add a stance only when a real sparring round genuinely needed a perspective the existing list didn't cover. Don't speculate stance kinds in advance. Same discipline as bands/gates' "add new gate kinds only when a new gate-shape genuinely shows up in a real spar."

If a stance never gets used in practice, consider whether it's actually load-bearing or inherited from initial sketch. The menu should be honest about what the maintainer actually reaches for.

### Recommended second-pass at promotion

During thought → backlog promotion (the "Ask about promotion" step), the workflow prompts:

> *"Should we run a second-pass sparring round under a different stance? (yes [pick stance] / no)"*

This is **recommended, not required.** Most small thoughts (rename a field, fix a small bug, polish a component) don't benefit from a second stance — decline cheaply. The act of asking is the value: a regular reminder the option exists. If declining 95% of the time becomes the pattern, the prompt isn't pulling its weight — revisit the recommendation.

#### Stronger nudge at priority extremes

The priority axis matters at *both* ends, for different reasons:

- **`priority: Must Have`** (especially combined with `band: mvp`) — *"**Strongly recommend** a second-pass — which stance?"* Cost of a blind spot is largest on first-ship-critical work. **Recommended stance bundle:** security auditor, on-call, future-self.
- **`priority: Should Have` or `Nice to Have`** — *"**Strongly recommend** a second-pass to check the case for doing this at all."* Different failure mode: solo dev with deep domain expertise is most vulnerable here to engineering-aesthetic-driven scope ("this would be elegant" rather than "users need this"). **Recommended stance bundle:** customer adoption, cost owner, domain canonicality.

Both nudges are still opt-out-able — the workflow surfaces the recommendation; the maintainer's judgment is final.

### When to escalate to parallel subagent review

For high-stakes thoughts where a single-pass stance round may itself be insufficient, escalate to **parallel subagent review**: spawn 2-3 subagents in fresh contexts, each running a different stance, returning short critiques the maintainer integrates.

Subagent review is **meaningfully more expensive** than a stance-prompted second-pass round — fresh-context spin-up, parallel run, integration time. Reach for it when one of the signals below fires AND the cost of a missed perspective is higher than the cost of the review. Most thoughts don't need it; some categorically benefit.

Diagnostic signals (not enforced thresholds):

1. **Thought is >500 lines** — same threshold as the bloated-thought split. If it's big enough to need spin-out, single-perspective review may miss interactions across embedded pillars.
2. **`priority: Must Have`** — under-specification risk on first-ship-critical items. Stance bundle: security auditor + on-call + future-self.
3. **`priority: Should Have` or `Nice to Have`** — scope-justification risk on engineering-aesthetic-driven work. Stance bundle: customer adoption + cost owner + domain canonicality.
4. **`gates: [when-evidence]`** — architectural complexity gated on prediction-rather-than-observation. The case rests on what hasn't happened yet; outsider perspectives catch the most where evidence is thinnest.
5. **`depends_on` ≥ 3 entries** — cross-system implications. Single mind likely to model some interaction wrong.
6. **Maintainer's gut said the regular sparring round didn't fully test it** — the meta-signal. Sometimes you just know. Documenting this as a legitimate trigger gives explicit permission to escalate without specific evidence.

### Subagent escalation mechanism

Manual mechanics (until/unless automated into a skill):

1. Identify the stance bundle (from the signal that fired, or maintainer choice).
2. For each stance in the bundle, spawn a subagent via the Agent tool with:
   - The thought file content as the input.
   - The stance prompt (e.g., *"Review this thought from the perspective of an on-call engineer — what would break during an incident? How would you observe and recover?"*).
   - **No conversation history** — fresh perspective is the point.
   - Constraint: critique in ≤200 words.
3. Spawn the subagents **in parallel** (single message with multiple Agent tool calls).
4. Read all critiques. Integrate findings into the thought file via a dated `## YYYY-MM-DD: Subagent stance review` section listing each stance, the critique, and the maintainer's response (accepted / rejected / partially incorporated).
5. Re-spar if any critique surfaces a load-bearing concern. Proceed if all critiques can be incorporated or dismissed with reason.

The fresh-context constraint is load-bearing. Subagent value comes from *genuinely independent perspectives*, not from the same conversation's perspective wearing a different hat. Don't shortcut the spin-up.

### Cross-references

- A stance-prompted second pass is **part of the sparring discipline, not optional ceremony** — the first pass is where you convince yourself, and it is the pass most likely to be wrong.
- `## Bands and gates` (above) — `band: mvp` and `gates: when-evidence` are signals used by the subagent-escalation triggers.
- `## Acceptance criteria` (below) — stances may also be invoked at backlog → active reaffirmation when criteria need fresh perspective.

## Vault hub page proposals

The maintainer's Obsidian vault is append-only — notes accumulate, but are never edited or reorganized. New synthesis content joins the vault as a new note (a "hub page" combining content from multiple existing notes), authored by the maintainer in a dedicated session outside the workflow.

When sparring research surfaces synthesis-worthy moments, the agent may propose a vault hub page at end-of-round. The synthesis **conclusion** lives in the project (in the thought file's `## References` section, in `project/lessons.md`, or in `project/reference/` per the existing close-out spawn-out triage) — so the agent can retrieve it in future sparring without a vault round-trip. The hub page captures the **depth** for human follow-up. The project artifact contains both: the conclusion plus a pointer to the (eventual) hub page.

### Entry filter

The pattern only enters consideration when the sparring round is:

- A **substantial thought** — substantial enough to warrant the full sparring workflow (not trivial UI tweaks or routine bug fixes), or
- A **new-dependency decision** — which library to adopt, framework selection, evaluation criteria. These naturally synthesize across multiple vault sources (ecosystem norms, past evaluations, performance considerations, domain fit).

If the round doesn't meet the entry filter, the proposal flow is skipped entirely. Most sparring rounds fall outside it.

### Two trigger paths

**Path A — agent-initiated.** During sparring, the agent walks the vault and notices a synthesis emerging across multiple notes. The proposal fires when all four of these signals are present:

1. Synthesis crosses **≥3 vault entries** (two-note connections are routine retrieval, not synthesis).
2. **No existing hub note** in the vault covers the synthesis (the agent had to draw the connections).
3. Resulting insight is **domain-general** — useful beyond this project's immediate need.
4. Both user and agent **remarked on the connection** during sparring (the "interesting, A+B suggests C" moment, not silent retrieval).

The signals are calibrated *slightly loose* — if 3 of 4 fire clearly, propose. False positives cost one word to dismiss; false negatives are silent and compounding.

**Path B — user-initiated.** The maintainer signals at the start of sparring that they've already curated vault content for this thought (*"I have notes on this — start by looking at..."*). The proposal bar then drops: pre-curation is itself a signal of vault-worthiness. The agent's job becomes synthesis, not discovery; surfacing the proposal at end-of-round is the default rather than the exception.

The maintainer may also retroactively prompt the proposal: *"that synthesis we just did seems vault-worthy — draft the proposal."* Counters false negatives that the four-signal filter missed.

### Timing — end of round, never mid-flow

Don't interrupt sparring with hub-page proposals. Note synthesis-worthy moments as they happen, surface them as a batch at the end. If multiple syntheses emerge in one round, list all candidates and let the maintainer triage.

### Proposal format

When the agent surfaces a candidate at end-of-round:

```
End-of-round vault hub page candidate:

  Title: <suggested title>
  Synthesizes: vault://note-a, vault://note-b, vault://note-c
  Why a hub: <one-sentence rationale — why this synthesis warrants a vault note>

Create page (maintainer authors), defer (record placeholder in project), or skip?
```

Three closes:

- **Create** — maintainer authors the vault page (now or soon); agent records the project conclusion plus a placeholder pointer that will be updated once the page exists.
- **Defer** — agent records the project conclusion plus a placeholder noting "vault hub page proposed YYYY-MM-DD, pending creation."
- **Skip** — no vault page; project records the synthesis conclusion plus multi-source citations only.

### Three-state recording in the project

The thought file's `## References` section (or wherever the conclusion lands per close-out spawn-out triage) carries one of three states:

**State 1 — no hub page proposed:**

```markdown
- Sources consulted: vault://A, vault://B
```

**State 2 — hub page proposed, pending creation:**

```markdown
- Synthesis: <1-2 sentence conclusion>
  - Sources: vault://A, vault://B, vault://C
  - Depth: vault hub page proposed 2026-MM-DD — *pending creation*; update once authored
```

**State 3 — hub page exists:**

```markdown
- Synthesis: <1-2 sentence conclusion>
  - Sources: vault://A, vault://B, vault://C
  - Depth: vault://hub-page-X (authored YYYY-MM-DD) — for full reasoning
```

State 2 is self-healing: it either advances to state 3 when the page is authored, or sits indefinitely (which is fine — the project artifact is complete on its own; the placeholder is an honest TODO).

### Frequency expectations

Expected firing: roughly **once every 4-8 weeks** at typical pace. Bursty rather than uniform — clusters during domain-heavy phases (positioning, vendor analysis, dep decisions), quiet during execution-heavy phases. Asymmetric error tolerance: better to slightly over-propose (cheap dismissal) than under-propose (silent compounding loss).

Drift detection: the workflow retro (§ "Workflow retro thoughts") catches the pathological extremes — *"have any proposals fired this quarter? if none, is the agent missing synthesis moments, or is the vault mature enough that most syntheses are already captured?"*

### Cross-references

- The vault being **append-only** is what makes this work: notes are added, never edited or reorganized, so a citation into it stays valid indefinitely and needs no maintenance.
- `## Sparring stances` (above) — both fire at end-of-sparring-round; compose naturally with each other.
- Close-out spawn-out triage in "Design Docs" section — same shape of "where does this content live" decision (lessons / reference / thought file).

## Acceptance criteria — what "done" means per item

Every backlog and active item carries an `## Acceptance criteria` section defining what must be true for the item to be considered done. Optionally, items with scope-misreading risk also carry an `## Out of scope` section naming explicit exclusions. Together they form the *delivery contract* — distinct from `priority` (how important), `band`/`gates` (when), and `depends_on` (what blocks).

### Why this exists

Your project's quality gate and test suite verify *code* correctness. Acceptance criteria verify *feature* correctness — the gap where AI-generated code historically falls down because implicit expectations in the maintainer's head never made it into the spec. Without acceptance criteria, the agent's stop signal is "compiles and green," which is much weaker than "actually does what was intended."

### Required by stage

- **Thoughts**: not required. Thoughts are problem-exploration; pinning criteria prematurely anchors the design on the wrong shape.
- **Backlog**: **required** at promotion. Criteria are derived during the sparring round when a thought is promoted (see "Ask about promotion" step 5.4). The `## Acceptance criteria` section is the *commitment artifact* — `priority` can't be set honestly without knowing what done means.
- **Active**: required at activation. Criteria are reaffirmed when promoting backlog → active (see "When a backlog item is promoted to active"). Stale criteria are revised via a dated section.
- **Completed / Rejected**: criteria carry forward as historical record.

### Section format

Top-level bullets with optional sub-bullets:

```markdown
## Acceptance criteria

- One binary-checkable behavior per top-level bullet
  - Optional sub-bullets clarify specifics or edge cases
  - Use sub-bullets only when the top-level alone is ambiguous
- Functional, non-functional, and security criteria all count — if binary-checkable
- The test: "can I answer yes/no in 60 seconds?"
```

Optional companion section:

```markdown
## Out of scope

- Explicit exclusions that scope misreading might assume are in scope
- Tracked separately in [thought slug] or [reasoning]
```

The `## Out of scope` section is **optional** — only add it when scope misreading is plausible. For most items (rename a field, fix a bug, small UI change) it's unnecessary noise. For larger items where neighboring features could be assumed in scope, it earns its keep. Place it immediately after `## Acceptance criteria` — together they form the contract.

### What counts as binary-checkable

A criterion passes the binary-checkability test if a verification step can be expressed in one sentence. Examples:

- **Pass:** "Upload rejects malformed bundles with a flash error" — verifiable by submitting malformed input and checking for the flash.
- **Pass:** "P95 latency on the detail route < 500ms (verified by timing 20 requests locally)" — verification method named, result numeric.
- **Pass:** "Audit log entry written with `channel: :web` and `user_id` on every upload attempt (including failures)" — specific fields named, specific cases covered.
- **Fail:** "Feels snappy" — subjective, no verification step.
- **Fail:** "Resistant to injection attacks" — too vague; "rejects SQL fragments in `name` input with `error.invalid_characters`" would pass.
- **Fail:** "Uses `Task.async_stream`" — implementation detail, not behavior. The criterion belongs in the design discussion above, not in the contract.

### Mid-active revision

When implementation reveals criteria are wrong, revise via a dated section:

```markdown
## YYYY-MM-DD: Criteria revision

[Reason for the revision. Often: an assumption broke, a constraint surfaced, scope shifted, an edge case emerged that the original criteria didn't cover.]

**Criterion N updated to:** "[new wording]"
```

Then update the live `## Acceptance criteria` section to reflect the new contract. The dated section preserves the reasoning; the live section preserves the contract. Revisions can shrink scope too (a criterion was over-specified) — same protocol, same dated section.

### Demote back to backlog when revisions accumulate

Two signals suggest the item should demote back to `backlog/` for re-sparring rather than be patched in flight:

- **Two or more revisions stack within one active session** — suggests the original spec was missing a load-bearing concept; re-sparring will produce a cleaner contract than incremental patches.
- **A single revision invalidates most of the original criteria** — suggests the design has shifted enough that the active doc is no longer describing the same item.

Both are *diagnostic signals*, not enforced thresholds. The maintainer's judgment is final. Because `active/` typically holds only one item, demoting back is **cheap** — there's no half-started workstream to abandon, just a deferred decision returned to the backlog. When demoting:

1. Move the active file to `backlog/` per "Moving files between stages"
2. Add a `## YYYY-MM-DD: Demoted from active` section explaining what broke and why a re-spar is cleaner than patching
3. Update the history table with a `Demoted` row
4. Re-spar before re-promoting

### Verification at close-out

At close-out — the moment an active item is about to move to `completed/` — walk each `## Acceptance criteria` bullet and establish whether it is verified. Three states per bullet:

- **verified** — the criterion holds; proceed.
- **obsolete with reason** — the criterion changed during implementation. Append a `## YYYY-MM-DD: Criteria revision` section to the active doc with the reason, then proceed.
- **block** — the criterion is not yet met. The close-out aborts and the item stays in `active/`.

For `## Out of scope` (if present), walk each item binary: `confirmed not drifted into?` y / block. No "obsolete" path — if an exclusion turned into in-scope, that's a scope expansion warranting a new thought or backlog item, not an obsolete marking on the current one.

The walk runs only when an item is actually closing — not on every commit. Sessions that triage scrap, bump deps, or make partial progress on an active item skip the walk because no item is closing.

### Intervention recording at close-out

After the criteria/exclusions walk completes successfully, record the **intervention level** for the closure — the harness-health metric that tracks whether the agent ran end-to-end without maintainer intervention. Four levels: `none` / `minor` / `major` / `abort`. Recorded **per closure** — one row per item moving to `completed/`, not one per close-out session, which may close none or several.

Persisted in two places:

1. **Active doc** under a `## YYYY-MM-DD: Implementation notes` section — narrative context for future-self.
2. **A durable record outside the doc** — the active doc is eventually pruned, so an intervention noted only there disappears with it. A single append-only CSV under `project/instrumentation/` (one row per completed item) is enough; whatever aggregation your project layers on top reads from there.

If you keep such a record, have `/prune-completed` verify the row exists for the slug before deleting the doc, backfilling from the doc when it's missing. This is optional — the pipeline works without it, and it is the one part of close-out that needs a project-specific instrument.

### Rollout — going forward, not retroactive

The system applies to **new** items promoted to backlog or activated from the day you adopt it. Items already in `backlog/` and `active/` retain their current shape; criteria are added only when an item is touched by a sparring round (promotion, revision, or re-spar). Same pattern as the bands/gates rollout.

## Workflow retro thoughts — periodic reflection on the workflow itself

Every quarter (or when a major workflow change has bedded in for several months), write a workflow retro thought reflecting on how the workflow itself is performing. Catches qualitative drift that no instrument surfaces — "are we using bands/gates the way we expected?" isn't a metric question.

### When to write one

Recommended cadence: **quarterly**. Earlier if a major workflow change (e.g., adoption of bands/gates, acceptance criteria, sparring stances) has been in use for 2-3 months and you want to evaluate whether it's pulling its weight.

If your project has a periodic health report, have it show the age of the last retro and nudge when overdue. Keep the nudge *informational only* — it should never trigger writing automatically.

### Trigger the retro in a dedicated session

**Open a fresh conversation explicitly for writing the retro thought.** Do not bundle it into a session focused on other work — the retro deserves a clean commit and a context not contaminated by feature work, dep bumps, or scrap triage.

The session produces one focused commit (`docs(workflow): YYYY-Qn retro` or similar). Mixed commits are an anti-pattern here: the retro's value comes from cross-cutting reflection, which is hard to read when interleaved with feature-change diffs. Auto-scheduling the retro via `/loop` or `/schedule` would defeat this discipline by firing whenever the schedule says, regardless of what session is open — manual trigger is load-bearing.

### Filename and frontmatter

```yaml
---
type: code
band: later
---
```

File: `project/workflow/thoughts/YYYYMMDD_workflow_retro.md` (or `..._workflow_retro_q1.md` if you want quarter labels). Lives in `thoughts/` permanently — no promotion. The retro is historical observation, not a candidate for execution. The filename date is the origin date (when the retro was written).

### Question categories to consider

Not a checklist; not all questions apply to every retro. Pick what's lived since the last one.

- **Bands/gates usage drift.** Are bands being applied? Has `later` become a black hole? Have any gates fired since last retro? Any `gates:` items showing accumulating evidence the binary mechanism doesn't capture (see `thoughts/20260511_graduated_gate_status.md`)?
- **Acceptance criteria honesty.** Are `## Acceptance criteria` sections binary-checkable, or has anything drifted to "feels right"? Have any criteria been marked `obsolete` repeatedly across closures (pattern of under-specification)?
- **Sparring stance uptake.** Is the second-pass stance prompt being accepted at promotion, or declined 95%+ of the time? If high decline rate, is the prompt pulling its weight or should it be revisited?
- **Intervention trend.** From the intervention record, if you keep one: is the intervention-free rate stable, trending up, or trending down? Any clustering of `major` events on a particular kind of work?
- **Stale-thought catch rate.** Run `/audit-thoughts`; are items being correctly flagged as stale, or are obvious-stale items slipping through? Any items in `thoughts/` you've been ignoring that should be rejected?
- **Reference-doc freshness.** Any ref docs that haven't been touched since shipped systems they describe have evolved? `git log -- project/reference/` against `git log -- lib/` for the same topic catches drift.
- **Skill suite scope.** Is the skill suite growing faster than the codebase? Have any skills not been invoked in 60+ days? Worth pruning or consolidating?
- **Meta-workflow.** Has any workflow rule been quietly ignored? Has any been quietly added without going through a thought first?

### Format

Free-form reflection, not a structured report. The retro is qualitative. Capture observations and open questions, list any workflow changes the retro proposes (which become their own thoughts or backlog items). Past retros serve as baselines — "compared to last quarter, intervention-free rate held steady" reads useful only if last quarter's number is recorded.

Don't over-template. The questions above are a starting menu; they evolve as the workflow does.

## Skill change rationale via commit messages

Skills are agent-facing instructions. Inline change-history would pollute the agent's context window with information it doesn't need — the agent operates on the *current* rules, not the skill's evolution. So skill rationale is not captured inside SKILL.md.

The git log is the durable record instead. When a skill changes meaningfully (steps added/removed, gating changed, output format changed, flags added), write structured trailers in the commit body capturing the change, rationale, and a durable source pointer. `git log <path-to-skill>` then gives the full evolution, with `--grep="^Skill: <name>"` filtering to rationale-bearing commits.

Define the trailer format once in your commit tooling, and keep "meaningful" narrow — a typo fix does not need a rationale trailer.

The convention is going-forward only — skill changes made before you adopt it don't get backfilled.

## Splitting bloated thoughts

When a thought grows past ~500 lines and several sub-sections develop into fully-specified design pillars, split it rather than letting it sprawl. The `agent_architecture.md` cluster is the worked example: §5.10 was originally a 20-line stub pointing to `agent_security_posture.md`; later §5.11–5.16 each became their own sibling thought using the same template.

Pattern:

1. **Identify the pillars** — sub-sections that have grown to 50+ lines with their own governing principles, deliberately-NOT-in-the-model lists, MVP-vs-v1.0 splits, etc. These are independent design surfaces hiding inside the spine.
2. **For each pillar**, write a sibling thought (same date prefix as the spine) named `<spine>_<pillar>.md` (e.g. `agent_architecture` + `hitl_approval` → `agent_hitl_approval.md`). Lift the full content. Add a *Spun out of …* opening paragraph and a *Cross-references* section.
3. **Replace the original sub-section** in the spine with a stub — short framing paragraph + binding-commitments list (5–6 bullets) + pointer to the sibling. Keep stubs uniform (~15–25 lines) so the spine reads as a contract layer, not a design document.
4. **Update the references section** of the spine — group the new siblings under "§X.x binding-contract spin-outs" so readers see the relationship structurally.
5. **Repoint cross-references** in any other thought that pointed at the now-stubbed sub-section (grep for the old §-number references and the old filename).
6. **Update `_MAP.md`** — shorten the spine's entry, add one-paragraph entries for each new sibling.

Treat siblings as "binding-contract spin-outs" rather than "rejected" — the work wasn't rejected, it was extended. When existing thoughts get fully harvested into the new structure (e.g. an earlier UX thought folded into a new sibling), delete the originals; don't move to `rejected/`. Preserve provenance with a one-line "subsumes the earlier thought from <date>" note in the new file.

## Rejecting items

Items can be rejected from any stage (`thoughts/`, `backlog/`, or `active/`) when we deliberately decide not to implement them. This preserves the reasoning so the idea doesn't resurface without context.

1. Move the file to `project/workflow/rejected/` using the standard move mechanics below
2. Add a `Rejected` row to the history table with the date
3. Add a `## YYYY-MM-DD: Rejected` section explaining **why** — the reasoning is the whole point of keeping the file
4. Filename keeps the **origin date** (same as non-completed moves)
5. Rejected items are **not** tracked in `_DEPS.md`, but other docs may reference rejected slugs for context (e.g., "see `rejected/20260301_foo.md` for why we decided against this approach")
6. **No pruning** — rejected files are kept indefinitely since their value is the historical reasoning

## Moving files between stages

(thought → backlog, backlog → active, active → completed, any → rejected)

1. Write the file to the **target directory** with updated content:
   - Add a new row to the history table with the new stage and date
   - Add a new `## YYYY-MM-DD: <topic>` section noting the promotion/rejection and rationale
2. **Delete the file from the source directory** — the file must only exist in one location
3. **Filename date rules:**
   - For all moves **except** to `completed/`: the filename (`YYYYMMDD_slug.md`) keeps the **origin date**
   - When moving to `completed/`: rename the date slug to the **completion date** (e.g., `20260320_feature.md` → `20260322_feature.md` if completed on 2026-03-22). The document content retains all original dates in the history table.
