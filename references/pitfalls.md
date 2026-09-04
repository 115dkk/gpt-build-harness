# Pitfalls (the verified ones)

Only what was actually stepped on while running a GPT labourer, with the evidence. This is the source that the SKILL.md summary condenses.

## The relay form

**Run the relay from the PowerShell tool (pwsh 7) only.**
The `powershell.exe` that the Bash tool invokes is Windows PowerShell 5.1, and on this machine its network stack is blocked from chatgpt.com and hangs forever. `gpt-relay.ps1` also uses `-SkipHttpErrorCheck`, which is pwsh 7 only. That is why the `gpt` agent definition forces the PowerShell tool.

**PowerShell `>` redirection does not capture the relay's output.**
The relay writes its answer straight to the console handle with `[Console]::Out.Write`, so it never passes through the PowerShell success stream. Add `... > out.txt` and you are left with an **empty file** and the answer is gone. The task output file of a background run does capture it properly, so read that instead. If you really need it in a file, start it as a child process (`pwsh -File ...`) and redirect at the process level.

**The relay is a tool-less oracle.**
GPT cannot read a file, cannot write one, cannot run anything. The context (existing code, the spec, logs) has to be pasted into the prompt body, self-contained. Ask it about a repository fact you did not paste and it may invent one, so give it the escape route "if you cannot verify it, say that you cannot verify it". Applying, building and judging the returned work is Claude's job.

**The model slug is `gpt-daybreak-blue` (measured 2026-08-19).**
Variants with a version prefix (`gpt-5.6-daybreak-blue`, `gpt-5.6-daybreak`, `gpt-5.6-sol-daybreak-blue` and so on) are all rejected by the codex responses backend with HTTP 400. The relay, the proxy and the launcher already default to this slug, so omitting it is safe.

## Getting results back from agents and Workflows

**HTML entity escaping is a display-layer artefact. Do not restore it by hand.**
When a subagent's or Workflow's result arrives as notification or result text, `<` `>` `&` in code turn into `&lt;` `&gt;` `&amp;`. Two things were corrected by measurement.

- **It is not specific to the GPT relay.** In the same Workflow, **a Claude agent's return value** came back broken as `&lt;=` too. The cause is the delivery layer, not the model.
- **`journal.jsonl` holds the original text.** Code pulled from the journal had zero entities and compiled and passed tests as it was.

So do not build a restoration procedure; **read from the journal**. It is at `<transcriptDir>/journal.jsonl`, and the `result` field of the line where `type == "result"` is the agent's actual return value. Restoring a large body of code by eye is risky, and it is not necessary in the first place.

## The proxy, worker and main forms

**The worker and main forms are for proxy sessions only.**
The `gpt-worker` subagent and a GPT main model both need `ANTHROPIC_BASE_URL` pointing at `gpt-proxy.mjs`. Call a `gpt-daybreak-blue-*` model from an ordinary Claude session and it goes to the real Anthropic and dies at once (measured 2026-08-20: the agent terminated with a "model may not exist" API error). The session that drives the harness and the session that GPT runs in are two different things. When an ordinary session needs a tool-holding GPT, go around it with `gpt-agent.ps1` (the direct worker built on a child claude).

**Subscription OAuth survives a custom base URL (measured 2026-08-20).**
Claude Code sends its subscription OAuth bearer even when `ANTHROPIC_BASE_URL` is the proxy, and the proxy hands it to api.anthropic.com unchanged and gets a 200 back. That is why a mixed session (`gpt-cc.ps1 -Main claude`) needs no API key. Setting `ANTHROPIC_AUTH_TOKEN`, however, **overrides** the OAuth and makes the pass-through return 401. Never set it in mixed mode (leave the dummy token of GPT main mode alone).

**`--allowedTools` in `claude -p` takes a variable number of arguments and swallows the prompt.**
`claude -p --allowedTools "Read Write" "task..."` eats the task as part of the tool list and dies with "Input must be provided either through stdin or as a prompt argument" (measured). Pipe the task in over stdin (`"task" | claude -p --allowedTools "Read,Write"`). Every other `claude` argument has to come before `--allowedTools` for the same reason; `gpt-agent.ps1` does both (its pass-through arguments used to be swallowed silently until 2026-09-04).

**The unrecognised-model warning is harmless.**
Starting a child claude on `gpt-daybreak-blue-*` prints a "not a model this version recognizes" warning. Pin the window with `CLAUDE_CODE_AUTO_COMPACT_WINDOW`/`CLAUDE_CODE_MAX_CONTEXT_TOKENS`; the `modelOverrides` setting the warning suggests is a mapping from a known Anthropic ID to a provider ID (for managed settings) and does not fit this use.

**A worker's self-report and its output are two different things (measured sample).**
While verifying a mixed session, gpt-worker wrote the correct result into the file ("ykseulb") and put a typo in its report sentence ("ykseulba"). Always judge by opening the output yourself. A chat report is never the gate.

**The proxy's tool-call translation works (confirmed).**
Driving the proxy with direct requests in Anthropic Messages API format, a plain request answered 200 and a request carrying tool definitions returned a tool call with the right arguments and `stop_reason: "tool_use"`. That means GPT can genuinely dig through code and edit it in a proxy session.

**codex responses rejects `max_output_tokens`.**
Passing the Anthropic `max_tokens` straight through gets HTTP 400 `Unsupported parameter`. Do not forward it (codex manages it itself).

