---
name: implement-task
description: Factory build stage. Implements an approved spec's task plan test-first on the item branch, opens the code PR linked to the tracker issue, and moves the issue to Verifying. Also used in "address review comments" mode for PR review comments.
---

# implement-task

## Purpose
Turn an approved spec into a mergeable PR that satisfies every acceptance criterion, in small verified steps.

## Inputs
- Tracker issue `<KEY>-<num>`, with its comments. `Feedback from Slack:` and reviewer comments take precedence.
- The approved spec `docs/specs/<KEY>-<num>-*.md` on the default branch.
- The project's `verify-*` skill (`.agents/skills/project/verify-*`), which says how to build, test and lint.
- In **review-comments mode**: the PR review comments that triggered the run.

## Outputs
- Branch `<key>-<num>/<slug>` with commits carrying the trailers `Factory-Issue: <KEY>-<num>` and `Factory-Stage: build` (or `comment-fix`).
- Code PR titled `[<KEY>-<num>] <title>`, using the PR template, linking the issue and spec, with the acceptance-criteria checklist.
- Issue moved to **Verifying**.

## Done criteria
- Every task in the plan is ticked (update the spec's checklist in the PR).
- Tests exist for every acceptance criterion.
- The verification the `verify-*` skill says you can run locally passes. Anything you can't run locally is left to CI.
- The PR is open and linked on the issue.

## Steps
1. Check out or create the branch from the latest default branch. If a PR already exists (a re-run after feedback), continue on it.
2. For each task in order:
   1. Write or adjust the test first.
   2. Implement the smallest change that makes it pass.
   3. Run the local verification the `verify-*` skill allows.
   4. Commit with trailers. Push small and often; CI is the source of truth for anything you can't run locally.
3. Open the PR, or update its description (checklist, notes).
4. Move the issue to **Verifying**. Post in the thread: `🔨 PR for <KEY>-<num>: <url> (CI running)`.

**Review-comments mode:**
- Address each comment with a fix commit (`Factory-Stage: comment-fix`), or reply explaining why not.
- Reply on each comment thread, push, then move the issue to **Verifying**.

## Escalation
Escalate if the spec is wrong or incomplete (don't silently change scope; ask in the thread), you've made 3 failed attempts on the same task, or a dependency or access is missing. Follow the common escalation.

## Reporting
Per `.agents/skills/factory/README.md`, with stage `build` or `comment-fix`.
