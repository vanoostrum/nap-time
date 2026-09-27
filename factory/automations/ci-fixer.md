# ci-fixer

- **Stage:** `ci-fix`
- **Trigger:** GitHub → *Workflow run completed* → workflow `CI`, conclusion `failure`, branch filter `nap-*`
- **Repository:** `vanoostrum/nap-time`
- **Model:** `claude-sonnet-5` (coding)
- **Tools:** Send to Slack, MCP: Linear (pushing to the existing PR branch is built in)
- **Prompt:**
  > Run the `fix-ci-failure` skill (`.agents/skills/factory/fix-ci-failure/SKILL.md`) for the failed workflow run in this event.
