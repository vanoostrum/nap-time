# spec

- **Stage:** `spec`
- **Trigger:** Linear → *Status changed* → team **Nap Time**, to status **Specifying**
- **Repository:** `vanoostrum/nap-time`
- **Model:** `claude-opus-5-5` (reasoning)
- **Tools:** Pull request creation, Send to Slack, Read Slack channels, MCP: Linear
- **Prompt:**
  > Run the `write-spec` skill (`.agents/skills/factory/write-spec/SKILL.md`) for the Linear issue in this event.
