---
name: bootstrap-project-skills
description: Meta-skill. Inspects a repository and generates the project-specific skills the factory delegates to - verify-<stack> (build/test/lint) and release-<channel> (ship + where to see status) - under .agents/skills/project/.
disable-model-invocation: true
---

# bootstrap-project-skills

## Purpose
Make the factory portable. Factory stage skills only say "use the project's `verify-*` / `release-*` skill"; this skill writes those for a new repo.

## Inputs
- The repository: build files, package manifests, CI workflows, release tooling, lint configs, README, and `AGENTS.md`.

## Outputs
- `.agents/skills/project/verify-<stack>/SKILL.md`, covering: prerequisites; exact build, test and lint commands (fast subset first); how to run a single test; what can and can't run on the agent's own machine (e.g. OS/toolchain limits) and the fallback (CI); where CI logs live; common failures and fixes.
- `.agents/skills/project/release-<channel>/SKILL.md`, covering: what triggers a release; the exact command or workflow; required secrets (names only); where to see status and build numbers; how to attach release notes; rollback or re-run.
- A short diff summary for a human to review.

## Done criteria
- Every command in the generated skills has been executed successfully on this machine, or explicitly marked "CI-only" with the CI job that runs it.
- The frontmatter is valid (`name` and `description`).
- No secrets are included.

## Steps
1. Detect the stack(s) from the manifests and the CI config. Prefer what CI actually runs over what the README says.
2. Extract the commands from CI jobs and task runners. Try each one locally and record the results.
3. Detect the release path (deploy workflow, release tooling config) and its secrets by name.
4. Write both skills using the section lists above. If project skills already exist, diff them against the existing ones and preserve human-written notes.
5. Open a PR titled `Bootstrap project skills`, or print the files if you have no PR tool.

## Escalation
If there's no CI and the build can't be run locally, write the skill with `TODO(human)` markers and say so.

## Reporting
The PR description lists the commands verified locally vs. CI-only.
