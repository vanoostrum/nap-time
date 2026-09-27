# release-notes

- **Stage:** `release-notes`
- **Trigger:** GitHub → *Workflow run completed* → workflow `Release`, conclusion `success`, branch `main`
- **Repository:** `vanoostrum/nap-time`
- **Model:** `claude-haiku-4-5` (fast)
- **Tools:** Send to Slack, MCP: Linear (attaching notes follows the project `release-*` skill)
- **Prompt:**
  > Run the `write-release-notes` skill (`.agents/skills/factory/write-release-notes/SKILL.md`) for the release run in this event.
