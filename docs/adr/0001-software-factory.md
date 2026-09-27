# ADR 0001: Software factory

- **Status:** Accepted
- **Date:** 2026-09-28

## Context
We want an automated software lifecycle in which AI cloud agents do the specifying, building, verifying, reviewing and releasing. A human stays in control at two gates: approving the spec and approving the merge. The setup must stay swappable: harness, models, and project stack can change without redesigning the factory.

## Decision
The factory has five layers:

| Layer | Tool | Role |
|---|---|---|
| **Interface** | Slack `#factory` (+ `#factory-log`) | The only human ↔ factory channel. One thread per work item; ✅ approves a gate. |
| **State** | Linear (team `NAP`) | Workflow states are the state machine: Triage → Specifying → Spec review → Building → Verifying → Reviewing → Ready to merge → Shipping → Done; plus Needs human and Canceled. |
| **Knowledge** | This repo | `AGENTS.md`, `docs/` (specs, ADRs, architecture), `.agents/skills/` (factory contracts + project craft), `factory/stages.yaml` (source of truth). |
| **Execution** | Cursor cloud agents + Automations | One automation per stage. Its trigger is a Linear status change, a Slack event, or a GitHub event. Each automation has a one-line prompt that points at a skill. |
| **Verify / Release** | GitHub Actions + fastlane | `ci.yml` gates PRs (required check). `release.yml` ships `main` to TestFlight. |

**Orchestration** has no central orchestrator. It emerges from:
1. **Linear workflow states.** Moving an issue into a state triggers that stage's automation.
2. **The Slack front desk.** It turns messages and ✅ reactions into Linear transitions and merges.
3. **GitHub events.** CI completions trigger the CI-fixer, the spec-reviewer and the release-notes stages.

**Swappability rules:**
- `factory/` and `.agents/skills/factory/` are stack-agnostic.
- Stage skills define *contracts* (inputs, outputs, done criteria, escalation, reporting) and delegate craft to other skills.
- Models are chosen by *class* (`reasoning`, `coding`, `review-different-family`, `fast`) in `stages.yaml`. The concrete models are mapped per harness in `factory/automations/`.

**Safety rails:**
- Branch protection on `main`: PR required, CI must pass, no force pushes.
- Loop cap of 3 automatic fix attempts per stage, then **Needs human**.
- The reviewer uses a model from a different vendor than the builder.

**Measurability:** branch names, PR titles, commit trailers (`Factory-Issue`, `Factory-Stage`) and Linear run-record comments make every run attributable, so cycle time, loop counts and cost per item can be computed later.

## Consequences
- Cloud agents run on Linux without Xcode. They rely on CI for iOS builds, so logic is pushed into the `Core` package (`swift test` runs on Linux) and agents push small commits.
- Automations are configured in Cursor's UI and aren't in version control. `factory/automations/*.md` is the reviewable spec they're derived from.
- Slack thread replies via "Send to Slack" must be validated during setup. The fallback is channel posts prefixed `[NAP-<num>]`.