**Automatic caching is tied to the `session_id` header.**
Even with the same large prefix, a session_id randomised per request means zero cache hits and a full charge for the system prompt every turn. The proxy has to use a stable per-conversation session_id for hits to land.

**The 500k auto-compact of a main session is set by the launcher.**
`gpt-daybreak-blue-*` is a slug Claude Code does not recognise, so without an explicit `CLAUDE_CODE_AUTO_COMPACT_WINDOW` (or the `autoCompactWindow` setting) the session falls back to the default window for unrecognised models. `gpt-cc.ps1` sets 500000 when it is unset.

## The execution environment

**`--dangerously-skip-permissions` is blocked by the auto mode classifier.**
It refuses the attempt to start a child `claude` in dangerous mode from inside a parent Claude session.

**A child `claude` resets cwd to the project root.**
Even after `Set-Location`, the child resets cwd to the parent worktree root. Address files by absolute path.

**`claude -p` waits three seconds on stdin.**
Pipe an empty stdin with `$null | & claude -p ...` and it does not wait.

**In cmd, a backslash at the end of a quoted path eats the quote.**
A quoted path ending in a backslash, like `/Fo:"...\obj\"`, escapes the closing quote and breaks the whole command line (cl dies with `D8003 missing source filename`). Move into the directory and use a relative path, or drop the trailing backslash.

**The Bash tool's heredoc breaks on code containing single quotes.**
Writing a heredoc that contains a fragment such as `&'static` through the Bash tool throws the shell's quote parsing off and dies with `unexpected EOF while looking for matching`. Write those files with the Write tool (Rust lifetime notation and PowerShell literal strings hit this often).

**Do not trust the Bash tool's cwd.**
A `cd` from an earlier call sometimes survives, and sometimes the tool puts you back at the project root. Either way, always write paths as absolute.

## Distribution (learned from the toy)

**Do not commit the toy (public) and the skill (internal infrastructure) on the same branch.**
Internal GPT tooling mixed into a public repo makes the auto-mode classifier block the push.

**create-tauri-app bakes the Windows username into the identifier.**
It becomes `com.<Korean username>.…`, and `generate_context!` sometimes rejects a non-ASCII identifier. Fix it to an ASCII reverse-DNS name.

## In practice: delegating the whole backend (2026-08-30, Tauri 2 + Rust)

What came out of the first real run where the core of an Android app (domain, slot computation, storage, PNG rendering, export) went to the `gpt-agent.ps1` direct worker in one piece while Claude owned the screens (Svelte). The result shipped as a release with 56 core tests attached.

**Give it search permission too (the default since v0.4.0).**
Putting WebSearch, WebFetch and a search MCP in the worker's allowed tools cuts down hallucinated guesses at crate APIs it does not know. Letting the worker check the documentation itself is cheaper than letting it invent what it could not verify. WebSearch and WebFetch are in `gpt-agent.ps1`'s default list now; a search MCP tool goes in through `-Tools` or `GPT_AGENT_EXTRA_TOOLS`. Whether to open up Bash is a separate decision to make deliberately (it is an unsupervised shell).

**The worker starts subagents and worktrees on its own.**
The direct worker is a child `claude` session, so on its own judgement it spawns subagents, produces output in a separate worktree, and even sends messages to other sessions (measured). **Check the work tree yourself rather than the completion report**, and copy back anything produced outside the main tree. Nailing the absolute output paths into the delegated task reduces the scatter.

**Claude always re-runs the gates.**
Even when the worker reports a pass, Claude runs format, lint and tests itself. In practice `cargo fmt --check` was broken in the worker's output (fixed with `cargo fmt --all` before the commit). Compiling and testing successfully and reporting honestly are two different things.

**Implement and audit in two different forms.**
Handing the finished core to the relay (the tool-less oracle) for an audit turned up a real defect: where a new file is created, the id-collision check and the save were not inside the same lock, so concurrent creation could race. The same model in a different form gives a different field of view. Implementation by the worker, audit by the relay, is the cheap split.

## Web search, MCP and function calling through the proxy (2026-09-04)

**Claude Code's WebSearch is a server-side tool, and codex cannot run Anthropic's.**
The proxy used to drop it, so a worker's WebSearch silently returned nothing. Since v0.4.0 the proxy maps the `web_search` server tool onto the codex web search (domain filters and a forced tool choice included) and rebuilds the `server_tool_use` and `web_search_tool_result` blocks Claude Code parses from the answer's URL citations. Measured end to end: a worker asked to search got four links back. WebFetch never needed this; it fetches locally and summarises through the pass-through model.

**Send function tools with `strict: false`.**
Under the codex default the model treated every schema property as required and invented values for the optional ones: a search tool received both a recency filter and explicit date filters and rejected the call seven times in a row, and Read got `pages: ""`. With strict off the same model sends only the arguments it means. The proxy sets it on every function tool.

**Function names over 64 characters are rejected by codex.**
MCP tool names (`mcp__<server>__<tool>`) can exceed that. The proxy shortens them with a hash suffix on the way in and restores the original on the way out, so long MCP names work unchanged.

**A claude.ai connector's tools arrive late.**
In a headless `claude -p` the connectors do load, but their tools appear in the tool list only after the connector has connected, which can be a few turns into the run. A one-turn probe reported the tool as missing while a four-turn run used it (three results). Give the worker something to do first, or name the tool in the task and let it retry.
