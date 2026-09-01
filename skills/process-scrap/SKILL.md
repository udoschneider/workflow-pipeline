---
name: process-scrap
description: "Process scrap.md notes — triage each item into thoughts, backlog, or drop. Invoke with /process-scrap."
---

# Process Scrap Skill

Triage items from `project/scrap.md` into the workflow pipeline.

## Invocation

```
/process-scrap
```

## Rules

1. **Never remove items without explicit approval** — present each item with a proposed action and wait for confirmation before modifying scrap.md
2. **Verify against codebase** — before proposing an action, check whether the item is already implemented, already tracked in thoughts/backlog, or outdated
3. **One item at a time — hard stop.** Up-front read-only research across all items is fine. But disposition + action is strictly per-item: present exactly ONE item (the item, proposed disposition, reasoning), then **STOP and end the turn**. Do not present or act on any other item in the same turn. Do not call any Write/Edit tool until the user has approved *that specific item*. Approval of one item is never approval of the next, nor of "the rest." Batching dispositions into one wall of text — even when the items look simple — is the failure mode this rule exists to prevent.

## Proposed Actions (per item)

For each scrap item, propose one of:

- **thought** — idea needs refinement, create a thought file via the standard Socratic + adversarial workflow. If refinement involves non-trivial sparring (not a quick one-liner), run the prior-art sweep (below) with tokens for *this item* before engaging, per `project/workflow/README.md` ("When sparring on a rough idea").
- **backlog** — actionable and well-defined enough to skip thought refinement, create a backlog item directly
- **existing** — already tracked (cite the file), remove from scrap
- **done** — already implemented (cite the code), remove from scrap
- **drop** — no longer relevant (explain why), remove from scrap
- **keep** — not ready to triage yet, leave in scrap

## Workflow

**Regenerate the indexes first.** They are derived projections of per-item frontmatter, and anything written since the last regeneration is not in them yet:

```sh
bin/workflow-index
```

If `project/workflow/README.local.md` names a different command for this, use that one — it is the one the project's own gates run. Cheap and idempotent. Do not skip it on the assumption that a hook already ran — hooks are an optimisation here, not the guarantee, and they are absent entirely on some install paths.

**Sweep the prior art before sparring any item.** The moment an item's disposition turns into real back-and-forth rather than one-line triage, run:

```sh
bin/workflow-index sweep <token> ...
```

Tokens come from what the item *does* and what it would replace, not from its own wording. This is one command over four corpora — pipeline, reference tree, lessons, vault — because running only the first is what makes a partial sweep look like a complete one. Relay any `!! NOT SEARCHED` corpus to the user in the dialogue rather than proceeding as though it were empty. Full rationale in `project/workflow/README.md` § "When sparring on a rough idea"; if `README.local.md` names a different command, use that one.

1. Read `project/scrap.md`
2. Read `project/workflow/thoughts/_MAP.md` and `project/workflow/backlog/_DEPS.md` for existing items
3. For each scrap item, run this loop — **one item per turn, no exceptions**: a. Verify against codebase and existing workflow items (read-only research may be done ahead for all items) b. Present **one** item with proposed action and reasoning c. **STOP — end the turn.** Wait for the user to approve *this item* d. On approval, execute the approved action for *this item only* e. Return to (b) for the next item in a new turn
4. After all items are processed, show a summary of actions taken
