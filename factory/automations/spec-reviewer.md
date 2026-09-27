# spec-reviewer

- **Stage:** `review`
- **Trigger:** GitHub → *CI completed* → conclusion `success`, PRs whose head branch matches `nap-*`. Exclude spec PRs (`*-spec`) if the filter allows; otherwise the skill no-ops on them.
- **Repository:** `vanoostrum/nap-time`
- **Model:** `gpt-5.6-sol` (review-different-family; the builder is Anthropic)
- **Tools:** Comment on pull request, Send to Slack, MCP: Linear
- **Prompt:**
  > Run the `review-against-spec` skill (`.agents/skills/factory/review-against-spec/SKILL.md`) for the pull request in this event.
