# Factory skills

Generic stage **contracts** for the software factory. They're stack-agnostic: they must not mention a specific language, platform, store or app.

Every factory skill has the same sections: **Purpose · Inputs · Outputs · Done criteria · Steps · Escalation · Reporting**.

Shared references:
- Stage definitions: `factory/stages.yaml`
- Tracker IDs and issue key: `factory/linear.yaml` (`team.key` is written `<KEY>` below)
- Conventions: `AGENTS.md` → "Factory conventions"
- Craft is delegated to project skills (`.agents/skills/project/verify-*`, `release-*`) and other craft skills.

## Common reporting (applies to every stage)
1. **Slack thread.** Post a short human-facing update in the item's thread. The permalink is the `Slack-Thread:` line in the Linear issue description. Keep it to at most 3 lines, with links.
2. **Log channel.** Post noisy detail in the log channel (`#factory-log`), prefixed `[<KEY>-<num>] <stage>:`.
3. **Run record.** Append a Linear comment:
   `Run record: <stage> | <model id> | <started ISO> | <finished ISO> | <success|failed|escalated|noop> | <notes>`
4. **Metrics tags.** Commits carry `Factory-Issue: <KEY>-<num>` and `Factory-Stage: <stage>` trailers. Branches are `<key>-<num>/<slug>`; PR titles are `[<KEY>-<num>] <title>`.

## Common escalation
If you hit the loop cap, lack access, or face a decision only a human can make, do the following. Don't guess.
1. Move the issue to **Needs human**.
2. Post in the thread: what you tried, what's blocking, and the specific question.
3. Write a run record with outcome `escalated`.
