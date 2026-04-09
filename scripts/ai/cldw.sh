#!/bin/bash

# Creates a git worktree, starts Claude Code in it,
# and splits iTerm2 vertically with the repo open.
cldw() {
  local worktree_name="$1"

  if [[ -z "$worktree_name" ]]; then
    echo "Usage: cldw <worktree-name>"
    return 1
  fi

  local repo_root
  repo_root=$(git rev-parse --show-toplevel 2>/dev/null)

  if [[ -z "$repo_root" ]]; then
    echo "Error: Not inside a git repository."
    return 1
  fi

  local worktree_path="${repo_root}/.claude/worktrees/${worktree_name}"

  mkdir -p "${repo_root}/.claude/worktrees"

  git worktree add "$worktree_path" -b "$worktree_name" 2>/dev/null || git worktree add "$worktree_path" "$worktree_name"

  if [[ $? -ne 0 ]]; then
    echo "Error: Failed to create worktree."
    return 1
  fi

  local abs_worktree_path
  abs_worktree_path=$(cd "$worktree_path" && pwd)

  # Split the terminal vertically and open the worktree on the right
  case "$TERM_PROGRAM" in
    iTerm.app)
      osascript <<EOF
        tell application "iTerm2"
          tell current session of current tab of current window
            set newSession to split vertically with default profile
            tell newSession
              write text "cd ${abs_worktree_path}"
            end tell
          end tell
        end tell
EOF
      ;;
    WezTerm)
      wezterm cli split-pane --right --cwd "$abs_worktree_path" >/dev/null
      ;;
    *)
      echo "Warning: Unsupported terminal ($TERM_PROGRAM); skipping split."
      ;;
  esac

  # Start Claude Code in the worktree in the current pane
  cd "$abs_worktree_path" && claude
}
