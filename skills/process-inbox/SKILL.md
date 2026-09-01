---
name: process-inbox
description: "Triage items from project/workflow/inbox/ into the workflow pipeline — offer to re-spar, create frontmatter, and wire into the indexes (_MAP, _DEPS). Invoke with /process-inbox."
---

# Process Inbox Skill

Triage richer-than-scrap sparring outputs deposited in `project/workflow/inbox/` and graduate them into the workflow pipeline (or shrink/discard).

`inbox/` is the integration buffer for **multi-paragraph** sparring outputs that don't fit cleanly as scrap one-liners. It's normally untracked (visible in `git status` as `??`), surviving locally via Time Machine until promoted or discarded. See `project/workflow/README.md` § "Inbox — pre-thoughts integration buffer" for the convention.

## Invocation

```
/process-inbox
```

## Rules

1. **Never modify or remove an inbox file without explicit approval** — present the item, propose a disposition, wait for confirmation.
2. **One item at a time** — present each file, your proposed disposition, and reasoning. Wait for approval before moving to the next item.
3. **Default to discard.** Inbox items are *raw captures*; many won't survive triage, and that's correct. The skill should propose `discard` whenever the item turns out to be ephemeral, context-bound to a session that already shipped, or duplicate of existing thoughts/backlog. Don't silently promote.
4. **Verify against the codebase and pipeline** before proposing — check whether the captured idea is already implemented, already tracked under a different slug, or addressed by a recent commit.
5. **Re-spar before promotion** when the captured content is raw — see "Re-spar offer" below. The inbox item is rarely promotion-ready as-written.
6. **Set `summary:` on every new thought** — the `_MAP.md` row is generated from it. Don't hand-edit `_MAP.md` / `_DEPS.md`; they regenerate automatically (see "Indexes regenerate themselves" below).

## Proposed Actions (per item)

For each inbox file, propose one of:

- **discard** — not worth keeping; `rm` the file with a one-line reason recorded in the session output (not in any persistent doc — the discard reason dies with the conversation).
- **shrink-to-scrap** — the captured content compresses into a single line worth keeping; append to `project/scrap.md` as one or more bullet items, then `rm` the inbox file. Use when the item is real but overlong for its actual signal.
- **existing** — already tracked in `thoughts/` or `backlog/` (cite the file); `rm` the inbox file. Optionally append a dated `## YYYY-MM-DD: Inbox addendum` section to the existing thought/backlog file if the inbox content adds genuinely new context.
- **done** — already implemented (cite the code or recent commit); `rm` the inbox file.
- **thought** — the item is real but raw. **Offer to re-spar** (see below). After refinement (or if the user declines), write a properly-frontmattered file to `project/workflow/thoughts/YYYYMMDD_slug.md`, `rm` the inbox source.
- **backlog** — the item is real *and* well-formed enough to skip thought refinement. Rare; the bar is high. Offer to re-spar at the backlog level (acceptance-criteria derivation, second-pass stance per `project/workflow/README.md` § "Sparring stances"). Write to `project/workflow/backlog/YYYYMMDD_slug.md` with full frontmatter, `rm` the inbox source.
- **keep** — not ready to triage yet; leave the file in `inbox/`. Use sparingly — items lingering for >2 weeks should surface during the next workflow retro.

## Re-spar offer

When proposing `thought` or `backlog`, **always offer a re-spar round** before writing the destination file:

> *"This item reads as [raw / partially-formed / promotion-ready]. Want to run a brief Socratic + adversarial round before I write it as a thought / backlog item? (yes / no — write as captured / no — let me edit the captured text first)"*

If the user accepts the re-spar:

1. **Sweep the prior art first** — `bin/workflow-index sweep <token> ...`, with tokens drawn from what the item *does* and what it would replace, never from its own wording. One command over four corpora (pipeline, reference tree, lessons, vault); running only the first is what makes a partial sweep look like a complete one. Relay any `!! NOT SEARCHED` corpus in the dialogue rather than treating it as empty. See `project/workflow/README.md` § "When sparring on a rough idea"; if `README.local.md` names a different command, use that one.
2. Follow the **Thought Refinement** workflow in `project/workflow/README.md` (Socratic dialogue + adversarial round, one question at a time, 2–4 rounds).
3. For `backlog` destinations, additionally derive `## Acceptance criteria` per the workflow's promotion-step questions, and offer the second-pass stance round per § "Sparring stances."
4. After refinement, draft the destination file content and present for final review before writing.

If the user declines re-spar:

- Write the destination file using the inbox content largely as-is, structured into the standard format (frontmatter + history table + `## YYYY-MM-DD: Initial thought` or `## YYYY-MM-DD: Initial backlog entry` section).
- The file can be re-sparred later by any sparring session that touches it.

## Frontmatter — what to write per destination

