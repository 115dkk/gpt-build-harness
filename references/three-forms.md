# The four forms of the GPT labourer

Two questions decide the form: **does the job need GPT to hold tools itself**, and **is this session pointed at the proxy base_url**. Whichever form you pick, the model is one of two: Daybreak Blue (`gpt-daybreak-blue`) for backend labour, ASTRA (`gpt-6-astra`) for drawing, i18n catalogues and the problems Daybreak stalls on.

| Form | Tools | Where it works | Whose hands | When |
|---|---|---|---|---|
| Oracle relay | none (reasoning only) | any session | Claude's | pure reasoning over pasted context: review notes, cross-checks, second opinions |
| Direct worker (`gpt-agent.ps1`) | Read/Edit/Write/Grep/Glob/WebSearch/WebFetch (+Bash and MCP opt-in) | **any session**, bridge included | GPT's own | the **default choice** when an ordinary session needs a tool-holding labourer; `-Model astra` for drawing and i18n |
| Worker subagent (`gpt-worker`, `astra-worker`) | Read/Write/Edit/Bash/… | proxy sessions (gpt-cc, including `-Main claude` mixed) | GPT's own | parallel and background collaboration through the native Agent() UX; `astra-worker` is the drawing one |
| Main loop model | all of Claude Code's tools | proxy sessions (gpt-cc) | GPT's own | the experiment of running a whole session on GPT |

## 1. Oracle relay (the `gpt` agent / `tools/gpt-relay.ps1`)

GPT reasons without tools. Claude hands it context as a self-contained prompt; GPT returns code and opinions as text; Claude applies, builds and judges. It is called straight through pwsh, so it works instantly in any session and structurally forces the Claude gate. The cramped part is that GPT cannot see the repository at all, so the whole context has to be pasted in. **If the job needs tools, go to the direct worker below.**

For precise measurement, call **the relay script directly** rather than going through the `gpt` subagent. Going through a subagent puts the result through the display layer, which mixes in HTML entities and blurs the token and time figures.

## 2. Direct worker (`tools/gpt-agent.ps1`), the default labourer in ordinary sessions

This runs a tool-holding Daybreak **in any session**, with no haiku wrapper (verified 2026-08-20: Read and Write file work performed correctly from an ordinary session). It starts a child `claude -p` with the proxy env so that GPT reads and edits files directly from its own main loop. There is no LLM relaying layer: the script starts the proxy, sets and restores the env, and returns GPT's final answer on stdout.

```powershell
& "$env:USERPROFILE\.claude\tools\gpt-agent.ps1" -Task "<self-contained task, absolute paths>"
& ... -Model astra        # ASTRA (gpt-6-astra): drawing, i18n, hardest backend
& ... -Effort xhigh        # ASTRA's unmeasured middle rung
& ... -Effort max          # only for hopelessly hard problems
& ... -AllowBash           # allow the Bash tool (an unsupervised shell, opt in deliberately)
& ... -TaskFile big.txt    # long tasks go in a file
& ... -Tools 'Read,Grep,mcp__<server>__<tool>'   # replace the tool list outright
```

- The task is passed over stdin, which avoids the trap where `--allowedTools` takes a variable number of arguments and swallows the positional prompt.
- The default tool set is Read/Edit/Write/Grep/Glob/WebSearch/WebFetch. Everything else is auto-denied in -p mode, so GPT cannot widen it on its own; `-Tools` replaces the list and the `GPT_AGENT_EXTRA_TOOLS` environment variable (comma-separated) appends to it, which is where a search MCP tool name goes.
- WebSearch works through the proxy: it maps Claude Code's server-side web search onto the codex web search and rebuilds the result blocks from the answer's citations (verified 2026-09-04). WebFetch fetches locally and summarises through the pass-through model, so it needs no mapping.
- MCP tools pass through the proxy as ordinary functions, but a claude.ai connector's tools only appear once the connector has connected, which can be a few turns into the run; a task that needs them on its first turn will not see them.
- Extra `claude` arguments (`--output-format stream-json --verbose` and the like) are passed through after the script's own parameters; the script places them before `--allowedTools`, which would otherwise swallow them.
- Use **absolute paths** in the task body; the child claude sometimes resets cwd.
- The "unrecognized model" warning the child prints is harmless (the window is pinned through the env).
- The window follows `-Model`: Daybreak gets `CLAUDE_CODE_AUTO_COMPACT_WINDOW=500000`, ASTRA gets `CLAUDE_CODE_MAX_CONTEXT_TOKENS=1000000` with compaction at 860000. The script sets them for the model chosen rather than inheriting a stale value from the shell, and restores the caller's values when the child exits.

