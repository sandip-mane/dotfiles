---
name: pr-submit-feedback
description: Use when asked to post PR review findings to GitHub as inline comments, or to send some or all findings from a review report in the conversation to a pull request.
---

# PR Submit Feedback

Turn findings from a review report into **one** GitHub review with inline comments. Readers are the PR author (often a bot) and teammates, so each comment must make sense without the chat review.

## Choosing what to send

Arguments select findings from the most recent review report in the conversation, by its numbering:

| Argument | Sends |
|---|---|
| `1,2,4` or `1-3` | Those numbered findings |
| `all` | Every numbered finding and every Tests bullet |
| Numbers plus a note, e.g. `1,2 skip the test nits` | Those findings, adjusted by the note |
| No arguments | Nothing yet: list the report's findings as a numbered one-line summary and ask which to send |

When no report exists in the conversation, ask the user for the findings or run pr-review first.

## Review shape

- **Main body**: the first line is exactly `@{author} _a please check`, followed by a blank line and one or two sentences saying what kind of issues follow.
  - `{author}` is the PR author login with any `app/` prefix removed: `app/neeto-dev-bot` becomes `@neeto-dev-bot`.
- **Event**: `COMMENT`. Use `APPROVE` or `REQUEST_CHANGES` only when the user asks.
- **commit_id**: the PR's current `headRefOid`.
- **One inline comment per finding**, on the line the fix touches. A finding that repeats across lines goes in one comment naming the other lines ("here, at L240 and at L273").

## Comment style

Plain, short English, in this order:
1. What is wrong, in one or two sentences.
2. What happens because of it: a concrete case, or the probe result in a few words.
3. The fix, as a small code block or one sentence.

## Steps

1. Get the head SHA and author: `gh pr view <N> --json headRefOid,author`.
2. Find line numbers on the head commit: `git show <sha>:<path> | grep -n "<snippet>"`. Each line must be inside a diff hunk (check with `gh pr diff <N>`).
3. Write the payload to the scratchpad:
   ```json
   {
     "commit_id": "<sha>",
     "event": "COMMENT",
     "body": "@author _a please check\n\n<one-line summary>",
     "comments": [
       { "path": "app/x.rb", "line": 42, "side": "RIGHT", "body": "..." }
     ]
   }
   ```
4. **Show the draft in chat**: the main body, then each comment under a `path:line` heading, exactly as it will be posted. Ask the user to approve or request edits. Apply edits and show the draft again. Post only after an explicit yes.
5. Fetch `headRefOid` again. If it changed, re-check the line numbers before posting.
6. Post: `gh api repos/<owner>/<repo>/pulls/<N>/reviews --method POST --input <file> --jq '.html_url'`.
7. Give the user the review URL.

## Common mistakes

| Mistake | Result / fix |
|---|---|
| Line outside a diff hunk | 422 `Line could not be resolved`. Move the comment to the nearest changed line. |
| Line numbers from the base branch or local checkout | Comment lands on the wrong line. Read the file from `<sha>`. |
| Posting each comment with a separate API call | One notification per comment. Send them all in one review. |
| Stale `commit_id` after the author pushes | Comments show as outdated. Fetch `headRefOid` right before posting. |
| Review jargon ("verified", "Pass A", "Blocking tier", `file:line` of the same file) | Readers don't know it. Write plain sentences. |
