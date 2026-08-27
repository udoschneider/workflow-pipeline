---
name: audit-thoughts
description: "Sweep thoughts/ and backlog/ for already-shipped ideas — surface stale items so the workflow indexes stay trustworthy. Invoke with /audit-thoughts."
---

# Audit Thoughts Skill

Sweep `project/workflow/thoughts/` and `project/workflow/backlog/` for items whose deliverable has already shipped (directly, indirectly, or via architectural drift). Complements close-out reconciliation, which sees only the session in front of it, and `/prune-completed`, which works the downstream end — this skill handles the *upstream* end on a recurring cadence.

## Invocation

```
/audit-thoughts              # Full sweep of thoughts/ + backlog/
/audit-thoughts <slug>       # Audit a single file (partial slug match OK)
/audit-thoughts --include-meta   # Don't skip design-discussion thoughts
```

## Why this skill exists

Close-out reconciliation checks the current session's diff against the pipeline. It does *not* sweep the existing corpus for ideas that shipped under a different slug, in an opportunistic refactor, or because the architecture moved underneath the thought. `_MAP.md` listing 140+ thoughts means triage cost compounds — every promotion review and cluster reconsideration pays attention proportional to corpus size, including stale items. This skill is the upstream-end maintenance pass.

## Scope

- **In scope:** `thoughts/` and `backlog/` — both are upstream of `active/` and can drift.
- **Out of scope:** `active/` (in progress — close-out reconciliation catches drift there) and `completed/` (`/prune-completed` handles that end).

## Per-match action

The per-match discipline:

| Situation                                                                       | Action                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| ------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Fully implemented (value harvested into shipped code / docs / a completed twin) | **Delete** the thought (`git rm`). **Not** `completed/` — `/prune-completed` would mine its stale *pre-build* design rationale and risk contradicting as-built reality; **not** `rejected/` — that means "decided against", a category error for shipped work. Record the disposition + where the value shipped in the sweep's manifest (this audit's outcome doc); content stays recoverable via `git log --diff-filter=D`. This applies the README "Splitting bloated thoughts" delete-on-harvest precedent (generalized from "harvested into a split" to "harvested into shipped code/docs"). Reserve `completed/` for items that actually ran through `active/`. |
| Partially implemented                                                           | Append `## YYYY-MM-DD: Partially shipped` section listing done sub-items + remaining scope. **No move** — file stays where it is. (If a discrete unbuilt residual remains, spin it to its own `backlog/` item and then delete the harvested parent.)                                                                                                                                                                                                                                                                                                                                                                                                                 |
| Superseded by a later thought / completed item                                  | **Delete** the thought (`git rm`); add a one-line "subsumes `<slug>`" provenance note to the **living** successor (per the README split precedent). If the successor is pruned/completed (no living file), the manifest is the pointer.                                                                                                                                                                                                                                                                                                                                                                                                                              |
| Genuinely declined (decided *not* to do — neither implemented nor superseded)   | Append `## YYYY-MM-DD: Rejected` section, move to `rejected/` per `project/workflow/README.md`. This is the **only** path to `rejected/` — reserve it for real declined decisions, not shipped/harvested work.                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| Surfaced as possible match, evidence too thin to act on                         | Append `## YYYY-MM-DD: Considered for drop during /audit-thoughts sweep — kept` section explaining what surfaced the file (e.g. "wrapper component is installed", "model exists in production") and why that evidence wasn't enough to close it (e.g. "investigation never explicitly closed", "consumer-side wiring isn't shipping just because the primitive is installed"). Same trail-leaving rationale as the partial-shipped annotation: prevents the next monthly sweep from re-triaging the same item from scratch.                                                                                                                                          |
| No clear match                                                                  | No action. Item stays where it is.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |

Decisions are user-confirmed **one at a time**, never batch-applied.

## Workflow

### 1. Build the candidate pool

**Regenerate the indexes first.** They are derived projections of per-item frontmatter, and anything written since the last regeneration is not in them yet:

```sh
bin/workflow-index
```

If `project/workflow/README.local.md` names a different command for this, use that one — it is the one the project's own gates run.

Cheap and idempotent. Do not skip it on the assumption that a hook already ran — hooks are an optimisation here, not the guarantee, and they are absent entirely on some install paths.

