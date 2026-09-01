---
name: pr-review
description: Use when asked to review a pull request, review a branch or diff, or check whether changed code follows conventions, can be cleaned up, or reuses existing code.
---

# PR Review

Review a change for correctness, authorization, reuse, convention adherence, and test quality — and **prove** the serious findings by running them.

## Core principles

**A finding you have not executed is a suspicion, not a finding.** Reading code tells you what it looks like; running it tells you what it does. Every blocking claim carries real output — a status code, an error message, a query log — captured from the branch. Anything you could not execute is labelled unverified.

**Green CI is not evidence of correctness.** Tests frequently pass because they avoid the broken path. Look for what the tests *don't* exercise; that gap is often the finding.

**The convention lives in the codebase, not in your training data.** Judge the change against its neighbours, not against generic best practice.

## Before you start

1. If the repo has an `LLM.md` at the root, read it — `CLAUDE.md` and `AGENTS.md` are auto-loaded, `LLM.md` is not.
2. Confirm the target: a PR URL, a number, a branch name, or "the current diff".
3. Prefer a high reasoning effort. Reuse and convention findings depend on holding a lot of the codebase in mind at once.

## Step 1: Gather the change

```bash
gh pr view <N> --json title,body,author,state,files,additions,deletions
gh pr diff <N>
```

If the body references an issue (`Fixes #NNNN`), read it. The stated intent is what you check completeness against — a PR titled "build API and CLI" that ships only the API half is a finding no amount of line-by-line reading will surface.

Then **check out the branch** and note the branch you started on:

```bash
gh pr checkout <N>
```

Reviewing from the diff alone is the single biggest cause of wrong findings. You need the branch on disk to grep for callers, read the definitions the diff depends on, and run probes.

## Step 2: Establish the convention baseline

Do this before judging anything. It is what separates a real review from generic advice.

**a. Prior art in the same repo.** For every new file, find its closest existing sibling and compare the approach. A new `Api::External::V1::FooController` is reviewed against the existing `Api::V1::FooController`.

**b. Prior art in sibling repos.** Organizations that run many similar services (a monorepo, or a set of sibling product repos cloned side by side) keep their conventions there. The same file usually exists next door:

```bash
cd <dir containing the sibling repos>
for d in */; do f="$d/<path/of/the/new/file>"; \
  [ -f "$f" ] && echo "--- $f ---" && cat "$f"; done
```

If another service already solved this — pagination helper, base controller, serializer layout — the change should match it or justify diverging.

**c. Read the dependencies the change inherits from.** Framework code inherits enormous behaviour from base classes, mixins, and packages. You cannot judge a class without reading what it inherits and includes.

```bash
bundle info <gem> --path        # Ruby
# or: cat node_modules/<pkg>/... , go doc, etc.
```

Read at minimum: every base class in the new class's chain, and every `include` / mixin / `skip_before_action`-style opt-out it declares. And any shared module the change adds to a model — it may already define the thing being added.

**d. Read the models/types the diff touches.** The full association, scope, and method list. This is where "you reinvented something that already exists" findings come from.

## Step 3: Review passes

Run every pass that applies to the languages in the diff. Skip the rest explicitly — say which passes produced nothing rather than padding. Record each finding with `file:line`, the offending code, and the concrete fix.

### Pass A — Correctness, auth, and authorization

The highest-value pass.

- **Who is the caller, really?** Trace every authentication path the endpoint accepts. When a base class opts out of the normal auth filter, the "current user" on that path may be `nil` — grep the new code for it and ask whether it is reachable. An endpoint that advertises two credential types and only works with one is the recurring version of this.
- **Does the authorization helper actually authorize?** Open the scope/guard being relied on and read its body. Helpers named like filters are often preload helpers that ignore the user entirely:
  ```ruby
  def resolve
    scope.includes(:project, :list, field_values: :field)   # filters NOTHING
  end
  ```
  A controller relying on that for authorization has none.
- **Is authorization symmetric?** When a change adds sibling endpoints, compare them line by line. One having an explicit authorize call and its sibling having nothing is almost always an oversight, not a decision.
- **Cross-tenant / cross-parent leakage.** A bare `Model.where(...)` where scoping through the parent (`@parent.things.where(...)`) would enforce the boundary.
- **Ignored return values.** A service invoked with no success/error check, where surrounding code checks it.
- **Unguarded parsing.** `Date.parse`, `JSON.parse`, `Integer()`, `parseInt` on stored or user-supplied data — raises and 500s on bad input.
- **Injection and secrets.** String-interpolated SQL, shell, or HTML built from user or record data; credentials or tokens committed; overly broad mass-assignment.

