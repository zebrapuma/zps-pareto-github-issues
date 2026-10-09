#!/usr/bin/env bash
# zps-pareto plugin - prints what must be read of one issue to score it, no more. Read-only.
#
# Usage: read-issue.sh [--full] [--no-notes] owner/repo number
#   Without a reading note for the issue (or with --full / --no-notes): the whole issue, body
#   and every comment.
#   With a note: the note itself, then only the comments written after the note's last one
#   (score comments left out). If the body or a comment was edited since the note, the whole
#   issue is printed again.
#
# Output, in this order:
#   # read: full | partial          how much follows
#   # note: {...}                   the reading note (partial only)
#   # issue: title [state] labels   always
#   body and comments               everything (full) or the new comments (partial)
#   # cursor: <id>@<edit>@<updatedAt>
#                                   give it back, unchanged, to record-note.sh when the issue is
#                                   scored: it is what was read, not what is on GitHub later
set -euo pipefail
# shellcheck source-path=SCRIPTDIR source=lib.sh
. "$(dirname "$0")/lib.sh"

FULL=""
NOTES=1
POS=()
while (($# > 0)); do
  case $1 in
    --full) FULL=1; shift ;;
    --no-notes) NOTES=""; shift ;;
    *) POS+=("$1"); shift ;;
  esac
done
if ((${#POS[@]} != 2)) || ! [[ ${POS[0]} =~ ^$REPO_RE$ ]] || ! [[ ${POS[1]} =~ ^[0-9]+$ ]]; then
  echo "Usage: read-issue.sh [--full] [--no-notes] owner/repo number" >&2
  exit 1
fi
repo=${POS[0]}
num=${POS[1]}

load_context

# The last note of this issue, if any, and the cursor it holds.
note=""
flc=0
fed="-"
if [[ -n $NOTES ]]; then
  note=$(notes_for "$repo" | awk -v n="$num" '
    match($0, /"n":[0-9]+/) && substr($0, RSTART + 4, RLENGTH - 4) + 0 == n + 0 { last = $0 }
    END { if (last != "") print last }')
fi
if [[ -n $note ]]; then
  if [[ $note =~ \"lastComment\":([0-9]+) ]]; then flc=${BASH_REMATCH[1]}; else note=""; fi
  if [[ $note =~ \"edited\":\"([^\"]*)\" ]]; then fed=${BASH_REMATCH[1]}; else note=""; fi
fi
mode=full
if [[ -n $note && -z $FULL ]]; then mode=auto; fi
fed=${fed//\"/}

# GraphQL variables, not shell ones: single quotes on purpose.
# shellcheck disable=SC2016
QUERY='query($owner: String!, $name: String!, $number: Int!) {
  repository(owner: $owner, name: $name) {
    issue(number: $number) {
      title body state updatedAt lastEditedAt
      labels(first: 30) { nodes { name } }
      comments(last: 100) {
        totalCount
        nodes { databaseId author { login } body createdAt lastEditedAt }
      }
    }
  }
}'

# flc is digits and fed an ISO date or "-" (checked by the regexes above): safe to inline.
if [[ ! $fed =~ ^([-]|[0-9TZ:.-]+)$ ]]; then mode=full; fi
JQ_PROGRAM=$(
  printf 'def flc: %s; def fed: "%s"; def mode: "%s";\n' "$flc" "$fed" "$mode"
  cat <<'EOF'
.data.repository.issue as $i
| if $i == null then "# error: issue not found or no access"
  else
    ([$i.comments.nodes[] | select((.body // "") | startswith("Pareto score:") | not) | .databaseId] | map(select(. != null)) | max // 0) as $lc
    | ([$i.lastEditedAt] + [$i.comments.nodes[].lastEditedAt] | map(select(. != null)) | max // "-") as $ed
    | (if mode == "full" or $ed != fed then "full" else "partial" end) as $m
    | [ $i.comments.nodes[]
        | select($m == "full" or (((.body // "") | startswith("Pareto score:") | not) and ((.databaseId // 0) > flc)))
        | "--- comment " + ((.databaseId // 0) | tostring) + " by " + (.author.login // "ghost") + ", " + .createdAt + "\n" + (.body // "") ] as $cs
    | "# read: " + $m + (if $m == "full" and mode == "auto" then " (edited since the note)" else "" end)
      + "\n# issue: " + $i.title + " [" + $i.state + "] labels: " + ([$i.labels.nodes[].name] | join(", "))
      + (if $i.comments.totalCount > 100 then "\n# warning: " + ($i.comments.totalCount | tostring) + " comments, only the last 100 are shown" else "" end)
      + (if $m == "full" then "\n\n" + ($i.body // "") else "" end)
      + "\n\n" + (if ($cs | length) == 0 then "(no new comment: only the title, labels or state may have changed)" else ($cs | join("\n\n")) end)
      + "\n\n# cursor: " + ($lc | tostring) + "@" + $ed + "@" + $i.updatedAt
  end
EOF
)

if ! out=$(gh api graphql -f owner="${repo%%/*}" -f name="${repo#*/}" -F number="$num" \
  -f query="$QUERY" --jq "$JQ_PROGRAM" 2>&1); then
  echo "# error: cannot read $repo#$num (repository missing or no access)"
  exit 1
fi
out=$(tr -d '\r' <<<"$out")
# The note goes right after the "# read:" line, only when the issue is read from it.
if [[ $out == "# read: partial"* ]]; then
  head -n 1 <<<"$out"
  echo "# note: $note"
  tail -n +2 <<<"$out"
else
  echo "$out"
fi
