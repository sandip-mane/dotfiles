# Creates a new release branch and opens a pull request
release() {
  REPO_NAME=$(basename $(pwd))
  RELEASE_BRANCH=$(date "+release-%Y-%m-%d")
  BASE_BRANCH=production
  if [[ $REPO_NAME == *"widget"* ]] ;then
    BASE_BRANCH=stable
  fi

  # NOTE on SKIP_INSTALL_COMMANDS_AFTER_PULL=true prefix below: husky
  # post-checkout/post-merge auto-runs `yarn install` (and `bundle install`)
  # when lockfiles differ, which dirties the working tree mid-flow. The helper
  # at .husky/helpers/run_install_commands.sh honors this env var.

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

  # Pre-flight: refuse to run with a dirty working tree. A later `git merge`
  # would abort with "Your local changes would be overwritten" and leave the
  # repo on the release branch in a half-done state.
  if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "❌ Cannot run release: uncommitted changes detected"
    echo ""
    git status --short
    echo ""
    echo "⚠️  Commit, stash, or discard these changes before running release."
    return 1
  fi

  # Show initial status
  show_progress "$pretext" 1 0 "${release_steps[@]}"

  # Step 1: Switch to production branch
  if ! SKIP_INSTALL_COMMANDS_AFTER_PULL=true gco $BASE_BRANCH >/dev/null 2>&1; then
    show_progress "$pretext" 1 1 "${release_steps[@]}"
    echo "❌ Failed to switch to $BASE_BRANCH branch"
    return 1
  fi
  show_progress "$pretext" 2 0 "${release_steps[@]}"

  # Step 2: Pull latest changes from production
  if ! SKIP_INSTALL_COMMANDS_AFTER_PULL=true gl >/dev/null 2>&1; then
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
  if ! SKIP_INSTALL_COMMANDS_AFTER_PULL=true gcb $RELEASE_BRANCH >/dev/null 2>&1 && ! SKIP_INSTALL_COMMANDS_AFTER_PULL=true gco $RELEASE_BRANCH >/dev/null 2>&1; then
    show_progress "$pretext" 4 1 "${release_steps[@]}"
    echo "❌ Failed to create/switch to release branch: $RELEASE_BRANCH"
    return 1
  fi
  show_progress "$pretext" 5 0 "${release_steps[@]}"

  # Step 5: Merge main into release branch (prefer main's changes to override production)
  local merge_output
  merge_output=$(SKIP_INSTALL_COMMANDS_AFTER_PULL=true git merge origin/main -X theirs --no-edit 2>&1)
  if [ $? -ne 0 ]; then
    # When production and main share no common ancestor, git falls back to a
    # 2-way merge that cannot distinguish "deleted in main" from "never existed
    # in main", so files deleted on main are wrongly retained on the release.
    # Workaround: merge with --allow-unrelated-histories, then snap the tree to
    # match origin/main exactly while keeping the merge commit's parentage.
    if echo "$merge_output" | grep -q "refusing to merge unrelated histories"; then
      if ! SKIP_INSTALL_COMMANDS_AFTER_PULL=true git merge origin/main -X theirs --no-edit --allow-unrelated-histories >/dev/null 2>&1; then
        show_progress "$pretext" 5 1 "${release_steps[@]}"
        echo "❌ Failed to merge main into release branch (unrelated histories)"
        echo "⚠️  You may need to resolve conflicts manually"
        return 1
      fi
      if ! git read-tree -u --reset origin/main >/dev/null 2>&1; then
        show_progress "$pretext" 5 1 "${release_steps[@]}"
        echo "❌ Failed to sync release tree to main"
        return 1
      fi
      if ! git commit --amend --no-edit --allow-empty >/dev/null 2>&1; then
        show_progress "$pretext" 5 1 "${release_steps[@]}"
        echo "❌ Failed to amend merge commit with synced tree"
        return 1
      fi
    else
      show_progress "$pretext" 5 1 "${release_steps[@]}"
      echo "❌ Failed to merge main into release branch"
      echo ""
      echo "$merge_output"
      echo ""
      echo "⚠️  You may need to resolve conflicts manually"
      return 1
    fi
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
    # Subjects of every squashed PR going out in this release, oldest first.
    local release_subjects automated_subjects manual_subjects release_body
    local automated_pattern='^\[(neeto-translate|Playwright)\]|^Automated rollout|^Bump '
    release_subjects=$(git log --no-merges --reverse --format="%s" $BASE_BRANCH..HEAD)
    automated_subjects=$(printf '%s\n' "$release_subjects" | grep -E "$automated_pattern")
    manual_subjects=$(printf '%s\n' "$release_subjects" | grep -vE "$automated_pattern")

    # GitHub renders a bare "#1234" as the PR title, so the subject is redundant.
    local to_bullets='{ if (match($0, /\(#[0-9]+\)$/)) print "- #" substr($0, RSTART + 2, RLENGTH - 3); else print "- " $0 }'

    release_body=""
    if [ -n "$manual_subjects" ]; then
      release_body+="## Changes"$'\n\n'"$(printf '%s\n' "$manual_subjects" | awk "$to_bullets")"$'\n\n'
    fi
    if [ -n "$automated_subjects" ]; then
      release_body+="## Automated"$'\n\n'"$(printf '%s\n' "$automated_subjects" | awk "$to_bullets")"
    fi

    if [ -z "$release_body" ]; then
      release_body="No changes since the last release."
    fi

    if ! gh pr create --base $BASE_BRANCH --title "$(date "+Release %Y-%m-%d")" --body "$release_body" >/dev/null 2>&1; then
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
