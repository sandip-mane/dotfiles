# Starts a named Claude session that runs /pr-review on a GitHub PR URL
aireview() {
  local url="$1"

  if [[ ! "$url" =~ '^https://github\.com/[^/]+/[^/]+/pull/([0-9]+)' ]]; then
    echo "usage: aireview https://github.com/<owner>/<repo>/pull/<number>"
    return 1
  fi

  claude --name "PR Review #${match[1]}" "/pr-review $MATCH"
}
