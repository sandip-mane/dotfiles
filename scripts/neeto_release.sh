# This script is used to release a new version of the application.
# It creates a new release branch, pushes it to the remote repository, and creates a pull request to the base branch.
# It also deploys the application to the production environment.

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

# Creates a new release branch and opens a pull request
release() {
  REPO_NAME=$(basename $(pwd))
  RELEASE_BRANCH=$(date "+release-%Y-%m-%d")
  BASE_BRANCH=production
  if [[ $REPO_NAME == *"widget"* ]] ;then
    BASE_BRANCH=stable
  fi
  
  # Define steps array
  local release_steps=(
    "Switch to production branch"
    "Pull latest changes from production"
    "Pull latest changes from main"
    "Create release branch from production"
    "Merge main into release branch"
    "Push release branch"
    "Create pull request"
    "Open pull request in browser"
  )
  
  # Create pretext for this operation
  local pretext="Release project: $REPO_NAME\nTarget branch: $BASE_BRANCH\nStrategy: Merge main into production-based release"
  
  # Show initial status
  show_progress "$pretext" 1 0 "${release_steps[@]}"
  
  # Step 1: Switch to production branch
  if ! gco $BASE_BRANCH >/dev/null 2>&1; then
    show_progress "$pretext" 1 1 "${release_steps[@]}"
    echo "❌ Failed to switch to $BASE_BRANCH branch"
    return 1
  fi
  show_progress "$pretext" 2 0 "${release_steps[@]}"
  
  # Step 2: Pull latest changes from production
  if ! gl >/dev/null 2>&1; then
    show_progress "$pretext" 2 1 "${release_steps[@]}"
    echo "❌ Failed to pull latest changes from $BASE_BRANCH"
    return 1
  fi
  show_progress "$pretext" 3 0 "${release_steps[@]}"
  
  # Step 3: Pull latest changes from main (to ensure we have latest main)
  if ! git fetch origin main >/dev/null 2>&1; then
    show_progress "$pretext" 3 1 "${release_steps[@]}"
    echo "❌ Failed to fetch latest changes from main"
    return 1
  fi
  show_progress "$pretext" 4 0 "${release_steps[@]}"
  
  # Step 4: Create release branch from production
  if ! gcb $RELEASE_BRANCH >/dev/null 2>&1 && ! gco $RELEASE_BRANCH >/dev/null 2>&1; then
    show_progress "$pretext" 4 1 "${release_steps[@]}"
    echo "❌ Failed to create/switch to release branch: $RELEASE_BRANCH"
    return 1
  fi
  show_progress "$pretext" 5 0 "${release_steps[@]}"
  
  # Step 5: Merge main into release branch (prefer main's changes to override production)
  if ! git merge origin/main -X theirs --no-edit >/dev/null 2>&1; then
    show_progress "$pretext" 5 1 "${release_steps[@]}"
    echo "❌ Failed to merge main into release branch"
    echo "⚠️  You may need to resolve conflicts manually"
    return 1
  fi
  show_progress "$pretext" 6 0 "${release_steps[@]}"
  
  # Step 6: Push release branch
  if ! ggp --no-verify >/dev/null 2>&1; then
    show_progress "$pretext" 6 1 "${release_steps[@]}"
    echo "❌ Failed to push release branch"
    return 1
  fi
  show_progress "$pretext" 7 0 "${release_steps[@]}"
  
  # Step 7: Create pull request
  # Check if a pull request already exists for this branch
  if gh pr list --head $RELEASE_BRANCH --base $BASE_BRANCH --json url --jq '.[0].url' 2>/dev/null | grep -q .; then
    echo "ℹ️  Pull request already exists for $RELEASE_BRANCH - skipping creation"
  else
    if ! gh pr create --fill --base $BASE_BRANCH --title "$(date "+Release %Y-%m-%d")" >/dev/null 2>&1; then
      show_progress "$pretext" 7 1 "${release_steps[@]}"
      echo "❌ Failed to create pull request"
      return 1
    fi
  fi
  show_progress "$pretext" 8 0 "${release_steps[@]}"
  
  # Step 8: Open pull request in browser
  if ! gh pr view --web >/dev/null 2>&1; then
    show_progress "$pretext" 8 1 "${release_steps[@]}"
    echo "❌ Failed to open pull request in browser"
    return 1
  fi
  show_progress "$pretext" 9 0 "${release_steps[@]}"
}

