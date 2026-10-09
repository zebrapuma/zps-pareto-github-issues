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

actual=$("$JQ" -r "$(issues_jq_filter acme/app 'priority: high' priority:medium pareto:P2 pareto:quick-win detail)" "$FIX/issues.json" | tr -d '\r')
check "issues filter: detail adds V, I, R, E" "$(cat "$FIX/issues-factors.expected")" "$actual"

# End to end: list-issues.sh --factors against the fixture, with a stub gh that answers from
# the fixture instead of GitHub. Behaviours pinned by the fixture: decimal factors and score
# "12.0" are kept as written; when the most recent score comment carries no factors, the most
# recent comment wins and the factors are empty ("-"), even if an older comment had them;
# incomplete factors give "-" for all four.
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir "$tmp/bin" "$tmp/work" "$tmp/work/.claude"
cat >"$tmp/bin/gh" <<'STUB'
#!/usr/bin/env bash
case "$1 $2" in
  "repo view") echo acme/app ;;
  "api graphql")
    while (($# > 0)); do
      if [[ $1 == --jq ]]; then "$JQ" -r "$2" "$FIXTURE"; exit 0; fi
      shift
    done
    exit 1 ;;
  *) exit 1 ;;
esac
STUB
chmod +x "$tmp/bin/gh"
printf '## Labels

| Class | Label |
|---|---|
| P0 | priority: high |
| P1 | priority:medium |
' >"$tmp/work/.claude/pareto.md"
root=$PWD
actual=$(cd "$tmp/work" && PATH="$tmp/bin:$PATH" JQ="$JQ" FIXTURE="$root/$FIX/issues.json"   bash "$root/scripts/list-issues.sh" --factors | grep -v '^#' | tr -d '')
check "list-issues.sh --factors end to end" "$(cat "$FIX/list-factors.expected")" "$actual"

# ---- Reading notes ("fiches de lecture"): staleness, how much to read, recording.
NJ=$FIX/issues-notes.json
actual=$("$JQ" -r "$(issues_jq_filter acme/app 'priority: high' priority:medium pareto:P2 pareto:quick-win '' cursor)" "$NJ" | tr -d '\r')
check "issues filter: cursor mode adds last comment, last edit and updatedAt" "$(cat "$FIX/issues-cursor.expected")" "$actual"

actual=$(apply_notes "$FIX/notes.jsonl" "" what <<<"$actual")
check "notes: only what the triage did leaves an issue scored; comments and edits make it stale" "$(cat "$FIX/issues-notes.expected")" "$actual"

actual=$(apply_notes "$tmp/missing.jsonl" "" "" <<<"$("$JQ" -r "$(issues_jq_filter acme/app 'priority: high' priority:medium pareto:P2 pareto:quick-win '' cursor)" "$NJ" | tr -d '\r')" | awk -F' [|] ' '{ print $1 " | " $2 " | " $3 }')
check "notes: without notes a stale or new issue is read in full" "$(cat "$FIX/issues-nonotes.expected")" "$actual"

# End to end with a stub gh: notes in the hub, the listing reads them.
mkdir -p "$tmp/hubwork/.claude/pareto-notes"
printf '## Labels

| Class | Label |
|---|---|
| P1 | priority:medium |

## Portfolio

| Repo | Role | Value notes |
|---|---|---|
| acme/app | app | x |
' >"$tmp/hubwork/.claude/pareto.md"
cp "$FIX/notes.jsonl" "$tmp/hubwork/.claude/pareto-notes/acme-app.jsonl"
actual=$(cd "$tmp/hubwork" && PATH="$tmp/bin:$PATH" JQ="$JQ" FIXTURE="$root/$NJ" bash "$root/scripts/list-issues.sh" --what | grep -v '^#' | tr -d '\r')
check "list-issues.sh --what end to end" "$(cat "$FIX/issues-notes.expected")" "$actual"

actual=$(cd "$tmp/hubwork" && PATH="$tmp/bin:$PATH" JQ="$JQ" FIXTURE="$root/$NJ" bash "$root/scripts/list-issues.sh" --no-notes | grep -v '^#' | tr -d '\r' | awk -F' [|] ' '{ print $1 " | " $2 " | " $3 }')
check "list-issues.sh --no-notes reads every changed issue in full" "$(cat "$FIX/issues-nonotes.expected")" "$actual"

actual=$(cd "$tmp/hubwork" && PATH="$tmp/bin:$PATH" JQ="$JQ" FIXTURE="$root/$NJ" bash "$root/scripts/list-issues.sh" --classes P0 | { grep -vc '^#' || true; })
check "list-issues.sh --classes still filters on the class column" "0" "$actual"
actual=$(cd "$tmp/hubwork" && PATH="$tmp/bin:$PATH" JQ="$JQ" FIXTURE="$root/$NJ" bash "$root/scripts/list-issues.sh" --classes P1 | grep -vc '^#')
check "list-issues.sh --classes P1 keeps the P1 issues" "11" "$actual"

# read-issue.sh: partial from the note, full when edited or without note.
ri() { (cd "$tmp/hubwork" && PATH="$tmp/bin:$PATH" JQ="$JQ" FIXTURE="$root/$FIX/$1" bash "$root/scripts/read-issue.sh" "${@:2}" | tr -d '\r'); }
actual=$(ri issue-read.json acme/app 11)
check "read-issue.sh: with a note, only the comments after the last one read" "$(cat "$FIX/read-partial.expected")" "$actual"
actual=$(ri issue-read.json acme/app 11 | grep -c 'First look\|Prices are below' || true)
check "read-issue.sh: partial does not repeat the body or old comments" "0" "$actual"
actual=$(ri issue-read.json --full acme/app 11)
check "read-issue.sh --full: body and every comment" "$(cat "$FIX/read-full.expected")" "$actual"
actual=$(ri issue-read-edited.json acme/app 11 | head -n 1)
check "read-issue.sh: edited since the note means a full read" "# read: full (edited since the note)" "$actual"
actual=$(ri issue-read.json acme/app 99 | head -n 1)
check "read-issue.sh: no note for the issue means a full read" "# read: full" "$actual"
actual=$(ri issue-read.json acme/app 11 | tail -n 1)
check "read-issue.sh: the cursor is the last comment that is not a score" "# cursor: 102@-@2026-10-05T09:00:00Z" "$actual"

# record-note.sh: batch of notes, replace by issue number, hub only.
rn() { (cd "$tmp/hubwork" && PATH="$tmp/bin:$PATH" JQ="$JQ" bash "$root/scripts/record-note.sh" "$@"); }
rm "$tmp/hubwork/.claude/pareto-notes/acme-app.jsonl"
out=$(rn --date 2026-10-09 2>&1 <<'NOTES'
acme/app#12 | 7@-@2026-10-05T09:00:00Z | 3 | 2 | 2 | 2 | 6 | Invoice total "rounds" wrong | Rounds down. / Finance fixes by hand. | easy fix
acme/app#3 | 0@2026-10-04T08:00:00Z@2026-10-04T08:00:30Z | 5 | 4 | 1 | 2.5 | 8 | Orders stuck | Back\slash. / Two. / Three.
acme/app#4 | nope | 1 | 1 | 1 | 1 | 1 | bad cursor | s
acme/app#5 | 1@-@2026-10-04T08:00:00Z | 1 | x | 1 | 1 | 1 | bad factor | s
NOTES
) && rc=0 || rc=$?
check "record-note.sh: valid lines are recorded, bad ones rejected with status 1" "1" "$rc"
check "record-note.sh: says what it recorded" "1" "$(grep -c 'Recorded 2 note' <<<"$out")"
check "record-note.sh: says what it rejected" "2" "$(grep -c 'cannot record' <<<"$out")"
check "record-note.sh: JSON lines, sorted by issue number, text escaped" "$(cat "$FIX/recorded.expected")" "$(tr -d '\r' <"$tmp/hubwork/.claude/pareto-notes/acme-app.jsonl")"
rn --date 2026-10-10 >/dev/null 2>&1 <<'NOTES'
acme/app#12 | 9@-@2026-10-06T09:00:00Z | 4 | 2 | 2 | 2 | 8 | Invoice total rounds wrong | Second version.
NOTES
check "record-note.sh: a new note replaces the previous one of the same issue" "2" "$(grep -c . "$tmp/hubwork/.claude/pareto-notes/acme-app.jsonl")"
check "record-note.sh: replaced note carries the new cursor" "1" "$(grep -c '"n":12,"lastComment":9,' "$tmp/hubwork/.claude/pareto-notes/acme-app.jsonl")"
# A note it wrote is read back by list-issues (round trip): #12 is stale because of its edit.
actual=$(cd "$tmp/hubwork" && PATH="$tmp/bin:$PATH" JQ="$JQ" FIXTURE="$root/$NJ" bash "$root/scripts/list-issues.sh" --what | grep 'app#12 ' | tr -d '\r')
check "record-note.sh: list-issues reads back what it wrote" "acme/app#12 | stale | full | P1 | - | 6 | Invoice total rounds wrong | 2026-10-04 | note, body edited" "$actual"

mkdir -p "$tmp/member/.claude"
printf 'Portfolio hub: acme/hub\n' >"$tmp/member/.claude/pareto.md"
out=$(cd "$tmp/member" && PATH="$tmp/bin:$PATH" JQ="$JQ" bash "$root/scripts/record-note.sh" <<<"acme/app#1 | 0@-@2026-10-01T00:00:00Z | 1 | 1 | 1 | 1 | 1 | Small thing | Short." 2>&1) && rc=0 || rc=$?
check "record-note.sh: refuses to write from a member repository" "2" "$rc"
check "record-note.sh: a member prints the lines for the hub" "1" "$(grep -c 'NOT WRITTEN' <<<"$out")"
check "record-note.sh: a member writes nothing" "no" "$([[ -e $tmp/member/.claude/pareto-notes ]] && echo yes || echo no)"

if ((failures > 0)); then
  echo "$failures test(s) failed"
  exit 1
fi
echo "All tests passed."
