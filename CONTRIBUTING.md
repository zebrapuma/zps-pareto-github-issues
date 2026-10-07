# Contributing

Thanks for your interest in `zps-pareto`. Issues and pull requests are welcome.

## Reporting a bug or proposing a feature

Use the issue templates: **Bug report** or **Feature request**. Include your Claude Code version (`claude --version`), your OS and, for a bug, the exact command and output.

## Pull requests

1. Fork the repository and create a branch from `main`.
2. Keep changes focused: one topic per pull request.
3. Check locally before pushing:
   ```bash
   claude plugin validate --strict .
   shellcheck -x scripts/*.sh tests/run.sh
   bash tests/run.sh        # needs gojq (or JQ=jq)
   ```
4. Update `CHANGELOG.md` under an `[Unreleased]` section.
5. Describe what changes for the user and how you tested it.

The same checks run in CI on every push and pull request.

## Design principles

Any change must keep these guarantees:

- **Claude never invents business value**: missing information leads to a question.
- **Nothing changes without confirmation**: issues, labels, files and commits are shown first.
- **Setup is non-destructive and idempotent**: existing content and labels are never overwritten silently.
- **Scripts are read-only** except `setup-labels.sh`, which only creates missing labels.
- Scripts run on bash 3.2+ (macOS) and Git Bash (Windows).

## Style

- Skills and documentation in English; `README.fr.md` mirrors `README.md`.
- Plain ASCII hyphens (`-`) only: no em or en dashes (CI checks it).

## Releases

SemVer. A release is: `version` in `.claude-plugin/plugin.json`, a `CHANGELOG.md` entry, a `zps-pareto--vX.Y.Z` tag created with `claude plugin tag --push`, and a GitHub Release on that tag. The plugin `name` (`zps-pareto`) never changes: renaming it would break existing installations.
