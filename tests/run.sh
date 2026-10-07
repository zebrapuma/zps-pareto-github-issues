#!/usr/bin/env bash
# zps-pareto plugin - offline tests of the script logic (no GitHub access needed).
# Usage: tests/run.sh   (JQ=gojq by default, the engine embedded in gh; JQ=jq also works)
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck source-path=SCRIPTDIR/.. source=scripts/lib.sh
. scripts/lib.sh

JQ=${JQ:-gojq}
FIX=tests/fixtures
failures=0

check() { # name expected actual
  if [[ "$2" == "$3" ]]; then
    echo "ok   $1"
  else
    echo "FAIL $1"
    diff <(echo "$2") <(echo "$3") || true
    failures=$((failures + 1))
  fi
}

check "portfolio_repos reads only the Portfolio table" \
  "$(printf 'acme/engine\nacme/client-app')" "$(portfolio_repos <"$FIX/hub.md")"

check "hub_of reads the member pointer" "acme/hub" "$(hub_of "$FIX/member.md")"
check "hub_of is empty without pointer" "" "$(hub_of "$FIX/hub.md")"

# Context normally set by load_context, read by labels_for.
# shellcheck disable=SC2034
HERE=acme/client-app
# shellcheck disable=SC2034
HUB=acme/hub
# shellcheck disable=SC2034
HUB_RULES=$(cat "$FIX/hub.md")
# shellcheck disable=SC2034
LOCAL_RULES=$(cat "$FIX/member.md")
map=$(labels_for acme/client-app)
check "labels: hub table overrides defaults" "priority: high" "$(label_of P0 <<<"$map")"
check "labels: member table overrides hub" "urgent-ish" "$(label_of P1 <<<"$map")"
check "labels: unmapped class keeps default" "pareto:P2" "$(label_of P2 <<<"$map")"
check "labels: request keeps default" "pareto:request" "$(label_of request <<<"$map")"

actual=$("$JQ" -r "$(issues_jq_filter acme/app 'priority: high' priority:medium pareto:P2 pareto:quick-win)" "$FIX/issues.json" | tr -d '\r')
check "issues filter: status, class, tag and score" "$(cat "$FIX/issues.expected")" "$actual"

if ((failures > 0)); then
  echo "$failures test(s) failed"
  exit 1
fi
echo "All tests passed."
