# Starts (or resumes) a named Claude session that runs /pr-review on a GitHub PR URL
aireview() {
  local url="$1"

  if [[ ! "$url" =~ '^https://github\.com/([^/]+)/([^/]+)/pull/([0-9]+)' ]]; then
    echo "usage: aireview https://github.com/<owner>/<repo>/pull/<number>"
    return 1
  fi

  local pr_number="${match[3]}"
  local hash=$(print -n "aireview:${match[1]}/${match[2]}#${pr_number}" | md5)
  local session_id="${hash:0:8}-${hash:8:4}-4${hash:13:3}-a${hash:17:3}-${hash:20:12}"
  local session_files=(~/.claude/projects/*/"${session_id}".jsonl(N))

  if (( ${#session_files} )); then
    local session_cwd=$(jq -r 'select(.cwd) | .cwd' "${session_files[1]}" | head -1)
    (cd "${session_cwd:-$PWD}" && claude --resume "$session_id")
  else
    claude --session-id "$session_id" --name "PR Review #${pr_number}" "/pr-review $MATCH"
  fi
}