### Pass B — Reuse, simplification, and existing code

**Assume the thing already exists until you have grepped and found it doesn't.** Most cleanup findings live here.

- **Does an association, scope, helper, or utility already do this?** A `case` on a param that rebuilds filtering the model already exposes as named associations.
- **Does an inherited module already define what's being added?** Read the mixin before accepting any new scope, validation, callback, or helper.
- **Is this duplicated from the analogous file?** Verbatim blocks — raw SQL joins, dependency lists, param builders — copied from an existing namespace into a new one belong in a shared scope, module, or base class used by both.
- **Are copy-pasted eager-loads actually used?** Compare the preload list against what the serializer emits. Preloading half a dozen associations for a partial that renders three fields is waste dragged along from the original.
- **Can these two files become one?** Two partials or components with identical bodies — one should call the other.
- **Dead code.** Private methods never called; names that promise something the body doesn't do.
- **Needless indirection.** Locals assigned once and used once; instance variables no view reads; methods that mutate state as a side effect after the fact instead of joining the chain.
- **Wrong altitude.** Business logic, formatting, or SQL sitting in a controller action or a view.

Frame each as *"X already exists at `file:line` — use it"* or *"this is a verbatim copy of `file:line` — extract it"*. A reuse finding without a pointer to the existing code is not actionable.

### Pass C — Backend conventions

Match the repo, not the textbook.

