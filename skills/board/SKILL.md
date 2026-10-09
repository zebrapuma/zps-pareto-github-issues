---
name: board
description: Show the Pareto priority board, read-only. Explains V, I, R, E, the score, the classes and the quick-win tag, then lists every scored issue sorted by score with its factors, the current P0 threshold, the unscored issues and the suggested order of work. Use when the user wants to see, understand or share the ranking without changing anything.
argument-hint: "[owner/repo | all] [P0 | P1 | P2 | quick-win]"
allowed-tools: Bash(bash *) Bash(gh issue list *) Bash(gh issue view *) Read Grep Glob
---

# Pareto board (read-only)

Reply in the user's language. This skill never writes: no label, no comment, no file. To score or re-score, point to `/zps-pareto:triage`.

## Scope and scoring rules

!`bash "${CLAUDE_PLUGIN_ROOT}/scripts/pareto-context.sh" 2>&1 || cat "${CLAUDE_PLUGIN_ROOT}/templates/pareto.md"`

## Open issues, with the factors of their last score

!`bash "${CLAUDE_PLUGIN_ROOT}/scripts/list-issues.sh" --factors 2>&1 || echo "(GitHub CLI unavailable: run 'gh auth login' in a GitHub repository)"`

Line format: `owner/repo#n | status | read | class | tag | score | V | I | R | E | updated | title`. `read` (`full`, `partial`, `none`) says how much of the issue triage would have to read again: the board ignores it. A factor is `-` when the last score comment does not carry it (an old or hand-written comment).

## Arguments

$ARGUMENTS

## Steps

1. **Set the scope and the filter** from the arguments:
   - `owner/repo`: that repository only; `all`: the whole portfolio. No repository: the whole portfolio from the hub, the current repository otherwise.
   - `P0`, `P1`, `P2` or `quick-win`: show only that class or tag in the table. The legend, the threshold and the counts stay global.
2. **Legend first**, before anything else, for a reader who does not know the method. Take the scales and thresholds from the scoring rules printed above (`.claude/pareto.md`, or the portfolio hub it names), never from memory or from the defaults in this file: a hub may have changed them. One line each:
   - `V` value: business value of the issue.
   - `I` impact: how directly it helps or blocks (someone blocked today is the top of the scale).
   - `R` reach: how many people or customers it touches.
   - `E` effort: how much work it takes (more is costlier).
   - `Score` = V x I x R / E.
   - `Class`: `P0` vital few (the top of the scores), `P1`, `P2`, with the current rules.
   - `Quick win`: the threshold is the Quick win line of the rules printed above (hub rules when they apply): do it now, whatever the class.
   Give the real scale range of each factor, as written in the rules.
3. **State the current P0 threshold**: global to the portfolio, as in `/zps-pareto:triage`, even when an `owner/repo` argument limits the table (compute it from the issues of every repository listed above): the lowest score among the issues classed `P0`, and how many issues are classed `P0`. None: say so. The class is read from the labels, so for `stale` issues it may be outdated: say so when a `stale` issue is counted.
4. **Table** of the issues with a numeric score (status `scored` or `stale`), sorted by score, descending, after the filter:
   `Repo#n | Title | V | I | R | E | Score | Class | Quick win | Status`
   - Use the factors printed above; do not re-read the issues to recompute them.
   - Link each issue as `owner/repo#n`.
   - Mark `stale` issues (changed since their last score): their score may be outdated.
5. **Unscored issues** ("not scored"), counted apart and never in the table: status `new`, and every issue whose score is `-`, including a `stale` issue that has a class label but no score comment. Give the count per repository and name a few (the most recently updated). Suggest `/zps-pareto:triage` for them.
6. **Suggested order of work**: quick wins first (highest score first), then `P0`. Skip issues blocked by another open issue when the title or a previous read shows it; do not fetch bodies just to check. Five lines at most.
7. Close with one line: the board is read-only, `/zps-pareto:triage` changes scores and labels, `/zps-pareto:next` picks one issue and plans it.
