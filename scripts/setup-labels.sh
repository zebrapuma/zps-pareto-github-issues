#!/usr/bin/env bash
# zps-pareto plugin - creates the Pareto labels in a GitHub repository, using the label names
# of its "## Labels" table (or the hub's, or the plugin defaults).
# Non-destructive: an existing label is never modified, so a mapped existing label is reused.
# Usage: setup-labels.sh [owner/repo]   (default: the current repository)
set -euo pipefail
# shellcheck source-path=SCRIPTDIR source=lib.sh
. "$(dirname "$0")/lib.sh"

load_context
REPO=${1:-$HERE}
if [[ -z $REPO ]]; then
  echo "No GitHub repository found: run inside a GitHub repository, after 'gh auth login'." >&2
  exit 1
fi
MAP=$(labels_for "$REPO")
EXISTING=$(gh label list --repo "$REPO" --limit 500 --json name --jq '.[].name')

create() {
  local label
  label=$(label_of "$1" <<<"$MAP")
  if grep -Fxq "$label" <<<"$EXISTING"; then
    echo "= $label ($1): already exists, left unchanged"
  else
    gh label create "$label" --repo "$REPO" --color "$2" --description "$3" >/dev/null
    echo "+ $label ($1): created"
  fi
}

create "P0"        "B60205" "Pareto: top 20% of scores, the vital few"
create "P1"        "FBCA04" "Pareto: score >= 3, next in line"
create "P2"        "C5DEF5" "Pareto: score < 3, not without approval"
create "quick-win" "0E8A16" "Pareto: score >= 15 and effort <= 2, do it now"
create "request"   "5319E7" "Request captured via /zps-pareto:intake"

echo "Pareto labels OK in $REPO."