## 3. Worker subagent (`gpt-worker` for Daybreak, `astra-worker` for ASTRA)

GPT is the subagent's own LLM, so it reads files, edits them and runs commands directly. It only works in sessions where `ANTHROPIC_BASE_URL` points at `gpt-proxy.mjs`. Call it from an ordinary session and `gpt-daybreak-blue-*` or `gpt-6-astra-*` goes to the real Anthropic and dies at once (measured: "model may not exist" API error). Use form 2 in that case.

The two subagents are the same shape with different models and different boundaries: `gpt-worker` is the backend labourer, `astra-worker` is the one sent at screens and i18n catalogues.

There are two kinds of proxy session (both verified 2026-08-20).

- **GPT main session** (`gpt-cc.ps1`): main loop and subagents are all GPT.
- **Mixed session** (`gpt-cc.ps1 -Main claude`): the main loop stays Claude on its subscription OAuth (the proxy passes non-GPT requests through to api.anthropic.com unchanged; OAuth was confirmed to survive a custom base URL, and no API key is needed), while only `Agent(gpt-worker)` goes to codex. **This is collaboration with a GPT subagent inside the ordinary conversation UX.** Note that setting `ANTHROPIC_AUTH_TOKEN` overrides the OAuth and makes the pass-through return 401, so mixed mode leaves it alone.

The proxy's tool-call translation has been verified in practice: in a mixed session gpt-worker performed file work correctly. (In that same run the subagent's *report sentence* contained a typo while the file output was correct, which is the sample behind the rule about never gating on a self-report.)

There is no gate here, so `gpt-worker` is used only as a backend logic labourer and never on frontend work; drawing goes to `astra-worker` instead (see the role boundary in SKILL.md).

## 4. Main loop model (`tools/gpt-cc.ps1`)

All of Claude Code runs on GPT. The proxy translates the Anthropic Messages API into codex responses in real time. There is no gate, so the user supervises directly.

**The window follows `-Base`.** A Daybreak Blue session compacts at 500k (`CLAUDE_CODE_AUTO_COMPACT_WINDOW=500000`, the same knob as the `autoCompactWindow` setting); an ASTRA session carries 1M and compacts at 860k (`CLAUDE_CODE_MAX_CONTEXT_TOKENS=1000000` plus `CLAUDE_CODE_AUTO_COMPACT_WINDOW=860000`). Neither slug is one Claude Code recognises, so without these the session falls back to the default window for unrecognised models. The launcher writes the values for the base it is starting, so a leftover from an earlier launch in the same shell cannot mis-size the session.

On the Codex side (the CLI and the desktop app, not the harness) the same numbers live in a profile file layered with `codex -p <name>`: `model`, `model_context_window`, `model_auto_compact_token_limit` and `model_auto_compact_token_limit_scope = "total"`. A model that the account's catalogue does not list can still be added through `model_catalog_json`, where its `context_window` is what the picker and the compaction maths use.

**It is incompatible with the remote control bridge (measured 2026-07-31).** `claude remote-control` inspects `ANTHROPIC_BASE_URL` at startup and refuses with exit 1 if it is not api.anthropic.com.

```
Error: Remote Control is only available when using Claude via api.anthropic.com.
ANTHROPIC_BASE_URL is set and does not point at api.anthropic.com ...
```

This applies to mixed sessions (`-Main claude`) as well; a bridge session cannot be attached to the proxy. **When a bridge session needs a tool-holding GPT, form 2 (`gpt-agent.ps1`) is the only way** (the child claude is not a bridge, so it has no such restriction).

## The model names and their two syntaxes