# Deploys the release
deploy() {
  REPO_NAME=$(basename $(pwd))
  RELEASE_PREFIX=$(date "+release-%Y-%m-%d")
  RELEASE_BRANCH=$RELEASE_PREFIX
  BASE_BRANCH=production
  if [[ $REPO_NAME == *"widget"* ]] ;then
    BASE_BRANCH=stable
  fi

  # Prefer a matching micro release branch if present locally
  if git show-ref --verify --quiet "refs/heads/${RELEASE_PREFIX}-micro"; then
    RELEASE_BRANCH="${RELEASE_PREFIX}-micro"
  fi
  
  # Define steps array
  local deploy_steps=(
    "Switch to release branch"
    "Pull latest changes"
    "Merge release branch"
    "Push to remote"
    "Delete local release branch"
    "Switch back to main"
  )
  
  # Create pretext for this operation
  local pretext="Deploying project: $REPO_NAME"
  
  # Show initial status
  show_progress "$pretext" 1 0 "${deploy_steps[@]}"
  
  # Step 1: Switch to release branch
  if ! gco $BASE_BRANCH >/dev/null 2>&1; then
    show_progress "$pretext" 1 1 "${deploy_steps[@]}"
    echo "❌ Failed to switch to release branch: $BASE_BRANCH"
    return 1
  fi
  show_progress "$pretext" 2 0 "${deploy_steps[@]}"
  
  # Step 2: Pull latest changes
  if ! gl >/dev/null 2>&1; then
    show_progress "$pretext" 2 1 "${deploy_steps[@]}"
    echo "❌ Failed to pull latest changes"
    return 1
  fi
  show_progress "$pretext" 3 0 "${deploy_steps[@]}"
  
  # Step 3: Merge release branch
  if ! gm $RELEASE_BRANCH --no-edit >/dev/null 2>&1; then
    show_progress "$pretext" 3 1 "${deploy_steps[@]}"
    echo "❌ Failed to merge release branch: $RELEASE_BRANCH"
    return 1
  fi
  show_progress "$pretext" 4 0 "${deploy_steps[@]}"
  
  # Step 4: Push to remote
  if ! ggpnp --no-verify >/dev/null 2>&1; then
    show_progress "$pretext" 4 1 "${deploy_steps[@]}"
    echo "❌ Failed to push to remote"
    return 1
  fi
  show_progress "$pretext" 5 0 "${deploy_steps[@]}"
  
  # Step 5: Delete local release branch
  if ! gbD $RELEASE_BRANCH >/dev/null 2>&1; then
    show_progress "$pretext" 5 1 "${deploy_steps[@]}"
    echo "❌ Failed to delete local release branch: $RELEASE_BRANCH"
    return 1
  fi
  show_progress "$pretext" 6 0 "${deploy_steps[@]}"
  
  # Step 6: Switch back to main
  if ! gcm >/dev/null 2>&1; then
    show_progress "$pretext" 6 1 "${deploy_steps[@]}"
    echo "❌ Failed to switch back to main branch"
    return 1
  fi
  show_progress "$pretext" 7 0 "${deploy_steps[@]}"
}

