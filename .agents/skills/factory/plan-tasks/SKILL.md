---
name: plan-tasks
description: Breaks an approved or draft spec into an ordered list of small, independently verifiable implementation tasks, each mapped to acceptance criteria and a test. Used by write-spec; can be reused by any planning step.
---

# plan-tasks

## Purpose
Turn acceptance criteria into a sequence of small steps a coding agent can implement and verify one at a time. Each step should keep the build green.

## Inputs
- A spec file: its acceptance criteria and design notes.
- The code layout (`AGENTS.md`).

## Outputs
A markdown list to append under `## Task plan`:
```
1. [ ] T1: <imperative, one change> (verifies: AC1) — test: <which test proves it>
```

## Done criteria
- Tasks are ordered so each one leaves the build and tests green.
- Each task is small, with one reviewable change of roughly ≤150 changed lines.
- Every acceptance criterion is covered by at least one task.
- Test-first: each task names the test that proves it.
- Pure logic goes before UI and integration wiring.

## Steps
1. List the acceptance criteria.
2. Identify seams: pure logic (unit-testable), state, UI, and integration.
3. Draft tasks bottom-up: logic, then state, then UI, then wiring, then docs.
4. Check coverage (AC → tasks) and size, and split anything too large.
5. Output the list.

## Escalation
If an acceptance criterion can't be made testable, flag it back to the caller. Don't invent a test.

## Reporting
None of its own. The calling stage reports.
