---
name: what-next
description: "Triage assistant over the workflow indexes — proposes 2-3 candidates matched to the current effort window and session goal, and surfaces a separate \"what are you avoiding?\" smells section (stale-actives, stale clusters, high-pull raw thoughts, unpromoted promotion-ready). Default-declines when nothing fits. Invoke with /what-next."
---

# What-Next Skill

Suggest next work matched to *current-state context* (effort window, session goal), with honest concrete costs and a separate look at what's quietly rotting.

This is a triage assistant, not a planner. It reads the workflow indexes (`backlog/_DEPS.md`, `thoughts/_MAP.md`, `thoughts/_DEPS.md`), asks two questions, surfaces 2–3 candidates, and shows a "what are you avoiding?" section for smells. It will *not* invent ROI scores or hour-based estimates; it will default-decline when nothing genuinely fits.

## Invocation

```
/what-next
```

No arguments. Each invocation runs fresh — no cross-invocation memory.

## When to Use

At session start when the next move isn't obvious, or mid-session when current work blocks and you want to bridge with something else.

Skip when:

- A clear active item is in flight and you're not blocked — keep going.
- You already know what you want to do — this skill exists to reduce friction, not add ceremony.

## Steps

### 1. Read the indexes

**Regenerate the indexes first.** They are derived projections of per-item frontmatter, and anything written since the last regeneration is not in them yet:

```sh
bin/workflow-index
```

If `project/workflow/README.local.md` names a different command for this, use that one — it is the one the project's own gates run.

Cheap and idempotent. Do not skip it on the assumption that a hook already ran — hooks are an optimisation here, not the guarantee, and they are absent entirely on some install paths.

