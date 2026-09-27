---
name: fix-ci-failure
description: Factory CI-fixer stage. On a failed CI run for a factory item branch, reads the logs, fixes the cause, and pushes; counts attempts via commit trailers and escalates to Needs human at the loop cap.
---

# fix-ci-failure

## Purpose
Get a factory branch back to green without human help, within a bounded number of attempts.

## Inputs
- The failed workflow run: its ID, branch `<key>-<num>/<slug>`, and the job logs (`gh run view <id> --log-failed`).
- Tracker issue `<KEY>-<num>` and its spec.
- The project's `verify-*` skill, for how to reproduce failures locally where possible.

## Outputs
- One fix commit with trailers `Factory-Issue: <KEY>-<num>` and `Factory-Stage: ci-fix`, pushed to the branch. CI re-runs automatically.
- Or escalation to **Needs human**.

## Done criteria
- The root cause is identified and fixed. Don't skip or weaken failing tests, and don't disable lint rules to get green.
- The fix is pushed, and the issue stays in or returns to **Verifying**.

## Steps
1. Count prior attempts: `git log origin/<default>..HEAD --format=%B | grep -c '^Factory-Stage: ci-fix'`. If the count is 3 or more, escalate and stop.
2. Read the failing job logs and find the first real error; later errors are often cascades.
3. Classify the failure:
   - **Code/test failure:** fix the code, or fix the test if the test is wrong against the spec.
   - **Lint:** fix the code.
   - **Infra/flaky:** re-run the job once (`gh run rerun <id> --failed`). If it fails again, escalate.
4. Reproduce locally if the `verify-*` skill allows it on this machine. Otherwise reason from the logs and keep the change minimal.
5. Commit with trailers, push, and post to the log channel: `[<KEY>-<num>] ci-fix attempt <n>/3: <one-line cause>`.

## Escalation
At attempt 4, for repeated infra failures, or for failures outside the branch's changes (e.g. the default branch is broken), follow the common escalation. Include the failing step and your hypothesis.

## Reporting
Per `.agents/skills/factory/README.md`, with stage `ci-fix`. Human-facing thread posts happen only on escalation; routine attempts go to the log channel.
