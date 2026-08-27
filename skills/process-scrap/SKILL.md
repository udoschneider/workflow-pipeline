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

- **thought** — idea needs refinement, create a thought file via the standard Socratic + adversarial workflow. If refinement involves non-trivial sparring (not a quick one-liner), follow the vault-consultation step from `project/workflow/README.md` ("When sparring on a rough idea") before engaging.
- **backlog** — actionable and well-defined enough to skip thought refinement, create a backlog item directly
- **existing** — already tracked (cite the file), remove from scrap
- **done** — already implemented (cite the code), remove from scrap
- **drop** — no longer relevant (explain why), remove from scrap
- **keep** — not ready to triage yet, leave in scrap

## Workflow

1. Read `project/scrap.md`
2. Read `project/workflow/thoughts/_MAP.md` and `project/workflow/backlog/_DEPS.md` for existing items
3. For each scrap item, run this loop — **one item per turn, no exceptions**: a. Verify against codebase and existing workflow items (read-only research may be done ahead for all items) b. Present **one** item with proposed action and reasoning c. **STOP — end the turn.** Wait for the user to approve *this item* d. On approval, execute the approved action for *this item only* e. Return to (b) for the next item in a new turn
4. After all items are processed, show a summary of actions taken
