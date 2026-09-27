# Software Factory Setup Log

Source prompt: [docs/factory-setup-prompt.md](docs/factory-setup-prompt.md)
Branch: `factory-setup` · Secrets live in `~/.config/factory-setup/.env` (never in this repo).

## Checklist

### Phase 0 — Inputs & prerequisites
- [x] 0.1 Collect inputs (repo, Linear team, Slack workspace, app name/bundle ID/Team ID, Xcode project, Cursor Mac access)
- [x] 0.2 Local tools: git ✅, jq ✅, curl ✅, node/npx ✅, xcodebuild (Xcode 26.6) ✅, fastlane ✅, xcodegen 2.46.0 ✅ (brew), swiftlint 0.65.1 ✅ (brew), gh auth ✅ (fine-grained PAT as GH_TOKEN in env file)
- [x] 0.3 Branch `factory-setup` created
- [x] 0.4 MANUAL: `LINEAR_API_KEY`, `CURSOR_API_KEY` in env file; verified

### Phase 1 — Linear
- [x] 1.1 Team `Nap Time` / `NAP` (reused existing)
- [x] 1.2 Workflow states (11)
- [x] 1.3 Labels (`type:*`, `risk:*`)
- [x] 1.4 IDs → `factory/linear.yaml` + this log
- [x] 1.5 Verify states/labels

### Phase 2 — Slack
- [x] 2.1 `factory/slack-app-manifest.yaml`
- [x] 2.2 MANUAL: create/install app, `SLACK_BOT_TOKEN`; verify `auth.test`
- [x] 2.3 Channels `#factory`, `#factory-log`
- [x] 2.4 Pinned "How to talk to the factory" in `#factory`
- [x] 2.5 Purpose message in `#factory-log`

### Phase 3 — GitHub repo scaffold
- [x] 3.1 `AGENTS.md`, `docs/architecture.md`, `docs/adr/0001-software-factory.md`, `docs/specs/README.md`
- [x] 3.2 `factory/stages.yaml`
- [x] 3.3 Factory skills (8) + project skills (2)
- [x] 3.4 XcodeGen SwiftUI app + `Core` package; local build + test
- [x] 3.5 CI/CD: `ci.yml`, `release.yml`, fastlane, `Gemfile`, PR template, GitHub labels
- [~] 3.6 Commit, PR ✅ https://github.com/vanoostrum/nap-time/pull/1 · MANUAL merge ⏳ · branch protection ⏳

### Phase 4 — Apple / TestFlight
- [ ] 4.1 MANUAL: Team ID, App ID, ASC app record, ASC API key
- [ ] 4.2 Private certificates repo + `fastlane match appstore`
- [ ] 4.3 CI secrets via `gh secret set`
- [ ] 4.4 Verify: `release.yml` dispatch → TestFlight processing

### Phase 5 — Cursor
- [ ] 5.1 MANUAL: connect GitHub/Slack/Linear, spend limit, cloud agent env
- [ ] 5.2 Bugbot (+Autofix), Security Reviewer
- [x] 5.3 `factory/automations/*.md` (7)
- [ ] 5.4 Create automations (API/Terraform or manual)
- [ ] 5.5 Verify automations active
- [ ] 5.6 Open questions: threaded Send to Slack? Linear status/comment ability?

### Phase 6 — Smoke test
- [ ] 6.1–6.4 End-to-end "About screen" run

### Phase 7 — Wrap-up
- [ ] Summary + final log PR

## Created resources
_(IDs, URLs, names — never secrets)_

### Inputs
- GitHub repo: `vanoostrum/nap-time`
- Linear: workspace `nap-time`, team **Nap Time** key `NAP` (`7f0c8ad0-d011-49f3-936b-1888bdc1266b`) — reused existing team
- Slack workspace: `clearblocks`
- App: **Nap Time**, bundle ID `nl.clearblocks.naptime`, Apple Team ID: TBD (Phase 4)
- Xcode project: none → generate XcodeGen SwiftUI skeleton (approved)
- Cursor: no Mac/self-hosted machines → Linux cloud agents + macOS CI
- Verified: Linear `viewer` = Theo; Cursor `GET /v1/me` = key `factory-setup`

