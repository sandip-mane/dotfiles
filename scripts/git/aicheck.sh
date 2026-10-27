# Starts (or resumes) a named Claude session that checks whether a PR fully fixes a GitHub issue
aicheck() {
  local url="$1"

  if [[ ! "$url" =~ '^https://github\.com/([^/]+)/([^/]+)/issues/([0-9]+)' ]]; then
    echo "usage: aicheck https://github.com/<owner>/<repo>/issues/<number>"
    return 1
  fi

  local issue_number="${match[3]}"
  local hash=$(print -n "aicheck:${match[1]}/${match[2]}#${issue_number}" | md5)
  local session_id="${hash:0:8}-${hash:8:4}-4${hash:13:3}-a${hash:17:3}-${hash:20:12}"
  local session_files=(~/.claude/projects/*/"${session_id}".jsonl(N))

  if (( ${#session_files} )); then
    local session_cwd=$(jq -r 'select(.cwd) | .cwd' "${session_files[1]}" | head -1)
    (cd "${session_cwd:-$PWD}" && claude --resume "$session_id")
  else
    local prompt="Investigate the GitHub issue $MATCH: read it with all its comments and linked context, then trace the reported problem in the code to its root cause. \
Find the PR that addresses this issue; if one exists, review it with the /pr-review skill. \
Then verify whether the PR fully resolves the issue: list every scenario the issue describes or implies, mark each as covered or missed by the PR, and call out any edge cases or related code paths it leaves unhandled. \
Do not change any code."
    claude --session-id "$session_id" --name "Issue Check #${issue_number}" "$prompt"
  fi
}
