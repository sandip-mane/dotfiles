# Drops each worktree's database, removes all worktrees, then deletes every local branch except the current one
gitclean() {
  local main_dir
  main_dir=$(git worktree list --porcelain | sed -n '1s/^worktree //p')
  [ -n "$main_dir" ] && cd "$main_dir" || return 1

  local worktree
  for worktree in ${(f)"$(git worktree list --porcelain | sed -n 's/^worktree //p' | tail -n +2)"}; do
    if [ -f "$worktree/bin/rails" ]; then
      echo "Dropping database for $worktree"
      (cd "$worktree" && bin/rails db:drop) || { echo "Skipping $worktree: db:drop failed"; continue; }
    fi
    git worktree remove --force "$worktree"
  done
  git worktree prune

  local branches=(${(f)"$(git branch --format='%(refname:short)' | grep -vx "$(git branch --show-current)")"})
  (( ${#branches} )) && git branch -D $branches
}
