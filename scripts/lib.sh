# shellcheck shell=bash
# zps-pareto plugin - shared helpers, sourced by the other scripts (not executed directly).
# Written for bash 3.2+ (macOS default) as well as Git Bash on Windows.
# The variables set here are used by the scripts that source this file.
# shellcheck disable=SC2034

RULES_FILE=".claude/pareto.md"
# Reading notes ("fiches de lecture"): one JSON line per issue, kept in the hub (or in the
# standalone repository), one file per scored repository: .claude/pareto-notes/<owner>-<repo>.jsonl
NOTES_DIR=".claude/pareto-notes"
REPO_RE='[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+'
# How many comments of an issue are fetched. One value for list-issues.sh and read-issue.sh: the
# cursor kept in a reading note (last comment, last edit) is computed on this window by the
# second and compared with the one computed by the first, so the two must see the same comments.
COMMENTS_WINDOW=100

# Moves to the root of the git repository containing the current directory (nothing to do outside
# a git repository). The rules file and the reading notes are looked up relative to the root, so
# a script run from a sub-folder behaves as if run from the root. Call it before load_context.
goto_root() {
  local top
  top=$(git rev-parse --show-toplevel 2>/dev/null) || return 0
  [[ -z $top ]] || cd "$top" || return 1
}

# Default GitHub label of each class, overridden by a "## Labels" table in .claude/pareto.md.
DEFAULT_LABELS="P0=pareto:P0
P1=pareto:P1
P2=pareto:P2
quick-win=pareto:quick-win
request=pareto:request"

# owner/repo of the current directory, empty when not in a GitHub repository.
current_repo() {
  gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null || true
}

# Hub named in a rules file by a "Portfolio hub: owner/repo" line, empty if none.
hub_of() {
  grep -m1 -oE "^Portfolio hub: *$REPO_RE" "$1" 2>/dev/null | sed -E 's/^Portfolio hub: *//' || true
}

# Rules file of another repository, read through the GitHub API.
fetch_rules() {
  gh api "repos/$1/contents/$RULES_FILE" -H "Accept: application/vnd.github.raw" 2>/dev/null
}

# Repositories listed in the "## Portfolio" table of the rules read on stdin, one per line.
portfolio_repos() {
  awk '/^## /{p=($0 ~ /^## Portfolio/)} p && /^\|/' | cut -d'|' -f2 | tr -d ' `' | grep -E "^$REPO_RE$" || true
}

# class=label lines from the "## Labels" table of the rules read on stdin.
label_overrides() {
  awk -F'|' '/^## /{p=($0 ~ /^## Labels/)} p && /^\|/ {
    c=$2; l=$3
    gsub(/^[ \t`]+|[ \t`]+$/, "", c); gsub(/^[ \t`]+|[ \t`]+$/, "", l)
    if (c ~ /^(P0|P1|P2|quick-win|request)$/ && l != "") print c "=" l
  }'
}

# class=label lines for a repository: plugin defaults, then the hub's table, then the
# repository's own table (the last one wins). Requires load_context.
labels_for() {
  local rules=""
  if [[ $1 == "$HERE" ]]; then
    rules=$LOCAL_RULES
  else
    rules=$(fetch_rules "$1") || rules=""
  fi
  {
    echo "$DEFAULT_LABELS"
    label_overrides <<<"$HUB_RULES"
    label_overrides <<<"$rules"
  } | awk -F= '{ k=$1; v=substr($0, index($0, "=") + 1); if (!(k in m)) o[++n]=k; m[k]=v }
               END { for (i=1; i<=n; i++) print o[i] "=" m[o[i]] }'
}

# Label of one class, from class=label lines read on stdin.
label_of() {
  awk -v k="$1" 'index($0, k "=") == 1 { print substr($0, length(k) + 2) }'
}

