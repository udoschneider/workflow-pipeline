# Changelog

What changed in each release, and — for any release that needs it — what a consumer has to do after updating.

**Which version am I on?** `project/workflow/.version` in your repository, written on every install. Apply the **Migrating** steps of every entry newer than it, oldest first.

Versioning follows [SemVer](https://semver.org/). While the package is below 1.0:

- **minor** (`0.x.0`): a consumer must act after updating — a spec rule changed, a new gate needs wiring, citations need rewriting, a file was removed or renamed. The entry always carries a **Migrating** section.
- **patch** (`0.x.y`): drop-in. Updating is the whole migration.

## [0.2.1] — Unreleased

Drop-in.

### Added

- `project/workflow/.version`, written by `install.sh` (version plus the package commit, `+dirty` for an uncommitted checkout) and by `/workflow-pipeline-init` (version). It tells you which entries below you have not applied yet.
- This changelog, and a `test.sh` check that every version field in the package agrees with the newest entry here.

### Changed

- `/what-next` treats an over-full `active/` as a smell, not only a stale one.

## [0.2.0] — 2026-09-01

Baseline: the first tagged release. Nothing earlier is recorded here.
