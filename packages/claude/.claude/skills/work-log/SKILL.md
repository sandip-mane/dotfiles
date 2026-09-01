---
name: work-log
description: Use when asked for a work log, daily update, standup entry, or "what did I work on" for a day — gathers the user's commits and PRs across every local repo and formats them as issue-grouped log entries
argument-hint: "[today | yesterday | YYYY-MM-DD | YYYY-MM-DD..YYYY-MM-DD]"
---

# Work Log

Produce the user's daily work log: one entry per **GitHub issue**, with short bullets describing what was done.

## Step 1: Collect

`$ARGUMENTS` is the day. Default to `today` if empty.

```bash
~/.claude/skills/work-log/collect.sh today       # or: yesterday | 2026-07-23 | 2026-07-20..2026-07-23
```

**A work day runs 06:00 to 05:59 the next morning**, so a session that carries past midnight stays on the
day it started. Two consequences: run it before 06:00 and `today` means the date that just ended — the
script says so on a `# note:` line and the header is already correct, so just use it. And an explicit date
is always taken literally; `2026-07-23` is that one work day, never shifted.

The script searches `~/Work` up to 4 levels deep for git repos (override with `WORKLOG_ROOTS` /
`WORKLOG_DEPTH`), stopping at each repo rather than descending into it, and de-duplicating worktrees
against their parent repo. It prints three sections:

| Section | What it gives you |
|---|---|
| `## repo:` blocks | Commits authored that day, with the branch each sits on |
| `# ---- Pull requests ----` | Each PR behind those branches, with its `closes:` issue refs |
| `# ---- Your PRs closed/merged ----` | Work with no commits that day — triage, closures, supersessions |

Read all three. The commit scan is the **primary** source — it is the only one that sees open PRs and
work not yet merged. The third section only supplements it with work that left no commits that day.

Check the `# Scanned N repo(s)` line before trusting the output. If it says `0`, or the script prints a
`# WARNING: no git repos found`, the commit scan saw nothing and the log would be silently built from
merged PRs alone — stop and fix `WORKLOG_ROOTS`/`WORKLOG_DEPTH`, do not write a log from what remains.
Same for the `no commits matched author` note: fix `WORKLOG_AUTHOR` and re-run.

## Step 2: Map commits to issues

**The unit of the log is the issue, not the commit or the PR.** Resolve the number in this order:

1. The PR's `closes:` line → that issue number.
2. No `closes:` → use the PR number itself.
3. Issue in a different repo (e.g. an integrations-nano PR closing `neeto-cal-web#25383`) → file the entry
   under the repo where the *work* happened, and write the ref cross-repo: `neeto-integrations-nano - neeto-cal-web#25383`.
4. One PR closing several issues → one entry, all numbers on the header line.
5. Personal repos with no issue tracker → header is just the repo name.

Group every commit on the same branch into a single entry. A `MERGE` line is not work — it is a pointer
to a branch whose PR you should look up.

## Step 3: Write the entries

**Emit the whole log inside one fenced code block, every line flush against the left margin.** The log
gets pasted elsewhere verbatim, so no line may carry leading spaces — not the date, not the repo header,
not the bullets. Do not indent entries under the date, do not indent bullets under their repo header, and
do not wrap the log in a markdown list. Blank line between entries, nothing else.

The log opens with the date, always as `DD-MM-YYYY`. The script prints the exact string to use on its
`# Header to use in the log output:` line — copy it verbatim. Never head the log with `Today`, `Yesterday`,
a weekday, or a month name, whatever word the user typed to ask for it.

````
```
23-07-2026

<repo-name> - #<issue>
- <what was done, one line>
- <second thing, only if genuinely separate>
```
````

For a multi-day range, repeat the header per day (`20-07-2026`, `21-07-2026`, …) and file each entry under
the day the script stamps on its commits. That stamp is already the owning work day, so a commit reading
`22-07-2026 00:36` belongs under `22-07-2026` — file it there, not under the 23rd.

Rules:
- Bullets come from the PR title and commit subjects — the user's own words for the change. Never paraphrase the
  PR body's prose or explain the root cause; this is a log, not a summary.
- Past tense or imperative, matching the commit subjects. One line each, no trailing period.
- A `Fix:` follow-up commit on the same branch is usually part of the same bullet, not a new one.
- Order entries chronologically by when that branch's work started that day.
- List personal-repo commits last, under a short note, since they have no issue number.

## Step 4: Report the deltas

Outside the code block — this part is commentary, not log content. State briefly what was non-obvious: issues spanning two repos, PRs where the user only
pushed review feedback to someone else's branch, dependabot/triage closures, and any PR whose issue number
could not be resolved. This is what the user cannot see from `git log` alone.

## Common mistakes

| Mistake | Fix |
|---|---|
| Logging the PR number when the PR says `closes #N` | The log tracks issues. Use `#N`. |
| One entry per commit | Group by branch/issue. |
| Skipping the closed-PRs section | Triage and review-only work has no commits and would be lost. |
| Writing a log when `Scanned 0 repo(s)` | The commit scan found nothing. Fix the roots and re-run. |
| Logging only merged work | Open PRs with commits that day are work. The commit scan catches them. |
| Restating the PR body | Bullets are one line. The reader already has the PR. |
| Counting a `Merge branch 'main' into X` as work | Look up X's PR instead. |
| Trusting `gh search` dates | It is UTC. The script re-filters to the local work day; commit times are already local. |
| Re-filing a `00:36` commit onto the next date | The work day ends at 06:00. The script already assigned it. |
| Inventing work to fill a thin day | A short log is a correct log. |
| Heading the log `Today` / `Yesterday` / `Jul 23` | Always `DD-MM-YYYY`, e.g. `23-07-2026`. |
| Indenting entries under the date, or bullets under the repo | Every log line starts at column 1. |
| Mixing the deltas into the code block | The block holds only what gets pasted. |