# Creates a cherry-picked micro release from production and opens a PR
release_micro() {
  REPO_NAME=$(basename $(pwd))
  RELEASE_BRANCH=$(date "+release-%Y-%m-%d-micro")
  BASE_BRANCH=production
  if [[ $REPO_NAME == *"widget"* ]] ;then
    BASE_BRANCH=stable
  fi

  local commit_hashes=()

  prompt_read() {
    local __prompt="$1"
    shift
    if [ -n "$BASH_VERSION" ]; then
      read -r -p "$__prompt" "$@"
    else
      printf "%s" "$__prompt"
      read -r "$@"
    fi
  }

  # if ! git fetch origin main $BASE_BRANCH >/dev/null 2>&1; then
  #   echo "❌ Failed to fetch main/$BASE_BRANCH. Please check your network or remotes."
  #   return 1
  # fi

  # Try to use interactive picker (fzf) by default, fall back to manual entry if not available
  if command -v fzf >/dev/null 2>&1; then
    # Use remote refs to avoid missing local branches
    picks=$(git log --oneline origin/$BASE_BRANCH..origin/main \
      | fzf --multi \
            --prompt="Pick commits to cherry-pick > " \
            --header="Tab select/unselect | Enter submit | Esc cancel" \
            --color="fg:#d8dee9,bg:#2e3440,hl:#88c0d0,fg+:#eceff4,bg+:#1f3b2b,hl+:#a3e635,info:#81a1c1,prompt:#b48ead,pointer:#22c55e,marker:#a3e635,spinner:#b48ead,header:#81a1c1" \
            --bind "enter:accept,esc:abort" \
            --print0 \
            --exit-0)
    if [ $? -ne 0 ]; then
      echo "Aborted."
      return 1
    fi
    picks=$(printf "%s" "$picks" | tr '\0' '\n' | awk '{print $1}' | sed '/^$/d')
    if [ -z "$picks" ]; then
      echo "No commits selected. Aborting."
      return 1
    fi
    if [ -n "$BASH_VERSION" ]; then
      read -r -a commit_hashes <<< "$picks"
    else
      commit_hashes=(${=picks})
    fi
  fi

  if [ ${#commit_hashes[@]} -eq 0 ]; then
    prompt_read "Enter commit hashes to cherry-pick (space separated): " commit_input
    if [ -n "$BASH_VERSION" ]; then
      IFS=$' \t\n' read -r -a commit_hashes <<< "$commit_input"
    else
      IFS=$' \t\n' commit_hashes=(${=commit_input})
    fi
  fi

  if [ ${#commit_hashes[@]} -eq 0 ]; then
    echo "No commit hashes provided. Aborting."
    return 1
  fi

  local micro_steps=(
    "Switch to production branch"
    "Pull latest changes"
    "Create micro release branch"
    "Cherry-pick commits"
    "Push release branch"
    "Create pull request"
    "Open pull request in browser"
  )

  local pretext="Micro release: $REPO_NAME\nTarget branch: $BASE_BRANCH\nCherry-picked commits: ${commit_hashes[*]}"
  show_progress "$pretext" 1 0 "${micro_steps[@]}"

  if ! gco $BASE_BRANCH >/dev/null 2>&1; then
    show_progress "$pretext" 1 1 "${micro_steps[@]}"
    echo "❌ Failed to switch to $BASE_BRANCH"
    return 1
  fi
  show_progress "$pretext" 2 0 "${micro_steps[@]}"

  if ! gl >/dev/null 2>&1; then
    show_progress "$pretext" 2 1 "${micro_steps[@]}"
    echo "❌ Failed to pull latest changes"
    return 1
  fi
  show_progress "$pretext" 3 0 "${micro_steps[@]}"

  if ! gcb $RELEASE_BRANCH >/dev/null 2>&1 && ! gco $RELEASE_BRANCH >/dev/null 2>&1; then
    show_progress "$pretext" 3 1 "${micro_steps[@]}"
    echo "❌ Failed to create/switch to release branch: $RELEASE_BRANCH"
    return 1
  fi
  show_progress "$pretext" 4 0 "${micro_steps[@]}"

  for commit_hash in "${commit_hashes[@]}"; do
    if ! git cherry-pick -X theirs "$commit_hash" >/dev/null 2>&1; then
      show_progress "$pretext" 4 1 "${micro_steps[@]}"
      echo "❌ Failed to cherry-pick $commit_hash"
      return 1
    fi
  done
  show_progress "$pretext" 5 0 "${micro_steps[@]}"

  if ! ggp --no-verify >/dev/null 2>&1; then
    show_progress "$pretext" 5 1 "${micro_steps[@]}"
    echo "❌ Failed to push release branch"
    return 1
  fi
  show_progress "$pretext" 6 0 "${micro_steps[@]}"

  if gh pr list --head $RELEASE_BRANCH --base $BASE_BRANCH --json url --jq '.[0].url' 2>/dev/null | grep -q .; then
    echo "ℹ️  Pull request already exists for $RELEASE_BRANCH - skipping creation"
  else
    release_commits=$(git log --format="- %h %s" $BASE_BRANCH..HEAD)
    release_prs=$(git log --format="%s" $BASE_BRANCH..HEAD | grep -oE '#[0-9]+' | sed 's/[#()]//g' | awk '!seen[$0]++')

    if [ -n "$release_prs" ]; then
      printf -v release_body "Cherry-picked changes:\n\n%s" "$(printf '%s\n' $release_prs | sed 's/^/- #/')" 
    else
      printf -v release_body "Cherry-picked changes:\n\n%s" "$release_commits"
    fi

    if ! gh pr create --fill --base $BASE_BRANCH --title "$(date "+Release %Y-%m-%d Micro")" --body "$release_body" >/dev/null 2>&1; then
      show_progress "$pretext" 6 1 "${micro_steps[@]}"
      echo "❌ Failed to create pull request"
      return 1
    fi
  fi
  show_progress "$pretext" 7 0 "${micro_steps[@]}"

  if ! gh pr view --web >/dev/null 2>&1; then
    show_progress "$pretext" 7 1 "${micro_steps[@]}"
    echo "❌ Failed to open pull request in browser"
    return 1
  fi
  show_progress "$pretext" 8 0 "${micro_steps[@]}"
}
