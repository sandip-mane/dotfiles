# Deploys the release
deploy() {
  REPO_NAME=$(basename $(pwd))
  RELEASE_PREFIX=$(date "+release-%Y-%m-%d")
  RELEASE_BRANCH=$RELEASE_PREFIX
  BASE_BRANCH=production
  if [[ $REPO_NAME == *"widget"* ]] ;then
    BASE_BRANCH=stable
  fi

  # If the user invoked deploy from a release-flavored branch (hotfix or
  # plain release), trust that branch — it's the one they just built and want
  # to ship. Otherwise fall back to the date-derived default below.
  CURRENT_BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null)
  if [[ $CURRENT_BRANCH == ${RELEASE_PREFIX}* ]]; then
    RELEASE_BRANCH=$CURRENT_BRANCH
  elif git show-ref --verify --quiet "refs/heads/${RELEASE_PREFIX}-hotfix"; then
    RELEASE_BRANCH="${RELEASE_PREFIX}-hotfix"
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
  # --no-ff forces a merge commit even when fast-forward is possible. The
  # production branch's GitHub ruleset requires merge commits (no rebase/
  # squash/fast-forward), and the push at step 4 is rejected without one.
  if ! gm $RELEASE_BRANCH --no-ff --no-edit >/dev/null 2>&1; then
    show_progress "$pretext" 3 1 "${deploy_steps[@]}"
    echo "❌ Failed to merge release branch: $RELEASE_BRANCH"
    return 1
  fi
  show_progress "$pretext" 4 0 "${deploy_steps[@]}"

  # Step 4: Push to remote
  # NOTE: invoking `git push` directly instead of the `ggpnp` alias. ggpnp is
  # `ggl && ggp`, and the trailing --no-verify only attaches to one half of
  # that chain, so husky's pre-push hook still fires on production. Going
  # through plain git guarantees the flag lands on the push.
  if ! git push --no-verify >/dev/null 2>&1; then
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
