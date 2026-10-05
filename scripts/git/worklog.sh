# Runs /work-log headlessly and prints the log (worklog [today | yesterday | YYYY-MM-DD | range])
worklog() {
  claude -p "/work-log ${*:-today}" \
    --allowedTools "Bash($HOME/.claude/skills/work-log/collect.sh:*)" \
      "Bash(gh pr view:*)" "Bash(gh pr list:*)" "Bash(gh search:*)" "Bash(gh issue view:*)" \
    < /dev/null
}
