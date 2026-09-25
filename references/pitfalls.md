# Pitfalls (the verified ones)

Everything here was stepped on. Items that only described the old relay, the old proxy or the child-`claude` worker were dropped when the router replaced them; what remains is either still live or was re-checked.

## Model slugs

**The model slug is `gpt-daybreak-blue` (measured 2026-08-19).**
Variants with a version prefix, `gpt-5.6-daybreak-blue` and `gpt-5.6-daybreak`, return HTTP 400. Only the bare slug returns 200.

**ASTRA's slug is `gpt-6-astra`, and its `version` gate fires on a stale claim, not on silence.**
`gpt-6`, `gpt-astra` and `gpt-6-astra-latest` all return 400 (measured 2026-09-05). Separately, the backend answers `The 'gpt-6-astra' model requires a newer version of Codex` when the caller claims an old CLI version: 0.144.1 was refused, 0.153.4 accepted, which is why the old proxy sent `version: 0.153.4`. The router sends no `version` header at all, and that passes: measured 2026-09-18, a request with the router's exact header set reached the quota check. Sending nothing beats sending something stale, so do not reintroduce the header without re-measuring.

**A 429 is how you validate a slug with no quota left.**
Model validation happens before the quota check. Measured 2026-09-18 on the same credentials within a minute of each other: `gpt-6-astra-latest` came back 400 `model is not supported`, while `gpt-6-astra` and `gpt-daybreak-blue` came back 429 `usage_limit_reached`. So a 429 means the slug was accepted, and a slug can be checked while the account is fully spent. The probe used here was a small script placed in the router checkout that imports the adapter's own `readBorrowed`, `toResponsesRequest` and `DEFAULT_BASE`, so it sends exactly what the adapter sends. It is not shipped; write your own the same way rather than hand-building a request.

## Router gaps

Three were reported on 2026-09-17 after reading the router's source, and all three were fixed within two days. A fourth, found by being bitten by it on 2026-09-19, was fixed the next day.

**Long tool names: fixed, but check which build you are on.**
A Responses function name must match `^[a-zA-Z0-9_-]{1,64}$`, and one bad name fails the whole request rather than that one tool. Claude Code names MCP tools `mcp__<server>__<tool>`, and a claude.ai connector's server name is a UUID, so the prefix alone eats 43 characters. The router now mangles every name it has to touch (first 55 of the sanitised name plus `_` and 8 hex of sha256 of the original, so `a.b` and `a-b` cannot collide) and restores it on the inbound `function_call`. Names already inside the constraint pass untouched, so a session with no MCP tools produces byte-identical output and the cache prefix does not move. Issue #1, closed. **Shipped in 0.3.0 (2026-09-23); 0.2.0 does not have it.**

**Per-model context windows: fixed.**
`CliModel.contextWindow` and `Route.contextWindow` now win over the global `cli.autoCompactWindow`, with a vendor-reported `context_length` in between. Issue #2, closed, shipped in 0.3.0.

**`contextWindow` is not the compaction point, and the gap is a fixed reserve.**
Read from the 2.1.258 binary: the threshold is `effectiveWindow - 13000`, where `effectiveWindow = contextWindow - min(maxOutputTokens, 20000)`. Not a fraction. With `behavesAs` inheriting an Opus-sized output cap the reserve is a flat 33,000, so to land compaction on a chosen number, write that number plus 33,000. That is where the config's 533000 (Daybreak, compacting at 500k) and 893000 (ASTRA, at 860k) come from. Two ways this drifts: drop `behavesAs` and an unknown model's smaller output default shrinks the reserve, raising the threshold; and if upstream changes the arithmetic the two numbers stop meaning what they say. Upstream's own note that a 200K window compacted at 151K does not fit this formula, which yields 167,000, so re-derive rather than trusting either number across versions.

**Server-side tools: fixed, and the interesting part is why it never bit.**
Anthropic's `web_search` and its kind are run by Anthropic, not by the model holding them, so declaring one to a translated provider offers a tool that cannot execute. Both translators now drop any tool whose `type` is set and is not `custom`, and clear a `tool_choice` naming a dropped one, reusing the `compat.ts` rule. Issue #4, closed, shipped in 0.3.0.

It was a guard, not a repair. **Claude Code does not put `web_search` in the main request at all.** WebSearch opens a separate side request, with its own system prompt and the server tool forced, and sends it to a fixed small model behind the `tengu_plum_vx3` flag rather than to the session model. Measured upstream 2026-09-17: an Opus session and a routed session produced byte-identical search requests, both on `claude-haiku-4-5` straight to Anthropic. Issue #4, closed.

