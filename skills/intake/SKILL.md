---
name: intake
description: Turn a raw request (email, chat message, call notes) into a scored GitHub issue so nothing gets lost, in the right repository when several are managed as a portfolio. Use when the user pastes or describes a new request, bug report or feature ask that is not yet tracked.
argument-hint: "<pasted email, message or call notes>"
allowed-tools: Bash(bash *) Bash(gh issue list *) Bash(gh issue view *) Bash(gh issue create *) Bash(gh issue comment *) Read Grep Glob
---

# Intake a request

Reply in the user's language.

## Scope and scoring rules

!`bash "${CLAUDE_PLUGIN_ROOT}/scripts/pareto-context.sh" 2>&1 || cat "${CLAUDE_PLUGIN_ROOT}/templates/pareto.md"`

## Raw request

$ARGUMENTS

## Steps

1. **Extract** the requester, the real need (the problem, not the proposed solution), context, acceptance criteria and deadline.
   If the request contains several distinct needs, split it into several issues.
2. **Choose the target repository.**
   - Single repository: the current one.
   - Portfolio: match the need against each repository's role. Keep the current repository when it fits; if another one fits better, or several could, propose one and ask.
   - A need spanning several repositories becomes one issue per repository, cross-linked with `owner/repo#n`; the dependent issues say `Blocked by owner/repo#n`.
3. **Check duplicates** in each target repository: `gh issue list --repo <owner/repo> --state open --search "<keywords>"`.
   If a matching issue exists, propose to comment on it instead of creating a new one.
4. **Estimate effort** by reading the relevant code when it is available locally (otherwise say the estimate comes from the description only), then **score** with the rules above.
   If information is missing to score, ask before creating anything.
   Class: `P0`, `P1` or `P2`, plus the `quick-win` tag when its rule applies. To decide `P0`, compare with the lowest
   score currently in class `P0`: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/list-issues.sh" --classes P0 <owner/repo>`
   (add the other repositories of the portfolio). With no `P0` yet, use `P1` and suggest `/zps-pareto:triage`.
5. **Show the draft** (repository, title, body, score, class) and wait for confirmation.
6. **Create** the issue after confirmation:
   `gh issue create --repo <owner/repo> --title "<title>" --label "<request label>,<class label>[,<quick-win label>]" --body "<body>"`
   Use the label names of the target repository: the `# labels` line printed by `list-issues.sh` for it.
   Body format:
   ```
   **Requester:** …
   **Received:** <date> (channel: email / chat / call)
   **Need:** …
   **Acceptance criteria:** …
   **Deadline:** …

   **Original request:**
   > …
   ```
   If the labels do not exist in that repository, say so and suggest `/zps-pareto:setup`.
7. **Record the score** as the issue's first comment, in the exact format `/zps-pareto:triage` reads back:
   `gh issue comment <n> --repo <owner/repo> --body "Pareto score: <score> -> <class>[ + quick-win] (V<v> x I<i> x R<r> / E<e>, <date>). <one-line rationale>"`
8. If the issue is `P0` or tagged `quick-win`, say so and offer to start right away (in the current repository only; otherwise name the repository to open).
