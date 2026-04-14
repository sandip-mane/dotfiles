---
name: fix-aside
description: Fix a GitHub issue in an isolated worktree - creates worktree, implements fix, creates PR, and cleans up
disable-model-invocation: true
argument-hint: <github-issue-url>
---

Fix a GitHub issue in an isolated worktree. The user provides a GitHub issue URL as $ARGUMENTS.

Follow these steps automatically:

1. **Extract the issue number** from the URL (e.g., `21983` from `https://github.com/org/repo/issues/21983`)
2. **Create a worktree** named after the issue number
3. **Read the issue** from GitHub to understand what needs to be done
4. **Do the work** - thoroughly check usage/references before making changes. Ask for input when a business or complex decision needs to be taken.
5. **Review the changes** - ensure the code is efficient, readable, and maintainable before proceeding.
6. **Verify tests pass** - run the relevant tests and ensure they all pass before proceeding.
7. **Create a branch** starting with the issue number (e.g., `21983-description`)
8. **Commit and push** the changes (do not include the issue number in the commit message)
9. **Create a PR** linking to the issue
10. **Open the PR** in the browser
11. **Remove the worktree** after PR is created (run `rails db:drop` before deleting)
12. **Exit**
