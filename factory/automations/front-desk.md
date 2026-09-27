# front-desk

- **Stage:** `front-desk` (also handles `spec-gate` and `merge-gate`)
- **Triggers:**
  1. Slack → *New message in channel* → `#factory`, with a **message filter regex `.+`**. Without a filter, only top-level messages fire; the filter makes thread replies fire too.
  2. Slack → *Emoji reaction added* → `#factory`, emoji `white_check_mark`
  If one automation can't hold both triggers, create **front-desk** (trigger 1) and **front-desk-approve** (trigger 2) with identical settings.
- **Repository:** `vanoostrum/nap-time`
- **Model:** `claude-haiku-4-5` (fast)
- **Tools:** Read Slack channels, Send to Slack, Pull request (merge), MCP: Linear
- **Prompt:**
  > Run the `front-desk` skill (`.agents/skills/factory/front-desk/SKILL.md`) for the Slack event in this trigger.
