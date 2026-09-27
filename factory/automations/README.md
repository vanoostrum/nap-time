# Automations (Cursor harness)

Derived from `factory/stages.yaml`. Cursor has **no public API or Terraform provider** for automations (checked 2026-09-28: `GET /v1/automations` → 404; no provider in the Terraform registry). Automations are therefore created in the Cursor UI (cursor.com/automations → New automation) or via `/automate`, using these files as the spec.

## Model mapping (from `GET /v1/models`, 2026-09-28)
| Class | Model | Why |
|---|---|---|
| `reasoning` | `claude-opus-5-5` | strongest reasoning model offered |
| `coding` | `claude-sonnet-5` | strong, fast coding model |
| `review-different-family` | `gpt-5.6-sol` | OpenAI, a different vendor from the coding model (Anthropic) |
| `fast` | `claude-haiku-4-5` | cheap and fast, reliable tool use |

## Shared settings (every automation)
- **Repository:** `vanoostrum/nap-time`, branch `main`
- **Environment:** cloud (Linux) default environment for the repo
- **MCP:** Linear (`https://mcp.linear.app/mcp`). Cursor has no built-in Linear editing tool, and agents need it to change status and comment.
- **Memory:** on (default)
- **Prompt:** always one line, pointing at a skill file.
