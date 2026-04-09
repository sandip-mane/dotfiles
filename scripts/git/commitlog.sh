# Generates and displays a formatted commit log for the current branch
commitlog() {
  ISSUE=$(git branch --show-current | cut -d "-" -f 1)
  if [[ $ISSUE == 'main' || $ISSUE == 'production' ]]; then
    return 42
  fi

  REPO_NAME=$(basename $(pwd))
  COMMITLOG=$(git shortlog --no-merges main..$(git branch --show-current) | sed 1d)
  COMMITLOG=$(echo $COMMITLOG | sed 's/^[[:space:]]*/- /')
  COLOR="\033[1;33m"
  echo "\n"
  echo "${COLOR}NeetoInvoice logs:\n"

  if [[ $ISSUE =~ '^[0-9]+$' ]]; then
    echo "${COLOR}${REPO_NAME} - #${ISSUE}"
  fi
  echo "${COLOR}${COMMITLOG}"
  echo "\n\n"
}
