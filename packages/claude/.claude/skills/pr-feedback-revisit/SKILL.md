---
name: pr-feedback-revisit
description: Revisit unresolved PR review comments — verify each as valid or false-positive, reply (prefix false positives with "false-p: "), apply fixes, resolve threads, and push
disable-model-invocation: true
argument-hint: <pr-number-or-url> (optional; inferred from current branch if omitted)
---

Process unresolved review comments on a pull request.

## Input

`$ARGUMENTS` may be a PR number, a PR URL, or empty. If empty, infer the PR from the current branch:

```
gh pr view --json number,url,headRepositoryOwner,headRepository
```

Capture `{owner, repo, pr_number}`. Abort with a clear message if no PR is associated with the current branch.

## Steps

### 1. Fetch unresolved review threads

The REST API does not expose thread resolution state, so use GraphQL:

```
gh api graphql -F owner=OWNER -F name=REPO -F pr=PR_NUMBER -f query='
query($owner:String!,$name:String!,$pr:Int!) {
  repository(owner:$owner, name:$name) {
    pullRequest(number:$pr) {
      reviewThreads(first:100) {
        nodes {
          id
          isResolved
          isOutdated
          path
          line
          comments(first:50) {
            nodes {
              id
              databaseId
              body
              path
              line
              author { login }
              createdAt
            }
          }
        }
      }
    }
  }
}'
```

Keep only threads where `isResolved == false`. Ignore outdated threads unless they are clearly still actionable (e.g., the same line was rewritten in a way that preserves the concern).

### 2. For each unresolved thread

1. Read the first comment to understand the concern. If the thread has subsequent comments, read those too — treat the most recent comment as the live state.
2. **Investigate the codebase** to verify the concern. A reviewer bot only sees the diff, so check the broader context it could not see: the actual data, related call sites, type definitions, tests. Go beyond the reviewer's verification questions — ask your own.
3. Classify as **false-positive** or **valid**.

### 3. False-positive branch

- Post a reply on the thread starting with `false-p: ` followed by a concise, evidence-backed reason (one or two sentences; cite file paths, grep results, or data that disproved the concern).
- Resolve the thread.

### 4. Valid branch

- Implement the fix. Keep it surgical — address only what the comment identified.
- Post a reply describing what was changed (one or two sentences). Reference the file and line where the fix lives.
- Resolve the thread once the fix is committed.

### 5. Posting replies

Prefer the MCP tool `mcp__github__add_reply_to_pull_request_comment` if available. Otherwise:

```
gh api -X POST repos/OWNER/REPO/pulls/PR_NUMBER/comments/COMMENT_ID/replies -f body="..."
```

`COMMENT_ID` is the REST `databaseId`, not the GraphQL `id`. Reply to the **first** comment in the thread so replies nest correctly.

### 6. Resolving a thread

```
gh api graphql -F threadId=THREAD_ID -f query='
mutation($threadId:ID!) {
  resolveReviewThread(input:{threadId:$threadId}) {
    thread { isResolved }
  }
}'
```

Use the GraphQL `id` of the thread, not the comment id. Only resolve after the reply has been posted.

### 7. Commits

- Follow the repo's existing commit-message style (`git log --oneline -10`).
- Do not include the GitHub issue number in the commit message.
- Group related fixes into a single commit; keep unrelated fixes in separate commits.
- Never amend previous commits. Never force-push.

### 8. Summary

After all threads are processed, print a Markdown table to the conversation:

| # | File:Line | Severity | Verdict | Action taken |
|---|-----------|----------|---------|--------------|

- **File:Line** — from the thread.
- **Severity** — the reviewer's own rating when provided; infer (critical/major/minor/trivial) otherwise.
- **Verdict** — `valid` or `false-p`.
- **Action taken** — brief description ("committed <sha-short>: <subject>" or "replied only").

### 9. Push

Run `git push`. Do not force-push. If the push is rejected (pre-push hook, upstream divergence), stop and report — do not bypass with `--no-verify` or force flags.

## Guardrails

- Do not resolve a thread unless your reply has been posted successfully.
- If a fix requires a product/UX judgment call, post a reply asking the question and **leave the thread open**.
- If a comment is ambiguous, investigate before replying — do not guess intent.
- Keep replies short and factual. Match the tone of the thread; avoid emoji unless the thread already uses them.
- Skip threads you authored yourself.
