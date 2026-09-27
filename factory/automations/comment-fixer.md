# comment-fixer

- **Stage:** `comment-fix`
- **Trigger:** GitHub → *Pull request review comment* (and *Review submitted* with changes requested) → PRs whose head branch matches `nap-*`
- **Repository:** `vanoostrum/nap-time`
- **Model:** `claude-sonnet-5` (coding)
- **Tools:** Comment on pull request, MCP: Linear
- **Prompt:**
  > Run the `implement-task` skill (`.agents/skills/factory/implement-task/SKILL.md`) in review-comments mode for the PR comments in this event.
