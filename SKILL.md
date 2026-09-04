---
name: gpt-build-harness
description: >-
  A harness that puts Daybreak Blue (ChatGPT subscription quota, no API
  billing) to work as a backend labourer and auditor, so that implementation
  and verification cost almost no Claude tokens. Daybreak Blue
  (gpt-daybreak-blue, the new tuning of GPT-5.6 Sol) is the only model ever
  called; effort is high by default, and max is reserved for hopelessly hard
  problems. Claude keeps architecture, planning and the verdict; Daybreak
  produces backend code and opinions. Frontend work, both planning and
  implementation, belongs to Claude alone and is never handed to Daybreak.
  GPT runs in four forms: (1) a tool-less oracle relay for opinions only,
  (2) the direct worker (gpt-agent.ps1: a tool-holding GPT in any session
  with no haiku wrapper, the default labourer in ordinary sessions), (3) the
  worker subagent (proxy sessions only; with gpt-cc -Main claude the main
  loop stays Claude and Agent() collaboration is native), (4) Claude Code's
  main loop model (auto-compact at 500k). Use it when a large backend build
  would burn too many Claude tokens, when cross-checking or a second opinion
  is needed, or to split audit and review work. The executable tools ship as
  a release asset.
---

# GPT Build Harness (Daybreak Blue)

Instead of burning Claude on the whole build, attach Daybreak Blue as a backend labourer: delegate implementation and verification, and keep architecture, planning, integration and the verdict with Claude. Calls run on the ChatGPT **subscription quota**, so Claude tokens are saved.

This document is the overview; per-form detail lives in `references/`. **The executable scripts (relay, proxy, launcher, agent) are not in this repository's source. They ship as the release asset `gpt-build-harness-tools.zip`.**

> The Korean edition of this document is kept in the repository as `SKILL_ko.md`. English is the canonical text: it is what gets installed, and it costs far fewer tokens to load.

> Everything in the old docs that read as "how to use GPT" (the luna/sol/terra tier table, the effort measurement table, the prompt A/B battery) was **discarded outright** on 2026-08-19 for being riddled with hallucination. The policy below replaces it.

## Model policy — Daybreak Blue only

**Call Daybreak Blue and nothing else.** It is the top-performing model and its quota economics are overwhelming, so there is no reason to call luna/sol/terra or anything else. It is the new tuning of GPT-5.6 Sol.