**A marker written as an example is still a marker.**
The router matches the `[[gpt: ...]]` form anywhere in the first five user messages, and since its 2026-09-19 routing change it applies to every model, not only one a rule already routes. So prose that quotes the syntax becomes a directive. Measured here on 2026-09-19: the string sitting in this harness's own notes sent every `claude-sonnet-5` and `claude-haiku-4-5` call in the session to ASTRA at max effort for twenty minutes, at roughly 80k input tokens each. The visible symptom was the auto-mode classifier taking 17 to 120 seconds instead of one, timing out, and refusing every Bash call. Write the syntax with an angle-bracket placeholder, which the marker's character class cannot match. Reported as clauderipple#13; emptying the provider's `models` list stops it within one request, because the marker then resolves to a model no provider declares.

Fixed upstream on 2026-09-20 (`60028ba`), and the shape of the fix matters. A marker counts **only at the very top of a user message** now, where a task brief puts it and a compaction summary never does, so quoting the syntax mid-prose routes nothing. `[[ripple: …]]` is the router's own spelling; `[[gpt: …]]` still resolves. Under a prefix rule the marker's model is placed by its own rule or by its single declaring provider instead of inheriting the matched rule's provider, so a marker naming a model that provider does not serve is refused here with the reason rather than sent out to earn a vendor's 400. A route a marker chose is tagged `(marker)` in the log line (`bd39ac3`).

**Declaring a model in `providers.*.models` now also creates an agent file.**
Since `441cb3d`, `cli.agentFiles` (default true) has the router write `~/.claude/agents/<id>.md` for every id exactly one non-ingress provider declares, record what it wrote in `generated-agents.json`, and touch only those files. Hand-written agents win by name, so `gpt-worker.md` and `astra-worker.md` are never overwritten. But the reason to keep `providers.chatgpt.models` empty is now double: filling it would put one worker per junk model into the Agent list, which is the thing the picker allowlist exists to prevent. The marker alias table is the union of `aliases` and every agent file's name → model, so a worker that exists is an alias that resolves without declaring anything.

**A non-`claude-*` model the router cannot route is refused by name.**
Also `441cb3d`: an unroutable id used to be forwarded to Anthropic as an ordinary `PASS`, which answered `404 model: …` and read like the model had stopped working. It is now refused at the router with the reason (undeclared, declared by two providers, ingress-only owner, unknown or dangling marker alias). Native Claude ids still pass through untouched.

**Agent definitions are read once per session.**
Editing `model:` in `~/.claude/agents/*.md` does nothing to the session you edit it in: the old value keeps going out. Measured 2026-09-19, where a worker still sent the retired `gpt-daybreak-blue-high` after the file already said `@high`, and the backend answered 400. Start a new session before judging whether a frontmatter change worked.

## Getting results back from agents and Workflows

**HTML entity escaping is a display-layer artefact. Do not restore it by hand.**
When a subagent's or Workflow's result arrives as notification or result text, `<` `>` `&` in code turn into `&lt;` `&gt;` `&amp;`. Two things were corrected by measurement.

- **It is not specific to GPT.** In the same Workflow, a Claude agent's return value came back broken as `&lt;=` too. The cause is the delivery layer, not the model.
- **`journal.jsonl` holds the original text.** Code pulled from the journal had zero entities and compiled and passed tests as it was.

So do not build a restoration procedure; read from the journal. It is at `<transcriptDir>/journal.jsonl`, and the `result` field of the line where `type == "result"` is the agent's actual return value.

## Working with a worker

**A slug missing from `availableModels` is substituted in silence, and the match wants the exact string.**
Measured 2026-09-18 by pointing `ANTHROPIC_BASE_URL` at a recorder and reading the `model` field of the outgoing request. With `["haiku", "gpt-daybreak-blue@high"]` in the list, `--model gpt-daybreak-blue@high` went out as itself. With `["haiku", "gpt-daybreak-blue"]`, the same flag went out as `claude-opus-5`, and neither stdout nor stderr said a word. **The bare id does not cover the `@effort` form.** So the list has to carry every form actually used, `@high` and `@max` included. Reported as anthropics/claude-code#95324. If a worker's output reads like Claude wrote it, check the allowlist before anything else.

**`behavesAs` on a picker row silences the unknown-model warning, and a bogus target is ignored.**
`behavesAs: "claude-opus-5"` removed the "isn't described by this version's model catalog" paragraph; `claude-nonexistent-9` in the same place was dropped and the paragraph came back (measured 2026-09-18).

**`[1m]` is stripped before both the allowlist check and the wire.**
`--model 'gpt-6-astra@high[1m]'` puts `gpt-6-astra@high` on the wire and matches an allowlist entry that has no `[1m]` in it. It is a client-side way to tell Claude Code the window is 1M without touching the router or setting `CLAUDE_CODE_MAX_CONTEXT_TOKENS` for the whole machine. Which window wins when it is combined with `behavesAs` has not been measured.