When promoting to **thoughts/**:

```yaml
---
type: code        # or "initiative" — ask if not obvious from content
---
```

`refinement_state:` and `cluster:` are *thoughts/-only* fields per the schema; only set them when the user explicitly indicates the right value. Default omitted (treated as raw).

When promoting to **backlog/**:

```yaml
---
type: code | initiative                           # ask if not obvious
priority: Must Have | Should Have | Nice to Have  # ask explicitly
band: mvp | v1.0 | later                          # ask if non-trivial; omit if MVP-routine
gates: [when-enterprise | when-evidence]          # only if applicable
depends_on: [slug_a, slug_b]                      # only if applicable; bare slugs
---
```

Required fields per stage: `thoughts/` needs `type` **and `summary`**; `backlog/` needs `type` and `priority`. `summary` is not optional — `bin/workflow-index --check` fails on a thought without one, because it is the row text of `_MAP.md` and the one thing the generator cannot derive. See `project/workflow/README.md` § "Frontmatter schema" for the full spec.

## File structure — destinations

**Thoughts file** (`project/workflow/thoughts/YYYYMMDD_slug.md`):

```markdown
---
type: code
summary: |
  Two or three lines of navigation summary. This becomes the thought's row in
  _MAP.md, and the generator rejects a thought that lacks it.
---

# Title

| Stage   | Date       |
| ------- | ---------- |
| Thought | YYYY-MM-DD |

## YYYY-MM-DD: Initial thought

[Refined description from the re-spar, or the captured content as-is if re-spar declined.]
```

**Backlog file** (`project/workflow/backlog/YYYYMMDD_slug.md`):

```markdown
---
type: code
priority: Should Have
band: v1.0
---

# Title

| Stage   | Date       |
| ------- | ---------- |
| Backlog | YYYY-MM-DD |

## YYYY-MM-DD: Initial backlog entry

### Problem

[…]

### Approach

[…]

### Out of scope

[…]

## Acceptance criteria

- [Binary-checkable behavior]

## References

- Captured via /process-inbox from `inbox/<original-slug>.md` on YYYY-MM-DD.
- [Other references]
```

Date in the filename is the **origin date** (today) — see `project/workflow/README.md` § "Moving files between stages" for the date-rules.

## Indexes regenerate themselves

`_MAP.md` / `_DEPS.md` are generated + gitignored — never hand-edit them. They rebuild from frontmatter via `bin/workflow-index`, or whatever `project/workflow/README.local.md` names in its place.

**Run it yourself before reading an index, and again after promoting anything.** Agent hooks and pre-commit steps may also fire it, but they are an optimisation and are absent entirely on some install paths — so a skill that reads an index without regenerating is reading whatever happened to be on disk. That is worse than a missing index, because a stale table is complete and well-formed and reads as current.

Your only obligation beyond that is the **source**: every new thought must carry a `summary:` frontmatter field (the `_MAP.md` row), and `depends_on:` / `refinement_state:` drive the `_DEPS` tables.

## Workflow

1. **List inbox files** — read `project/workflow/inbox/*.md` (excluding `.gitkeep`). If empty, report "Inbox is empty" and exit.
2. **Regenerate, then read existing pipeline state** for verification — run `bin/workflow-index` first, then read `project/workflow/thoughts/_MAP.md`, `project/workflow/backlog/_DEPS.md`, and `project/workflow/thoughts/_DEPS.md`. These let you cite "already tracked" cases without re-reading every file.
3. **For each inbox file** (oldest first by filename): a. Read the file. b. Verify against codebase and existing workflow items (grep / read). c. Present the item with proposed action and reasoning. d. If `thought` or `backlog`, offer the re-spar round per § "Re-spar offer." e. Wait for user approval on the disposition (and re-spar outcome if relevant). f. Execute the approved action — write destination file, `rm` inbox source, append to scrap.md, etc.
4. **Batch index regeneration** (if any promotions happened).
5. **Summary** — show actions taken: N discarded, N shrunk-to-scrap, N promoted-to-thought, N promoted-to-backlog, N kept, N already-tracked, N done.

## Anti-patterns to avoid

- **Don't auto-promote.** Default-to-discard discipline is what keeps inbox/ from becoming a slow leak into thoughts/.
- **Don't re-spar in the inbox file itself.** The inbox is a capture buffer, not a refinement surface. Re-spar produces the destination file's content directly.
- **Don't index inbox/.** No `_MAP.md`, no `_DEPS.md`, no entries in other indexes pointing into inbox/. The buffer is invisible to the workflow by design.
- **Don't update `MEMORY.md`, `project/lessons.md`, or `project/reference/` from inbox triage.** Those are separate workflows. If a triaged inbox item suggests a lesson or reference belongs somewhere, surface that *separately* after triage — don't bundle it.
