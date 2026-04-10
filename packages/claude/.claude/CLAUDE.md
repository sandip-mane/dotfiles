# User Preferences

## General Rules

- If any changes are made to server-side code, add unit tests to cover the cases.

## "fix aside <github-issue-url>" Workflow

When I say "fix aside https://github.com/..." with a GitHub issue URL, follow these steps automatically:

1. **Create a worktree** named after the issue number
2. **Read the issue** from GitHub to understand what needs to be done
3. **Do the work** - thoroughly check usage/references before making changes. Ask for input when a business or complex decision needs to be taken.
4. **Review the changes** - ensure the code is efficient, readable, and maintainable before proceeding.
5. **Verify tests pass** - run the relevant tests and ensure they all pass before proceeding.
6. **Create a branch** starting with the issue number (e.g., `21983-description`)
7. **Commit and push** the changes
8. **Create a PR** linking to the issue
9. **Open the PR** in the browser
10. **Remove the worktree** after PR is created
11. **Exit**
