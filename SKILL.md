---
name: gpt-build-harness
description: >-
  A harness that puts two OpenAI models (ChatGPT subscription quota, no API
  billing) to work as labourers and auditors, so that implementation and
  verification cost almost no Claude tokens. Daybreak Blue (gpt-daybreak-blue,
  the tuning of GPT-5.6 Sol) does the backend labour; ASTRA (gpt-6-astra,
  GPT-6 Astra, released 2026-09-03) is the model trusted with screens, so
  non-trivial frontend drawing and i18n catalogue labour go to it and Claude
  stops drawing them by hand. Effort is high by default, and max is reserved
  for hopelessly hard problems. Claude keeps architecture, design direction,
  planning and the verdict; the workers produce code and opinions.
  GPT runs in four forms: (1) a tool-less oracle relay for opinions only,
  (2) the direct worker (gpt-agent.ps1: a tool-holding GPT in any session
  with no haiku wrapper, the default labourer in ordinary sessions, used for
  backend work without the user having to ask), (3) the
  worker subagent (proxy sessions only; with gpt-cc -Main claude the main
  loop stays Claude and Agent() collaboration is native), (4) Claude Code's
  main loop model (auto-compact at 500k). Backend implementation goes to the
  Daybreak worker by default and non-trivial drawing to the ASTRA worker
  (gpt-agent.ps1 -Model astra, or the astra-worker subagent); the relay is
  only for audit or for work where GPT must not hold write access. The
  executable tools ship as a release asset.
---

# GPT Build Harness (Daybreak Blue + ASTRA)

Instead of burning Claude on the whole build, attach GPT as a labourer: delegate implementation and verification, and keep architecture, design direction, integration and the verdict with Claude. Calls run on the ChatGPT **subscription quota**, so Claude tokens are saved.

This document is the overview; per-form detail lives in `references/`. **The executable scripts (relay, proxy, launcher, agent) are not in this repository's source. They ship as the release asset `gpt-build-harness-tools.zip`.**

> The Korean edition of this document is kept in the repository as `SKILL_ko.md`. English is the canonical text: it is what gets installed, and it costs far fewer tokens to load.

> Everything in the old docs that read as "how to use GPT" (the luna/sol/terra tier table, the effort measurement table, the prompt A/B battery) was **discarded outright** on 2026-08-19 for being riddled with hallucination. The policy below replaces it.

## Model policy — two models, one job each

**Daybreak Blue is the backend labourer; ASTRA is the one that may draw.** Nothing else is called: luna/sol/terra and the rest of the 5.x line are discarded as targets.

- **Daybreak Blue, slug `gpt-daybreak-blue`**, with no version prefix. Confirmed against the codex responses backend on 2026-08-19: variants such as `gpt-5.6-daybreak-blue` and `gpt-5.6-daybreak` all return HTTP 400, and only `gpt-daybreak-blue` returns 200. It is the tuning of GPT-5.6 Sol, and it stays the default for backend labour because it is cheaper on the subscription quota and just as good at it.
- **ASTRA, slug `gpt-6-astra`** (GPT-6 Astra, released 2026-09-03). Verified live against the same backend on 2026-09-05: it returns 200 and echoes `model: gpt-6-astra`, while `gpt-6`, `gpt-astra` and `gpt-6-astra-latest` all return HTTP 400. This is the model sent at screens, i18n catalogues, and the backend problems Daybreak stalls on.
- **Effort: `high` by default.** Use `max` only when the problem is hopelessly hard. **The remaining efforts (low/medium/xhigh) are never used.** ASTRA takes low through max but rejects `ultra` with HTTP 400 (measured 2026-09-05) where Daybreak accepts it. The relay, the proxy, the launcher and the direct worker all default to daybreak-blue/high, so omitting the instruction still follows policy.
- **ASTRA is gated on the `version` header.** The backend answers `The 'gpt-6-astra' model requires a newer version of Codex` (HTTP 400) when the caller claims an old CLI version; the proxy used to send 0.144.1 and was refused. It now sends 0.153.4. Keep `GPT_CODEX_VERSION` at or above the installed codex CLI, and keep that CLI current (`codex update`; the Store app updates itself).
- The per-form syntax (the relay's `GPT-MODEL:`/`GPT-EFFORT:` directive lines, the direct worker's `-Model daybreak|astra`, the `gpt-daybreak-blue-high` / `gpt-6-astra-high` suffix form for worker and main) is in `references/three-forms.md`.

