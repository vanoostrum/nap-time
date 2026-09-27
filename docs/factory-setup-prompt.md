# Software Factory POC — Setup Prompt for Claude Code

You are setting up a **software factory POC** for me: an automated software development lifecycle for a native iOS app, driven by AI cloud agents. I am lazy — do everything you can yourself. Only stop when a step truly requires me (OAuth consent screens, creating tokens/keys, paid-account actions, anything in a browser UI you can't reach).

Work through the phases below **in order**. Keep going without asking unless a rule below says to stop.

---

## Working rules

1. **Plan first, then execute.** Start by reading this whole prompt, then create a checklist of all phases/steps in `SETUP_LOG.md` (in the repo root, on the setup branch). Tick items off as you go and log what you created (IDs, URLs, names — never secrets).
2. **Idempotent.** Before creating anything (Linear team/states/labels, Slack channels, GitHub labels, files, secrets), check whether it already exists. Reuse or update; never duplicate.
3. **Verify current docs before relying on them.** Products change. Before each phase, check the current official docs for the APIs/UIs you'll use (links at the bottom). If something in this prompt no longer matches reality, adapt, and note the deviation in `SETUP_LOG.md`.
4. **MANUAL STEP protocol.** When I must do something, stop and output exactly this block, then wait for my reply:
   ```
   🛑 MANUAL STEP <n>: <short title>
   Why: <one line>
   Do this:
     1. Open <exact URL>
     2. Click <exact button/menu path, verified against current docs>
     3. ...
   Then give me: <what to paste back, or "just reply done">
   Where to put secrets: <file path — never paste secrets into chat>
   I will verify by: <the check you'll run>
   ```
   After I reply, run the verification. If it fails, tell me precisely what's wrong and how to fix it.
   **Batch manual steps** where possible (e.g. collect all token creations in one stop) so I get interrupted as few times as possible.
5. **Secrets.** Never print, log, commit, or echo secrets. Keep them in `~/.config/factory-setup/.env` (create it, `chmod 600`, outside the repo). I'll paste secrets into that file myself; you read them from there. Push CI secrets with `gh secret set NAME < file` or `--body "$VAR"` from the env file, never inline literals.
6. **No destructive actions without asking.** Don't delete or overwrite existing Linear teams/states, Slack channels, GitHub branches, repo files, or settings without explicit confirmation. Work on a branch `factory-setup` and open a PR at the end; don't push directly to `main` (except enabling branch protection, which is a settings change).
7. **Stay generic where it's factory, specific where it's project.** Everything under `.agents/skills/factory/` and `factory/` must not mention Swift, iOS, TestFlight, or this app. Project specifics live only under `.agents/skills/project/`, `docs/`, CI, and fastlane.

---

## Phase 0 — Inputs & prerequisites

1. Ask me for these **in one message** (offer sensible defaults in brackets):
   - GitHub repo `owner/name` (it already exists)
   - Linear: create a new team `Factory` with key `FAC` [default], or use an existing team?
   - Slack workspace name
   - App display name, bundle ID [e.g. `com.<me>.<app>`], Apple Developer Team ID (if I know it)
   - Does the repo already contain an Xcode project? If not, may I generate a minimal SwiftUI skeleton?
   - Cursor plan: do I have access to self-hosted / Mac machines for cloud agents? [default: no → Linux agents + macOS CI]
2. Check local tools: `git`, `gh` (authenticated, with `repo`, `workflow`, `admin:repo_hook` scopes), `jq`, `curl`, `node`/`npx`, `ruby`/`bundler`, Xcode + `xcodebuild`, `xcodegen` (install via Homebrew if missing and I'm on macOS). Install what's missing if you can; otherwise tell me.
3. Clone/open the repo, create branch `factory-setup`.
4. **MANUAL STEP (batched): create tokens.** Guide me to create, and put into `~/.config/factory-setup/.env`:
   - `LINEAR_API_KEY` — Linear personal API key
   - `CURSOR_API_KEY` — Cursor API key (dashboard)
   - (Slack comes in Phase 2 because it needs an app first.)
   Verify each with a harmless read call (Linear `viewer` query; Cursor API "me"/models endpoint).

---

## Phase 1 — Linear (state machine)

Using the Linear GraphQL API (`https://api.linear.app/graphql`):

1. Create or select the team (default `Factory`, key `FAC`).
2. Create these **workflow states** (in this order, with appropriate state types). Rename/reuse Linear's defaults where they map cleanly; don't delete existing states without asking.

   | State | Type | Meaning |
   |---|---|---|
   | Triage | backlog | Front desk created it; may need clarification |
   | Specifying | started | Spec agent writing spec + plan |
   | Spec review | started | **Gate 1** — waiting for my ✅ in Slack |
   | Building | started | Build agent implementing |
   | Verifying | started | CI running / CI-fixer looping |
   | Reviewing | started | Automated reviewers |
   | Ready to merge | started | **Gate 2** — waiting for my ✅ in Slack |
   | Shipping | started | Merged; release pipeline → TestFlight |
   | Done | completed | Build available in TestFlight |
   | Needs human | started | An agent is stuck or hit a loop cap |
   | Canceled | canceled | — |

3. Create **labels**: `type:feature`, `type:bug`, `type:chore`, `risk:low`, `risk:high`.
4. Log team ID, state IDs, label IDs in `SETUP_LOG.md` and write them to `factory/linear.yaml` (IDs are not secrets).
5. Verify by querying the team's states and labels.

---

## Phase 2 — Slack (the only user ↔ factory interface)

1. Generate a Slack app manifest file `factory/slack-app-manifest.yaml` for a small **"Factory Setup"** bot with only the scopes needed to create/join channels, post messages, and pin (e.g. `channels:manage`, `channels:read`, `chat:write`, `pins:write`). This bot is only for setup; the runtime Slack interaction goes through Cursor's Slack integration.
2. **MANUAL STEP:** create the app from the manifest, install it to the workspace, put `SLACK_BOT_TOKEN` in the env file. Verify with `auth.test`.
3. Create public channels `#factory` and `#factory-log` (reuse if they exist).
4. Post and pin in `#factory` a short **"How to talk to the factory"** message:
   - Post a new top-level message to start a work item ("Add X", "Bug: Y").
   - Everything about that item happens in its thread.
   - React ✅ (or reply "approve") on a gate message to approve; reply with feedback to request changes.
   - Ask "status" / "what's in flight?" anytime.
5. Post a one-line purpose message in `#factory-log`.
6. Runtime integration is set up in Phase 5 (Cursor ↔ Slack), including inviting the Cursor app to both channels.

---

## Phase 3 — GitHub repo scaffold

Create the following on branch `factory-setup`.

### 3.1 Context layer
- `AGENTS.md` — concise: what the project is, where things live, conventions, and the **factory conventions**:
  - Branch names: `fac-<num>/<slug>`; PR titles: `[FAC-<num>] <title>`
  - Commit trailers: `Factory-Issue: FAC-<num>` and `Factory-Stage: <stage>`
  - Every stage agent appends a **run record** comment to the Linear issue: `stage | model | started | finished | outcome | notes`
  - Every stage agent posts its human-facing update into the item's Slack thread (thread link stored on the Linear issue); noisy detail goes to `#factory-log`
  - Loop cap: max 3 automatic fix attempts per stage, then move to **Needs human** and ping in the thread
- `docs/architecture.md` — placeholder with sections to fill; `docs/adr/0001-software-factory.md` — record the factory design (layers: Slack interface, Linear state, repo knowledge, Cursor execution, GitHub Actions + fastlane verify/release; orchestration = Linear workflow + Slack front desk); `docs/specs/README.md` — spec file naming `FAC-<num>-<slug>.md` and the spec template.

### 3.2 Harness-neutral factory definition
- `factory/stages.yaml` — for each stage: `name`, `linear_state`, `trigger` (described neutrally, e.g. `linear.status_changed: Specifying`), `skill`, `model_class` (`reasoning` | `coding` | `review-different-family` | `fast`), `outputs`, `next_state`, `on_failure`, `loop_cap`, `gate` (true/false). This file is the source of truth; harness-specific automation configs are derived from it.

### 3.3 Skills (Agent Skills format: folder + `SKILL.md` with `name`/`description` frontmatter)
Every **factory** skill must follow the same structure: *Purpose · Inputs · Outputs · Done criteria · Steps · Escalation (→ Needs human) · Reporting (Slack thread + Linear run record + metrics tags)*. Stage skills define the **contract**; they delegate craft (e.g. how to write good tests) to other skills where available, so those can be swapped later.

`.agents/skills/factory/`:
- `front-desk` — handles Slack messages in `#factory`:
  - New top-level message → clarify only if truly ambiguous (max 2 questions), then create Linear issue (state **Specifying**, with type label), store Slack thread link on the issue, reply in thread with the issue link.
  - ✅ reaction or "approve" in a thread → look up the issue: if **Spec review** → merge the spec PR and move to **Building**; if **Ready to merge** → merge (or enable auto-merge on) the code PR and move to **Shipping**. Otherwise say there's nothing to approve.
  - Feedback reply at a gate → pass feedback to the relevant stage (move back to Specifying/Building with the feedback added as a comment).
  - "status" questions → summarize in-flight issues by state.
- `write-spec` — from the Linear issue, write `docs/specs/FAC-<num>-<slug>.md` (context, scope, non-goals, testable acceptance criteria, design notes, risks) and a task plan (delegate to `plan-tasks`); open a spec PR; post a short summary + PR link in the thread as a **gate message** ("React ✅ to approve"); move to **Spec review**.
- `plan-tasks` — ordered, small, independently verifiable tasks appended to the spec.
- `implement-task` — implement the approved spec's tasks, tests first; use the project's `verify-*` skill for how to build/test; open code PR linked to the issue; move to **Verifying**.
- `fix-ci-failure` — on a failed CI run for a `fac-*` branch: read logs, fix, push; count attempts via commit trailers; at cap → **Needs human**.
- `review-against-spec` — on green CI: check the diff against the spec's acceptance criteria; comment on the PR; if all criteria met, post a gate summary in the thread ("React ✅ to merge") and move to **Ready to merge**; otherwise request changes and move back to **Building**.
- `write-release-notes` — after the release workflow succeeds: write TestFlight "What to test" notes from the spec, post build info in the thread, move to **Done**.
- `bootstrap-project-skills` — meta-skill: inspect a repository and generate project-specific `verify-*` and `release-*` skills. (For this POC, write it but the project skills below are hand-authored; later test it by regenerating them.)

`.agents/skills/project/`:
- `verify-ios` — how to build, test, lint this app (xcodebuild scheme/destination, SwiftLint/SwiftFormat); note that cloud agents may run on Linux without Xcode, so they must rely on CI results and push small, frequent commits; pure logic should live in Swift packages testable with `swift test`.
- `release-testflight` — how the fastlane lane ships to TestFlight and where to find build status.

### 3.4 iOS project (only if none exists and I agreed)
- Minimal SwiftUI app generated with **XcodeGen** (`project.yml` checked in, `.xcodeproj` generated), one unit test target, a local Swift package `Core` for testable logic. Build and test locally once to prove it works.

### 3.5 CI/CD
- `.github/workflows/ci.yml` — on PR and push: macOS runner, latest stable Xcode, `xcodegen generate` (if used), build + test, SwiftLint. Name the job clearly (branch protection will require it).
- `.github/workflows/release.yml` — on push to `main`: run fastlane `beta` lane → TestFlight.
- `fastlane/Appfile`, `fastlane/Fastfile` (`beta` lane: App Store Connect API key auth, signing via **match** in a private repo, bump build number, build, upload to TestFlight), `Gemfile`.
- `.github/pull_request_template.md` with `Factory-Issue`, spec link, acceptance-criteria checklist.
- GitHub labels mirroring Linear types/risk.

### 3.6 Commit, PR, protect
- Commit with sensible messages; open PR `factory-setup` → `main`. Tell me the PR link.
- After I merge it (**MANUAL STEP**: "review & merge PR"), enable branch protection on `main`: require PR, require the CI check, no force pushes.

---

## Phase 4 — Apple / TestFlight

1. **MANUAL STEP (batched):**
   - Confirm Apple Developer Program membership; note Team ID.
   - Create the App ID / bundle ID and the app record in App Store Connect (if not existing).
   - Create an **App Store Connect API key** (App Manager role), download the `.p8` to `~/.config/factory-setup/`, and put `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_PATH` in the env file.
2. Create a private GitHub repo `<owner>/<app>-certificates` for fastlane match (ask first). Run `fastlane match appstore` locally to create certs/profiles (may trigger a manual step for a match passphrase → env file `MATCH_PASSWORD`).
3. Push CI secrets with `gh secret set`: ASC key ID, issuer ID, key content (base64), `MATCH_PASSWORD`, and a deploy key or token for the certificates repo.
4. Verify: trigger `release.yml` manually (add `workflow_dispatch`) and confirm a build reaches TestFlight processing.

---

## Phase 5 — Cursor (execution layer)

1. **MANUAL STEP (batched):** in Cursor's dashboard, connect **GitHub** (grant access to the app repo), **Slack** (invite the Cursor app to `#factory` and `#factory-log`), and **Linear**; set a monthly **spend limit**; configure the **cloud agent environment** for the repo (Linux default; note Mac machines if I have them). Give me exact clicks verified against current docs.
2. Enable **Bugbot** (with Autofix) and the **Security Reviewer** agent for the repo (manual step if needed).
3. For each automation below, write a spec file `factory/automations/<name>.md` (trigger, filters, repo, model, tools, one-line prompt). Prompts stay **one line** and point to the skill, e.g. *"Run the `write-spec` skill for the Linear issue in this event."* Pick models from what Cursor currently offers (query the models endpoint): `reasoning` → strongest reasoning model; `coding` → strong fast coding model; `review-different-family` → a model from a **different vendor** than the coding model; `fast` → cheap fast model.

   | Automation | Trigger | Model class | Tools |
   |---|---|---|---|
   | front-desk | Slack new message in `#factory` (with a filter so thread replies also fire) + Slack ✅ reaction | fast | Read Slack, Send to Slack, Linear, GitHub (merge) |
   | spec | Linear status changed → Specifying | reasoning | Linear, Send to Slack, PR creation |
   | build | Linear status changed → Building | coding | Linear, Send to Slack, PR creation |
   | ci-fixer | GitHub workflow run completed (CI, failed, `fac-*` branches) | coding | Linear, Send to Slack |
   | spec-reviewer | GitHub CI completed (success, `fac-*` PRs) | review-different-family | Comment on PR, Linear, Send to Slack |
   | comment-fixer | PR review comment (on `fac-*` PRs) | coding | Comment on PR |
   | release-notes | GitHub workflow run completed (release, success, `main`) | fast | Linear, Send to Slack |

4. **Create the automations.** First check whether Cursor's API or Terraform provider supports creating automations; if yes, create them programmatically from the spec files. If not, give me **one MANUAL STEP per automation** with the exact text to paste into Cursor's `/automate` skill (or the Automations UI fields), derived from the spec file.
5. Verify each automation exists and is active (API list or ask me to confirm with a screenshot-free "done").
6. Open questions to test here and log the answer: can "Send to Slack" reply **in a thread**? If not, switch convention to channel posts prefixed with `[FAC-<num>]` and update `AGENTS.md` and skills accordingly. Does the Linear integration let agents change status and comment? If not, configure the Linear MCP server for the automations.

---

## Phase 6 — Smoke test (end to end)

1. Ask me to post in `#factory`: *"Add an About screen that shows the app version and build number."*
2. Watch the flow and report at each transition: Linear issue created → spec PR + gate message → (I ✅) → code PR → CI → spec review → gate message → (I ✅) → merge → release → TestFlight notes in thread → Done.
3. Check metrics tagging: branch/PR/commit trailers and Linear run records are present.
4. If anything breaks, diagnose, fix the relevant skill/config/automation, and re-run. Log every fix in `SETUP_LOG.md`.

---

## Phase 7 — Wrap-up

Finish with a short summary: what was created (with links), what's still manual or unverified, the manual steps I did, and the top 3 suggested next improvements (e.g. Mac-backed agents, `bootstrap-project-skills` validation, weekly metrics/retro automation). Commit the final `SETUP_LOG.md` via a small PR.

---

## Reference docs (check current versions)
- Cursor Automations: https://cursor.com/docs/cloud-agent/automations
- Cursor Cloud Agents & API: https://cursor.com/docs/cloud-agent
- Cursor Skills: https://cursor.com/docs/skills
- Cursor Bugbot: https://cursor.com/docs/bugbot · Security Agents: https://cursor.com/docs/security-agents
- Linear API: https://linear.app/developers
- Slack app manifests: https://api.slack.com/reference/manifests
- GitHub CLI: https://cli.github.com/manual
- fastlane (match, pilot/TestFlight): https://docs.fastlane.tools
- XcodeGen: https://github.com/yonaskolb/XcodeGen
- App Store Connect API keys: https://developer.apple.com/documentation/appstoreconnectapi
