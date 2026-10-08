---
name: setup
description: Set up the current repository for Pareto request management (scoring rules, optional portfolio of repositories, CLAUDE.md block, issue template, GitHub labels, optional Task Master). Run once per repository.
disable-model-invocation: true
allowed-tools: Bash(git rev-parse *) Bash(git status *) Bash(gh repo view *) Bash(gh api *) Bash(gh label list *) Bash(gh label create *) Bash(bash *) Bash(mkdir *) Bash(cp *) Read Write Edit
---

# Set up this repository

Reply in the user's language. Show ✅ / ⚠️ / ❌ per step. Every step must be idempotent and must never overwrite user content without asking.

Plugin files are in `${CLAUDE_PLUGIN_ROOT}`.

## 1. Checks
- `git rev-parse --show-toplevel`: work from the repository root. Not a git repo: stop and say so.
- `gh repo view --json nameWithOwner`: note the GitHub repo. No GitHub remote or `gh` not authenticated: warn and skip step 6.

## 2. Role of this repository
Ask which one applies (an existing `.claude/pareto.md` usually tells: a `## Portfolio` table means hub, a `Portfolio hub:` line means member):
- **Standalone** (default): this repository is prioritized on its own.
- **Portfolio hub**: this repository tracks priorities for several repositories (it may hold no code). All of them are triaged together, with a single P0 threshold.
- **Portfolio member**: another repository is the hub.

## 3. Scoring rules: `.claude/pareto.md`
- **Standalone or hub**:
  - Missing: copy `${CLAUDE_PLUGIN_ROOT}/templates/pareto.md` to `.claude/pareto.md`.
  - Present: leave it untouched (it is the user's configuration), except for the portfolio table below, shown as a diff first.
  - Ask the user to describe in one sentence what "high business value" means here, and update the "What value means here" section accordingly.
- **Hub only**: ask for the repositories to include (`owner/repo`, one-line role, value notes). Check access to each with `gh repo view <owner/repo> --json nameWithOwner`, then fill the `## Portfolio` table, the hub included if it holds issues.
- **Member**:
  - Ask for the hub (`owner/repo`) and read its rules: `gh api repos/<hub>/contents/.claude/pareto.md -H "Accept: application/vnd.github.raw"`.
  - Missing or unreadable: stop this step and suggest running the setup in the hub first.
  - Hub found but this repository is not in its `## Portfolio` table: warn, and tell the user to add it in the hub.
  - Copy `${CLAUDE_PLUGIN_ROOT}/templates/pareto.member.md` to `.claude/pareto.md` with `OWNER/REPO` replaced by the hub (existing file: show the diff and ask).

## 4. CLAUDE.md block
- Content: `${CLAUDE_PLUGIN_ROOT}/templates/CLAUDE.block.md` (delimited by `<!-- pareto:start -->` / `<!-- pareto:end -->`).
- **Target file.** `claude plugin validate --strict` rejects a `CLAUDE.md` at the root of a plugin repository, so the root file would fail CI. When `.claude-plugin/plugin.json` or `.claude-plugin/marketplace.json` exists at the repository root (the repository is itself a plugin or a plugin marketplace), target `.claude/CLAUDE.md` instead, and say why. Otherwise target `CLAUDE.md` at the root.
- Target missing: create it with the block (create `.claude/` first when needed).
- Present with markers: replace only the block between markers (`<!-- pareto:start -->` to `<!-- pareto:end -->`), so a block written by an older plugin version is updated, for example a `Fixes #123` instruction.
- Present without markers: append the block at the end; touch nothing else.
- In a plugin repository, if a root `CLAUDE.md` already contains the markers, warn that CI will reject it and offer to move the block to `.claude/CLAUDE.md`; never delete the file without asking.

## 5. Issue template
- Skip on a hub that holds no issues.
- Copy `${CLAUDE_PLUGIN_ROOT}/templates/.github/ISSUE_TEMPLATE/request.yml` to `.github/ISSUE_TEMPLATE/request.yml`, with `pareto:request` replaced by this repository's request label if the `## Labels` table maps it to another name.
- Already exists and differs: show the diff and ask.

## 6. GitHub labels
- **First, existing priority labels.** List them (`gh label list --repo <owner/repo>`). If the repository already uses a priority scheme (for example `priority:high`, `priority:medium`, `priority:low`), propose to map it in the `## Labels` table of its `.claude/pareto.md` (of the hub, when every repository shares the same scheme) instead of creating a second set of priority labels. Never rename, recolor or delete an existing label.
- This repository: run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/setup-labels.sh"` from the repository root. It creates only the missing labels of the table, so a mapped existing label is simply reused.
- **Hub**: for each repository of the portfolio, ask first, one repository at a time, then run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/setup-labels.sh" <owner/repo>`.

## 7. Task Master (optional)
- Ask whether the user wants Task Master for breaking down large features into tasks.
- If yes:
  - Not registered yet (`claude mcp list`): give the exact command for the user to run:
    `claude mcp add taskmaster-ai --scope user -- npx -y task-master-ai`
  - Then, after restart, initialize it in this repo and set the main model to `claude-code/sonnet` in `.taskmaster/config.json` (no API key needed).

## 8. Wrap-up
- List created or modified files (`git status --short`).
- Offer a commit `chore: set up zps-pareto request management`, and commit only after approval.
- Hub: remind the user to run `/zps-pareto:setup` in each member repository, as a member, for its CLAUDE.md block and issue template.
- Remind: `/zps-pareto:intake` to capture a request, `/zps-pareto:triage` to prioritize, `/zps-pareto:next` to know what to do now.