## Role boundary — what to delegate, what to keep

**Daybreak is an excellent backend practitioner and auditor.** Spend it freely on backend implementation, code review, verification, cross-checking, second opinions and knowledge lookup.

**It does, however, struggle to hold the whole context.** Therefore:

- **Claude nails down architecture and planning.** Module boundaries, interfaces (types, signatures, returns), data flow and error policy are settled by Claude first and handed over as a self-contained specification. Give Daybreak the structural design and you get something locally plausible that contradicts the whole.
- **CI/CD pipeline design is Claude's too.** It is whole-context work by nature, so it is not delegated for the same reason (implementing or reviewing an individual script can be).
- **Use it aggressively for audit.** Attaching finished backend code or a diff and asking for defects, boundary conditions and a second opinion is what Daybreak is good at. Its opinion is input, not a conclusion: Claude decides what to adopt and runs the real verification (compile, test).

**Never use Daybreak on the frontend.** Its aesthetic sense is catastrophic to a degree that produces output no human can use, and that prohibition has no exceptions.

**ASTRA draws instead, and Claude stops drawing by hand (2026-09-05).** ASTRA is good enough at screens that Claude hand-writing a non-trivial one is waste. So:

- **Claude settles the design direction**: what the screen is for, the layout intent, the states, the tokens (colour, spacing, radius, type scale, motion), the interface ids and the naming. That is a decision, not a drawing, and it is never delegated.
- **ASTRA draws it**: components, layouts, styles, mockups, gallery pages, and i18n catalogue labour (adding and syncing keys, keeping placeholder sets identical, running the catalogue gates).
- **Claude reviews the diff and runs the gates**, exactly as with backend work. ASTRA's self-report is not the gate.
- **Trivial edits stay with Claude**: a label, a colour swap, a few lines inside one component. Starting a worker for those costs more than doing them.

## Default delegation (2026-09-04)

Backend work goes to Daybreak **without being asked**. The user does not want to spell out "use the GPT worker" every time, so when a task is backend implementation (service, native code, scripts, test scaffolding, anything with no user-facing screen), Claude delegates it as a matter of course and says so in one line.

- **Default form:** the direct worker (`gpt-agent.ps1`) in an ordinary session, `gpt-worker` in a proxy session.
- **Non-trivial drawing goes the same way, to ASTRA (2026-09-05):** `gpt-agent.ps1 -Model astra` in an ordinary session, the `astra-worker` subagent in a proxy session. A new view, a component set, a layout or style system, a mockup, a gallery page or a batch of i18n keys is delegated as a matter of course, once the design direction is settled.
- **Claude keeps:** the design direction, the architecture (module boundaries, types and signatures, error policy), the task brief, the diff review, the format/lint/test gates, commits and PRs. CI/CD design is never delegated.
- **Claude does directly:** short edits inside one file, changes where settling the design is the implementation, and the polish after a worker's run; that is when starting a worker costs more than the work.
- **The relay (`gpt` agent) has two uses only:** audit of finished code or a diff (review, cross-check, second opinion), and work where GPT must not hold write access (a sensitive tree, a change that is hard to undo). Implementation is not taken through the relay and retyped by Claude.

### The whole-backend delegation pattern

This is the operating mode with the largest savings.

1. Claude settles architecture and interfaces, then delegates the entire backend (or a module at a time) to Daybreak.
2. Daybreak implements the backend and returns, alongside the code, a **"list of things to wire into the frontend"** (endpoints, function signatures, events, config keys). Ask for this list explicitly in the delegation prompt.
3. Claude takes that list, owns the design direction and the wiring, hands the drawing itself to ASTRA when it is more than a trivial edit, and passes judgement by running the integration build and tests.

## Delegation prompts

- **Write them self-contained.** In relay form Daybreak has no tools and cannot see the repository, so paste the existing code, spec and logs it needs into the prompt body. Ask about a repository fact you did not paste and it may invent one, so hand it an escape route: "if you cannot verify it, say that you cannot verify it."
- **Nail down what counts as finished.** For example: "this must compile as a single file", "put the wiring list in its own section".
- **Claude applies and verifies.** Daybreak's self-report (compiled fine, tests pass) is never the gate; Claude runs the build and tests itself.

