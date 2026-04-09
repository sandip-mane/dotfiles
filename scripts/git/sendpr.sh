# Creates a pull request with automatic issue linking and opens it in browser
sendpr() {
  REPO_NAME=$(basename $(pwd))
  ISSUE=$(git branch --show-current | cut -d "-" -f 1)
  BODY=" "
  if [[ $ISSUE =~ '^[0-9]+$' ]] ;then
    BODY="fixes #${ISSUE}"
  fi
  ggp --no-verify
  if [[ "$REPO_NAME" != *web* ]]; then
    gh pr create --fill-first --body "$BODY" --label "patch"
  else
    gh pr create --fill-first --body "$BODY"
  fi
  gh pr view --web
  commitlog
}
