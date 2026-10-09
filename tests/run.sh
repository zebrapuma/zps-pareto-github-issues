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
    if [[ -n ${GRAPHQL_FAIL:-} ]]; then
      printf '%s\n' "$GRAPHQL_FAIL" "second line of the answer" >&2
      exit 1
    fi
    while (($# > 0)); do
      if [[ $1 == query=* && -n ${QUERY_OUT:-} ]]; then printf '%s' "${1#query=}" >"$QUERY_OUT"; fi
      if [[ $1 == --jq ]]; then "$JQ" -r "$2" "$FIXTURE"; exit 0; fi
      shift
    done
    exit 1 ;;
  "api repos/"*pareto-notes*)
    # The reading notes of the hub, read through the API by a member repository.
    case "${CONTENTS_MODE:-404}" in
      ok) cat "$CONTENTS_FILE" ;;
      404) echo "gh: Not Found (HTTP 404)" >&2; exit 1 ;;
      *) echo "gh: HTTP 401: Bad credentials" >&2; exit 1 ;;
    esac ;;
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

# ---- The scripts work from the root of the git repository, whatever the current folder.
git init -q "$tmp/member"
mkdir -p "$tmp/member/src/sub"
out=$(cd "$tmp/member/src/sub" && PATH="$tmp/bin:$PATH" JQ="$JQ" bash "$root/scripts/record-note.sh" <<<"acme/app#1 | 0@-@2026-10-01T00:00:00Z | 1 | 1 | 1 | 1 | 1 | Small thing | Short." 2>&1) && rc=0 || rc=$?
check "record-note.sh: from a sub-folder of a member repository it still refuses (status 2)" "2" "$rc"
check "record-note.sh: from a sub-folder of a member it prints NOT WRITTEN" "1" "$(grep -c 'NOT WRITTEN' <<<"$out")"
check "record-note.sh: from a sub-folder of a member nothing is written" "no" "$([[ -e $tmp/member/src/sub/.claude/pareto-notes || -e $tmp/member/.claude/pareto-notes ]] && echo yes || echo no)"

git init -q "$tmp/hubwork"
mkdir -p "$tmp/hubwork/docs/deep"
(cd "$tmp/hubwork/docs/deep" && PATH="$tmp/bin:$PATH" JQ="$JQ" bash "$root/scripts/record-note.sh" --date 2026-10-09 >/dev/null 2>&1 <<<"acme/app#1 | 0@-@2026-10-01T00:00:00Z | 1 | 1 | 1 | 1 | 1 | Small thing | Short.") || true
check "record-note.sh: from a sub-folder of the hub the note goes to the hub root" "yes/no" "$([[ -f $tmp/hubwork/.claude/pareto-notes/acme-app.jsonl ]] && echo yes || echo no)/$([[ -e $tmp/hubwork/docs/deep/.claude ]] && echo yes || echo no)"

# ---- One comment window for the listing and for the single-issue read, so the cursors agree.
LW=$FIX/issues-long.json
RW=$FIX/issue-long.json
lcur=$("$JQ" -r "$(issues_jq_filter acme/app 'priority: high' priority:medium pareto:P2 pareto:quick-win '' cursor)" "$LW" | tr -d '\r' | awk -F' [|] ' '{ print $3 }')
rcur=$(ri issue-long.json --full acme/app 30 | tail -n 1 | sed 's/^# cursor: //')
check "cursor: 25 comments, an old edited one, ids past 2^31 (listing)" "4500000024@2026-10-03T08:00:00Z@2026-10-06T10:00:30Z" "$lcur"
check "cursor: the single-issue read computes the same cursor as the listing" "$lcur" "$rcur"
(cd "$tmp/hubwork" && PATH="$tmp/bin:$PATH" JQ="$JQ" FIXTURE="$root/$LW" QUERY_OUT="$tmp/q-list" bash "$root/scripts/list-issues.sh" >/dev/null 2>&1) || true
(cd "$tmp/hubwork" && PATH="$tmp/bin:$PATH" JQ="$JQ" FIXTURE="$root/$RW" QUERY_OUT="$tmp/q-read" bash "$root/scripts/read-issue.sh" acme/app 30 >/dev/null 2>&1) || true
check "comment window: list-issues.sh asks for the shared window" "1" "$(grep -c "comments(last: $COMMENTS_WINDOW)" "$tmp/q-list")"
check "comment window: read-issue.sh asks for the same window" "1" "$(grep -c "comments(last: $COMMENTS_WINDOW)" "$tmp/q-read")"
# A note written from the cursor of the long thread leaves the issue untouched (scored, nothing to read).
printf '%s\n' '{"n":30,"lastComment":4500000024,"edited":"2026-10-03T08:00:00Z","updatedAt":"2026-10-06T10:00:30Z","v":3,"i":2,"r":2,"e":2,"score":6,"date":"2026-10-06","what":"Long thread","summary":"s"}' >"$tmp/long-notes.jsonl"
actual=$(apply_notes "$tmp/long-notes.jsonl" "" "" <<<"acme/app#30 | scored | $lcur | P1 | - | 6 | 2026-10-06 | long thread" | awk -F' [|] ' '{ print $2 " | " $3 }')
check "notes: a long thread with a note taken from its cursor is scored, nothing to read" "scored | none" "$actual"

