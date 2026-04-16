bearin() {
  local repo="$HOME/Work/my-bear-notes"

  if [ ! -d "$repo" ]; then
    echo "Cloning my-bear-notes..."
    git clone https://github.com/sandip-mane/my-bear-notes.git "$repo"
  fi

  "$repo/bear.sh" import
}

bearout() {
  local repo="$HOME/Work/my-bear-notes"
  "$repo/bear.sh" export
}
