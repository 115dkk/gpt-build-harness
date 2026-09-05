# Setup (overview)

The executable tools (relay, proxy, launcher, agents) are **not in this repository's source**. They are in the release asset `gpt-build-harness-tools.zip`, and the install scripts place them for Claude Code, Codex or the Claude app. The concrete protocol and endpoints for calling the codex backend live inside those tools; this document covers the methodology only.

## Authentication and billing
The tools use the local ChatGPT **subscription token** (the codex login cache). That consumes subscription quota, not metered api.openai.com billing. The token is refreshed periodically by the running ChatGPT desktop app. When authentication expires, start the desktop app to revive the login session.

## The four forms (summary)
- **Oracle relay**: reasoning without tools. Works instantly in any session. Claude holds the hands. Opinions only.
- **Direct worker (`gpt-agent.ps1`)**: GPT holds the tools through a child claude, web search included (the proxy runs it as the codex web search). Works in any session, bridge included. The default labourer in ordinary sessions.
- **Worker subagent**: GPT holds the tools directly. Proxy sessions only (including the mixed session `gpt-cc -Main claude`). `gpt-worker` is Daybreak, `astra-worker` is ASTRA.
- **Main loop model**: the whole session runs on GPT. The launcher sizes the window per model: 500k auto-compact for Daybreak Blue, a 1M window compacting at 860k for ASTRA.

For the detailed decision, see `three-forms.md`.

## Model operation
Follow the model policy in SKILL.md. In short: two models and nothing else. `gpt-daybreak-blue` (the tuning of GPT-5.6 Sol; slug confirmed by measurement on 2026-08-19) does the backend labour, and `gpt-6-astra` (GPT-6 Astra; slug confirmed 2026-09-05) draws screens, does i18n catalogues and takes the problems Daybreak stalls on. Effort is high by default and high is the sweet spot; `xhigh` and `max` are the rungs above it, reserved on Daybreak for hopelessly hard problems and still unmeasured on ASTRA. `low` and `medium` are not used. The relay, the proxy, the launcher and the direct worker all default to daybreak-blue/high. ASTRA additionally needs the proxy's `version` header to be current, so keep the codex CLI updated.

## Installation
Download the tools zip from the release and run the install script. Placement and procedure per target follow the "Installation" section of the README. The detailed behaviour of each tool is in the comments of the installed script.
