#!/usr/bin/env bash
# Collect commits + PRs for a given work day (or range) across all local repos.
# A work day runs 06:00 to 05:59 the next morning, so a late-night session stays
# on the day it started.
# Usage: collect.sh [today|yesterday|YYYY-MM-DD|YYYY-MM-DD..YYYY-MM-DD]
# Env:   WORKLOG_ROOTS (colon-separated dirs to scan, one level deep)
#        WORKLOG_AUTHOR (git --author regex; defaults to first word of git user.name)
#        WORKLOG_DAY_START_HOUR (day boundary, default 6)
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPEC="${1:-today}"
ROOTS="${WORKLOG_ROOTS:-$HOME/Work:$HOME/Work/neetozone}"
AUTHOR="${WORKLOG_AUTHOR:-$(git config --global user.name 2>/dev/null | awk '{print $1}')}"
AUTHOR="${AUTHOR:-$(whoami)}"
DAY_START="${WORKLOG_DAY_START_HOUR:-6}"
BOUNDARY=$(printf '%02d:00' "$DAY_START")
NL=$'\n'

# Before the boundary the current work day is still yesterday's date, so the
# relative keywords roll back one. Explicit dates are taken literally.
SHIFT=0
[ "$(date +%-H)" -lt "$DAY_START" ] && SHIFT=1
days_ago() { date -v-"$1"d +%F 2>/dev/null || date -d "$1 days ago" +%F; }

case "$SPEC" in
  today)      FROM=$(days_ago "$SHIFT"); TO=$FROM ;;
  yesterday)  FROM=$(days_ago $((SHIFT + 1))); TO=$FROM ;;
  *..*)       FROM="${SPEC%%..*}"; TO="${SPEC##*..}"; SHIFT=0 ;;
  *)          FROM="$SPEC"; TO="$SPEC"; SHIFT=0 ;;
esac
NEXT=$(date -v+1d -j -f %F "$TO" +%F 2>/dev/null || date -d "$TO +1 day" +%F)
PREV=$(date -v-1d -j -f %F "$FROM" +%F 2>/dev/null || date -d "$FROM -1 day" +%F)

# Header dates are always DD-MM-YYYY. Multi-day runs stamp each commit with the day it belongs to.
fmt_header() { date -j -f %F "$1" +%d-%m-%Y 2>/dev/null || date -d "$1" +%d-%m-%Y; }
if [ "$FROM" = "$TO" ]; then
  HEADER=$(fmt_header "$FROM"); MODE=day
else
  HEADER="$(fmt_header "$FROM") .. $(fmt_header "$TO")"; MODE=range
fi

echo "# Work log data: $HEADER (work day $BOUNDARY to $BOUNDARY next morning), author=/$AUTHOR/i"
echo "# Header to use in the log output: $HEADER"
[ "$SHIFT" = 1 ] && echo "# note: it is before $BOUNDARY, so \"$SPEC\" resolves to $HEADER"

# --- Discover repos, resolving each remote exactly once
declare -a DIRS=() SLUGS=()
IFS=: read -r -a ROOT_LIST <<<"$ROOTS"
for root in "${ROOT_LIST[@]}"; do
  [ -d "$root" ] || continue
  for d in "$root"/*/; do
    r="${d%/}"
    url=$(git -C "$r" config --get remote.origin.url 2>/dev/null)
    if [ -z "$url" ]; then
      git -C "$r" rev-parse --git-dir >/dev/null 2>&1 || continue
    fi
    slug="${url#git@github.com:}"; slug="${slug#https://github.com/}"; slug="${slug%.git}"
    DIRS+=("$r"); SLUGS+=("$slug")
  done
done

# One directory per remote, preferring the one named after the repo (skips worktrees).
declare -a REPOS=()
seen_slugs="$NL"
for i in "${!DIRS[@]}"; do
  slug="${SLUGS[$i]}"
  key="${slug:-${DIRS[$i]}}"
  case "$seen_slugs" in *"$NL$key$NL"*) continue ;; esac
  seen_slugs="$seen_slugs$key$NL"
  best="${DIRS[$i]}"
  if [ -n "$slug" ]; then
    for j in "${!DIRS[@]}"; do
      if [ "${SLUGS[$j]}" = "$slug" ] && [ "${DIRS[$j]##*/}" = "${slug##*/}" ]; then
        best="${DIRS[$j]}"; break
      fi
    done
  fi
  REPOS+=("$best|$slug")
done

# --- Scan every repo at once; the log walks are independent and IO-bound
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
for i in "${!REPOS[@]}"; do
  entry="${REPOS[$i]}"
  git -C "${entry%%|*}" log --all --source --regexp-ignore-case \
      --author="$AUTHOR" --since="$FROM $BOUNDARY" --until="$NEXT $BOUNDARY" \
      --pretty=format:'%h|%S|%at|%P|%s' >"$TMP/$i" 2>/dev/null &
done
wait

declare -a PR_REFS=()
for i in "${!REPOS[@]}"; do
  entry="${REPOS[$i]}"
  r="${entry%%|*}"; slug="${entry##*|}"
  raw=$(<"$TMP/$i")
  [ -z "$raw" ] && continue

  echo
  echo "## repo: ${r##*/}  [${slug:-no-remote}]"
  printf '%s\n' "$raw" | python3 "$HERE/format_commits.py" "$MODE" "$DAY_START"

  branches=$(printf '%s\n' "$raw" | awk -F'|' 'NF{print $2}' \
             | sed -E 's#^(refs/heads/|refs/remotes/[^/]+/)##' | sort -u)
  for b in $branches; do
    case "$b" in main|master|production|stable|HEAD|"") continue ;; esac
    [ -n "$slug" ] && PR_REFS+=("$slug|head|$b")
  done
  while read -r n; do
    [ -n "$n" ] && [ -n "$slug" ] && PR_REFS+=("$slug|num|$n")
  done < <(printf '%s\n' "$raw" | grep -oE '\(#[0-9]+\)' | tr -d '(#)')
done

echo
echo "# ---- Pull requests ----"
command -v gh >/dev/null 2>&1 || { echo "gh not installed; skipping PR lookup"; exit 0; }

seen_prs="$NL"
emit_pr() { # slug number
  local key="$1#$2"
  case "$seen_prs" in *"$NL$key$NL"*) return ;; esac
  seen_prs="$seen_prs$key$NL"
  gh pr view "$2" -R "$1" --json number,title,state,url,author,body 2>/dev/null \
    | python3 "$HERE/format_pr.py"
}

for ref in $(printf '%s\n' "${PR_REFS[@]:-}" | awk 'NF && !seen[$0]++'); do
  IFS='|' read -r slug kind val <<<"$ref"
  if [ "$kind" = "num" ]; then
    emit_pr "$slug" "$val"
  else
    # --head hits the REST list endpoint, so it never lags behind the search index.
    for n in $(gh pr list -R "$slug" --state all --limit 5 --head "$val" --json number --jq '.[].number' 2>/dev/null); do
      emit_pr "$slug" "$n"
    done
  fi
done

echo
echo "# ---- Your PRs closed/merged in the window (catches review-only and triage work) ----"
gh search prs --author=@me --closed="$PREV..$NEXT" --limit 200 \
  --json number,title,repository,state,closedAt 2>/dev/null \
  | python3 "$HERE/filter_closed.py" "$FROM" "$TO" "$DAY_START"
