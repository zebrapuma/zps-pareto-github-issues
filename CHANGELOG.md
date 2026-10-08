# Changelog

All notable changes to this plugin are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Fixed
- `templates/CLAUDE.block.md` no longer tells Claude to use `Fixes #123`: issues are referenced with `Refs #123` and never closed before the acceptance criteria are verified (#9).
- `/zps-pareto:setup` step 4 writes the CLAUDE.md block to `.claude/CLAUDE.md` when the repository is itself a plugin (`.claude-plugin/plugin.json` at the root), because a root `CLAUDE.md` makes `claude plugin validate --strict` fail (#9).

## [1.0.0] - 2026-10-07

### Added
- `/zps-pareto:intake`: turns a raw request (email, chat, call notes) into a scored GitHub issue, with duplicate detection, multi-need splitting and, in a portfolio, routing to the right repository.
- `/zps-pareto:triage`: scores open issues with Value × Impact × Reach / Effort, highlights the vital few and proposes the order of work. Incremental by default (only new or changed issues are re-scored), `full` to re-score everything.
- `/zps-pareto:next`: picks the one issue to work on now, with a short plan.
- `/zps-pareto:setup`: non-destructive, idempotent setup of a repository as standalone, portfolio hub or portfolio member: scoring rules, CLAUDE.md block, issue template, labels, optional Task Master.
- Portfolio mode: one hub repository lists several repositories; they are triaged together with a single P0 threshold, and cross-repository dependencies (`Blocked by owner/repo#n`) are respected.
- Three priority classes (`P0`, `P1`, `P2`) plus a `quick-win` tag, with namespaced default labels (`pareto:P0`, ...). A `## Labels` table maps them to a repository's existing priority labels instead of duplicating them.
- Scripts `pareto-context.sh`, `list-issues.sh` (one GraphQL call per 100 issues) and `setup-labels.sh`.

[1.0.0]: https://github.com/zebrapuma/zps-pareto-github-issues/releases/tag/zps-pareto--v1.0.0
