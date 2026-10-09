# zps-pareto: never lose a request, always work on the vital few

A [Claude Code](https://code.claude.com) plugin by [ZebraPuma Services](https://zebrapuma.be). 🇫🇷 [Version française](README.fr.md)

Most backlogs fail the same way: requests arrive by email, chat and phone, some get lost, and the loudest ones get done first. `zps-pareto` turns Claude Code into a disciplined request manager built on the 80/20 rule:

- every request becomes a **GitHub issue**, the single source of truth;
- every issue is **scored**, and Claude works first on the few that carry most of the value;
- one repository or a **whole portfolio** of repositories, prioritized together.

## Install

```bash
claude plugin marketplace add zebrapuma/claude-plugins
claude plugin install zps-pareto@zebrapuma
```

Then, in each repository: `/zps-pareto:setup`.

### Updating

Third-party marketplaces do not update automatically. To get a new version:

```bash
claude plugin marketplace update zebrapuma
claude plugin update zps-pareto@zebrapuma
```

Or turn on auto-update for this marketplace once: `/plugin`, then **Marketplaces**, `zebrapuma`, **Enable auto-update**.

## Commands

| Command | What it does |
|---|---|
| `/zps-pareto:setup` | One-time setup of a repository (standalone, portfolio hub or portfolio member): scoring rules, CLAUDE.md block, issue template, GitHub labels, optional Task Master. |
| `/zps-pareto:intake <request>` | Turns a pasted email, message or call notes into a scored GitHub issue. Detects duplicates, splits multi-need requests, picks the right repository in a portfolio. |
| `/zps-pareto:triage [owner/repo \| all] [full]` | Scores open issues, highlights the ~20 % that carry ~80 % of the value, proposes today's order of work, updates labels after confirmation. Incremental: only new or changed issues are re-scored, unless you pass `full`, and a changed issue is read again from its reading note and its new comments only. The table starts with a plain-words "What it is" column and says how many issues were read in full, in part, or not at all. |
| `/zps-pareto:next [owner/repo \| all]` | Tells you the one issue to work on right now, with a short plan and a table of the next candidates in plain words ("What it is"). |
| `/zps-pareto:board [owner/repo \| all] [P0 \| P1 \| P2 \| quick-win]` | Read-only board: explains V, I, R, E, the score and the classes, then lists the scored issues by score with their factors, the current P0 threshold, the unscored issues and the suggested order. Writes nothing. |

## Scoring

```
Score = (Value × Impact × Reach) / Effort
```

Inspired by [RICE](https://www.intercom.com/blog/rice-simple-prioritization-for-product-managers/) and WSJF: value delivered, weighted by how many it reaches, divided by the effort it costs.

| Criterion | Scale |
|---|---|
| Value | 1-5: business value (revenue, orders, legal = 5) |
| Impact | 1-5: someone is blocked today = 5 |
| Reach | 1-3: whole company = 3 |
| Effort | 1-5: < 1 h = 1, > 3 days = 5 |

Each scored issue gets one priority class, and possibly the quick-win tag:

| Class | Default label | Rule |
|---|---|---|
| P0 | `pareto:P0` | Top 20 % of scores: the vital few |
| P1 | `pareto:P1` | Score ≥ 3 |
| P2 | `pareto:P2` | Score < 3: not without approval |
| quick-win (tag) | `pareto:quick-win` | Score ≥ 15 and Effort ≤ 2: do it now, whatever the class |

P0 here means "most valuable", not "production is down": incidents keep following your usual process.

**Already have priority labels?** Map them in the `## Labels` table of `.claude/pareto.md` (for example P0 = `priority:high`) instead of creating new ones. `/zps-pareto:setup` offers it when it finds an existing scheme.

Rules live in `.claude/pareto.md` and are yours to edit: define what "high value" means for your business and the scoring becomes reliable. Each score is recorded as an issue comment (`Pareto score: 18 -> P0 (...)`), which is how the next triage knows what has changed.

### Reading notes

A score says how much an issue is worth, not what was understood. At each score, triage also keeps a **reading note** per issue in the hub, in `.claude/pareto-notes/<owner>-<repo>.jsonl` (one JSON line per issue): a 3-line summary, a 4 to 8 word "What it is", V, I, R, E, the date, and what was read (last comment, last edit, `updatedAt`). The next triage then:

- reads a changed issue from its note and the comments written after the note's last one, not from scratch (`read: partial`); an issue edited since, or never noted, is read in full (`read: full`);
- does not call an issue changed because of what triage itself did (class labels, the `Pareto score:` comment);
- says how many issues it read in full, in part, or not at all.

The note is a normal file of the hub: review it, commit it. `triage reread` ignores the notes.

## Portfolio mode

When work spans several repositories (an engine, the apps built on it, a shared library), prioritizing each one separately gives you one P0 list per repository, and nothing tells you which matters most. Portfolio mode fixes that.

1. Pick a **hub** repository, typically your project-management repository. Run `/zps-pareto:setup` there and choose *portfolio hub*. It lists the repositories in `.claude/pareto.md`:

   ```markdown
   ## Portfolio

   | Repo | Role | Value notes |
   |---|---|---|
   | acme/engine     | Core product engine              | V5: anything blocking production |
   | acme/client-app | Client application on the engine | V5: orders and invoicing |
   | acme/shared-lib | Shared library                   | Reach = number of dependent repos |
   ```

2. In each listed repository, run `/zps-pareto:setup` and choose *portfolio member*. It writes a one-line pointer to the hub.

Then:

- `triage` from the hub ranks **all** open issues in one table, with a **single P0 threshold**, and respects cross-repository blockers (`Blocked by acme/engine#42`);
- `intake` proposes the right repository from each one's role, and splits a cross-repository need into linked issues;
- `next` picks one issue across the portfolio (from the hub) or in the current repository (from a member, mentioning anything more urgent elsewhere).

Labels stay per repository (a GitHub constraint): the hub creates them in each repository after asking, one at a time.

## Principles

- **GitHub issues are the single source of truth.** Nothing is tracked only in a chat.
- **Claude never invents business value.** Missing information means a question, not a guess.
- **Nothing changes without your confirmation**: issues, labels and commits are always shown first.
- **Non-destructive setup**: existing CLAUDE.md content, templates and labels are preserved.
- **Cheap on large backlogs**: issues are read with one GraphQL call per 100, and triage only re-scores what changed.

## Requirements

- [Claude Code](https://code.claude.com)
- [GitHub CLI](https://cli.github.com) authenticated (`gh auth login`), with access to every repository of the portfolio
- bash (built in on macOS and Linux, Git Bash on Windows)
- Optional: Node.js ≥ 18 for [Task Master](https://github.com/eyaltoledano/claude-task-master), to break large P0 features into tasks

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Changes are listed in [CHANGELOG.md](CHANGELOG.md).

## About

Built by [Régis Scyeur](https://regis.scyeur.net/en/), Slasher / Digital Architect / Coach, at [ZebraPuma Services](https://zebrapuma.be).
More open tooling from the same workshop: [github.com/zebrapuma](https://github.com/zebrapuma) and the [`zebrapuma` plugin marketplace](https://github.com/zebrapuma/claude-plugins).

## License

[MIT](LICENSE) © ZebraPuma Services