## The four forms of the GPT labourer

Which form applies is decided by two things: **does GPT need to hold tools directly**, and **is this session pointed at the proxy base_url**. The decision table is in `references/three-forms.md`.

1. **Oracle relay (the `gpt` agent)**: Daybreak reasons without tools. For opinions and cross-checks on code and logs you paste in. It works **instantly in any session** and structurally forces the Claude gate, but pasting the entire context is cramped work. If tools are needed, go to form 2.
2. **Direct worker (`tools/gpt-agent.ps1`)**: no haiku wrapper. **In any session (bridge sessions included)** it attaches a child `claude -p` to the proxy so Daybreak holds the tools itself (Read/Edit/Write/Grep/Glob plus WebSearch and WebFetch, with `-AllowBash` as an opt-in; a search MCP tool name goes in through `-Tools` or `GPT_AGENT_EXTRA_TOOLS`). This is the **default choice** when an ordinary session needs a tool-holding GPT (verified in practice on 2026-08-20).
3. **Worker subagent (`gpt-worker` for Daybreak, `astra-worker` for ASTRA)**: GPT is the subagent's own LLM, so it reads files, edits them and runs commands directly. Only in sessions where `ANTHROPIC_BASE_URL` points at the proxy. In a **mixed session** (`gpt-cc.ps1 -Main claude`) the main loop stays Claude on its subscription OAuth (pass-through confirmed in practice, no API key needed) while `Agent(gpt-worker)` gives native in-conversation collaboration.
4. **Main loop model (the `gpt-cc.ps1` launcher)**: run all of Claude Code on Daybreak. The launcher sets `CLAUDE_CODE_AUTO_COMPACT_WINDOW=500000` so the session **auto-compacts at 500k tokens** (the same knob as the `autoCompactWindow` setting; it overrides the fallback window used for unrecognised models).

**The syntax for naming the model differs by form.** The relay takes directive lines on the first lines of the prompt (`GPT-MODEL: gpt-daybreak-blue` or `gpt-6-astra`, plus `GPT-EFFORT: high|max`); the direct worker takes `-Model daybreak|astra` and `-Effort high|max`; worker and main take a model id with the effort as a suffix (`gpt-daybreak-blue-high`, `gpt-6-astra-high`, or the `-max` forms for hopeless problems). The main model cannot be switched with `/model`: that swaps the endpoint, so it needs a new session from the launcher.

**GPT can search the code and the web now, too.** The relay has no tools and cannot search, but the direct worker (form 2) digs through the codebase itself with Grep/Glob/Read in any session, and since v0.4.0 its WebSearch runs as the codex web search through the proxy, so it checks documentation instead of writing from memory. Split the work with Claude (Explore) as you like.

## Proven pitfalls

Collected in `references/pitfalls.md`. The ones stepped on most often:

- Run the relay under pwsh 7 only (Windows PowerShell 5.1 is blocked at the network layer).
- **PowerShell `>` redirection does not capture the relay's output** (`[Console]::Out.Write` writes straight to the console handle).
- **HTML entities in agent and Workflow results are a display-layer artefact.** Do not restore them by hand; pull the original text from `journal.jsonl`. Claude agents' results are escaped exactly the same way.
- The proxy must not send `max_output_tokens` to codex responses (400).
- Worker and main forms only work in a proxy session. Calling `gpt-daybreak-blue-*` from an ordinary session gives a 404, so ordinary sessions use the direct worker (`gpt-agent.ps1`).
- `--allowedTools` in `claude -p` takes a variable number of arguments and swallows the positional prompt that follows. Pipe the task in over stdin, and put every other `claude` argument before it (`gpt-agent.ps1` does both).
- **ASTRA is gated on the `version` header** the proxy sends: an old value gets HTTP 400 telling you to upgrade Codex. Keep the codex CLI and the Store app updated, and `GPT_CODEX_VERSION` current.
- Function tools reach codex with `strict: false`. Under strict function calling GPT fills every optional property with invented values (dates, filters) that the tool then rejects; the proxy turns strict off (v0.4.0).
- **The main model cannot be launched through the remote control bridge.** `claude remote-control` inspects `ANTHROPIC_BASE_URL` and refuses anything that is not api.anthropic.com. Driving from a phone means the ordinary bridge plus the relay.
