---
name: gpt-build-harness
description: >-
  Operating manual for the two GPT labourers that run on the ChatGPT
  subscription quota: Daybreak Blue (gpt-daybreak-blue) for backend work,
  ASTRA (gpt-6-astra) for wiring backend to frontend, knowledge-heavy
  implementation, i18n catalogues and audits. Screens are not GPT work: Claude Opus 5.5 draws
  them, and Opus 5.5 also stands in for both GPT workers when the quota is
  spent. Holds the measured model facts (slugs, effort rungs, context
  windows), how the ClaudeRipple router puts both one Agent() call away in
  every session, how to write a task brief, what to do on a spent quota, and
  the pitfalls. Read it before delegating to gpt-worker or astra-worker the
  first time in a session, and whenever a call does not route, a worker's
  output looks like Claude wrote it, or a gate fails in a way the worker did
  not report. Who gets which task is not here: that policy is always loaded
  from ~/.claude/rules/gpt-workers.md.
---

# GPT Build Harness (Daybreak Blue + ASTRA)

Instead of burning Claude on the whole build, attach GPT as a labourer: delegate implementation and verification, keep architecture, design direction, integration and the verdict with Claude. Calls run on the ChatGPT **subscription quota**, so Claude tokens are saved.

**Who gets what is not in this document.** That policy is in `~/.claude/rules/gpt-workers.md`, which loads in every session. This document holds what you only need once you are actually delegating: the measured model facts, the plumbing, the brief, and the pitfalls.

> Everything in the pre-2026-08-19 docs that read as "how to use GPT" (the luna/sol/terra tier table, the effort measurement table, the prompt A/B battery) was discarded outright for being riddled with hallucination.

## Model facts, all measured

**Daybreak Blue is the backend labourer; ASTRA wires, looks things up and audits.** Neither draws: since 2026-09-25 screens are Claude Opus 5.5's work. Nothing else is called on the GPT side: luna/sol/terra and the rest of the 5.x line are discarded as targets.

- **Daybreak Blue, slug `gpt-daybreak-blue`**, with no version prefix. Confirmed against the codex responses backend on 2026-08-19: `gpt-5.6-daybreak-blue` and `gpt-5.6-daybreak` return HTTP 400, and only `gpt-daybreak-blue` returns 200. It is the tuning of GPT-5.6 Sol, and it stays the default for backend labour because it is cheaper on the subscription quota and just as good at it.
- **ASTRA, slug `gpt-6-astra`.** Verified live on 2026-09-05: it returns 200 and echoes `model: gpt-6-astra`, while `gpt-6`, `gpt-astra` and `gpt-6-astra-latest` all return HTTP 400.
- **Effort: `high` by default, and high is the sweet spot.** Three rungs are used, `high`, `xhigh` and `max`; `low` and `medium` never are. On Daybreak, `max` stays reserved for hopelessly hard problems. On ASTRA the two rungs above high are open but **unmeasured**, so climb them deliberately and report what you find.
- **`ultra` is not sendable.** The responses endpoint answers HTTP 400 for it on both models, listing none/minimal/low/medium/high/xhigh/max (measured 2026-09-05). Ultra is a Codex client mode, so it is selectable for ASTRA in the Codex app and CLI but never here. The router clamps `ultra` to `max` rather than forwarding it.
- **Context windows differ, and `contextWindow` is not the compaction point.** Claude Code compacts at `contextWindow - min(maxOutputTokens, 20000) - 13000`, a fixed reserve rather than a fraction (read from the 2.1.258 binary). With `behavesAs` inheriting an Opus-sized output cap, the reserve is a flat 33,000. So the config carries the compaction target plus 33,000: Daybreak 533000 to compact at 500k, ASTRA 893000 to compact at 860k. See the pitfalls.
- **ASTRA's `version` gate fires on a claimed-old version, not on an absent one.** The backend answers `The 'gpt-6-astra' model requires a newer version of Codex` (HTTP 400) when the caller claims an old CLI version: 0.144.1 was refused and 0.153.4 accepted (measured 2026-09-05). The router sends no `version` header at all, and that passes (measured 2026-09-18). Claiming nothing is safer than claiming something stale.

## Routing

One router in front of everything, so one calling form. `Agent(gpt-worker)` is Daybreak and `Agent(astra-worker)` is ASTRA, and both work in any session because the router is wired through `settings.json` rather than a per-session base URL. To change model or effort for one call only, put a marker on the first line of the brief:

```
[[gpt: <model>@<effort>]]
```

The setup, the config file and what to do when a call does not route are in `references/routing.md`.

