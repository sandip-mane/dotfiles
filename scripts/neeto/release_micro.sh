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
