# Specs

One spec per work item, written by the `write-spec` stage and approved by a human at **Gate 1** (Spec review).

**File name:** `NAP-<num>-<slug>.md`, e.g. `NAP-12-about-screen.md`. The slug is kebab-case, 2–5 words.

**Lifecycle:** spec PR (branch `nap-<num>/<slug>-spec`) → ✅ in Slack → merged to `main` → the build stage implements it on `nap-<num>/<slug>`.

## Template

```markdown
# NAP-<num>: <Title>

- Linear: <issue URL>
- Slack thread: <permalink>
- Type: feature | bug | chore · Risk: low | high

## Context
Why this matters; what the user asked for (quote the request).

## Scope
What will change, in user-visible terms.

## Non-goals
What we explicitly won't do in this item.

## Acceptance criteria
Each criterion is testable and numbered; reviewers check the diff against these.
- [ ] AC1: Given …, when …, then …
- [ ] AC2: …

## Design notes
Approach, affected modules/files, data model changes, UI sketch in words.

## Risks
What could go wrong; mitigations; anything that makes this `risk:high`.

## Task plan
Ordered, small, independently verifiable tasks (from `plan-tasks`).
1. [ ] T1: … (verifies: AC1) — test: …
2. [ ] T2: …
```