- Read `project/workflow/thoughts/_MAP.md` (and the backlog files when sweeping `backlog/`).
- For `thoughts/`: items whose summary describes a concrete deliverable go into the search pool. Pure design discussions (e.g. `scope_discipline.md`, `meta_quality_audit.md`) are **skipped by default** — heuristic: skip when the `_MAP.md` summary contains "design discussion", "sparring", "meta", or when the file's frontmatter has `band: later, gates: [when-evidence]` (deliberately not yet actionable).
- The skip list is conservative — anything ambiguous goes through the matcher. Pass `--include-meta` to run the matcher on every thought regardless.
- For `backlog/`: every file is a candidate (it's already passed promotion review, so it has a concrete shape).

### 2. Match each candidate

For every candidate file:

1. Read the **full file** — `_MAP.md` summaries are too thin to act on alone.
2. Identify load-bearing claims: concrete symbols, file paths, behaviors, features the thought says should exist.
3. Verify via `Grep` / `Glob` / `Read` against `lib/`, `priv/`, `assets/`, `test/`.
4. Tier the result:
   - **Strong match** — clear evidence the thought's deliverable exists.
   - **Possible match** — some evidence, ambiguous.
   - **No match** — drop silently.
5. As a hint, run `git log --grep=<slug>` (or grep for the slug across commit messages) to surface implementing commits. Treat as advisory — the user confirms relevance before it gets written into the move annotation.

**Threshold differences:**

- `thoughts/` — looser threshold; thoughts are exploratory, partial overlap is common.
- `backlog/` — tighter threshold; backlog items are concrete, so a partial match is more likely a *real* partial than a different shape.

### 3. Surface results

Output format:

```
## Strong matches (N)

### file.md
- Claimed deliverable: <one line summary of what the file said should ship>
- Evidence: <files / symbols / commits found>
- Proposed action: Implemented / Partially shipped / Obsoleted
- Rationale: <one or two lines>

## Possible matches (N)

- file.md — one-line rationale
- file.md — one-line rationale
```

Process strong matches **one at a time** — propose the action, wait for the call. Possible matches go through as a flat list for user dismissal; confirmed ones then run through the matcher again as strong matches.

### 4. Apply approved actions

For each user-confirmed action, follow `project/workflow/README.md` "Moving files between stages" mechanics:

- **Delete-on-harvest (implemented / superseded):** `git rm` the thought. Record the disposition + shipped-artifact pointer in the sweep's manifest doc (a per-item "deleted — value at `<artifact>`" row); for superseded items, also add the "subsumes `<slug>`" note to the living successor. No `completed/` move — content is recoverable via `git log --diff-filter=D`.
- **Partial:** append the dated `## YYYY-MM-DD: Partially shipped` section. **No move.**
- **Rejected (genuine declined decision only):** append `## YYYY-MM-DD: Rejected` section, write to `rejected/`, delete from source, keep the origin date.

### 5. Update indexes

After all approved actions:

- `thoughts/_MAP.md` regenerates if `thoughts/` changed (drop moved files, refresh modified summaries).
- `backlog/_DEPS.md` regenerates if `backlog/` changed.

### 6. Close-out spawn-outs

If the sweep surfaces a recurring failure mode (e.g. "thoughts about UI components keep getting implemented without promotion"), capture as a lesson in `project/lessons.md` so the workflow discipline tightens. This is the workflow README's "close-out preparation" pattern applied to the audit itself.

## Batch mode

For full sweeps:

1. First, list every file with a quick triage estimate (skipped / candidate / will-investigate) so the user sees the surface area.
2. Process candidates in batches of 5–10. After each batch, present strong + possible matches and ask whether to continue or act on current results.
3. Strong matches within a batch still get one-at-a-time confirmation — batching applies only to *which set the matcher is currently chewing on*, not to user decisions.

## Rules

- **Read-only by default** — never move or annotate files without explicit user approval.
- **Per-match confirmation** — strong matches surface one at a time, never as a batch to approve wholesale.
- **Cite evidence** — every strong match must name the implementing files / symbols / commits. "Looks shipped" is not enough.
- **Respect the skip list** — meta/design-discussion thoughts are deliberately deferred. Use `--include-meta` to override; don't override silently.
- **Don't widen the matcher beyond v1** — embedding-based matching is a v2 deliberately deferred. v1 leans on `Grep` / `Read` / user pattern recognition. If v1 misses obvious matches or floods on false positives, surface that as a meta-finding, don't bolt embeddings on inline.
- **Cadence** — recurring monthly sweep. Lighter than `/prune-completed` (weekly) because the upstream end of the pipeline drifts slower.

## Cross-references

- `project/workflow/README.md` — file-move mechanics, rejection flow, `_MAP.md` / `_DEPS.md` regeneration triggers.
- Your project's close-out reconciliation, if it has one — this audit is its cross-history counterpart: one session's diff versus the whole corpus.
- `/prune-completed` — sister skill at the downstream end.
- `project/workflow/thoughts/_MAP.md`, `project/workflow/backlog/_DEPS.md` — first-pass filter inputs.

## Record the run

If your project tracks recurring-maintenance cadences, stamp this run now so the cadence clock resets — `project/workflow/README.local.md` names the command if there is one. If your project doesn't track them, skip this step; the skill is complete either way.
