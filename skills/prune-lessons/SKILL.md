---
name: prune-lessons
description: "Triage project/lessons.md entries into references, code comments, or drop. Evidence-based, fully interactive. Invoke with /prune-lessons."
---

# Prune Lessons Skill

Triage `project/lessons.md` by clustering related entries topic-wise and moving them to their best home — a reference doc, a code comment, or outright deletion. Fully interactive, one lesson (or cluster) at a time.

## Why this skill exists

`project/lessons.md` is the raw catch-all for cross-cutting lessons. Without periodic triage it turns into a junkyard: related insights scattered across hundreds of lines, nothing synthesized, nothing discoverable. This skill distills the file into coherent, topic-based references that Claude actually finds when doing the relevant work.

Principles:

- **Evidence-based, not text-based.** Verify each lesson against the codebase before recommending. If the pattern is gone or the rule is formalized elsewhere, the default recommendation is *drop*. Git history is the safety net.
- **Most lessons flow to references.** Lessons that truly belong next to a single module should have landed as code comments at write-time; if they're in lessons.md, they're usually cross-cutting. The agent instructions file (`AGENTS.md`, `CLAUDE.md`, or your agent's equivalent) is **not** a destination for this skill — broad conventions are authored there deliberately, not extracted here.
- **Topic-wise, not line-by-line.** Related lessons can be scattered across the file. Cluster them first, then decide.
- **Synthesis over accumulation.** A new reference doc should read like a designed document (principle + examples), not a bulleted dump. Bullet-list references are a legitimate fallback for tactical grab-bags (CSS tricks, HTML snippets) where a higher-level narrative genuinely doesn't exist.
- **Orphans are fine.** Lessons that don't cluster yet stay in lessons.md. Don't force-promote them.

## Invocation

```
/prune-lessons
```

Manual-only trigger. Run whenever lessons.md feels heavy. No fixed cadence.

## Thresholds

- **Existing reference cluster — 1+.** Any single lesson that clearly belongs to an existing reference (`project/reference/*.md`) flows there immediately.
- **New cluster — 5+.** A new reference is only spawned when at least 5 related lessons form a coherent topic. Smaller clusters wait in lessons.md for friends.

## Per-lesson outcomes

For each lesson (or cluster of lessons), the skill proposes one of:

- **Move to existing reference** — augments a `project/reference/*.md` file
- **Extract to new reference** — creates a new `project/reference/TOPIC.md` (only at 5+ threshold)
- **Move to code comment** — rare; the lesson really belongs in a `@moduledoc` / `@doc` / inline comment in a specific module
- **Drop** — default when evidence is missing (pattern is gone, rule formalized elsewhere, no longer relevant)
- **Leave in lessons.md** — orphan, waiting for cluster mass

## Pre-passes (offered before triage)

Before the main triage walk, the skill scans for:

- **Merges** — two or more entries that say the same thing in different words. Offer to combine before treating as separate entries (prevents inflating the 5+ cluster threshold with dupes).
- **Splits** — a single entry that conflates two distinct insights that might flow to different destinations. Offer to split before triaging.

Both are interactive proposals — user confirms each one before the rewrite happens.

## Workflow

1. **Read inputs**
   - `project/lessons.md` — full file
   - `project/reference/_INDEX.md` — if missing, bootstrap it by scanning `project/reference/*.md` (see Bootstrap below)
   - Skim the agent instructions file so you know which sections exist for pointer placement

2. **Cluster mentally** Group related lessons by topic across the whole file (ignore line order). For each cluster, note whether an existing reference already owns the topic.

3. **Pre-pass: merge + split** Walk any obvious merge/split candidates first. Confirm each with the user before rewriting lessons.md.

4. **Main triage walk — one lesson/cluster at a time** For each lesson or cluster:

   a. **Verify against the codebase.** Grep for the patterns/anti-patterns the lesson is about. Check referenced module/function names still exist. Check whether the rule has been formalized in the agent instructions file, an existing reference, or a code comment.

   b. **Propose an outcome** with reasoning and evidence:
   - If the evidence says the pattern is gone or already documented → propose *drop*
   - If it fits an existing reference → propose *move to existing reference*
   - If it's part of a 5+ cluster → propose *extract to new reference* (ask: synthesized narrative or bullet-list fallback?)
   - If it belongs next to a single module → propose *move to code comment*
   - Otherwise → propose *leave in lessons.md* (orphan)

   c. **Wait for user confirmation.** User may redirect (e.g., "actually this should go in X reference" or "drop it").

   d. **Execute immediately** on confirmation — don't accumulate a change set:
   - Write/update the target file (reference, code comment, etc.)
   - Remove the source lines from `lessons.md`
   - Update `project/reference/_INDEX.md` (add new entry, or refresh description if the reference grew)
   - For new references: add a one-line pointer to the relevant section of the agent instructions file (ask the user which section if it's not obvious)

5. **Summary** After the walk, report: lessons moved to existing references, new references created, code comments added, items dropped, orphans remaining.

## Bootstrap: `_INDEX.md`

If `project/reference/_INDEX.md` does not exist on first run, build it before clustering:

1. List all `.md` files in `project/reference/` (and immediate subdirs)
2. For each, read the top of the file (`# Title` and opening paragraph)
3. Write `project/reference/_INDEX.md` with one entry per reference doc:

```markdown
# Reference Index

Topic-based reference docs for this project. Each entry summarizes what the doc covers and when to consult it.

## filename.md

**Topic:** <one-line topic> **Covers:** <2-3 lines on scope — what's inside, what decisions/patterns are captured> **Consult when:** <the situation where Claude should reach for it>
```

The index is richer than the pointers in the agent instructions file — that file gives a one-liner in the relevant section; the index gives enough detail that the agent can rule out references without opening them.

Keep the index updated on every skill run: refresh the "Covers" paragraph when a reference gains new content.

## Synthesis vs bullet-list (when creating a new reference)

**Default: synthesized narrative.** Read all lessons in the cluster together and write a cohesive document that states the underlying principle and uses the individual lessons as supporting examples or sub-rules. The cluster members should not appear verbatim — they're raw material, not the output.

**Fallback: bullet list.** Some topics genuinely don't synthesize (CSS tricks, HTML snippets, tactical recipes). A bullet-list reference is fine; just make the grouping explicit and the intent clear. Don't force a narrative if the content resists it.

When proposing a new reference, ask the user which form fits before drafting.

## Rules

- **Never bulk-execute.** Every move (including merges and splits) is confirmed by the user before the files are touched.
- **Codebase evidence first.** Don't base recommendations on the lesson text alone — verify. The user explicitly wants "this is no longer applicable" as an evidence-based recommendation, not a guess.
- **Don't fear deletion.** Git history preserves everything. When evidence is missing, *drop* is the correct default, not "leave just in case."
- **No orphan references.** Every new reference gets an entry in `_INDEX.md` and a pointer in the relevant agent-instructions section, atomically with its creation.
- **The agent instructions file is not a destination for lessons.** Add pointers to references, never bulk-extract lesson text into its rules. If a lesson genuinely reads like a top-level convention, surface it to the user and let them decide whether to author it manually.
- **Lessons.md file edits must be surgical.** Remove only the lines/blocks approved for extraction. Do not reformat, reorder, or restructure lessons.md as a side effect.

## Record the run

If your project tracks recurring-maintenance cadences, stamp this run now so the cadence clock resets — `project/workflow/README.local.md` names the command if there is one. If your project doesn't track them, skip this step; the skill is complete either way.
