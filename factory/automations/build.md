# build

- **Stage:** `build`
- **Trigger:** Linear → *Status changed* → team **Nap Time**, to status **Building**
- **Repository:** `vanoostrum/nap-time`
- **Model:** `claude-sonnet-5` (coding)
- **Tools:** Pull request creation, Send to Slack, MCP: Linear
- **Prompt:**
  > Run the `implement-task` skill (`.agents/skills/factory/implement-task/SKILL.md`) for the Linear issue in this event.