**A worker's self-report and its output are two different things (measured sample).**
While verifying a mixed session, a worker wrote the correct result into the file ("ykseulb") and put a typo in its report sentence ("ykseulba"). Always judge by opening the output yourself. A chat report is never the gate.

**Opening the shell means opening both shell tools on Windows.**
Claude Code exposes `Bash` and `PowerShell`; a worker granted only `Bash` is auto-denied when the model picks `PowerShell`, and it cannot ask. Measured 2026-09-12: an ASTRA worker chose PowerShell, every cargo and pnpm gate came back "requires approval", and it delivered code without a single verified gate. Grant both names or neither.

**The worker starts subagents and worktrees on its own.**
On its own judgement it spawns subagents, produces output in a separate worktree, and even sends messages to other sessions (measured). Check the work tree yourself rather than the completion report, and copy back anything produced outside the main tree. Nailing absolute output paths into the brief reduces the scatter.

**Claude always re-runs the gates.**
Even when the worker reports a pass, Claude runs format, lint and tests itself. In practice `cargo fmt --check` was broken in the worker's output and needed `cargo fmt --all` before the commit. Compiling successfully and reporting honestly are two different things.

**Implement and audit in two separate runs.**
Handing the finished core to a fresh read-only worker turned up a real defect: where a new file is created, the id-collision check and the save were not inside the same lock, so concurrent creation could race. The same model with a fresh context gives a different field of view. Implementation by one worker, audit by another, is the cheap split.

**Give the worker the documentation.**
WebSearch and WebFetch in the allowed tools cut down hallucinated guesses at crate APIs. Letting a worker check the documentation is cheaper than letting it invent what it could not verify. Whether to open the shell is a separate decision to make deliberately, because it is an unsupervised one.

**A worker's WebSearch does not run on the worker's model, and it does not spend ChatGPT quota.**
Claude Code sends every web search as a side request on a fixed small model straight to Anthropic, whatever the session model is. So search works on a routed worker, it bills Claude, and the query is written and read by a model that is not the one doing the job. Only titles and URLs survive the hand-back, plus the search model's own prose; the CLI drops the snippets (measured upstream 2026-09-17). When the exact wording of an API matters, name the URL and send the worker to WebFetch instead, which is local end to end.

**A claude.ai connector's tools arrive late.**
Connectors do load, but their tools appear in the tool list only after the connector has connected, which can be a few turns in. A one-turn probe reported a tool as missing while a four-turn run used it. Give the worker something to do first, or name the tool in the brief and let it retry.

## The execution environment

**The U+FFFD corruption of the instructions block did not reappear on 2.1.278.**
The fault in `anthropics/claude-code#93848` (one multibyte character of the embedded `CLAUDE.md` arriving as three U+FFFD, splitting the prompt prefix and costing the whole conversation's cache) was measured at 3 of 17 requests on 2.1.258. Re-measured 2026-09-20 on 2.1.278 with the same recorder method: 29 requests captured, 27 carrying the block, one seed hash across all 27, and zero `EF BF BD` bytes in 6.6 MB of bodies. The character that used to break sits at byte offset 7,885 of the block now against 7,982 then, so the position was crossed 27 times untouched. At the old rate the chance of zero in 27 is 0.5%; zero in 27 bounds the rate at 10.5% or below. Treat the fault as unreproducible on demand rather than as fixed, and keep a recorder at hand (point `ANTHROPIC_BASE_URL` at a local server that saves each request body and forwards it) for the next time a session's cache hit rate falls without explanation.

**`--dangerously-skip-permissions` is blocked by the auto mode classifier.**
It refuses the attempt to start a child `claude` in dangerous mode from inside a parent Claude session.

**In cmd, a backslash at the end of a quoted path eats the quote.**
A quoted path ending in a backslash, like `/Fo:"...\obj\"`, escapes the closing quote and breaks the whole command line (cl dies with `D8003 missing source filename`). Move into the directory and use a relative path, or drop the trailing backslash.

**The Bash tool's heredoc breaks on content containing single quotes.**
Writing a heredoc that contains a fragment such as `&'static`, or ordinary English apostrophes, throws the shell's quote parsing off and dies with `unexpected EOF while looking for matching`. Write those files with the Write tool. Rust lifetime notation, PowerShell literal strings and prose all hit this.

**Do not trust the Bash tool's cwd.**
A `cd` from an earlier call sometimes survives, and sometimes the tool puts you back at the project root. Either way, always write paths as absolute.

## Distribution

**Do not commit the toy (public) and the skill (internal infrastructure) on the same branch.**
Internal GPT tooling mixed into a public repo makes the auto-mode classifier block the push.

**create-tauri-app bakes the Windows username into the identifier.**
It becomes `com.<Korean username>.…`, and `generate_context!` sometimes rejects a non-ASCII identifier. Fix it to an ASCII reverse-DNS name.
