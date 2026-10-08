---
name: triage
description: Score and prioritize open GitHub issues with the Pareto rules (Value × Impact × Reach / Effort), for one repository or a whole portfolio of repositories, highlight the vital few and propose today's order of work. Use when the user wants to prioritize, groom or review the backlog.
argument-hint: "[owner/repo | all] [full] [extra requests to include]"
allowed-tools: Bash(bash *) Bash(gh issue list *) Bash(gh issue view *) Bash(gh issue edit *) Bash(gh issue comment *) Read Grep Glob
---

# Triage the backlog

Reply in the user's language.

## Scope and scoring rules

!`bash "${CLAUDE_PLUGIN_ROOT}/scripts/pareto-context.sh" 2>&1 || cat "${CLAUDE_PLUGIN_ROOT}/templates/pareto.md"`

## Open issues and their Pareto status

!`bash "${CLAUDE_PLUGIN_ROOT}/scripts/list-issues.sh" 2>&1 || echo "(GitHub CLI unavailable: run 'gh auth login' in a GitHub repository)"`

## Arguments

$ARGUMENTS

## Steps

1. **Set the scope** from the arguments:
   - `owner/repo`: re-score that repository only; `all`: the whole portfolio.
   - No repository given: the whole portfolio from the hub, the current repository otherwise.
   - `full`: re-score every issue in scope. Otherwise re-score only issues whose status is `new` or `stale`, and keep the recorded `score` of the others.
   - Anything else in the arguments is an extra request to score.
   If more than about 40 issues need scoring, propose batches (one repository at a time, or the most recently updated first) before reading them.
2. **Score** each issue to re-score: read it (`gh issue view <n> --repo <owner/repo> --comments`) and, when the code is available locally, the relevant code to estimate effort.
   Never invent a value: if business value cannot be inferred, write `?` and list the question to ask.
3. If extra requests are provided, score them too and offer to capture them with `/zps-pareto:intake`.
4. **Compute the classes** over every scored issue listed above (the whole portfolio when one exists, even if only one repository was re-scored), so there is a single `P0` threshold. State that threshold.
   Each issue gets one class (`P0`, `P1`, `P2`) and the `quick-win` tag when its rule applies.
   An issue whose score did not change can still change class because the threshold moved: include it.
5. **Show a legend, then a table.** Before the table, a short legend for a reader who does not know the method, one line each, with the scales and thresholds taken from the scoring rules printed above (`.claude/pareto.md`, or the portfolio hub it names), never hard-coded here: a hub may have changed them.
   - `V` value: business value. `I` impact: how directly it helps or blocks. `R` reach: how many people it touches. `E` effort.
   - `Score` = V x I x R / E.
   - `Class`: `P0` vital few, `P1`, `P2`.
   - `Quick win`: the threshold is the Quick win line of the rules printed above.
   - `Change`: old class -> new class.

   Then the table, sorted by score, descending:
   `Repo#n | Title | V | I | R | E | Score | Class | Quick win | Change | One-line rationale`
   (`=` in V/I/R/E for a recorded score that was not re-scored; `Change` shows old -> new class.)
6. Point out the ~20 % of issues that carry ~80 % of the value.
7. **Propose today's order of work**: quick wins first, then P0, respecting dependencies, including `Blocked by owner/repo#n` across repositories.
8. List open questions (issues that could not be scored).
9. **Wait for confirmation**, then for each confirmed issue whose class, tag or score changed, labels first and comment last (the comment marks the issue as freshly scored).
   Use the label names of the issue's repository, from the `# labels` line printed for it above:
   - `gh issue edit <n> --repo <owner/repo> --remove-label "<old class label>" --add-label "<new class label>"` (omit `--remove-label` when there was no class; add or remove the quick-win label the same way)
   - `gh issue comment <n> --repo <owner/repo> --body "Pareto score: <score> -> <class>[ + quick-win] (V<v> x I<i> x R<r> / E<e>, <date>). <rationale>"`
   Keep that first line format exactly: it is how the next triage knows the issue is up to date.
