# User Preferences

## General Rules
- When asked to plan, do NOT to create design spec docs unless the work is multi-commit or a big feature.
- Always ask for confirmation before committing, I prefer to review the code before its committed.
- Use minimal to no code comments. Prefer self-explanatory code; only add a comment when the "why" is genuinely non-obvious, and keep it to a single concise line. This overrides matching surrounding style — do NOT match the comment density of existing verbose code; new comments stay minimal even in a heavily-commented file.

## Production Access Rules
- Read-only production scripts/queries may run WITHOUT approval: SQL SELECTs via `neetodeploy pg cli`, and rails runner scripts that only read — ActiveRecord finders/count/pluck, inspecting records, read-only GET/list calls to external APIs.
- Anything else NEEDS my explicit approval of the exact script before running — show me the script and wait for a yes. Mutating means: any DB write (create/save/update/destroy/update_all, raw DML/DDL), enqueuing jobs, sending emails/notifications/webhooks, external API calls that create/modify/delete remote resources, or invoking app service objects/jobs/mailers (business logic may mutate internally even when it sounds read-only).
- When unsure whether a script is fully read-only, treat it as mutating and ask.
- Approval for one production script does NOT carry over to the next one.

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
- When a method chain must be broken across lines (e.g. to satisfy Rubocop line length), put the receiver on its own line and lead each chained call with a dot on its own line, including `.deliver_later`. Keep the args of a call like `.with(...)` on a single line when they fit under the limit; only when they don't, break each arg onto its own line under `.with(` and put the closing `)` on its own line aligned with `.with`. Never glue the receiver to `.with(`, and never append a trailing call (e.g. `.deliver_later`) onto another call's line.
  ```ruby
  # Preferred
  Builder
    .with(foo: foo_value, bar: bar_value)
    .transform(first_arg, second_arg)
    .commit

  # Preferred when args must break
  Builder
    .with(
      foo: foo_value,
      baz: baz_value,
      bar: bar_value
    )
    .transform(first_arg, second_arg)
    .commit

  # Avoid
  Builder.with(
    foo: foo_value,
    bar: bar_value)
    .transform(first_arg, second_arg).commit
  ```
