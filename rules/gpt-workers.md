# GPT worker delegation policy

Backend implementation goes to the GPT workers without being asked; screens are drawn by Claude Opus 5.5. When a task fits, Claude delegates on its own and says so in one line, because being told to delegate every time is the chore this policy exists to remove.

There are three workers. Daybreak Blue (`gpt-daybreak-blue`) takes the backend. ASTRA (`gpt-6-astra`) takes the seam between backend and frontend, work that needs more knowledge than plain backend, i18n catalogues, and audits. Opus 5.5 (`claude-opus-5-5`) takes the screens. For both GPT models, `high` effort is the default and the sweet spot; pick `xhigh` or `max` only when the problem is genuinely hard.

## How to call them

The ClaudeRipple router runs all the time, so `Agent(gpt-worker)` and `Agent(astra-worker)` work in any session. There is no launcher, no child `claude -p` and no relay. To change model or effort for one call, put a marker such as `[[gpt: <model>@<effort>]]` on the first line of the brief. Opus 5.5 is called through the Agent tool's `model` argument set to `"opus"`, an alias that follows the newest Opus (it went out as `claude-opus-5-5` when measured on 2026-09-25). It has no agent definition of its own.

## Daybreak's work

Implementation with no screen in it: services, native code (Rust, C++, C#), scripts, build and test support code, and the unit tests for all of these.

## ASTRA's work

Wiring the backend into the frontend. Take Daybreak's wiring list (endpoints, function signatures, events, config keys) and connect the frontend's calls, state and event handling to it.

Work that needs more knowledge than plain backend: implementation that depends on platform APIs, protocols or external specs, and the backend problems Daybreak stalls on.

i18n catalogues: writing and translating the text, adding and syncing keys, keeping placeholders identical, font-subset gates. What matters here is whether the text reads naturally rather than how much of it there is, and ASTRA keeps sentimental, dressed-up phrasing out better than Claude does.

Audits: show ASTRA finished code or a diff and have it look for defects.

## Not ASTRA's work

Screens. ASTRA does not make views, components, layouts, styles or mockups. When wiring takes it into a screen file, it changes calls and state only and leaves markup and styles alone. ASTRA never does design.

## Opus 5.5's work

All screens: new views, component sets, layout and style systems, mockups, gallery pages. When a screen needs new text, Opus settles the keys and ASTRA writes the catalogue entries. Opus 5.5 draws better than ASTRA, so it also raises a frontend from nothing.

If the main session runs Opus 5.5 it may draw directly. When the batch is large enough that the main context is worth sparing, or the main session runs another model, hand it to `Agent(subagent_type: "general-purpose", model: "opus")`.

## When the GPT quota is spent

Daybreak and ASTRA share one ChatGPT subscription quota, so a 429 `usage_limit_reached` from either means neither can run. It also shows in `clauderipple logs`, and sometimes the user says so. Do not wait for the quota to come back: call the same worker with the same brief and add `model: "opus"`. That argument overrides the agent file's `model:` line, so the worker's boundaries stay in force and only the model changes (measured with `gpt-worker` on 2026-09-25). Remove any model marker from the brief's first line first: the router honours a marker on any model, and one left in place sends the call straight back to the spent quota.

## What Claude keeps

Design direction (what a screen is for, layout intent, states, tokens, interface ids and names), architecture (module boundaries, types and signatures, error policy), writing the brief, reviewing the worker's diff, rerunning format, lint and test gates, commits and PRs. A worker's self-report is never a gate. CI/CD design is never delegated. The GPT workers do not touch screens.

## What Claude may do directly

A short edit inside one file, a change of a few dozen lines where settling the design is the implementation, a trivial screen touch such as one string or one colour, finishing a worker's result. That is, cases where starting a worker costs more than the work.

## Review only

For a second opinion on finished code or a diff, call a worker with `Read` as its only tool. Audits can go to ASTRA, and giving the audit to a different worker from the one that implemented turns up defects the implementation missed. Work where GPT must not have write access (sensitive trees, changes that are hard to undo) is handled the same way. Do not take an implementation as an opinion and have Claude copy it in.

## Brief rules

Self-contained. Nail down the design and signatures, list the files it may touch, the verification commands and the report format. Absolute paths throughout. Tell it to run build and test commands in the foreground and to end its turn only after reporting. Tell it to check any API it is unsure of. Where exact wording matters, name the URL and have it use WebFetch.

For screens handed to an Opus 5.5 subagent, add the design direction: the tokens and where they are defined, the path of a neighbouring component to imitate, the list of states, the interface ids it must not touch, the gate commands to run. With no frontend yet, give what the screen is for and the framework instead of tokens and neighbours.

For ASTRA's wiring, give Daybreak's wiring list, the call-site and state files it may change, and the markup and style files it must leave alone.

Two workers run side by side in one worktree when their file sets do not overlap.
