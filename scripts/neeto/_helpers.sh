# Shared progress display helper for release scripts
show_progress() {
  local pretext="$1"
  local current_step="$2"
  local failed_step="$3"
  shift 3
  local steps=("$@")
  local total_steps=${#steps[@]}

  # Clear screen and move cursor to top
  printf "\033[2J\033[H"

  echo "$pretext"
  echo ""

  for i in $(seq 1 $((total_steps))); do
    local step_text="${steps[$i]}"
    local step_number=$((i))
    if [ $failed_step -eq $step_number ] && [ $step_number -eq $current_step ]; then
      echo -e "\033[31m❌ $step_number. $step_text - FAILED\033[0m"
    elif [ $step_number -lt $current_step ]; then
      echo "✅ $step_number. $step_text"
    elif [ $step_number -eq $current_step ]; then
      echo "-> $step_number. $step_text"
    else
      echo "☑️ $step_number. $step_text"
    fi
  done
  echo ""
}
