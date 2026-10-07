# shellcheck shell=bash
# zps-pareto plugin - shared helpers, sourced by the other scripts (not executed directly).
# Written for bash 3.2+ (macOS default) as well as Git Bash on Windows.
# The variables set here are used by the scripts that source this file.
# shellcheck disable=SC2034

RULES_FILE=".claude/pareto.md"
REPO_RE='[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+'

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
# Arguments: repo, then the labels of P0, P1, P2 and quick-win in that repository.
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
| "$1#\(.number) | \(\$status) | \(\$class) | \(\$tag) | \(\$score) | \(.updatedAt[0:10]) | \(.title)"
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
