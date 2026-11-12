# Changelog

What changed in each release, and — for any release that needs it — what a consumer has to do after updating.

**Which version am I on?** `project/workflow/.version` in your repository, written on every install. Apply the **Migrating** steps of every entry newer than it, oldest first.

Versioning follows [SemVer](https://semver.org/). While the package is below 1.0:

- **minor** (`0.x.0`): a consumer must act after updating — a spec rule changed, a new gate needs wiring, citations need rewriting, a file was removed or renamed. The entry always carries a **Migrating** section.
- **patch** (`0.x.y`): drop-in. Updating is the whole migration.

## [0.3.0] — 2026-11-12

A citation into the pipeline or the memory files may no longer dangle. Needs action: see **Migrating**.

### Added

- `bin/workflow-index links [--fix]`. It fails (exit 1) on a bare stage-path citation that neither resolves nor carries `(pruned)`, and on a `§ "Heading"` citation into `lessons.md`, `scrap.md` or `reference/` whose heading is missing, ambiguous or unquoted. It exits 2 when it could not run. `--fix` repoints moved docs and moved headings, marks `(pruned)` when git history shows the doc existed, prints each repair, and refuses in a shallow clone. It is never run by `--check` or a hook.
- `project/workflow/links.json` (optional, committed): `exclude` and `extensions` for the scan.
- Spec § "Citing pipeline files and memory entries": the citation convention, and the rule that repairing a citation in a live pipeline file is not rewriting history.

### Changed

- `/prune-completed` has a new step 7, "Inbound references", and runs `links --fix` in the same commit as the delete.
- `/prune-lessons` resolves citations to a lesson in the same change that removes it.
- Moving a file between stages now ends with `links --fix`.

### Migrating

1. Update the package.
2. Optionally add `project/workflow/links.json` with `exclude` for vendored code, generated files and test fixtures that cite example docs.
3. Run `bin/workflow-index links --fix`, review the printed repairs, and commit them.
4. Resolve what it reports, then re-run until it exits 0:
   - `unquoted`: rewrite `§ Heading` / `§1.` as `§ "Heading text"` (the heading's leading words are enough if they're unique in that file).
   - `missing-heading` / `missing-file`: inline the point into the citing text, or delete the citation. Never mark it `(pruned)`.
   - `ambiguous-heading`: make the heading unique, or cite more of it.
   - `dangling` that `--fix` left alone: the slug never existed at a stage path, so fix the typo or drop the citation.
5. Wire `bin/workflow-index links` into your pre-commit or CI gate, and name that line in `project/workflow/README.local.md`.
6. If you run your own citation checker, retire its stage-path and memory-citation checks so the two can't disagree. Keep anything it checks beyond those.

## [0.2.1] — 2026-11-12

Drop-in.

### Added

- `project/workflow/.version`, written by `install.sh` (version plus the package commit, `+dirty` for an uncommitted checkout) and by `/workflow-pipeline-init` (version). It tells you which entries below you have not applied yet.
- This changelog, and a `test.sh` check that every version field in the package agrees with the newest entry here.

### Changed

- `/what-next` treats an over-full `active/` as a smell, not only a stale one.

## [0.2.0] — 2026-09-01

Baseline: the first tagged release. Nothing earlier is recorded here.
