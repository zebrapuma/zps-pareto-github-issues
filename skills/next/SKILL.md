---
name: next
description: Tell the user which issue to work on right now, based on Pareto classes (quick wins, then P0, then P1), in the current repository or across a portfolio of repositories. Use when the user asks what to do next, what to work on, or where to start.
argument-hint: "[owner/repo | all]"
allowed-tools: Bash(bash *) Bash(gh issue list *) Bash(gh issue view *) Read Grep Glob
---

# What to work on next

Reply in the user's language.

## Scope

!`bash "${CLAUDE_PLUGIN_ROOT}/scripts/pareto-context.sh" --scope-only 2>&1 || echo "(scope unavailable)"`

## Prioritized open issues

!`bash "${CLAUDE_PLUGIN_ROOT}/scripts/list-issues.sh" --what --classes quick-win,P0,P1 2>&1 || echo "(GitHub CLI unavailable: run 'gh auth login' in a GitHub repository)"`

Line format: `owner/repo#n | status | read | class | tag | score | what | updated | title`. `what` is the one-line "What it is" kept in the issue's reading note (`-` when it has none).

## Arguments

$ARGUMENTS

## Steps

1. **Set the scope**: `owner/repo` or `all` from the arguments; otherwise the whole portfolio from the hub, the current repository elsewhere.
   When the scope is the current repository and a higher class waits elsewhere in the portfolio, mention it in one line.
2. **Pick one** issue: the highest-score issue tagged `quick-win`, otherwise the highest-score `P0`, otherwise the highest-score `P1`.
   Skip issues blocked by another open issue (check their body and comments, including `Blocked by owner/repo#n`).
   If the pick is `stale`, say its score may be outdated.
   **Show the candidates** as a short table, the pick first, then up to four more in order (quick wins, then P0, then P1):
   `Repo#n | What it is | Score | Class | Status`
   `What it is` is 4 to 8 words in plain language on the business problem, before the score: the `what` printed above, or, when it is `-`, written from the title without reading the issue and marked `~`. Never a number or an issue number alone.
3. Read it (`gh issue view <n> --repo <owner/repo>`) and summarize in 3 lines: what, why it matters, acceptance criteria.
4. Propose a short plan (3 to 5 steps). If the issue belongs to the current repository, offer to start; otherwise name the repository to open and stop at the plan.
5. If no issue has a Pareto class, say so and suggest running `/zps-pareto:triage`.
