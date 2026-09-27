---
name: write-release-notes
description: Factory release-notes stage. After the release workflow succeeds on the default branch, writes tester-facing "what to test" notes from the shipped items' specs, attaches them to the release channel, posts build info in each item's Slack thread, and moves items to Done.
---

# write-release-notes

## Purpose
Close the loop. Testers know what to test, the human sees the build is out, and the tracker reflects reality.

## Inputs
- The successful release workflow run: commit range, build/version number, and the artifact or build link. The project's `release-*` skill says where to find these.
- The issues shipped in this range: `Factory-Issue:` trailers in `git log <previous release tag or run>..<sha>`, plus issues in **Shipping**.
- Each issue's spec (acceptance criteria are the best test checklist).

## Outputs
- "What to test" notes. Attach them to the release channel as the project's `release-*` skill describes; otherwise, post them in the thread.
- A thread message per item: `🚀 <KEY>-<num> shipped in <version> (<build>). What to test: …`.
- Each shipped issue moved to **Done**.

## Done criteria
- Every shipped issue is in **Done** with a run record, and its thread has the build info.
- The notes are attached to the release channel (or the fallback is documented in the run record).

## Steps
1. Determine the shipped issues from the commit trailers in the release range.
2. For each issue, draft at most 5 bullets of tester instructions from its acceptance criteria, in plain language.
3. Combine them into release notes (at most 4000 characters) and attach them via the `release-*` skill's method.
4. Post in each item's thread and move it to **Done**.

## Escalation
If the release workflow run reports success but the build isn't visible in the release channel after a reasonable wait, post in the thread and leave the item in **Shipping**, with a run record outcome of `failed`.

## Reporting
Per `.agents/skills/factory/README.md`, with stage `release-notes`.