Then read (don't grep) in this order:

1. `project/workflow/backlog/_DEPS.md` — Actionable + Active sections give the pickable backlog. Blocked section names what's waiting on what.
2. `project/workflow/thoughts/_DEPS.md` — ranked by `downstream_pull`. Top of this list is the strongest promotion signal.
3. `project/workflow/thoughts/_MAP.md` — 2–3 line summaries for any thought a candidate references.

These three are the *complete* input. Do not also walk individual backlog/thought files at this stage — the indexes are the floor. Drill into a specific file only if the maintainer picks a candidate that needs more context.

### 2. Ask effort window

> "Roughly how much focused time is available now?
>
> - 30 minutes
> - An afternoon (2–4 hours)
> - A full day
> - A multi-day stretch
> - Other"

Ask this as a single multiple-choice question — these four options plus an "Other" escape (in Claude Code, `AskUserQuestion`). Wait for the answer.

### 3. Ask session goal

> "What's the right shape for this session?
>
> - Ship something (visible delivery, move an item to completed)
> - Unblock work (clear a dep, prep a foundation)
> - Learn (explore, sparring, refinement, no commitment)
> - Polish (cleanup, refactors, gardening)
> - Other"

Same pattern. Wait for the answer.

### 4. Compute candidates

Filter the pool against the effort + goal pair:

**Pool by goal:**

- `ship` → `backlog/_DEPS.md` Actionable section. Items in Active also count if they're close to closing.
- `unblock` → backlog/active items in the Blocked section whose blocker is a thought you could promote in this session; or high-`downstream_pull` raw thoughts that, once promoted, unblock something downstream.
- `learn` → `thoughts/_MAP.md` entries that are unsparred or marked for re-spar; `thoughts/_DEPS.md` rows with `refinement_state: raw` and modest pull.
- `polish` → backlog items with `type: code` whose AC reads "lint", "cleanup", "rename", "convention", or whose summary mentions audit/sweep.

**Filter by effort window:**

- 30 min → only items with a small surface (one file, one rename, one doc edit). Reject anything with `wide blast radius`, `policy`, `migration`, `dependency upgrade`.
- afternoon → ordinary single-purpose backlog items. Reject multi-session refactors.
- full day → items with cross-cutting touches but no multi-day character.
- multi-day → architectural work, broad refactors, new mechanisms.

**Respect band/gates:**

- `band: later` items with unfired gates are NEVER actionable, regardless of `priority` or no-unmet-deps status. The gate is blocking. Mirror the rule in `project/workflow/README.md` § "Bands and gates".

**Pick 2–3 candidates max.** If the filtered pool has 8+ hits, narrow by:

1. Priority (Must Have > Should Have > Nice to Have)
2. Within priority, prefer items that *unblock* others (look at the Blocked section to see if any item is waiting on this one)
3. Within that, prefer items in the maintainer's preferred working area if one is obvious from recent git activity (optional — do not invent adjacency).

### 5. Render candidates

For each picked item, render:

```
### `<filename>`  —  <priority> / <band or —> / <type>
**Why this:** <one-line rationale — what makes this a fit for the effort/goal pair, and any unblock value>
**Concrete cost:** <specific risk> — not a t-shirt size.
```

**Concrete cost examples (the bar):**

- "needs test DB reset before starting (3–5 min)"
- "touches the authorization layer — expect a lint rabbit hole about bypassing the domain API"
- "wide blast radius across the UI component tree — plan for 2–3 sessions"
- "the form field itself is medium-friction; the unblock value is the deeper question of whether that state belongs in the URL at all"

**Concrete cost anti-patterns (do not produce):**

- "small" / "medium" / "large"
- "couple of hours"
- "easy win"
- "should be quick"

The rule: every cost line must name a *specific* risk, file, or dependency that the maintainer can verify in 10 seconds.

### 6. Surface smells — "What are you avoiding?"

Compute five signals. **Hide the section entirely when all five are empty.**

#### 6a. Stale-active items

A non-cluster item in `project/workflow/active/` with no commit touching it in the last 14 days. This operationalizes the *load-bearing* half of the README rule (`project/workflow/README.md` § "Stale active signal"): the README phrases it as "age × last-touch, not age alone — an item idle for 2 weeks is the actual signal, regardless of start date." 14 days = the "2 weeks" threshold. Cluster docs are exempt (see `project/workflow/README.md` § "Cluster coordination docs").

```sh
# For each non-cluster active file, get the most recent commit touching it:
for f in project/workflow/active/*.md; do
  last=$(git log -1 --format=%cs -- "$f")
  echo "$last  $f"
done | sort
```

A file is *cluster* if any thought references it via `cluster: <slug>` — check the `thoughts/_DEPS.md` Cluster column. Skip those.

For each stale item, render:

```
- `<filename>` — last touched <YYYY-MM-DD> (<N> days ago)
  Three good outcomes: bump back to backlog, reject, or annotate with `## YYYY-MM-DD: Why slow`.
```

#### 6b. Stale clusters

Cluster docs (in `active/`, slug appears in the Cluster column of `thoughts/_DEPS.md`) older than 6 months with no *member* file touched in 90+ days.

```sh
# Cluster age: when the cluster doc moved to active/
git log --diff-filter=A --format=%cs -- project/workflow/active/<cluster_doc>.md | tail -1

# Member activity: most recent commit touching any thought with `cluster: <slug>`
```

Render:

```
- Cluster `<slug>` — opened <YYYY-MM-DD>, no member movement since <YYYY-MM-DD>
  Either close the cluster (move remaining members to rejected/), or pick one member to push forward this session.
```

#### 6c. High-pull raw thoughts

Rows in `thoughts/_DEPS.md` where `downstream_pull >= 1` AND `refinement_state` is `raw` or `—`. These are foundation rot — real downstream work is waiting on something that hasn't been thought through.

Render:

```
- `<filename>` — `downstream_pull: <N>` but `refinement_state: <raw|—>`
  Blocking: <comma-separated downstream items from backlog/_DEPS.md Blocked section>
  A sparring round here unblocks <N> downstream item(s).
```

#### 6d. Unpromoted promotion-ready thoughts

Rows in `thoughts/_DEPS.md` with `refinement_state: promotion-ready` whose file hasn't been touched in 28+ days. The thought says "ready" — the maintainer is sitting on a yes.

Render:

```
- `<filename>` — marked `promotion-ready` <N> days ago, still unpromoted.
  Either promote (one Socratic round to set priority + AC), or downgrade `refinement_state` to `refined` if it's no longer ready.
```

#### 6e. Overdue recurring tasks

**Optional — only if your project tracks recurring-maintenance cadences.** This pipeline does not ship that instrument. If yours has one, `project/workflow/README.local.md` names it and the command that reports what is overdue; if it doesn't, omit this sub-section entirely.

Recurring maintenance tasks (weekly/monthly/quarterly audits, prunes, a dependency sweep) that are past their cadence. Each skill self-stamps at close-out and the stamps live in a small registry — a CSV under `project/instrumentation/` is enough. A documented cadence that never fires is exactly the silent rot this signal catches.

Report nothing when nothing is overdue; otherwise render one line per overdue task under a short header:

```
- Recurring maintenance: N overdue:
  - <slug> — <N>d since last run (cadence <C>d)   ← run the matching skill, then it self-stamps
```

Never-stamped tasks (a fresh registry, or a task never run) show as "never stamped" and sort to the top — on first rollout expect several; running each once clears it.

### 7. Default-decline when nothing fits

If steps 4–5 produce zero candidates after filtering by the effort/goal pair, **do not surface a poor match.** Render:

```
Nothing in the actionable pool fits a <effort> slot under "<goal>" right now.

Options:
1. Re-ask with a different goal — the actionable pool has good fits for: <list goals that have candidates>.
2. Re-ask with a wider effort window — the smallest blocking item needs <effort tier>.
3. Use this slot for the smells above (if any), or take a break.
```

If the smells section is also empty, that's a fine outcome: "Nothing actionable, nothing rotting. Solid place to pause."

## Output format

The full skill output is rendered in this order:

```
## Effort: <effort>  |  Goal: <goal>

## Candidates

[2-3 candidates per Step 5, or the default-decline block from Step 7]

## What are you avoiding?

[Smells from Step 6, omitting empty sub-sections; omit this whole heading if all five are empty]
```

No trailing summary. No "Hope this helps." The candidate block + smells block IS the output.

## Rules

- **Read the indexes only.** Drill into specific backlog/thought files only after the maintainer picks a candidate that needs more context — not during candidate computation.
- **Never invent adjacency from `git status` or branch state.** v1 does not consult git for context steering. The maintainer's "goal" answer is the steering signal.
- **No ROI scores.** No numeric ranking beyond what's already in `_DEPS.md` (priority, downstream_pull). The maintainer picks; the skill surfaces tradeoffs.
- **No hour estimates.** Concrete cost lines name specific risks or surface area, not durations.
- **Default-decline beats poor matches.** Suggesting a 30-min item when the pool only has multi-day work is worse than saying "nothing fits."
- **One question at a time.** Steps 2 and 3 are asked separately — never batch the two into one prompt.
- **No cross-invocation memory.** Each `/what-next` invocation asks fresh. Do not cache the effort/goal pair from a previous run.
- **Respect band/gates.** `band: later` + unfired gates = never actionable, no matter how high the priority.
- **Hide empty smells.** If sub-sections 6a–6e all return zero, omit the entire "What are you avoiding?" heading. Don't render "no smells detected."

## Cross-references

- `project/workflow/README.md` § "Thoughts Dependency Index" — schema and column meanings for the new ranked thought index.
- `project/workflow/README.md` § "Cluster coordination docs" — defines what counts as a cluster (used for the stale-cluster signal and the stale-active exemption).
- `project/workflow/README.md` § "Stale active signal" — the rule this skill operationalizes for sub-section 6a.
- `project/workflow/README.md` § "Bands and gates" — the gate-failure-is-blocking rule the candidate filter must respect.
- `/audit-thoughts` — adjacent skill. `/audit-thoughts` runs a deeper sweep on `thoughts/` (looking for already-shipped ideas); `/what-next` only surfaces a *light* smell of stale promotion-ready items as part of a triage prompt.
