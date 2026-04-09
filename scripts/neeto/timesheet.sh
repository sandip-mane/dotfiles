# Generates a formatted timesheet from issue references and copies it to clipboard
# Usage: timesheet (then paste multiline input, end with empty line)
timesheet() {
  echo "Copy paste timesheet entries:\n"
  local input=""
  vared input

  local output=""
  local remaining="$input"
  while [[ "$remaining" =~ ([a-zA-Z0-9_-]+)[[:space:]]*-[[:space:]]*#([0-9]+) ]]; do
    local repo="${match[1]:-${BASH_REMATCH[1]}}"
    local issue="${match[2]:-${BASH_REMATCH[2]}}"
    local entry="[${repo}/${issue}](https://github.com/neetozone/${repo}/issues/${issue}) - Done - Day 1"
    if [[ -z "$output" ]]; then
      output="$entry"
    else
      output+=$'\n'"$entry"
    fi
    remaining="${remaining#*#${issue}}"
  done

  if [[ -z "$output" ]]; then
    echo "No valid entries found."
    return 1
  fi

  output=$(echo "$output" | sort)
  echo "$output" | pbcopy
  local COLOR="\033[1;33m"
  local RESET="\033[0m"
  echo "\n${COLOR}Copied to clipboard:\n"
  echo "${COLOR}${output}${RESET}"
}
