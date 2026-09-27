---
name: write-spec
description: Factory spec stage. Turns a tracker issue in "Specifying" into a reviewed-ready spec file with testable acceptance criteria and a task plan, opens a spec PR, and posts a Gate 1 approval message in the item's Slack thread.
---

# write-spec

## Purpose
Produce a spec a human can approve in about 2 minutes and a build agent can implement without guessing.

## Inputs
- The tracker issue (`<KEY>-<num>`): title, description, comments. This includes any `Feedback from Slack:` comments, which take precedence.
- Repo knowledge: `AGENTS.md`, `docs/architecture.md`, `docs/adr/`, existing specs in `docs/specs/`, and the code.
- Template: `docs/specs/README.md`.

## Outputs
- `docs/specs/<KEY>-<num>-<slug>.md`, following the template, including a task plan.
- Spec PR from branch `<key>-<num>/<slug>-spec`, titled `[<KEY>-<num>] Spec: <title>`, with the issue linked in the body.
- Gate message in the Slack thread.
- Issue moved to **Spec review**.

## Done criteria
- Every acceptance criterion is observable and testable: it names the screen or behaviour and the expected result.
- Non-goals are explicit.
- The task plan exists and each task maps to at least one acceptance criterion.
- The PR is open and its checks aren't blocked by the spec itself.
- The gate message has been posted, and the issue is in **Spec review**.

## Steps
1. Read the issue and all comments. If this is a re-spec after feedback, update the existing spec file on the existing branch/PR rather than starting over.
2. Explore the code to ground the design notes in real files and types.
3. Write the spec: context (quote the request), scope, non-goals, acceptance criteria, design notes, and risks. Adjust the issue's risk label if warranted.
4. Delegate the task plan to the `plan-tasks` skill and append its output under `## Task plan`.
5. Commit with trailers `Factory-Issue: <KEY>-<num>` and `Factory-Stage: spec`, push, and open or update the PR.
6. Post the gate message in the Slack thread:
   ```
   📝 Spec ready for <KEY>-<num>: <title>
   <2–4 bullet summary: scope + key acceptance criteria>
   PR: <url>
   React ✅ to approve, or reply with changes.
   ```
7. Move the issue to **Spec review**.

## Escalation
Escalate if the request conflicts with an ADR, needs a product decision you can't infer, or needs access you lack. Follow the common escalation.

## Reporting
Per `.agents/skills/factory/README.md`, with stage `spec`.
