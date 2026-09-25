# gpt-build-harness

OpenAI 모델 둘을 ChatGPT **구독 쿼터**로(별도 API 과금 없이) 잡부로 부리는 Claude Code 스킬. 백엔드는 Daybreak Blue가 짓고, 백엔드와 화면을 잇는 일과 i18n과 감사는 ASTRA가 한다. 화면은 Claude Opus 5.5가 그리고, 아키텍처와 설계 방향, 적용, 판정은 Claude가 쥔다.

1.0.0부터는 [ClaudeRipple](https://github.com/PBJ-2/clauderipple) 라우터를 쓴다. 모든 Claude Code 요청이 라우터를 거치므로, 어느 세션에서든 `Agent(gpt-worker)`와 `Agent(astra-worker)`를 부르기만 하면 된다.

## 무엇인가

| 일꾼 | 모델 | 맡는 일 | 부르는 법 |
|---|---|---|---|
| Daybreak Blue | `gpt-daybreak-blue` | 화면과 무관한 구현(서비스, 네이티브 코드, 스크립트, 빌드와 테스트 보조 코드)과 그 단위 테스트 | `Agent(gpt-worker)` |
| ASTRA | `gpt-6-astra` | 백엔드와 프론트엔드를 잇는 일, 순수 백엔드보다 지식이 더 드는 구현, i18n 카탈로그, 감사 | `Agent(astra-worker)` |
| Opus 5.5 | `claude-opus-5-5` | 화면 전부(프론트엔드를 처음 만드는 일 포함), GPT 쿼터가 바닥났을 때의 대타 | 메인 세션이 직접 하거나 Agent 도구에 `model: "opus"` |

방법론은 [SKILL.md](SKILL.md)와 [references/](references/)에, 누구에게 무엇을 맡기는지는 [rules/gpt-workers.md](rules/gpt-workers.md)에 있다. 한국어로 읽으려면 각 문서의 `_ko` 짝을 본다.

- 라우터 배선과 호출이 안 될 때: [routing.md](references/routing.md) ([한국어](references/routing_ko.md))
- 검증된 함정: [pitfalls.md](references/pitfalls.md) ([한국어](references/pitfalls_ko.md))
- 위임 방침: [gpt-workers.md](rules/gpt-workers.md) ([한국어](rules/gpt-workers_ko.md))
- 워커 정의: [gpt-worker.md](agents/gpt-worker.md), [astra-worker.md](agents/astra-worker.md)

## 1.0.0에서 바뀐 것

- **네 형태와 자체 도구를 모두 뺐다.** 오라클 릴레이(`gpt-relay.ps1`과 `gpt` 에이전트), 직접 워커(`gpt-agent.ps1`), 프록시(`gpt-proxy.mjs`)와 런처(`gpt-cc.ps1`), 메인 루프 형태가 없어졌다. 요청을 ChatGPT 백엔드로 보내는 일은 ClaudeRipple이 하고, 이 저장소에는 방법론 문서와 워커 정의, 위임 방침만 남았다.
- **ASTRA는 화면을 그리지 않는다(2026-09-25).** Opus 5.5가 더 잘 그리고 맨땅에서 프론트엔드를 만드는 일도 해내므로 화면은 Claude 쪽으로 옮겼다. ASTRA는 연결과 지식이 드는 구현, i18n 카탈로그, 감사를 맡는다. i18n을 ASTRA에 남긴 것은 카탈로그에서는 문장이 자연스러운지가 관건이고, 감성적이고 꾸민 문장을 걸러내는 데는 ASTRA가 더 알맞기 때문이다.
- **GPT 쿼터가 바닥나면 Opus 5.5로 돌린다.** 두 GPT 모델은 쿼터를 함께 쓰므로 한쪽이 429 `usage_limit_reached`로 실패하면 둘 다 막힌 것이다. 이때는 같은 워커를 같은 작업서로 부르되 `model: "opus"`를 더한다. 이 인자가 에이전트 정의의 `model:`보다 우선하므로 워커의 경계 지침은 그대로 남는다.
- 옛 문서(`setup.md`, `three-forms.md`, 릴레이 에이전트의 한국어 사본)는 [references/legacy/](references/legacy/)로 옮겼다.

## 방침 (2026-09-25 개정)

- **백엔드 구현은 시키지 않아도 워커에 맡긴다.** Claude가 설계와 작업서, 검토와 게이트를 쥐고 구현은 Daybreak가 한다. 해당하는 작업이면 Claude가 알아서 위임하고 그 사실만 한 줄로 알린다.
- **Daybreak는 프론트엔드에 쓰지 않는다.** 미감이 파멸적이라 사람이 쓸 수 없는 결과가 나온다.
- **아키텍처, 기획, CI/CD 설계는 Claude가 쥔다.** Daybreak는 전체 맥락을 한꺼번에 다루지 못한다. 인터페이스를 못박아 자기완결 작업서로 넘기고, 적용과 빌드, 테스트, 판정은 Claude가 한다. 워커의 자기 보고는 게이트가 아니다.
- **effort는 `high`가 기본이다.** 그 위로 `xhigh`와 `max`를 열어 두되 문제가 정말 어려울 때만 쓴다. `ultra`는 응답 엔드포인트가 받지 않으므로 라우터가 `max`로 낮춘다.
- **압축 지점은 모델마다 다르다.** Daybreak는 500k, ASTRA는 860k에서 압축하도록 라우터 설정의 `contextWindow`에 33,000을 더해 적는다(533000, 893000). 까닭은 [pitfalls.md](references/pitfalls.md)에 있다.
- 구판의 luna/sol/terra 티어표, effort 실측표, 프롬프트 A/B 배터리는 [references/legacy/](references/legacy/)에 보존만 해 두었다. 환각이 심해 지침으로서는 2026-08-19에 폐기했다.

## 문서 언어

**모델이 읽는 문서는 영어가 정본이다.** 스킬 문서와 에이전트 정의, 위임 방침은 세션마다 모델의 맥락에 올라가는데, 한국어는 같은 내용에 토큰이 훨씬 많이 든다. 그래서 설치되는 `SKILL.md`, `references/*.md`, `agents/*.md`, `rules/gpt-workers.md`는 영어로 둔다.

한국어 역본(`*_ko.md`)은 사람이 읽으라고 저장소에 나란히 남기고, 설치에는 넣지 않는다. 이 README는 사람이 읽는 문서라 한국어가 정본이다. `references/legacy/`는 폐기한 구판 기록이라 손대지 않는다.

## 설치

1. **ClaudeRipple을 설치한다.** 방법은 [ClaudeRipple README](https://github.com/PBJ-2/clauderipple#install)를 따른다. 설치하면 `~/.claude/settings.json`에 `HTTPS_PROXY`와 `NODE_EXTRA_CA_CERTS`가 들어가고, 라우터가 상시 도는 서비스로 등록된다.
2. **라우터 설정(`~/.clauderipple/config.json`)에 ChatGPT 구독을 연결한다.** `borrow-codex`는 Codex나 ChatGPT 데스크톱 앱이 남긴 `~/.codex/auth.json`의 로그인을 빌려 쓴다.

   ```json
   {
     "providers": { "chatgpt": { "type": "chatgpt", "auth": "borrow-codex", "defaultEffort": "high" } },
     "direct": [{ "prefix": "gpt-", "provider": "chatgpt" }],
     "aliases": { "daybreak": "gpt-daybreak-blue", "astra": "gpt-6-astra" },
     "cli": {
       "extraModels": [
         { "model": "gpt-daybreak-blue", "name": "Daybreak Blue", "contextWindow": 533000 },
         { "model": "gpt-6-astra", "name": "ASTRA", "contextWindow": 893000 }
       ]
     }
   }
   ```

   `providers.chatgpt.models`에는 아무것도 적지 않는다. 모델을 적으면 라우터가 적힌 모델마다 에이전트 파일을 만들어 Agent 목록에 잡모델이 줄줄이 뜬다.
3. **최신 [Releases](../../releases)에서 `gpt-build-harness-1.0.0.zip`을 받아 `install/install-claude-code.ps1`을 실행한다.** 스킬은 `~/.claude/skills/gpt-build-harness/`에, 워커 정의는 `~/.claude/agents/`에, 위임 방침은 `~/.claude/rules/gpt-workers.md`에 놓는다. 같은 이름의 파일이 있으면 `.bak-<시각>`으로 옮겨 둔 뒤 덮어쓴다.
4. **`~/.claude/settings.json`에 모델을 노출한다.** 스크립트가 끝에 아래 조각을 출력한다. `availableModels`에는 실제로 쓰는 `@effort` 형태를 빠짐없이 적어야 한다. 빠진 형태는 경고 없이 Claude 모델로 바뀌어 나간다.

   ```json
   "availableModels": [
     "opus", "sonnet", "haiku",
     "gpt-daybreak-blue", "gpt-daybreak-blue@high", "gpt-daybreak-blue@max",
     "gpt-6-astra", "gpt-6-astra@high", "gpt-6-astra@xhigh", "gpt-6-astra@max"
   ],
   "modelPicker": {
     "options": [
       { "model": "gpt-daybreak-blue@high", "label": "Daybreak Blue · high", "behavesAs": "claude-opus-5" },
       { "model": "gpt-6-astra@high", "label": "ASTRA · high", "behavesAs": "claude-opus-5" }
     ]
   }
   ```

5. 새 세션을 연다. 에이전트 정의는 세션을 시작할 때 한 번만 읽힌다.

- **Claude 앱(claude.ai)**: zip 안의 `install/claude-app-skill.zip`을 claude.ai의 스킬 업로드에 넣는다. 방법론 문서만 들어 있다.
- **Codex에는 설치하지 않는다.** Codex 위의 GPT가 지침 맨 위에서 'GPT를 잡부로 부리는 하네스'를 읽으면 자기 자신을 부리려 드는 혼란이 생긴다.

## 어디서 왔나

Qt 데스크톱 앱(Equalizer APO 에디터)의 한 조각을 Tauri 웹뷰로 포팅하는 토이에서 시작했고, 이후 Tauri 2 + Rust 안드로이드 앱의 백엔드 전부를 위임하며 실전에서 다듬었다. 2026-09-19에 자체 프록시와 런처를 ClaudeRipple로 갈아탔다. 밟은 함정은 [references/pitfalls.md](references/pitfalls.md)와 [references/legacy/harness-log.md](references/legacy/harness-log.md)에 있다.

## 라이선스

MIT. [LICENSE](LICENSE) 참조. 이 저장소는 방법론 문서이며, 구독과 라우터는 사용자가 준비한다.
