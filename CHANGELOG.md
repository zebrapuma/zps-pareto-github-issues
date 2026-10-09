# Changelog

All notable changes to this plugin are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [1.1.0] - 2026-10-09

### Added
- Reading notes: at each score, `/zps-pareto:triage` keeps a note per issue in the hub (`.claude/pareto-notes/<owner>-<repo>.jsonl`): 3-line summary, "What it is", V, I, R, E, date, last comment read, last edit read, `updatedAt` read. A stale issue is read again from its note and the comments written after the note's last one (`scripts/read-issue.sh`); notes are written by `scripts/record-note.sh` after confirmation, from the hub only (#14).
- `triage` says how many issues were read in full, in part, or not at all; `triage reread` ignores the notes (#14).
- A "What it is" column (4 to 8 plain words on the business problem) before the numbers in the table of `triage`, and a short candidates table in `next` (#14).
- `list-issues.sh --what` adds the "What it is" of the note; `--no-notes` ignores the notes (#14).
- `/zps-pareto:board`: read-only board with a legend (V, I, R, E, score, classes, quick win), the current P0 threshold, the scored issues sorted by score with their factors, the unscored issues counted apart and the suggested order. Optional `owner/repo | all` and `P0 | P1 | P2 | quick-win` arguments (#11).
- `list-issues.sh --factors` adds the V, I, R, E columns read from the last score comment. The default output is unchanged (#11).

### Changed
- Every script moves to the git root before reading `.claude/pareto.md`, so `record-note.sh` run from a sub-folder of a member repository still refuses to write (#14).
- `list-issues.sh` and `read-issue.sh` read the same comment window (`COMMENTS_WINDOW` in `scripts/lib.sh`, 100), so the cursor of a note and the cursor of the listing agree on long threads (#14).
- Comment ids past 2^31 are written and compared as digit strings, never through a numeric conversion; leading zeros are rejected in identifiers, cursors and factors (#14).
- A member repository that cannot read the hub's notes through the API says why (`# warning: reading notes unreadable (...)`) unless it is a plain 404 (#14).
- `read-issue.sh` reports the first line of gh's answer when it fails, on stderr (#14).
- `list-issues.sh` output has a new `read` column after the status (`full`, `partial` or `none`). With a reading note, what triage did itself (class labels, the `Pareto score:` comment) no longer makes an issue `stale`; a new comment, an edit or another change after the note does (#14).
- `/zps-pareto:triage` shows a legend before its table, with the scales taken from the repository's scoring rules (#11).

### Fixed
- `templates/CLAUDE.block.md` no longer tells Claude to use `Fixes #123`: issues are referenced with `Refs #123` and never closed before the acceptance criteria are verified (#9).
- `/zps-pareto:setup` step 4 writes the CLAUDE.md block to `.claude/CLAUDE.md` when the repository is itself a plugin (`.claude-plugin/plugin.json` or `.claude-plugin/marketplace.json` at the root), because a root `CLAUDE.md` makes `claude plugin validate --strict` fail (#9).

## [1.0.0] - 2026-10-07

### Added
- `/zps-pareto:intake`: turns a raw request (email, chat, call notes) into a scored GitHub issue, with duplicate detection, multi-need splitting and, in a portfolio, routing to the right repository.
- `/zps-pareto:triage`: scores open issues with Value × Impact × Reach / Effort, highlights the vital few and proposes the order of work. Incremental by default (only new or changed issues are re-scored), `full` to re-score everything.
- `/zps-pareto:next`: picks the one issue to work on now, with a short plan.
- `/zps-pareto:setup`: non-destructive, idempotent setup of a repository as standalone, portfolio hub or portfolio member: scoring rules, CLAUDE.md block, issue template, labels, optional Task Master.
- Portfolio mode: one hub repository lists several repositories; they are triaged together with a single P0 threshold, and cross-repository dependencies (`Blocked by owner/repo#n`) are respected.
- Three priority classes (`P0`, `P1`, `P2`) plus a `quick-win` tag, with namespaced default labels (`pareto:P0`, ...). A `## Labels` table maps them to a repository's existing priority labels instead of duplicating them.
- Scripts `pareto-context.sh`, `list-issues.sh` (one GraphQL call per 100 issues) and `setup-labels.sh`.

[1.1.0]: https://github.com/zebrapuma/zps-pareto-github-issues/releases/tag/zps-pareto--v1.1.0
[1.0.0]: https://github.com/zebrapuma/zps-pareto-github-issues/releases/tag/zps-pareto--v1.0.0