# ---- Identifiers past 2^31 stay exact (no numeric conversion), numbers have no leading zero.
out=$(rn --date 2026-10-09 2>&1 <<'NOTES'
acme/app#40 | 4500000001@-@2026-10-05T09:00:00Z | 3 | 2 | 2 | 2 | 6 | Big comment id | Past 2^31.
acme/app#041 | 1@-@2026-10-05T09:00:00Z | 3 | 2 | 2 | 2 | 6 | Zero in front | s
acme/app#42 | 007@-@2026-10-05T09:00:00Z | 3 | 2 | 2 | 2 | 6 | Zero in the cursor | s
acme/app#43 | 7@-@2026-10-05T09:00:00Z | 03 | 2 | 2 | 2 | 6 | Zero in a factor | s
NOTES
) && rc=0 || rc=$?
check "record-note.sh: leading zeros are rejected" "3" "$(grep -c 'cannot record' <<<"$out")"
check "record-note.sh: a comment id past 2^31 is written as is" "1" "$(grep -c '"n":40,"lastComment":4500000001,' "$tmp/hubwork/.claude/pareto-notes/acme-app.jsonl")"
printf '%s\n' '{"n":40,"lastComment":4500000001,"edited":"-","updatedAt":"u","what":"w"}' >"$tmp/big-notes.jsonl"
actual=$(apply_notes "$tmp/big-notes.jsonl" "" "" <<'LINES' | awk -F' [|] ' '{ print $2 " | " $3 }'
acme/app#40 | scored | 4500000001@-@u | P1 | - | 6 | 2026-10-06 | same
acme/app#40 | scored | 4500000002@-@u | P1 | - | 6 | 2026-10-06 | one more
acme/app#40 | scored | 999999999@-@u | P1 | - | 6 | 2026-10-06 | shorter id
acme/app#40 | scored | 10000000000@-@u | P1 | - | 6 | 2026-10-06 | longer id
LINES
)
check "notes: ids past 2^31 are compared exactly" "$(printf 'scored | none\nstale | partial\nscored | none\nstale | partial')" "$actual"

# ---- Notes of the hub read through the API by a member: a 404 is silent, any other failure is said.
mkdir -p "$tmp/member2/.claude"
printf 'Portfolio hub: acme/hub

## Labels

| Class | Label |
|---|---|
| P1 | priority:medium |
' >"$tmp/member2/.claude/pareto.md"
git init -q "$tmp/member2"
ls2() { (cd "$tmp/member2" && PATH="$tmp/bin:$PATH" JQ="$JQ" FIXTURE="$root/$NJ" CONTENTS_FILE="$root/$FIX/notes.jsonl" CONTENTS_MODE="$1" bash "$root/scripts/list-issues.sh" --what 2>&1 | tr -d '\r'); }
out=$(ls2 404)
check "hub notes: a 404 means no notes yet, no warning" "0" "$(grep -c 'warning' <<<"$out" || true)"
out=$(ls2 401)
check "hub notes: another failure is reported with its reason" "1" "$(grep -c '^# warning: reading notes of acme/app unreadable (gh: HTTP 401: Bad credentials), every changed issue will be read in full$' <<<"$out" || true)"
check "hub notes: the listing still answers after a failure (everything is read in full)" "0" "$(grep -v '^#' <<<"$out" | grep -c ' | partial | ' || true)"
out=$(ls2 ok)
check "hub notes: readable notes are used" "$(cat "$FIX/issues-notes.expected")" "$(grep -v '^#' <<<"$out")"

# ---- read-issue.sh says why gh failed.
err=$(cd "$tmp/hubwork" && PATH="$tmp/bin:$PATH" JQ="$JQ" GRAPHQL_FAIL="gh: API rate limit exceeded (HTTP 403)" bash "$root/scripts/read-issue.sh" acme/app 30 2>&1 >"$tmp/read-out") && rc=0 || rc=$?
check "read-issue.sh: a failing gh gives status 1" "1" "$rc"
check "read-issue.sh: the first line of gh's answer is the reason, on stderr" "# error: cannot read acme/app#30: gh: API rate limit exceeded (HTTP 403)" "$err"
check "read-issue.sh: nothing on stdout when gh fails" "0" "$(wc -c <"$tmp/read-out" | tr -d ' ')"

# ---- list-issues.sh says why gh failed (it used to say "missing or no access" whatever the cause).
out=$(cd "$tmp/hubwork" && PATH="$tmp/bin:$PATH" JQ="$JQ" GRAPHQL_FAIL="gh: API rate limit exceeded (HTTP 403)" bash "$root/scripts/list-issues.sh" 2>/dev/null | tr -d '') && rc=0 || rc=$?
check "list-issues.sh: the first line of gh's answer is the reason" "acme/app | error: cannot read issues: gh: API rate limit exceeded (HTTP 403)" "$(grep -v '^#' <<<"$out")"
check "list-issues.sh: a failing repository does not stop the listing" "0" "$rc"

# ---- pareto-context.sh called by a relative path from a subdirectory: goto_root moves to the
# repository root, so the default rules (templates/pareto.md next to the scripts) must still be found.
# The scripts are copied next to the test repositories so that the relative path depends on the depth.
mkdir -p "$tmp/plug" "$tmp/member2/sub" "$tmp/bare/sub"
cp -r "$root/scripts" "$root/templates" "$tmp/plug/"
git init -q "$tmp/bare"
for d in member2 bare; do
  out=$(cd "$tmp/$d/sub" && PATH="$tmp/bin:$PATH" JQ="$JQ" bash ../../plug/scripts/pareto-context.sh 2>&1 | tr -d '') || true
  check "pareto-context.sh ($d): a relative path does not lose the default rules" "0" "$(grep -c 'No such file' <<<"$out" || true)"
  check "pareto-context.sh ($d): the default rules are printed" "1" "$(grep -c '^# Pareto scoring rules' <<<"$out" || true)"
done

if ((failures > 0)); then
  echo "$failures test(s) failed"
  exit 1
fi
echo "All tests passed."