# jq program turning the GraphQL issues page into list-issues.sh lines.
# Arguments: repo, then the labels of P0, P1, P2 and quick-win in that repository, then
# optionally "detail" to add the V, I, R, E factors of the last score comment after the score
# ("-" when the comment does not carry them), then optionally "cursor" to add, right after the
# status, what a reading note is compared with: <last comment id>@<last edit>@<updatedAt>
# (the last comment is the last one that is not a score comment; 0 and "-" when there is none).
# A score comment is followed by nothing but GitHub's own bookkeeping: allow 2 minutes
# between the comment and the issue's updatedAt before calling the issue stale.
issues_jq_filter() {
  cat <<EOF
def cls: if . == "$2" then "P0" elif . == "$3" then "P1" elif . == "$4" then "P2" else empty end;
.data.repository.issues.nodes[]
| ([.labels.nodes[].name | cls] | first // "-") as \$class
| (if any(.labels.nodes[].name; . == "$5") then "quick-win" else "-" end) as \$tag
| ([.comments.nodes[] | select(.body | startswith("Pareto score:"))] | last) as \$last
| (if \$last == null then (if \$class == "-" then "new" else "stale" end)
   elif ((.updatedAt | fromdate) - (\$last.createdAt | fromdate)) > 120 then "stale"
   else "scored" end) as \$status
| ((((\$last.body // "") | capture("^Pareto score: *(?<s>[0-9]+([.][0-9]+)?)") | .s)) // "-") as \$score
| ((((\$last.body // "") | capture("[(]V(?<v>[0-9]+([.][0-9]+)?) x I(?<i>[0-9]+([.][0-9]+)?) x R(?<r>[0-9]+([.][0-9]+)?) / E(?<e>[0-9]+([.][0-9]+)?)"))) // {}) as \$f
| ([.comments.nodes[] | select((.body // "") | startswith("Pareto score:") | not) | .databaseId] | map(select(. != null)) | max // 0) as \$lc
| ([.lastEditedAt] + [.comments.nodes[].lastEditedAt] | map(select(. != null)) | max // "-") as \$ed
| (if "${7:-}" == "cursor" then " | \(\$lc)@\(\$ed)@\(.updatedAt)" else "" end) as \$cur
| (if "${6:-}" == "detail" then " | \(\$f.v // "-") | \(\$f.i // "-") | \(\$f.r // "-") | \(\$f.e // "-")" else "" end) as \$extra
| "$1#\(.number) | \(\$status)\(\$cur) | \(\$class) | \(\$tag) | \(\$score)\(\$extra) | \(.updatedAt[0:10]) | \(.title)"
EOF
}

# Sets HERE, ROLE (single | hub | member), HUB, LOCAL_RULES, HUB_RULES (the hub's rules, also
# in the hub itself) and PORTFOLIO.
load_context() {
  HERE=$(current_repo)
  HUB=""
  LOCAL_RULES=""
  HUB_RULES=""
  if [[ -f $RULES_FILE ]]; then
    LOCAL_RULES=$(cat "$RULES_FILE")
    HUB=$(hub_of "$RULES_FILE")
    if [[ -n $HUB ]]; then
      HUB_RULES=$(fetch_rules "$HUB") || HUB_RULES=""
    fi
  fi

  if [[ -n $HUB ]]; then
    ROLE=member
    PORTFOLIO=$(portfolio_repos <<<"$HUB_RULES")
  else
    PORTFOLIO=$(portfolio_repos <<<"$LOCAL_RULES")
    if [[ -n $PORTFOLIO ]]; then
      ROLE=hub
      HUB=$HERE
      HUB_RULES=$LOCAL_RULES
    else
      ROLE=single
    fi
  fi
}

# Path of the reading-notes file of a repository, relative to the hub root.
notes_path() {
  echo "$NOTES_DIR/${1/\//-}.jsonl"
}

# Reading notes of a repository on stdout (empty when there are none): the local file when this
# clone has it (hub or standalone repository), otherwise the hub's file through the API.
# Requires load_context.
notes_for() {
  local f out err
  f=$(notes_path "$1")
  if [[ -f $f ]]; then
    tr -d '\r' <"$f"
  elif [[ -n $HUB && $HUB != "$HERE" ]]; then
    err=$(mktemp)
    if out=$(gh api "repos/$HUB/contents/$f" -H "Accept: application/vnd.github.raw" 2>"$err"); then
      tr -d '\r' <<<"$out"
    elif ! grep -qE 'HTTP 404|Not Found' "$err"; then
      # Not "no notes yet" (a 404): authentication, quota or network. Say it, on stderr.
      echo "# warning: reading notes unreadable ($(head -n 1 "$err" | tr -d '\r' | cut -c1-200)), every changed issue will be read in full" >&2
    fi
    rm -f "$err"
  fi
}

# Joins the issue lines of list-issues (read on stdin, produced by issues_jq_filter in "cursor"
# mode) with the reading notes of the repository, and decides how much of each issue must be read
# again. Arguments: notes file, "detail" if the factors are present, "what" to add the one-line
# description kept in the note (before the updated date, "-" when there is no note).
# Input:  repo#n | status | cursor | class | tag | score [| V | I | R | E] | updated | title
# Output: repo#n | status | read | class | tag | score [| V | I | R | E] [| what] | updated | title
#   read: full    = the whole issue must be read (never read, or edited since the note)
#         partial = the note plus the comments after the note's last one
#         none    = nothing to read
# With a note, the status ignores what the triage itself does (labels, "Pareto score:" comment):
# only a new comment, an edit, or another change after the note makes the issue stale.
apply_notes() {
  awk -v notes="$1" -v detail="${2:-}" -v what="${3:-}" '
    # Identifiers are compared as digit strings (no leading zero): comment ids go past 2^31 and
    # some awks print large numbers in exponent form.
    function gt(a, b) { return length(a) > length(b) || (length(a) == length(b) && (a "") > (b "")) }
    BEGIN {
      FS = " [|] "; OFS = " | "
      while ((getline line < notes) > 0) {
        if (!match(line, /"n":[0-9]+/)) continue
        n = substr(line, RSTART + 4, RLENGTH - 4)
        lc[n] = "0"; ed[n] = ""; up[n] = ""; wh[n] = "-"
        if (match(line, /"lastComment":[0-9]+/)) lc[n] = substr(line, RSTART + 14, RLENGTH - 14)
        if (match(line, /"edited":"[^"]*"/)) ed[n] = substr(line, RSTART + 10, RLENGTH - 11)
        if (match(line, /"updatedAt":"[^"]*"/)) up[n] = substr(line, RSTART + 13, RLENGTH - 14)
        if (match(line, /"what":"[^"]*"/)) wh[n] = substr(line, RSTART + 8, RLENGTH - 9)
      }
      close(notes)
      updated = (detail == "detail") ? 11 : 7
    }
    {
      sub(/\r$/, "")
      num = $1; sub(/^[^#]*#/, "", num)
      st = $2; rd = "none"
      split($3, cu, "@")
      if (st == "new") {
        rd = "full"
      } else if (num in lc) {
        if (cu[2] != ed[num]) { st = "stale"; rd = "full" }
        else if (gt(cu[1], lc[num])) { st = "stale"; rd = "partial" }
        else if (st == "stale" && cu[3] != up[num]) { rd = "partial" }
        else { st = "scored" }
      } else if (st == "stale") {
        rd = "full"
      }
      out = $1 OFS st OFS rd
      for (i = 4; i <= NF; i++) {
        if (what == "what" && i == updated) out = out OFS ((num in wh) ? wh[num] : "-")
        out = out OFS $i
      }
      print out
    }'
}
