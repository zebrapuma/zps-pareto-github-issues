# zps-pareto : ne plus perdre une demande, toujours traiter l'essentiel d'abord

Un plugin [Claude Code](https://code.claude.com) par [ZebraPuma Services](https://zebrapuma.be). 🇬🇧 [English version](README.md)

La plupart des backlogs échouent de la même façon : les demandes arrivent par mail, chat et téléphone, certaines se perdent, et les plus bruyantes passent en premier. `zps-pareto` fait de Claude Code un gestionnaire de demandes rigoureux, fondé sur la règle des 80/20 :

- chaque demande devient une **issue GitHub**, source de vérité unique ;
- chaque issue est **scorée**, et Claude traite d'abord les quelques demandes qui portent l'essentiel de la valeur ;
- un seul repo ou **tout un portefeuille** de repos, priorisés ensemble.

## Installation

```bash
claude plugin marketplace add zebrapuma/claude-plugins
claude plugin install zps-pareto@zebrapuma
```

Puis, dans chaque repo : `/zps-pareto:setup`.

### Mises à jour

Les marketplaces tierces ne se mettent pas à jour automatiquement. Pour obtenir une nouvelle version :

```bash
claude plugin marketplace update zebrapuma
claude plugin update zps-pareto@zebrapuma
```

Ou active une fois la mise à jour automatique de cette marketplace : `/plugin`, puis **Marketplaces**, `zebrapuma`, **Enable auto-update**.

## Commandes

| Commande | Rôle |
|---|---|
| `/zps-pareto:setup` | Configure un repo une fois (autonome, hub de portefeuille ou membre) : règles de scoring, bloc CLAUDE.md, modèle d'issue, labels GitHub, Task Master en option. |
| `/zps-pareto:intake <demande>` | Transforme un mail, un message ou des notes d'appel en issue GitHub scorée. Détecte les doublons, découpe les demandes multiples, choisit le bon repo dans un portefeuille. |
| `/zps-pareto:triage [owner/repo \| all] [full]` | Score les issues ouvertes, isole les ~20 % qui portent ~80 % de la valeur, propose l'ordre du jour, met à jour les labels après confirmation. Incrémental : seules les issues nouvelles ou modifiées sont rescorées, sauf avec `full`, et une issue modifiée est relue à partir de sa fiche de lecture et de ses seuls nouveaux commentaires. Le tableau commence par une colonne « What it is » en mots simples et dit combien d'issues ont été relues en entier, en partie ou pas du tout. |
| `/zps-pareto:next [owner/repo \| all]` | Indique la seule issue à traiter maintenant, avec un plan court. |
| `/zps-pareto:board [owner/repo \| all] [P0 \| P1 \| P2 \| quick-win]` | Tableau de bord en lecture seule : explique V, I, R, E, le score et les classes, puis liste les issues scorées par score avec leurs facteurs, le seuil P0 courant, les issues non notées et l'ordre conseillé. N'écrit rien. |

## Scoring

**Score = (Valeur × Impact × Portée) / Effort**, avec Valeur 1-5, Impact 1-5, Portée 1-3, Effort 1-5 (1 = moins d'une heure, 5 = plus de 3 jours). Inspiré de RICE et WSJF.

Chaque issue scorée reçoit une classe de priorité, et éventuellement le tag quick-win :

| Classe | Label par défaut | Règle |
|---|---|---|
| P0 | `pareto:P0` | Top 20 % des scores : l'essentiel |
| P1 | `pareto:P1` | Score ≥ 3 |
| P2 | `pareto:P2` | Score < 3 : pas sans accord |
| quick-win (tag) | `pareto:quick-win` | Score ≥ 15 et Effort ≤ 2 : à faire tout de suite, quelle que soit la classe |

Ici, P0 signifie « le plus de valeur », pas « la prod est en panne » : les incidents suivent ton processus habituel.

**Tu as déjà des labels de priorité ?** Déclare-les dans la table `## Labels` de `.claude/pareto.md` (par exemple P0 = `priority:high`) au lieu d'en créer de nouveaux. `/zps-pareto:setup` le propose quand il trouve un schéma existant.

Les règles vivent dans `.claude/pareto.md` et se modifient librement : définis ce que « forte valeur » veut dire pour ton activité, et le scoring devient fiable. Chaque score est consigné en commentaire d'issue (`Pareto score: 18 -> P0 (...)`) : c'est ainsi que le triage suivant sait ce qui a changé.

### Fiches de lecture

Un score dit ce que vaut une issue, pas ce qui a été compris. À chaque score, le triage garde aussi une **fiche de lecture** par issue dans le hub, dans `.claude/pareto-notes/<owner>-<repo>.jsonl` (une ligne JSON par issue) : un résumé en 3 lignes, un « What it is » de 4 à 8 mots, V, I, R, E, la date et ce qui a été lu (dernier commentaire, dernière modification, `updatedAt`). Le triage suivant :

- relit une issue modifiée à partir de sa fiche et des commentaires postérieurs au dernier lu, pas depuis zéro (`read: partial`) ; une issue modifiée dans son texte, ou sans fiche, est relue en entier (`read: full`) ;
- ne juge pas une issue modifiée à cause de ce que le triage a fait lui-même (étiquettes de classe, commentaire `Pareto score:`) ;
- dit combien d'issues il a relues en entier, en partie ou pas du tout.

La fiche est un fichier ordinaire du hub : relis-le, versionne-le. `triage reread` ignore les fiches.

## Mode portefeuille

Quand le travail s'étend sur plusieurs repos (un moteur, les applications bâties dessus, une librairie partagée), les prioriser séparément donne une liste de P0 par repo, sans dire laquelle compte le plus. Le mode portefeuille règle ce problème.

1. Choisis un repo **hub**, typiquement ton repo de pilotage. Lances-y `/zps-pareto:setup` et choisis *portfolio hub* : il liste les repos dans `.claude/pareto.md` (voir l'exemple du [README anglais](README.md#portfolio-mode)).
2. Dans chaque repo listé, lance `/zps-pareto:setup` et choisis *portfolio member* : il écrit une ligne qui pointe vers le hub.

Ensuite :

- `triage` depuis le hub classe **toutes** les issues ouvertes dans un seul tableau, avec **un seul seuil P0**, en respectant les blocages entre repos (`Blocked by acme/engine#42`) ;
- `intake` propose le bon repo d'après le rôle de chacun, et découpe une demande transverse en issues liées ;
- `next` choisit une issue dans tout le portefeuille (depuis le hub) ou dans le repo courant (depuis un membre, en signalant ce qui est plus urgent ailleurs).

Les labels restent propres à chaque repo (contrainte GitHub) : le hub les crée dans chaque repo après accord, un repo à la fois.

## Principes

- **Les issues GitHub sont la seule source de vérité.**
- **Claude n'invente jamais la valeur business** : une information manquante entraîne une question.
- **Rien ne change sans ta confirmation** : issues, labels et commits sont toujours montrés d'abord.
- **Setup non destructif** : le contenu existant de CLAUDE.md, les modèles et les labels sont préservés.
- **Économe sur les gros backlogs** : une requête GraphQL par tranche de 100 issues, et le triage ne rescore que ce qui a changé.

Claude répond dans ta langue.

## Prérequis

Claude Code, GitHub CLI connectée (`gh auth login`) avec accès à chaque repo du portefeuille, bash (Git Bash sous Windows), Node.js ≥ 18 en option pour Task Master.

## À propos

Conçu par [Régis Scyeur](https://regis.scyeur.net/), Slasher / Digital Architect / Coach, chez [ZebraPuma Services](https://zebrapuma.be).
Autres outils ouverts du même atelier : [github.com/zebrapuma](https://github.com/zebrapuma) et la [marketplace de plugins `zebrapuma`](https://github.com/zebrapuma/claude-plugins).

## Licence

[MIT](LICENSE) © ZebraPuma Services
