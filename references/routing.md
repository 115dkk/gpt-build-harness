# Routing

Replaces the old `setup.md` and `three-forms.md`. There are no longer four forms of the GPT labourer; there is one router and one calling form.

## What sits where

| Thing | Path | What it does |
|---|---|---|
| Router | background service, 127.0.0.1:8790 | Terminates `api.anthropic.com`, sends mapped models to a provider and passes everything else through byte for byte |
| Wiring | `~/.claude/settings.json`, `env.HTTPS_PROXY` and `env.NODE_EXTRA_CA_CERTS` | Two keys. Every Claude Code process reads them, which is why every session is routed and none needs a launcher |
| Config | `~/.clauderipple/config.json` | Providers, models, the `gpt-` direct rule, the `/model` entries. Hot-reloaded on mtime |
| Exposure | `~/.claude/settings.json`, `availableModels` and `modelPicker` | Which models Claude Code offers at all |
| Credentials | `~/.codex/auth.json` | The ChatGPT subscription token, borrowed, never refreshed by the router. The ChatGPT desktop app keeps it alive; when authentication expires, start that app |

Nothing is billed to api.openai.com. The calls consume subscription quota.

## How a model reaches a provider

`direct` holds one rule, prefix `gpt-`, pointing at the chatgpt provider. Any model id starting with `gpt-` goes there with the id unchanged, which is why a new slug needs no config change beyond making it selectable.

Effort rides on the id as `@high`, `@xhigh` or `@max`. `ultra` is clamped to `max` rather than forwarded, because the endpoint rejects it.

A marker on the first line of a brief overrides model and effort for that call only:

```
[[gpt: <model>@<effort>]]
```

Short names come from `aliases` in the config: `daybreak` and `astra`.

## Making a model selectable

Two separate gates, and a model has to clear both.

- `cli.extraModels` in the router config adds the entry to the bootstrap the CLI fetches, which is what makes `/model` accept the id at all. Agent frontmatter ids are picked up automatically: the router scans `~/.claude/agents/*.md` for `model:` and injects any routable id it finds.
- `availableModels` in `settings.json` is an allowlist and applies to `/model`, `--model`, `ANTHROPIC_MODEL`, subagent frontmatter, and skill and command frontmatter. Everything outside it is hidden from the picker.

**A slug missing from `availableModels` does not raise an error.** The subagent silently runs on a Claude model instead. If a worker's output reads like Claude wrote it, check this first.

`modelPicker.options` supplies the rows with their own labels. `replaceBuiltInOptions` stays off so the Claude lineup survives and follows new releases on its own.

`behavesAs` on a picker row attaches a known model's client-side handling (prompt profile, capabilities, effort defaults) to an id Claude Code does not recognise. It is what stops the old harness's "not a model this version recognizes" warning.

## When a call does not route

- **`clauderipple status`** names the chain. **`GET /readyz`** answers 200, or 503 with a list of what stands between a request and a model.
- **`clauderipple logs -f`** shows one line per request: who asked, which model answered, input and cache and output tokens, latency, status. A provider's error body is kept in the log head, so a 401 or a 400 says why.
- The router self-exits after repeated upstream connect failures and the supervisor restarts it. A restart drains in-flight calls rather than cutting them.
- If Claude Code itself stops working, the router is the first suspect: everything goes through it now, Claude traffic included.

## Undoing it

`clauderipple uninstall` restores `settings.json` from its backup and removes the certificate and the scheduled task. Then drop `availableModels` and `modelPicker`, and the machine is back to stock Claude Code.
