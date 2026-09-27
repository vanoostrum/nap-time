---
name: front-desk
description: Factory front desk. Handles every Slack event in the factory interface channel (new work requests, thread replies, ✅ approvals, status questions) and turns them into tracker issues, state transitions and merges. Use for any message or reaction in #factory.
---

# front-desk

## Purpose
Be the single entry point between the human and the factory. Translate Slack conversation into tracker state. Never do stage work (specs, code) yourself.

## Inputs
- The Slack event: channel, message text, author, `ts`, `thread_ts` (if a reply), or a reaction and the message it's on.
- `factory/linear.yaml` (team, state and label IDs), `factory/stages.yaml`.

## Outputs
- New tracker issue, state changes, comments.
- Merged PRs at gates (or auto-merge enabled).
- Replies in the Slack thread.

## Done criteria
- Every event gets exactly one outcome: issue created, gate handled, feedback routed, status answered, clarifying question asked, or explicitly ignored.
- Ignored events are bot messages, messages from the factory itself, and messages in the log channel.

## Steps
**0. Classify the event.** Ignore it if the author is a bot (including your own posts). Otherwise:

**A. New top-level message → new work item**
1. If the request is truly ambiguous, ask at most 2 clarifying questions in the thread and stop. The next thread reply re-triggers you, so continue from there. Never ask more than 2 rounds in total.
2. Pick the type: `type:feature`, `type:bug` or `type:chore`. Pick risk: `risk:high` if it touches data persistence, security/privacy, payments, or migrations; otherwise `risk:low`.
3. Create the issue in the team from `factory/linear.yaml`:
   - Title: a concise imperative sentence.
   - Description: the original request quoted, clarifications, then a final line `Slack-Thread: <permalink of the top-level message>`.
   - Labels: type and risk.
   - State: **Specifying**. This triggers the spec stage.
4. Reply in the thread: `Got it → <KEY>-<num> <issue URL>. Writing a spec next.`

**B. ✅ reaction (`white_check_mark`) or reply matching `approve|approved|lgtm|ship it` in a thread**
1. Find the issue whose description has `Slack-Thread:` equal to this thread's permalink. You can also search for the thread `ts`.
2. By state:
   - **Spec review:** find the open spec PR for the issue (branch `<key>-<num>/*-spec`, or the PR linked on the issue). Merge it with a squash merge. Move the issue to **Building**. Reply: `Spec approved and merged. Building.`
   - **Ready to merge:** find the open code PR. Merge it with a squash merge, or enable auto-merge if checks are still pending. Move the issue to **Shipping**. Reply: `Merging. Release pipeline will ship it.`
   - **Any other state:** reply `Nothing to approve right now (<KEY>-<num> is in <state>).`
3. Only the human requester or a workspace member may approve; ignore approvals from bots.

**C. Other thread reply while the item is at a gate (feedback)**
1. Add the reply as a tracker comment: `Feedback from Slack: <text>`.
2. At **Spec review**, move to **Specifying**. At **Ready to merge**, move to **Building**.
3. Reply: `Thanks. Sending back to <stage> with your feedback.`

**D. Other thread reply while the item isn't at a gate**
Add it as a tracker comment so the running stage can pick it up. Acknowledge briefly.

**E. "status" / "what's in flight?"** (top-level or in a thread)
Query the team's open issues grouped by state, and flag anything in **Needs human**. Reply with a compact list: `<KEY>-<num> title (state, age)`.

## Escalation
If you can't find the issue for a thread, or a merge fails (conflicts, protection rules), reply in the thread with the problem. On merge failure, move the issue to **Needs human**.

## Reporting
Per `.agents/skills/factory/README.md`. The run record uses stage `front-desk`, and only for events that changed state.
