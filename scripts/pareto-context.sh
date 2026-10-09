#!/usr/bin/env bash
# zps-pareto plugin - prints the scope (single repository or portfolio) and the scoring rules
# that apply in the current repository. Read-only.
# Usage: pareto-context.sh [--scope-only]
set -euo pipefail
# shellcheck source-path=SCRIPTDIR source=lib.sh
. "$(dirname "$0")/lib.sh"

goto_root
load_context

echo "## Scope"
echo
echo "- Current repository: ${HERE:-unknown (not a GitHub repository, or gh not authenticated)}"
case $ROLE in
  hub)    echo "- Mode: portfolio hub (this repository tracks priorities for the whole portfolio)" ;;
  member) echo "- Mode: member of the portfolio whose hub is $HUB" ;;
  single) echo "- Mode: single repository" ;;
esac
if [[ -n $PORTFOLIO ]]; then
  echo "- Portfolio: $(tr '\n' ' ' <<<"$PORTFOLIO")"
fi
if [[ -n $HERE ]]; then
  echo "- Labels in this repository (class=label): $(labels_for "$HERE" | tr '\n' ' ')"
fi
echo

if [[ ${1:-} == --scope-only ]]; then exit 0; fi

if [[ $ROLE == member ]]; then
  if [[ -n $HUB_RULES ]]; then
    echo "## Scoring rules (from the hub $HUB)"
    echo
    echo "$HUB_RULES"
  else
    echo "## Scoring rules"
    echo
    echo "WARNING: cannot read $RULES_FILE in the hub $HUB (missing file or no access). Plugin defaults apply."
    echo
    cat "$(dirname "$0")/../templates/pareto.md"
  fi
  echo
  echo "## Local notes (this repository)"
  echo
  echo "$LOCAL_RULES"
elif [[ -n $LOCAL_RULES ]]; then
  echo "## Scoring rules (this repository)"
  echo
  echo "$LOCAL_RULES"
else
  echo "## Scoring rules (plugin defaults: run /zps-pareto:setup to customize)"
  echo
  cat "$(dirname "$0")/../templates/pareto.md"
fi
