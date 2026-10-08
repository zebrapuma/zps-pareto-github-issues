#!/usr/bin/env bash
# zps-pareto plugin - lists open issues with their Pareto status, for one repository or a
# whole portfolio. Read-only. One GraphQL call per 100 issues, so large backlogs stay cheap.
#
# Usage: list-issues.sh [--classes c1,c2] [--factors] [owner/repo ...]
#   --classes  keep only these classes or tags (P0, P1, P2, quick-win)
#   --factors  add the V, I, R, E columns after the score (read from the last score comment)
#   Without a repository: every repository of the portfolio if one is defined,
#   otherwise the current repository.
#
# Output: for each repository, one "# labels" line giving the GitHub label used for each
# class there, then one line per issue:
#   owner/repo#n | status | class | tag | score | updated | title
#   (with --factors: owner/repo#n | status | class | tag | score | V | I | R | E | updated | title,
#   each factor being "-" when the score comment does not carry it)
#   status: new    = never scored
#           stale  = changed since its last score (comment, edit, label)
#           scored = score still valid
#   class:  P0, P1, P2 or "-", read from the repository's labels
#   tag:    quick-win or "-"
#   score:  read from the last comment starting with "Pareto score: <number>"
set -euo pipefail
# shellcheck source-path=SCRIPTDIR source=lib.sh
. "$(dirname "$0")/lib.sh"

CLASSES=""
DETAIL=""
REPOS=()
while (($# > 0)); do
  case $1 in
    --classes) CLASSES=${2:-}; shift 2 ;;
    --factors) DETAIL=detail; shift ;;
    *) REPOS+=("$1"); shift ;;
  esac
done

load_context
if ((${#REPOS[@]} == 0)); then
  if [[ -n $PORTFOLIO ]]; then
    while IFS= read -r r; do REPOS+=("$r"); done <<<"$PORTFOLIO"
  elif [[ -n $HERE ]]; then
    REPOS=("$HERE")
  fi
fi
if ((${#REPOS[@]} == 0)); then
  echo "No GitHub repository found: run inside a GitHub repository, after 'gh auth login'." >&2
  exit 1
fi

# GraphQL variables, not shell ones: single quotes on purpose.
# shellcheck disable=SC2016
QUERY='query($owner: String!, $name: String!, $endCursor: String) {
  repository(owner: $owner, name: $name) {
    issues(first: 100, after: $endCursor, states: OPEN) {
      pageInfo { hasNextPage endCursor }
      nodes {
        number title updatedAt
        labels(first: 30) { nodes { name } }
        comments(last: 20) { nodes { body createdAt } }
      }
    }
  }
}'

only_classes() {
  if [[ -z $CLASSES ]]; then
    cat
  else
    awk -F' [|] ' -v want=",$CLASSES," 'index(want, "," $3 ",") > 0 || ($4 != "-" && index(want, "," $4 ",") > 0)'
  fi
}

for repo in "${REPOS[@]}"; do
  if ! [[ $repo =~ ^$REPO_RE$ ]]; then
    echo "$repo | error: not an owner/repo name"
    continue
  fi
  map=$(labels_for "$repo")
  p0=$(label_of P0 <<<"$map"); p1=$(label_of P1 <<<"$map"); p2=$(label_of P2 <<<"$map")
  qw=$(label_of quick-win <<<"$map")
  echo "# labels $repo: $(tr '\n' ' ' <<<"$map")"
  # Label names end up inside jq string literals.
  if [[ "$p0$p1$p2$qw" == *[\"\\]* ]]; then
    echo "$repo | error: a label name in its ## Labels table contains a quote or a backslash"
    continue
  fi
  # Captured first: on a GraphQL error gh still prints the raw response on stdout.
  if out=$(gh api graphql --paginate \
    -f owner="${repo%%/*}" -f name="${repo#*/}" -f query="$QUERY" \
    --jq "$(issues_jq_filter "$repo" "$p0" "$p1" "$p2" "$qw" "$DETAIL")" 2>/dev/null); then
    [[ -z $out ]] || only_classes <<<"$out"
  else
    echo "$repo | error: cannot read issues (repository missing or no access)"
  fi
done
