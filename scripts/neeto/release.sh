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
