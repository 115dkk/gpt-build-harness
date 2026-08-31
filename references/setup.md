# Setup (overview)

The executable tools (relay, proxy, launcher, agents) are **not in this repository's source**. They are in the release asset `gpt-build-harness-tools.zip`, and the install scripts place them for Claude Code, Codex or the Claude app. The concrete protocol and endpoints for calling the codex backend live inside those tools; this document covers the methodology only.

## Authentication and billing
The tools use the local ChatGPT **subscription token** (the codex login cache). That consumes subscription quota, not metered api.openai.com billing. The token is refreshed periodically by the running ChatGPT desktop app. When authentication expires, start the desktop app to revive the login session.

## The four forms (summary)
- **Oracle relay**: reasoning without tools. Works instantly in any session. Claude holds the hands. Opinions only.
- **Direct worker (`gpt-agent.ps1`)**: GPT holds the tools through a child claude. Works in any session, bridge included. The default labourer in ordinary sessions.
- **Worker subagent**: GPT holds the tools directly. Proxy sessions only (including the mixed session `gpt-cc -Main claude`).
- **Main loop model**: the whole session runs on GPT. The 500k auto-compact (`CLAUDE_CODE_AUTO_COMPACT_WINDOW=500000`) is set by the launcher.

For the detailed decision, see `three-forms.md`.

## Model operation
Follow the model policy in SKILL.md. In short: the model called is `gpt-daybreak-blue` (the new tuning of GPT-5.6 Sol; slug confirmed by measurement on 2026-08-19) and nothing else, effort is high by default, and max is used only for hopelessly hard problems. No other model and no other effort. The relay, the proxy and the launcher all default to this policy.

## Installation
Download the tools zip from the release and run the install script. Placement and procedure per target follow the "Installation" section of the README. The detailed behaviour of each tool is in the comments of the installed script.
