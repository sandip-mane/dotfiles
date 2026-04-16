# Triggers a version bump by creating an empty commit on a branch, opening a PR with patch/frontend/backend labels, and merging it
bump_version() (
  export HUSKY=0
  BUMP_BRANCH="bump-version-$(date +%Y-%m-%d-%H%M%S)"

  gco main || return 1
  gl || return 1

  gcb $BUMP_BRANCH || return 1
  git commit --allow-empty -m "Trigger version bump" || return 1
  ggp --no-verify || return 1

  gh pr create --title "Trigger version bump" --body " " --label "patch,frontend,backend" || return 1
  gh pr merge --squash --delete-branch --admin || return 1

  gco main || return 1
  gl || return 1
  gbD $BUMP_BRANCH 2>/dev/null
)