- **Slug: `gpt-daybreak-blue`**, with no version prefix. Confirmed against the codex responses backend on 2026-08-19: variants such as `gpt-5.6-daybreak-blue` and `gpt-5.6-daybreak` all return HTTP 400, and only `gpt-daybreak-blue` returns 200.
- **Effort: `high` by default.** Use `max` only when the problem is hopelessly hard. **The remaining efforts (low/medium/xhigh) are never used.** The relay script, the proxy and the launcher all default to daybreak-blue/high, so omitting the instruction still follows policy.
- The per-form syntax (the relay's `GPT-MODEL:`/`GPT-EFFORT:` directive lines, the `gpt-daybreak-blue-high` suffix form for worker and main) is in `references/three-forms.md`.

## Role boundary — what to delegate, what to keep

**Daybreak is an excellent backend practitioner and auditor.** Spend it freely on backend implementation, code review, verification, cross-checking, second opinions and knowledge lookup.

**It does, however, struggle to hold the whole context.** Therefore:

- **Claude nails down architecture and planning.** Module boundaries, interfaces (types, signatures, returns), data flow and error policy are settled by Claude first and handed over as a self-contained specification. Give Daybreak the structural design and you get something locally plausible that contradicts the whole.
- **CI/CD pipeline design is Claude's too.** It is whole-context work by nature, so it is not delegated for the same reason (implementing or reviewing an individual script can be).
- **Use it aggressively for audit.** Attaching finished backend code or a diff and asking for defects, boundary conditions and a second opinion is what Daybreak is good at. Its opinion is input, not a conclusion: Claude decides what to adopt and runs the real verification (compile, test).

**Never use it on the frontend.** Its aesthetic sense is catastrophic to a degree that produces output no human can use. This prohibition has no exceptions: the old docs' loophole of "translating a settled design into render code" is discarded as well. **Claude owns the frontend end to end, planning and implementation alike.**

### The whole-backend delegation pattern

This is the operating mode with the largest savings.

1. Claude settles architecture and interfaces, then delegates the entire backend (or a module at a time) to Daybreak.
2. Daybreak implements the backend and returns, alongside the code, a **"list of things to wire into the frontend"** (endpoints, function signatures, events, config keys). Ask for this list explicitly in the delegation prompt.
3. Claude takes that list, owns frontend planning, implementation and wiring, and passes judgement by running the integration build and tests.

## Delegation prompts

- **Write them self-contained.** In relay form Daybreak has no tools and cannot see the repository, so paste the existing code, spec and logs it needs into the prompt body. Ask about a repository fact you did not paste and it may invent one, so hand it an escape route: "if you cannot verify it, say that you cannot verify it."
- **Nail down what counts as finished.** For example: "this must compile as a single file", "put the wiring list in its own section".
- **Claude applies and verifies.** Daybreak's self-report (compiled fine, tests pass) is never the gate; Claude runs the build and tests itself.

## The four forms of the GPT labourer

Which form applies is decided by two things: **does GPT need to hold tools directly**, and **is this session pointed at the proxy base_url**. The decision table is in `references/three-forms.md`.

1. **Oracle relay (the `gpt` agent)**: Daybreak reasons without tools. For opinions and cross-checks on code and logs you paste in. It works **instantly in any session** and structurally forces the Claude gate, but pasting the entire context is cramped work. If tools are needed, go to form 2.
2. **Direct worker (`tools/gpt-agent.ps1`)**: no haiku wrapper. **In any session (bridge sessions included)** it attaches a child `claude -p` to the proxy so Daybreak holds the tools itself (Read/Edit/Write/Grep/Glob plus WebSearch and WebFetch, with `-AllowBash` as an opt-in; a search MCP tool name goes in through `-Tools` or `GPT_AGENT_EXTRA_TOOLS`). This is the **default choice** when an ordinary session needs a tool-holding GPT (verified in practice on 2026-08-20).
3. **Worker subagent (the `gpt-worker` agent)**: Daybreak is the subagent's own LLM, so it reads files, edits them and runs commands directly. Only in sessions where `ANTHROPIC_BASE_URL` points at the proxy. In a **mixed session** (`gpt-cc.ps1 -Main claude`) the main loop stays Claude on its subscription OAuth (pass-through confirmed in practice, no API key needed) while `Agent(gpt-worker)` gives native in-conversation collaboration.
4. **Main loop model (the `gpt-cc.ps1` launcher)**: run all of Claude Code on Daybreak. The launcher sets `CLAUDE_CODE_AUTO_COMPACT_WINDOW=500000` so the session **auto-compacts at 500k tokens** (the same knob as the `autoCompactWindow` setting; it overrides the fallback window used for unrecognised models).

**The syntax for naming the model differs by form.** The relay takes directive lines on the first lines of the prompt (`GPT-MODEL: gpt-daybreak-blue` plus `GPT-EFFORT: high|max`); the direct worker takes an `-Effort high|max` parameter; worker and main take a model id with the effort as a suffix (`gpt-daybreak-blue-high`, or `gpt-daybreak-blue-max` for hopeless problems). The main model cannot be switched with `/model`: that swaps the endpoint, so it needs a new session from the launcher.

**GPT can search the code and the web now, too.** The relay has no tools and cannot search, but the direct worker (form 2) digs through the codebase itself with Grep/Glob/Read in any session, and since v0.4.0 its WebSearch runs as the codex web search through the proxy, so it checks documentation instead of writing from memory. Split the work with Claude (Explore) as you like.

## Proven pitfalls

Collected in `references/pitfalls.md`. The ones stepped on most often:

- Run the relay under pwsh 7 only (Windows PowerShell 5.1 is blocked at the network layer).
- **PowerShell `>` redirection does not capture the relay's output** (`[Console]::Out.Write` writes straight to the console handle).
- **HTML entities in agent and Workflow results are a display-layer artefact.** Do not restore them by hand; pull the original text from `journal.jsonl`. Claude agents' results are escaped exactly the same way.
- The proxy must not send `max_output_tokens` to codex responses (400).
- Worker and main forms only work in a proxy session. Calling `gpt-daybreak-blue-*` from an ordinary session gives a 404, so ordinary sessions use the direct worker (`gpt-agent.ps1`).
- `--allowedTools` in `claude -p` takes a variable number of arguments and swallows the positional prompt that follows. Pipe the task in over stdin, and put every other `claude` argument before it (`gpt-agent.ps1` does both).
- Function tools reach codex with `strict: false`. Under strict function calling GPT fills every optional property with invented values (dates, filters) that the tool then rejects; the proxy turns strict off (v0.4.0).
- **The main model cannot be launched through the remote control bridge.** `claude remote-control` inspects `ANTHROPIC_BASE_URL` and refuses anything that is not api.anthropic.com. Driving from a phone means the ordinary bridge plus the relay.