- Class/module declaration style, file placement, naming — as the neighbours do it.
- Idiomatic API over stringly-typed equivalents (`.order(created_at: :asc)` over `.order("created_at asc")`; `record.attr` over `record["attr"]` when it's a real column — check the schema).
- Strong params / input validation; raising vs non-raising finders; filter placement and `only:`/`except:` correctness.
- Fat controller: logic that belongs in a model, scope, or service.
- Pagination on collection endpoints — check whether sibling services use a shared helper.
- Response shape: exposing internal ids where the rest of the API uses public identifiers; human-formatted dates where consumers need ISO 8601.
- Run the repo's linters over the changed paths and report only what they *don't* catch. Say so when they're clean — it tells the author the findings are substantive, not style.

### Pass D — Frontend

Apply the same standard as the backend.

- **Reusability.** Does a component, hook, util, or constant already exist — in the repo, in the design-system packages it depends on, or in a sibling repo? A hand-rolled modal, dropdown, table, empty state, or date formatter that duplicates a design-system component is a finding. Grep before concluding it's new. Code that will be needed twice should be extracted now; copy-pasted markup should become one component with props.
- **Clean, standard implementation.** How the rest of *this* codebase does it, not how the framework can be used in general:
  - Hooks: rules-of-hooks, correct dependency arrays, no state derivable from props or render, cleanup in effects.
  - Data access through the repo's standard layer (query hooks, `apis/` modules) — not ad-hoc requests inside a component.
  - User-facing strings through i18n, never hardcoded.
  - Naming, file placement, and export style consistent with neighbouring files.
  - No inline styles or magic numbers where design tokens or utility classes exist.
  - Prop drilling beyond two levels, or one component fetching + transforming + rendering, means split it.
- **Thoroughness.** The states a happy-path implementation forgets: loading, empty, and error; disabled/in-flight submit buttons and double-submit; optimistic updates rolled back on failure and cache invalidated after mutations; form validation and server-error surfacing; accessibility (labels, keyboard operability, focus management); stable list keys, not array indices; cleanup of listeners, timers, subscriptions.
- **Dead weight.** Unused imports, props, and state; commented-out code; stray `console.log`; leftover TODOs.
- Run the frontend linters over changed paths and report what they miss. Lint catches none of reusability, missing states, or accessibility.

### Pass E — Tests

- **Do the tests avoid the broken path?** The strongest signal in the review. If every test for an endpoint exercises credential type A while the code advertises A and B, B is probably broken and untested. Verify it yourself in Step 4.
- **Do comments narrate the authoring process?** Blocks explaining why a test was *adjusted* to match current behaviour, or why one code path was avoided, are authoring narration — and they usually **document a bug instead of fixing it**. Flag both the comment and the bug it hides.
- **Unused setup.** Fixtures, factories, or headers built in setup and never referenced.
- **Name/behaviour mismatch.** A test named for a condition it never exercises.
- **Missing coverage** for exactly the paths Pass A flagged: the other credential type, the non-member/cross-tenant case, the error branch.
- Repo test conventions: placement (e.g. cases before the `private` block, not after), factory usage, framework assertions over hand-rolled checks.

## Step 4: Verify by execution

For each Pass A finding, write a throwaway probe and run it. Put it where the test framework will load it.

```ruby
# test/controllers/zz_probe_test.rb
require "test_helper"

class ZzProbeTest < ActionDispatch::IntegrationTest
  def setup
    @organization = create(:organization)
    @user = create(:user, :admin, organization: @organization)
    @api_key = @organization.api_keys.create!(label: "Key 1")
    host! test_domain(@organization.subdomain)
  end

  def test_probe
    get api_external_v1_projects_path, headers: { "X-API-KEY": @api_key.token }
    puts "STATUS=#{response.status} BODY=#{response.body[0..400]}"
  end
end
```

Adapt the harness to the stack — the shape is the same everywhere: minimal fixture, one call, print the raw result.

| Suspicion | Probe |
|---|---|
| Breaks on one auth path | Call it with each accepted credential type; print status + body |
| Missing authorization | Authenticate as a user who is **not** a member of the parent record; print status |
| Authorization asymmetry | Run the same non-member probe against both sibling endpoints and compare |
| N+1 / wasted preload | Assert on query count, or tail the log for repeated queries |
| Unguarded parse | Seed the malformed value, then call |

**Print, don't assert.** A passing assertion of the wrong expectation proves nothing. Read real output and quote it literally in the report:

```
GET /api/external/v1/projects  with a valid X-API-KEY
STATUS=500
BODY={"error":"undefined method 'id' for nil"}
```

For frontend suspicions the equivalent is running the app or the relevant spec. If you cannot execute something, say so and mark that finding unverified.

## Step 5: Rank

| Tier | Contains |
|---|---|
| **Blocking** | Verified crashes, authorization/data leaks, data loss, breaking API changes, missing scope from the linked issue. Each with executed evidence. |
| **Conventions / cleanup** | Reuse misses, duplication, dead code, non-idiomatic implementation, response-shape concerns. |
| **Tests** | Green-for-wrong-reason, narration comments, unused setup, missing coverage. |

Most-severe first within each tier. Three real findings beat fifteen nitpicks — if a pass produced nothing, say so rather than inventing something.

## Step 6: Clean up

```bash
rm -f <probe files>
git checkout <original-branch>
git status --short   # must be clean
```

Never leave probe files or a checked-out review branch behind.

## Step 7: Report

Report in the chat by default. Only post to GitHub if asked.

1. One line: what was reviewed, that you checked out the branch and ran probes, and the linter status.
2. `## Blocking` — numbered. Each: a title ending in **— verified**, the `file:line` and code, why it's wrong (citing the `file:line` in the dependency/guard/model that proves it), the literal probe output, and the fix.
3. `## Conventions / cleanup` — numbered, continuing. Each: `file:line`, the code, and a concrete replacement snippet.
4. `## Frontend` — same shape, when frontend files changed.
5. `## Tests` — bullets.
6. Close with which findings you'd block on, and offer to push fixes.

Rules for the write-up:
- Every finding cites `file:line`. No "somewhere in the controller".
- Every finding shows the fix as code, not a description of code.
- Verified findings marked **verified**; everything else plainly labelled a suspicion.
- No praise padding, no restating the PR description.

## Red flags — stop and go back

- About to report a bug you have not run → Step 4.
- About to say "this could be extracted" without having grepped for the existing thing → Step 2, Pass B.
- Reviewing from the diff output only → check out the branch.
- Judging a class without having read its base class and mixins → read them.
- Trusting an authorization helper without opening its body → open it.
- Concluding "tests pass, so it works" → find the path the tests avoid.
- Zero reuse findings in a change that adds a namespace parallel to an existing one → you have not compared them.

## Rationalizations

| Excuse | Reality |
|---|---|
| "The diff is small, I don't need the branch" | Reuse and authorization findings come from code outside the diff. |
| "CI is green" | Tests routinely dodge the broken path. That dodge is itself the finding. |
| "It's obviously broken, I can see it" | Obvious-looking bugs are wrong often enough to matter. Run it. |
| "The author probably had a reason" | Then the reason belongs in the code. Report it and let them answer. |
| "Checking sibling repos is overkill" | It is where the convention lives. It takes one `for` loop. |
| "Frontend just needs a lint run" | Lint catches none of reusability, missing states, or accessibility. |
| "I'll note it as a possible issue" | Verify it or label it a suspicion. Never blur the two. |
