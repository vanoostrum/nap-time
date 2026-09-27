---
name: review-against-spec
description: Factory review stage. On green CI for a factory PR, checks the diff against the spec's acceptance criteria and general quality, comments on the PR, and either posts a Gate 2 merge message or sends the item back to Building.
---

# review-against-spec

## Purpose
Be an independent check that the PR does what the approved spec says, and nothing risky besides. This stage runs on a model from a different family than the builder.

## Inputs
- The PR (from a `<key>-<num>/*` branch, CI green): its diff, description and commits.
- The spec `docs/specs/<KEY>-<num>-*.md`, especially the acceptance criteria and non-goals.
- Tracker issue `<KEY>-<num>` and `AGENTS.md` conventions.

## Outputs
- One PR review comment containing an AC table (`AC | met? | evidence (file:line / test name)`) and findings (blocking or nit).
- Either a gate message in the thread with the issue moved to **Ready to merge**, or the issue moved to **Building** with the requested changes as a tracker comment.

## Done criteria
- Every acceptance criterion is marked met or not met, with evidence.
- Each finding is labelled blocking or non-blocking.
- The state transition is done.

## Steps
1. Move the issue to **Reviewing**. If the PR has new commits since the last review, only review the delta plus the AC table.
2. Count prior review round trips in the run records. If there have been 3 or more, escalate.
3. For each acceptance criterion, find the implementing code and the proving test. No test means not met.
4. Check the non-goals weren't violated and the conventions were followed (branch, title, trailers). Check for obvious bugs, security and privacy issues, and dead code.
5. Post the review comment.
6. **All criteria met and no blocking findings:** post in the thread:
   ```
   ✅ <KEY>-<num> passes review. <1-line summary>
   PR: <url> · CI green
   React ✅ to merge, or reply with changes.
   ```
   Then move the issue to **Ready to merge**.
7. **Otherwise:** add a tracker comment `Review requested changes: <list>`, move the issue to **Building**, and post a one-liner in the thread.

## Escalation
Escalate at the round-trip cap, or if the spec itself looks wrong (surface it; don't rewrite it). Follow the common escalation.

## Reporting
Per `.agents/skills/factory/README.md`, with stage `review`.