Opus 5.5 needs no agent definition of its own. The Agent tool's `model` argument takes `"opus"`, which follows the newest Opus and went out as `claude-opus-5-5` when measured on 2026-09-25. For screens the main session should not draw itself, that is `Agent(subagent_type: "general-purpose", model: "opus")`. The argument also overrides an agent file's `model:` line, which is what the quota fallback below relies on.

## When the quota is spent

Both GPT models draw on one ChatGPT subscription quota, so a 429 `usage_limit_reached` from either means both are out. Measured 2026-09-18: both slugs came back 429 within a minute on the same credentials. The failure shows in the Agent result and in `clauderipple logs`.

Do not wait for the quota to come back. Repeat the same call, same worker and same brief, with `model: "opus"` added. The worker's own instructions stay in force and only the model changes: measured 2026-09-25, `gpt-worker` called that way answered as `claude-opus-5-5`. Take any model marker off the brief's first line first: the router honours a marker on any model, so a brief that still carries one sends the stand-in straight back to the spent quota.

## Why the boundary sits where it does

The policy states the boundary. The reasons are worth having when a case sits on the edge.

**Daybreak is an excellent backend practitioner and auditor, and it struggles to hold the whole context.** Spend it freely on implementation, review, verification and knowledge lookup. Do not spend it on anything whose correctness depends on the shape of the whole: module boundaries, interfaces, data flow, error policy, CI/CD design. Give Daybreak the structural design and you get something locally plausible that contradicts the whole.

**Never put Daybreak on the frontend.** Its aesthetic sense is catastrophic to a degree that produces output no human can use, and that prohibition has no exceptions.

**ASTRA no longer draws.** From 2026-09-05 to 2026-09-25 it drew inside frontends that already stood. Opus 5.5 draws better and can raise a frontend from nothing as well, so screens moved to Claude. ASTRA keeps the work where its breadth of knowledge pays: wiring the backend's surface into the frontend's calls, state and event handling; implementation that needs more than plain backend knowledge (platform APIs, protocols, external specs, the problems Daybreak stalls on); i18n catalogues; and audits. Catalogues stay with ASTRA because what matters there is whether the text reads naturally, and ASTRA keeps sentimental, dressed-up phrasing out better than Claude does (the user's judgement, 2026-09-25). On wiring it may open a screen file, but only to change calls and state, never markup or style, and it never decides what a screen is for.

## The whole-backend delegation pattern

This is the operating mode with the largest savings.

1. Claude settles architecture and interfaces, then delegates the entire backend, or a module at a time, to Daybreak.
2. Daybreak implements it and returns, alongside the code, a **list of things to wire into the frontend** (endpoints, function signatures, events, config keys). Ask for this list explicitly in the brief.
3. Claude takes that list and hands the wiring to ASTRA when it is more than a trivial edit. The screens themselves are drawn by Opus 5.5: the main session when it runs Opus 5.5, an Agent call with `model: "opus"` otherwise or when the batch is large. Claude passes judgement by running the integration build and tests.

## Writing the brief

- **Self-contained.** The worker holds tools and can read the repository, but it starts with none of this conversation. Nail down the design and the signatures, list the files it may touch, give the verification commands and the report format. Absolute paths throughout.
- **Nail down what counts as finished.** For example: this must compile as a single file; put the wiring list in its own section.
- **Foreground the gates.** Tell it to run build and test commands in the foreground and to end its turn only after reporting.
- **Send it to the documentation.** Tell it to check any API it is unsure of instead of writing from memory. When the exact wording matters, name the URL and let it use WebFetch: a worker's WebSearch runs on a small Anthropic model as a side request and hands back only titles and URLs.
- **For screens handed to an Opus 5.5 subagent, add the design direction**: the tokens to use and where they are defined, the path of a neighbouring component to imitate, the list of states, the interface ids it must not touch, the gate commands to run. With no frontend yet, give what the screen is for and the framework instead of tokens and neighbours.
- **For ASTRA's wiring**, add Daybreak's wiring list, the call-site and state files it may change, and the markup and style files it must leave alone.
- **Claude applies and verifies.** A worker's self-report is never the gate; Claude runs the build and the tests itself.

Two workers run side by side in one worktree when their file sets do not overlap.

## Pitfalls

In `references/pitfalls.md`. The ones stepped on most often:

- **A worker's self-report and its output are two different things.** Open the output yourself.
- **Opening the shell means opening both shell tools on Windows.** A worker given only `Bash` is auto-denied when it picks `PowerShell`, and it delivers code with no verified gate.
- **The worker starts subagents and worktrees on its own.** Check the tree, not the report, and pin absolute output paths in the brief.
- **HTML entities in agent and Workflow results are a display-layer artefact.** Read the original from `journal.jsonl`; do not restore them by hand.
- **A worker's WebSearch runs on Anthropic, not on the worker's model.** It works, it bills Claude rather than ChatGPT, and only titles and URLs come back.
