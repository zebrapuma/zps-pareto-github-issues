#!/usr/bin/env bash
# zps-pareto plugin - records the reading note ("fiche de lecture") of each scored issue, so the
# next triage reads only what changed. Writes only .claude/pareto-notes/<owner>-<repo>.jsonl in
# the hub (or the standalone repository): nothing else, no GitHub write.
#
# Usage: record-note.sh [--date YYYY-MM-DD] < lines
#   One line per issue on stdin:
#     owner/repo#n | cursor | V | I | R | E | score | what | summary
#   cursor   the "# cursor:" line printed by read-issue.sh, as read BEFORE scoring
#            (<last comment id>@<last edit>@<updatedAt>), so a comment that arrived since
#            is not recorded as read
#   what     4 to 8 plain words on the business problem (no "|", quotes are softened)
#   summary  3 short lines in one line, separated by " / " (it may contain " | ")
#   A note replaces the previous note of the same issue. Lines that cannot be recorded are
#   reported on stderr and the exit status is 1.
#   Run it from the hub (any folder of it: the scripts move to the git root first): from a member
#   repository, whatever the folder, nothing is written, the note lines to
#   commit in the hub are printed instead (exit status 2).
set -euo pipefail
# shellcheck source-path=SCRIPTDIR source=lib.sh
. "$(dirname "$0")/lib.sh"

DATE=$(date +%F)
while (($# > 0)); do
  case $1 in
    --date) DATE=${2:-}; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done
if ! [[ $DATE =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
  echo "--date must look like 2026-10-09" >&2
  exit 1
fi

goto_root
load_context

# stdin to JSON note lines, one "owner/repo<TAB>json" per valid input line, errors on stderr.
# Control characters are dropped first (the tab becomes a space), so every field is one line.
to_json() {
  tr '\t' ' ' | tr -d '\000-\010\013-\037' | awk -F' [|] ' -v date="$DATE" '
    function esc(s,   i, c, o) {
      o = ""
      for (i = 1; i <= length(s); i++) {
        c = substr(s, i, 1)
        if (c == "\\") o = o "\\\\"
        else if (c == "\"") o = o "\\\""
        else o = o c
      }
      return o
    }
    function trim(s) { gsub(/^ +| +$/, "", s); return s }
    # A JSON number: no leading zero. Identifiers and numbers are printed as the validated text,
    # never through a numeric conversion: comment ids go past 2^31 and some awks (mawk) print
    # large numbers in exponent form.
    BEGIN { NUM = "^(0|[1-9][0-9]*)([.][0-9]+)?$" }
    /^[ ]*$/ { next }
    {
      if (NF < 9) { print "cannot record (need 9 fields): " $0 > "/dev/stderr"; bad = 1; next }
      ref = trim($1); cursor = trim($2)
      v = trim($3); i2 = trim($4); r = trim($5); e = trim($6); score = trim($7)
      what = trim($8)
      summary = $9
      for (k = 10; k <= NF; k++) summary = summary " | " $k
      summary = trim(summary)
      if (ref !~ /^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+#[1-9][0-9]*$/) { print "cannot record (bad issue reference): " $0 > "/dev/stderr"; bad = 1; next }
      if (cursor !~ /^(0|[1-9][0-9]*)@[^@ ]+@[^@ ]+$/) { print "cannot record (bad cursor): " $0 > "/dev/stderr"; bad = 1; next }
      if (v !~ NUM || i2 !~ NUM || r !~ NUM || e !~ NUM || score !~ NUM) {
        print "cannot record (V, I, R, E and score must be numbers): " $0 > "/dev/stderr"; bad = 1; next
      }
      if (what == "" || summary == "") { print "cannot record (empty what or summary): " $0 > "/dev/stderr"; bad = 1; next }
      # "what" is read back without a JSON parser: no quote, backslash or bar inside.
      gsub(/"/, "\047", what); gsub(/\\/, "/", what); gsub(/[|]/, "/", what)
      split(cursor, cu, "@")
      repo = ref; sub(/#.*/, "", repo)
      num = ref; sub(/^[^#]*#/, "", num)
      printf "%s\t{\"n\":%s,\"lastComment\":%s,\"edited\":\"%s\",\"updatedAt\":\"%s\",\"v\":%s,\"i\":%s,\"r\":%s,\"e\":%s,\"score\":%s,\"date\":\"%s\",\"what\":\"%s\",\"summary\":\"%s\"}\n", \
        repo, num, cu[1], esc(cu[2]), esc(cu[3]), v, i2, r, e, score, date, esc(what), esc(summary)
    }
    END { if (bad) exit 3 }'
}

# Merges the note lines read on stdin into a notes file: same issue number = replaced,
# the file is kept sorted by issue number.
merge_into() { # file
  awk -v file="$1" '
    function num(l) { return match(l, /"n":[0-9]+/) ? substr(l, RSTART + 4, RLENGTH - 4) + 0 : -1 }
    BEGIN {
      while ((getline l < file) > 0) { k = num(l); if (k >= 0) { if (!(k in line)) keys[++cnt] = k; line[k] = l } }
      close(file)
    }
    { k = num($0); if (k >= 0) { if (!(k in line)) keys[++cnt] = k; line[k] = $0 } }
    END {
      for (a = 2; a <= cnt; a++) { t = keys[a]; b = a - 1; while (b >= 1 && keys[b] > t) { keys[b + 1] = keys[b]; b-- } keys[b + 1] = t }
      for (a = 1; a <= cnt; a++) print line[keys[a]]
    }'
}

status=0
json=$(to_json) || status=1
if [[ -z $json ]]; then
  echo "No note recorded." >&2
  exit 1
fi

if [[ $ROLE == member ]]; then
  echo "NOT WRITTEN: this repository is a member of the portfolio. Run record-note.sh from the hub $HUB."
  echo "Lines to put in the hub, in $NOTES_DIR/<owner>-<repo>.jsonl:"
  echo "$json"
  exit 2
fi

while IFS= read -r repo; do
  f=$(notes_path "$repo")
  mkdir -p "$NOTES_DIR"
  tmp=$(mktemp)
  # Only the lines of this repository, the JSON after the first tab.
  if ! awk -F'\t' -v r="$repo" '$1 == r { print substr($0, length(r) + 2) }' <<<"$json" | merge_into "$f" >"$tmp"; then
    rm -f "$tmp"
    exit 1
  fi
  mv "$tmp" "$f"
  echo "Recorded $(awk -F'\t' -v r="$repo" '$1 == r' <<<"$json" | wc -l | tr -d ' ') note(s) in $f"
done < <(cut -f1 <<<"$json" | sort -u)

exit "$status"
