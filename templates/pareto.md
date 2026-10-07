# Pareto scoring rules for this repository

<!-- Created by the `zps-pareto` plugin (/zps-pareto:setup). Edit freely: the plugin reads this file on every run. -->

## Criteria

Inspired by RICE and WSJF: value delivered, weighted by how many it reaches, divided by the effort it costs.

| Criterion | Scale | Meaning |
|---|---|---|
| **Value (V)** | 1-5 | Business value. 5 = revenue, orders, invoicing, stock, legal. 1 = nice to have. |
| **Impact (I)** | 1-5 | Directness. 5 = someone or production is blocked today. 1 = comfort. |
| **Reach (R)** | 1-3 | 3 = whole company / all flows. 2 = one team or process. 1 = one person. |
| **Effort (E)** | 1-5 | 1 = < 1 h · 2 = half a day · 3 = 1 day · 4 = 2-3 days · 5 = > 3 days. Estimated after reading the relevant code. |

**Score = (V × I × R) / E**, rounded to one decimal.

## Classes

Every scored issue gets exactly one priority class, and possibly the `quick-win` tag on top of it.

| Class | Rule | What to do |
|---|---|---|
| `P0` | Top 20 % of open-issue scores, across the whole portfolio when one is defined | The vital few: work on these first. |
| `P1` | Score ≥ 3, not P0 | Next in line. |
| `P2` | Score < 3 | Do not start without explicit approval. |
| `quick-win` (tag) | Score ≥ 15 **and** E ≤ 2 | Do it now, whatever its class. |

Here P0 means "most valuable", not "production is down": incidents keep following your usual process.

## Labels

GitHub label used for each class in this repository. Already have priority labels (for example
`priority:high`, `priority:medium`, `priority:low`)? Put them here instead of creating new ones.
In a portfolio, the hub's table is the default and a member can override it in its own file.

| Class | Label |
|---|---|
| P0 | pareto:P0 |
| P1 | pareto:P1 |
| P2 | pareto:P2 |
| quick-win | pareto:quick-win |
| request | pareto:request |

## What "value" means here

<!-- Make this concrete for your context: it is what makes scoring reliable. Examples: -->
- V5: anything touching orders, invoicing, stock accuracy, or a contractual deadline.
- V4: reporting used by management for decisions.
- V3: productivity of a whole team.
- V2: productivity of one person.
- V1: cosmetic, internal comfort.

## Portfolio

<!-- Optional. Fill this table only in the repository that acts as the portfolio hub: the plugin
     then triages every listed repository together, with a single P0 threshold. Each member
     repository points back here with a "Portfolio hub: owner/repo" line in its own
     .claude/pareto.md (/zps-pareto:setup writes it). Leave the table empty for a standalone
     repository. For a shared library, Reach usually reflects how many repositories depend on it. -->

| Repo | Role | Value notes |
|---|---|---|

## Working rules

- Every request becomes a GitHub issue **before** any work starts.
- If information is missing to score a request, ask, never invent a value.
- Do not start `P1` or `P2` work while `quick-win` or `P0` issues are open, unless told otherwise.
- Never change labels without showing the scoring table and getting confirmation.
- Record each score as an issue comment whose first line reads
  `Pareto score: <score> -> <class>[ + quick-win] (V<v> x I<i> x R<r> / E<e>, <date>)`.
  The plugin reads it back to skip issues that have not changed since.
- Across repositories, link issues as `owner/repo#123` and state blockers as `Blocked by owner/repo#123`.
