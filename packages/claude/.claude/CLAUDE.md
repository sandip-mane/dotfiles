# User Preferences

## General Rules
- When asked to plan, do NOT to create design spec docs unless the work is multi-commit or a big feature.
- Always ask for confirmation before committing, I prefer to review the code before its committed.
- Use minimal to no code comments. Prefer self-explanatory code; only add a comment when the "why" is genuinely non-obvious, and keep it to a single concise line.

## Git Rules
- While creating branches, use github issue number as prefix when available
  example: `100-login-enhancements`
- Do not include github issue number in the commit message or PR title

## Github Pull Request Rules
- Start description with "closes/fixes #{github_issue_number}" whenever it is available
- Keep the description concise
- When PR is created and changes are pushed, run commitlog and print the output
- If the repo name ends with "-nano" 
  - Add the tag "patch"
  - If JS changes are made, add "frontend" tag
  - If ruby changes are made, add "backend" tag

## Backend (Rails/Ruby) rules
- For a new_feature/enhancement ensure proper unit test coverage is added
- For a bug fix, reproduce the bug in an unit test before fixing
- While adding unit test cases, do not add the tests with a new public block after a private block, all the tests should be added before the existing private block
