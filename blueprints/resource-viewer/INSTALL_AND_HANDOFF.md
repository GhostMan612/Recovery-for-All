# Overlay ZIP — Installation and handoff

**Historical instructions:** this package has already been applied to the current working tree, and the viewer implementation is present. Do not re-extract the archive as part of the current implementation task; these steps describe the original 2026-10-09 overlay installation only.

## Extract location

Extract the ZIP **into the LOCAL ROOT** of your `Recovery-for-All` checkout, the directory containing `README.md`, `AGENTS.md`, `pubspec.yaml`, `lib/` and `blueprints/`. ZIP paths start at repository root; **there is no enclosing versioned directory**, so Windows Extract All must target the repo root (not a new nested directory).

## What will be overwritten

- `README.md` — original text preserved with one added entry under Documentation Map and a short planned-feature section (read/inspect the diff before committing).

## Newly added paths

- `blueprints/README.md`
- `blueprints/resource-viewer/` (complete architecture and phase specification, AGENTS, PDF manifest, acceptance lists)
- `lib/core/resources/AGENTS.md` (directory scaffold)
- `lib/screens/resource_viewer/AGENTS.md` (directory scaffold)
- `test/resource_viewer/AGENTS.md` (directory scaffold)

**No existing Dart, generated files, Gradle, manifest, keystore, Firebase rules, test files, handoff state, or existing blueprint documents are overwritten by this package.** The only file with intended overwrite is `README.md`. Back it up or review the diff if you have local edits; Windows extraction may prompt.

## Install (Windows Explorer)

1. Ensure the repository is the correct checkout and review `git status --short` for uncommitted work; make a local backup of any modified `README.md`.
2. Open ZIP; select **Extract All**. Destination: your repo root, e.g. `C:\Recovery-for-All` or wherever `pubspec.yaml` lives.
3. Confirm destination now has `blueprints\README.md`, `blueprints\resource-viewer\README.md`, `lib\core\resources\AGENTS.md` and `test\resource_viewer\AGENTS.md`.
4. In terminal at repo root inspect `git status --short` and `git diff -- README.md`; verify only intended additions before committing or authorizing code execution.
5. Give implementing coding agent: `Read blueprints/resource-viewer/README.md and root AGENTS.md; implement only authorized phases 00–06 in order; do not overwrite existing work; follow final-batch verification discipline.`

**Extraction alone adds no running viewer.** This ZIP is an actionable planning package and path scaffolding, not an APK update.

## Rollback (before committing)

Restore `README.md` from your own backed-up/staged version or Git if clean before install; delete only the newly added blueprint and scaffold paths listed in the package manifest. Do not run `git clean -fd` on the whole repo, and do not overwrite unrelated dirty files.
