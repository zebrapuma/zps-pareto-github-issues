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

!`bash "${CLAUDE_PLUGIN_ROOT}/scripts/list-issues.sh" --what 2>&1 || echo "(GitHub CLI unavailable: run 'gh auth login' in a GitHub repository)"`

Line format: `owner/repo#n | status | read | class | tag | score | what | updated | title`.
- `status`: `new` (never scored), `stale` (changed since its last score, ignoring what the triage itself did: class labels and the `Pareto score:` comment), `scored` (still valid).
- `read`: how much of the issue must be read to score it again. `full` (new, never noted, or edited since its reading note), `partial` (its reading note plus the comments after the note's last one), `none` (nothing).
- `what`: the one-line "What it is" kept in the issue's reading note, `-` when it has none.

## Arguments

$ARGUMENTS

## Steps

1. **Set the scope** from the arguments:
   - `owner/repo`: re-score that repository only; `all`: the whole portfolio.
   - No repository given: the whole portfolio from the hub, the current repository otherwise.
   - `full`: re-score every issue in scope. Otherwise re-score only issues whose status is `new` or `stale`, and keep the recorded `score` of the others.
   - `reread`: ignore the reading notes, so every issue to re-score is read in full (use it when the rules changed, or when a note looks wrong).
   - Anything else in the arguments is an extra request to score.
   If more than about 40 issues need scoring, propose batches (one repository at a time, or the most recently updated first) before reading them.
2. **Score** each issue to re-score. Read it with `bash "${CLAUDE_PLUGIN_ROOT}/scripts/read-issue.sh" [--full] <owner/repo> <n>` (add `--full` with `reread`), never with `gh issue view`: the script prints only what is new.
   - `# read: full`: the body and every comment. Read it all.
   - `# read: partial`: the reading note (`# note:`, with the factors, the summary and the "What it is" of the last score) and the comments written after it. Do not read the issue again beyond that: take the note as what was understood, and change a factor only for what the new comments change.
   - The script ends with `# cursor: <id>@<edit>@<updatedAt>`: keep it, unchanged, for step 9. It marks what you read, so a comment that arrives while you work is read next time.
   - When the code is available locally, read the relevant code to estimate effort (full reads, or when the new comments change the effort).
   Never invent a value: if business value cannot be inferred, write `?` and list the question to ask.
   For each issue also write its **What it is**: 4 to 8 words, plain language, the business problem as the person who lives it would say it. No issue number, no code name, no jargon, not the title copied. And a **summary** in 3 short lines (what, why it matters, what is decided or open), for the note.
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
   `Repo#n | Title | What it is | V | I | R | E | Score | Class | Quick win | Change | One-line rationale`
   - `What it is` comes before every number: the 4 to 8 words written in step 2, or, for an issue that was not re-scored, the `what` printed above. When an issue that was not re-scored has `-` there (no note yet), write it from its title, without reading the issue, and mark it with `~`.
   - `=` in V/I/R/E for a recorded score that was not re-scored; `Change` shows old -> new class.
   Under the table, one line saying how much was read: `Read in full: <a>, in part: <b>, not at all: <c>`.
   - `a` and `b`: the issues read in step 2 whose `# read:` line said `full` or `partial`.
   - `c`: the other issues of the scope, whose score was kept without opening them.
   - Add how many of the issues you scored have no reading note yet (they were read in full and are noted in step 10).
6. Point out the ~20 % of issues that carry ~80 % of the value.
7. **Propose today's order of work**: quick wins first, then P0, respecting dependencies, including `Blocked by owner/repo#n` across repositories.
8. List open questions (issues that could not be scored).
9. **Wait for confirmation**, then for each confirmed issue whose class, tag or score changed, labels first and comment last (the comment marks the issue as freshly scored).
   Use the label names of the issue's repository, from the `# labels` line printed for it above:
   - `gh issue edit <n> --repo <owner/repo> --remove-label "<old class label>" --add-label "<new class label>"` (omit `--remove-label` when there was no class; add or remove the quick-win label the same way)
   - `gh issue comment <n> --repo <owner/repo> --body "Pareto score: <score> -> <class>[ + quick-win] (V<v> x I<i> x R<r> / E<e>, <date>). <rationale>"`
   Keep that first line format exactly: it is how the next triage knows the issue is up to date.
10. **Record the reading notes**, in the same confirmation, for every issue read in step 2, including those whose score and class did not change (otherwise they come back `stale`). One line per issue on stdin of `bash "${CLAUDE_PLUGIN_ROOT}/scripts/record-note.sh"`:
    `owner/repo#n | <cursor of step 2> | V | I | R | E | score | What it is | summary in 3 short lines separated by " / "`
    The notes are the file `.claude/pareto-notes/<owner>-<repo>.jsonl` of the hub: tell the user it was changed and offer to commit it with the usual flow (never commit it silently). The script writes only from the hub (or a standalone repository); from a member repository it prints the lines and exits with status 2: give them to the user to put in the hub.
    The notes hold what was understood, never a guess: if a factor is `?`, the issue is not scored and has no note.
