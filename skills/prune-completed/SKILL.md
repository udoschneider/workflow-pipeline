---
name: prune-completed
description: "Audit completed workflow docs for pruning readiness — checks test coverage, code rationale, lessons extraction. Invoke with /prune-completed."
---

# Prune Completed Skill

Audit `project/workflow/completed/` docs against the 5-step pruning checklist and report readiness.

## Invocation

```
/prune-completed              # Audit all completed docs
/prune-completed <slug>       # Audit a specific file (partial match OK)
```

## Pruning Checklist (per file)

Each completed doc is evaluated against these 5 steps from the workflow rules:

### 1. Tests exist

Search for test files and test cases related to the feature/fix described in the doc. Check `test/` for relevant filenames, module names, and function names mentioned in the doc.

- **Pass:** Related tests found
- **Fail:** No related tests found — tests must be written before pruning

### 2. Design rationale in code

Check that key "why" decisions from the doc are captured in `@moduledoc`, `@doc`, or inline comments in the referenced source files. Focus on non-obvious design choices — things where a reader would ask "why not the simpler approach?"

- **Pass:** Key decisions documented in code
- **Partial:** Some decisions documented, others missing (list which)
- **Skip:** Doc has no significant design decisions (e.g., simple bug fixes)

### 3. Lessons and reference extracted

Check whether the doc contains gotchas, debugging stories, or domain knowledge that should live in `project/lessons.md` or `project/reference/`. Cross-reference against existing entries.

- **Pass:** Nothing to extract, or already extracted
- **Flag:** Specific items that should be extracted (list them)

### 4. Lessons promoted to code

Check `project/lessons.md` for entries that reference this completed item's modules or topic. If a lesson is tightly coupled to a specific module/function, it should be moved into that code as a `@doc` note.

- **Pass:** No tightly-coupled lessons, or already promoted
- **Flag:** Specific lessons that should move into code (list them)

### 5. Intervention metric persisted

Verify `project/instrumentation/agent_intervention.csv` has a row whose `slug` column matches this completed doc's slug (the filename minus the date prefix and `.md` extension). The CSV is the durable record that survives `completed/` pruning — without a row, the harness-health data this doc represents is lost.

- **Pass:** Row found in CSV with matching slug
- **Fail (backfill):** No matching row found, but the doc has a `## YYYY-MM-DD: Implementation notes` section with an intervention level. Extract from the doc and append the row to the CSV before continuing. Use today's date for the CSV row's `date` column (or the completion date from the doc's history table if recoverable).
- **Fail (no data):** No matching row in CSV and no Implementation notes section in the doc. This is an item that closed before the intervention-recording rollout (2026-05-11) — flag as "no metric available, pre-rollout closure" and proceed. Don't synthesize data.

### 6. Cluster gate

If this doc's frontmatter has a `cluster: <slug>` field, the doc is a *member* of a cluster coordination doc (see `project/workflow/README.md` § "Cluster coordination docs"). Cluster members can only be pruned once the cluster itself has closed — otherwise the cluster's rollup history needs intact member references.

- **Pass (no cluster):** Doc has no `cluster:` field. Skip to step 7.
- **Pass (cluster closed):** Doc has `cluster: <slug>`, and a file matching `<slug>` exists in `project/workflow/completed/`. Proceed.
- **Fail (cluster still active):** Doc has `cluster: <slug>`, and a file matching `<slug>` exists in `project/workflow/active/` (not yet in `completed/`). **Refuse to prune** — the cluster is still tracking its members. Re-evaluate after the cluster closes.
- **Fail (cluster missing):** Doc has `cluster: <slug>`, and no file matching `<slug>` exists in either `active/` or `completed/`. Flag as a workflow integrity issue (cluster doc lost or never created) and **refuse to prune** until resolved.

To locate the cluster doc, glob `project/workflow/{active,completed}/*_<slug>.md`. The match is the file whose slug (filename minus date prefix and `.md` extension) equals the `cluster:` value.

### 7. Ready to delete

Only passes if steps 1-6 all pass (or step 5 is "no metric available, pre-rollout closure").

## Workflow

1. **Read the target file(s)** in `project/workflow/completed/`
2. **Identify the scope** — what modules, files, and features does this doc cover? Extract key module names, file paths, and concepts.
3. **Run each checklist step** using Grep, Glob, and Read to verify:
   - Step 1: Search `test/` for related test files
   - Step 2: Read referenced source files, check for rationale comments
   - Step 3: Read `project/lessons.md`, check for unextracted content
   - Step 4: Check if lessons.md entries should be promoted to code
   - Step 5: Check `project/instrumentation/agent_intervention.csv` for a matching slug row; backfill from the doc's Implementation notes section if missing
   - Step 6: Check the doc's frontmatter for a `cluster:` field; if present, locate the cluster doc in `active/` or `completed/`
4. **Report results** per file in this format:

```
## filename.md

| Step | Status | Notes |
|------|--------|-------|
| 1. Tests | Pass/Fail | test files found or what's missing |
| 2. Rationale in code | Pass/Partial/Skip | what's documented vs missing |
| 3. Lessons extracted | Pass/Flag | items needing extraction |
| 4. Lessons promoted | Pass/Flag | items needing promotion |
| 5. Intervention metric | Pass/Backfill/Pre-rollout | CSV row found, or backfilled, or no data available |
| 6. Cluster gate | Pass/Fail | no cluster, cluster closed, cluster still active, or cluster missing |
| **7. Ready to prune** | **Yes/No** | blocking issues summary |
```

5. **After reporting**, ask the user which files to prune (if any are ready)
6. **On confirmation**, delete the approved files from `completed/`

## Batch Mode

When auditing all files, process them in groups to keep output manageable:

1. First, list all files with a quick readiness estimate (based on file age, size, and a fast scan)
2. Start with the oldest/smallest files — they're most likely ready
3. Present results in batches of 5-10 files
4. After each batch, ask whether to continue to the next batch or act on current results

## Rules

- **Read-only by default** — never delete files without explicit user approval
- **Be specific** about what's missing — "needs tests" is not enough; say what should be tested
- **Don't over-flag** — simple bug fixes or config changes may legitimately have no design rationale to extract
- **Check doc type** — `type: initiative` docs (marketing, partnerships) have different expectations than `type: code` docs. Initiative docs may not need test coverage.
- **Respect the pruning purpose** — the goal is to distribute knowledge to permanent homes, not to create busywork. If the doc's content is already fully represented elsewhere, it's ready to prune even if not every checkbox is formally checked.

## Record the run

If your project tracks recurring-maintenance cadences, stamp this run now so the cadence clock resets — `project/workflow/README.local.md` names the command if there is one. If your project doesn't track them, skip this step; the skill is complete either way.