There are two models, Daybreak Blue (`gpt-daybreak-blue`) and ASTRA (`gpt-6-astra`), and three rungs of effort: `high` (default and the sweet spot), `xhigh` and `max`. On Daybreak `max` is for hopelessly hard problems only; on ASTRA the two rungs above high are open but unmeasured. **The syntax for naming them differs by form**, and mixing them up either falls back to a default silently or returns a 404.

**The relay** takes directive lines at the top of the prompt. The effort is not attached to the model name.

```
GPT-MODEL: gpt-daybreak-blue
GPT-EFFORT: high
```

Omit them and the relay's own defaults are daybreak-blue/high, which matches policy anyway. Pass `GPT-MODEL: gpt-6-astra` when the opinion wanted is about a screen, a design or an i18n catalogue.

**The direct worker, the worker subagents and the main model** take one model name with the effort as a suffix.

```
gpt-daybreak-blue-<effort>      e.g. gpt-daybreak-blue-high, gpt-daybreak-blue-max
gpt-6-astra-<effort>            e.g. gpt-6-astra-high, gpt-6-astra-max
```

This is the form used by the `gpt-worker` and `astra-worker` frontmatter `model:` and by the `ANTHROPIC_MODEL` that the launcher and `gpt-agent.ps1` set (the direct worker takes `-Model daybreak|astra` and `-Effort high|xhigh|max` and builds the slug itself). Drop the suffix and the proxy falls back to the `GPT_EFFORT` environment variable (default high). The endpoint refuses `ultra` for both models with HTTP 400 (it is a Codex client mode, not an effort value), and ASTRA refuses to answer at all when the proxy claims an old codex version, so keep `GPT_CODEX_VERSION` current.

**The main model cannot be changed with `/model`.** It is not a matter of choosing a model but of swapping the endpoint. The launcher points `ANTHROPIC_BASE_URL` at the proxy and then starts `claude`, and that value is fixed when the process starts. Typing `/model gpt-daybreak-blue-high` in an already-running ordinary session sends the request to the real Anthropic and returns 404. To run GPT as the main model, start a **new session** from the launcher.

## Picking a form by role

**Backend implementation goes to forms 2 and 3 by default, without the user asking.** The relay GPT has no tools and cannot search the codebase at all, nor the web; forms 2 and 3 have WebSearch and WebFetch. In an ordinary session that work goes to `gpt-agent.ps1`; in a proxy session, to `gpt-worker`. Splitting it with Claude (Explore) is fine too.

**Non-trivial drawing goes to ASTRA by default, without the user asking (2026-09-05), as long as the frontend already stands.** A new view, a component set, a layout or style system, a mockup, a gallery page or a batch of i18n keys goes to `gpt-agent.ps1 -Model astra` in an ordinary session and to `astra-worker` in a proxy session, once Claude has settled the design direction. **A frontend being built from nothing is the exception**: Claude raises the skeleton (structure, component idiom, tokens, the first screens), and ASTRA takes over only once there is something to work inside. Claude reviews the diff and runs the gates, and keeps trivial edits (a label, a colour, a few lines in one component) for itself.

**The relay is for audit, or for work where GPT must not write.** Review, cross-check and second opinions on pasted code or diffs, and tasks in which GPT may not hold write access: for those there is no reason to start a child claude. Implementation is not taken through the relay.

**In a Workflow, use `agentType: 'gpt'`.** It works, and it comes back with the StructuredOutput schema filled in. Take the return value from `journal.jsonl` rather than from the notification text. (In a proxy session `agentType: 'gpt-worker'` works as well.)

## Choosing, in short

- GPT has to dig through and edit files in an ordinary session (bridge included) → **the direct worker (`gpt-agent.ps1`)**.
- Only an opinion or a cross-check on pasted code is needed → **the relay**.
- You can start a new local session and want parallel collaboration with GPT through Agent() inside the conversation → **a mixed session (`gpt-cc.ps1 -Main claude`) plus the worker**.
- It is drawing or i18n labour beyond a trivial edit, on a frontend that already stands → **ASTRA** (`gpt-agent.ps1 -Model astra`, or `astra-worker` in a proxy session), with Claude settling the design direction first and reviewing the diff.
- It is a frontend from nothing → **Claude**, until the skeleton and the first screens exist. Daybreak still never touches a screen at all.
- You want to try running a whole session on GPT → **the main model (`gpt-cc.ps1`)**.