### Linear (Phase 1) — full IDs in `factory/linear.yaml`
- Renamed defaults: Backlog → **Triage**, In Progress → **Building**, In Review → **Reviewing**; reused **Done**, **Canceled**
- Created (started): Specifying, Spec review, Verifying, Ready to merge, Shipping, Needs human
- Kept untouched: Todo (unstarted), Duplicate; existing labels Feature/Bug/Improvement
- Created labels: `type:feature`, `type:bug`, `type:chore`, `risk:low`, `risk:high`

### Slack (Phase 2)
- Workspace **Clearblocks**; setup app "Factory Setup", bot user `factorysetup` (bot ID `B0C5NFZ4AHE`)
- `#factory` = `C0C4U2EANN6`, `#factory-log` = `C0C4P3GT33P` (created by the setup bot)
- Pinned guide in `#factory`: ts `1790546470.971939`; purpose message in `#factory-log`: ts `1790546458.162939`

### GitHub
- `vanoostrum/nap-time` (public, admin via PAT); `vanoostrum/nap-time-certificates` (private, pre-created by user)

### Repo scaffold (Phase 3)
- XcodeGen app `NapTime` (display name "Nap Time", bundle `nl.clearblocks.naptime`, iOS 18, Swift 6) + local package `Packages/Core`
- Verified locally: `swift test` (Core, 6 cases) ✅, `xcodebuild test` on iPhone simulator (iOS 26.5) ✅, `swiftlint --strict` 0 violations ✅
- fastlane 2.240.1 via Bundler (Ruby 3.2.4); lanes `certs`, `beta`, `notes`; option names verified against the gem source
- Workflows: `CI` (job **Build & Test**, macos-26), `Release` (push to main + dispatch), `TestFlight Notes` (dispatch; lets Linux agents set What to Test without ASC creds)
- GitHub labels: `type:feature`, `type:bug`, `type:chore`, `risk:low`, `risk:high`, `factory`

### Phase 4/5 prep
- Match deploy key generated (`~/.config/factory-setup/match_deploy_key`, outside repo); private key pushed as secret `MATCH_DEPLOY_KEY`; public key must be added to `nap-time-certificates` manually (PAT got 403 on deploy-keys API)
- Cursor model mapping: reasoning `claude-opus-5-5`, coding `claude-sonnet-5`, review `gpt-5.6-sol`, fast `claude-haiku-4-5` (see `factory/automations/README.md`)

## Deviations from the prompt
- **Cursor automations can't be created programmatically**: no documented API (`GET /v1/automations` → 404) and no Terraform provider in the registry → one manual step per automation.
- **No built-in Linear editing tool** in Cursor automations (docs list Linear only as a trigger) → automations get the Linear MCP server (`https://mcp.linear.app/mcp`).
- `factory/automations/*.md` name the repo (`vanoostrum/nap-time`) and Linear team, which is harness instance config; they contain no stack mentions.
- Added `.github/workflows/testflight-notes.yml` + `notes` lane: cloud agents have no App Store Connect credentials, so `write-release-notes` sets notes by dispatching this workflow.
- Match auth in CI uses an SSH **deploy key** (read-only) on `nap-time-certificates` (`MATCH_DEPLOY_KEY` secret) instead of a PAT.
- `factory/linear.yaml` contains the team name "Nap Time" — it is instance data mandated by the prompt; stage definitions and factory skills stay app-agnostic (checked with grep).
- Cursor docs say project skills are discovered from `.agents/skills/**`; since cloud-agent loading of project skills is ambiguous in the docs, automation prompts reference the full `SKILL.md` path.
- Linear→Slack thread link is stored as a `Slack-Thread: <permalink>` line in the issue description (readable/writable by any Linear tool).
- Setup bot lacks `channels:history`, so re-runs can't check #factory-log / #factory history. First guide post went out without capturing its ts → **one unpinned duplicate guide message in #factory** (delete manually). Added `channels:history` to the manifest for future re-runs.
- Linear team is **Nap Time / `NAP`** (user choice), not `Factory / FAC`. Project conventions use `NAP-<num>`; factory-generic files use `<KEY>-<num>` and read the key from `factory/linear.yaml`.
- gh CLI was not authenticated at start → added to the first manual step.
- System Ruby is 2.6; using rbenv Ruby 3.2.4 (`.ruby-version`) for bundler/fastlane.

## Fix log
