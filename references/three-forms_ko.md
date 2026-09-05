# GPT 잡부의 네 형태

어느 형태를 쓸지는 두 가지가 정한다. **GPT가 도구를 직접 쥐어야 하는 일인가**, 그리고 **지금 세션이 프록시 base_url을 쓰는가**. 어느 형태든 부르는 모델은 둘 중 하나다. 백엔드 노동은 Daybreak Blue(`gpt-daybreak-blue`), 그림과 i18n 카탈로그와 Daybreak가 막히는 문제는 ASTRA(`gpt-6-astra`)가 맡는다.

| 형태 | 도구 | 어디서 되나 | 손은 누구 | 언제 |
|---|---|---|---|---|
| 오라클 릴레이 | 없음(추론만) | 어느 세션에서나 | Claude | 붙여 준 맥락에 대한 순수 추론(리뷰 소견, 교차검증, 2차 의견) |
| 직접 워커 (`gpt-agent.ps1`) | Read/Edit/Write/Grep/Glob/WebSearch/WebFetch (+Bash·MCP 옵트인) | **어느 세션에서나**(브릿지 포함) | GPT 자신 | 일반 세션에서 도구 쥔 잡부가 필요할 때의 **기본 선택**. 그림과 i18n은 `-Model astra` |
| 워커 서브에이전트 (`gpt-worker`, `astra-worker`) | Read/Write/Edit/Bash/… | 프록시 세션(gpt-cc, `-Main claude` 혼합 포함) | GPT 자신 | 네이티브 Agent() UX로 병렬·백그라운드 협업. 그리는 쪽은 `astra-worker` |
| 메인 루프 모델 | Claude Code 전체 도구 | 프록시 세션(gpt-cc) | GPT 자신 | 세션 전체를 GPT로 굴리는 실험 |

## 1. 오라클 릴레이 (`gpt` 에이전트 / `tools/gpt-relay.ps1`)

GPT는 도구 없이 추론만 한다. Claude가 맥락을 자기완결 프롬프트로 주고, GPT가 코드·소견을 텍스트로 돌려주면 Claude가 적용·빌드·판정한다. pwsh로 직접 호출하므로 어느 세션에서나 즉시 작동하고, Claude 게이트를 구조적으로 강제한다. 다만 GPT가 저장소를 전혀 못 보므로 맥락을 전부 붙여 줘야 하는 갑갑함이 있다. **도구가 필요한 일이면 아래 직접 워커로 간다.**

정밀 측정이 필요하면 `gpt` 서브에이전트를 거치지 말고 **릴레이 스크립트를 직접 호출**한다. 서브에이전트를 거치면 결과가 표시 계층을 지나며 HTML 엔티티가 섞이고 토큰·시간 계측이 흐려진다.

## 2. 직접 워커 (`tools/gpt-agent.ps1`), 일반 세션의 기본 잡부

haiku 껍데기 없이, **어느 세션에서든** 도구를 쥔 Daybreak를 부리는 형태다(2026-08-20 실측: 일반 세션에서 Read+Write 파일 작업 정상 수행). 자식 `claude -p`를 프록시 env로 띄워 GPT가 메인 루프에서 직접 파일을 읽고 고치게 한다. LLM 중계 계층이 없다. 스크립트가 프록시 기동·env 세팅·복원까지 처리하고 GPT의 최종 답을 stdout으로 돌려준다.

```powershell
& "$env:USERPROFILE\.claude\tools\gpt-agent.ps1" -Task "<자기완결 과제, 절대경로 사용>"
& ... -Model astra        # ASTRA(gpt-6-astra): 그림, i18n, 가장 어려운 백엔드
& ... -Effort xhigh        # ASTRA의 아직 측정되지 않은 중간 단
& ... -Effort max          # 절망적으로 어려운 문제만
& ... -AllowBash           # Bash 도구 허용 (무감독 셸, 의식적으로 옵트인)
& ... -TaskFile big.txt    # 긴 과제는 파일로
& ... -Tools 'Read,Grep,mcp__<server>__<tool>'   # 도구 목록을 통째로 바꿀 때
```

- 과제는 stdin으로 전달한다(`--allowedTools`가 가변 인자라 위치 프롬프트를 삼키는 함정을 피한다).
- 기본 허용 도구는 Read/Edit/Write/Grep/Glob/WebSearch/WebFetch. 나머지는 -p 모드에서 자동 거부하므로 GPT가 임의로 넓히지 못한다. `-Tools`는 목록을 통째로 바꾸고, 환경 변수 `GPT_AGENT_EXTRA_TOOLS`(쉼표 구분)는 목록에 덧붙인다. 검색 MCP 도구 이름은 여기에 넣는다.
- WebSearch는 프록시를 거쳐 동작한다. 프록시가 Claude Code의 서버 쪽 웹 검색을 codex 웹 검색으로 옮기고, 답변의 인용에서 결과 블록을 다시 만든다(2026-09-04 실측). WebFetch는 로컬에서 받아 패스스루 모델로 요약하므로 매핑이 필요 없다.
- MCP 도구는 프록시를 일반 함수로 통과한다. 다만 claude.ai 커넥터의 도구는 커넥터가 연결된 뒤에야 목록에 나타나고, 그때까지 몇 턴이 걸리기도 한다. 첫 턴부터 그 도구가 필요한 과제는 도구를 보지 못한다.
- 추가 `claude` 인자(`--output-format stream-json --verbose` 등)는 스크립트 파라미터 뒤에 붙이면 그대로 넘어간다. 스크립트가 그 인자를 `--allowedTools` 앞에 두므로 삼켜지지 않는다.
- 과제 본문에는 **절대경로**를 쓴다(자식 claude가 cwd를 리셋하기도 한다).
- 자식이 찍는 "unrecognized model" 경고는 무해하다(윈도우는 env로 고정한다).
- 윈도우는 `-Model`을 따라간다. Daybreak는 `CLAUDE_CODE_AUTO_COMPACT_WINDOW=500000`, ASTRA는 `CLAUDE_CODE_MAX_CONTEXT_TOKENS=1000000`에 860000 압축이다. 셸에 남아 있던 값을 물려받지 않고 고른 모델에 맞춰 새로 걸며, 자식이 끝나면 호출자의 값을 되돌린다.

## 3. 워커 서브에이전트 (Daybreak는 `gpt-worker`, ASTRA는 `astra-worker`)

GPT 자체가 서브에이전트의 LLM이라 파일 읽기·편집·명령 실행을 직접 한다. `ANTHROPIC_BASE_URL`이 `gpt-proxy.mjs`를 가리키는 세션에서만 작동한다. 일반 세션에서 부르면 `gpt-daybreak-blue-*`나 `gpt-6-astra-*`가 진짜 Anthropic으로 가 즉시 죽는다(실측: "model may not exist" API 오류). 그럴 땐 형태 2를 쓴다.

두 서브에이전트는 모양이 같고 모델과 경계만 다르다. `gpt-worker`는 백엔드 잡부, `astra-worker`는 화면과 i18n 카탈로그를 맡는 쪽이다.

프록시 세션은 두 종류다(2026-08-20 실측).

- **GPT 메인 세션** (`gpt-cc.ps1`): 메인도 서브도 GPT.
- **혼합 세션** (`gpt-cc.ps1 -Main claude`): 메인 루프는 Claude가 구독 OAuth 그대로 유지하고(프록시가 non-GPT 요청을 api.anthropic.com에 그대로 패스스루한다. OAuth가 커스텀 base URL을 통과함을 실측 확인했고 API 키는 필요 없다), `Agent(gpt-worker)`만 codex로 간다. **일반 대화 UX 그대로 GPT 서브에이전트와 협업하는 형태**다. 단 `ANTHROPIC_AUTH_TOKEN`을 세팅하면 OAuth를 덮어 패스스루가 401 나므로 혼합 모드는 이를 건드리지 않는다.

프록시의 도구 호출 변환은 실측으로 확인했다. 혼합 세션에서 gpt-worker가 파일 작업을 정확히 수행했다(같은 실측에서 서브에이전트의 *보고 문장*에는 오탈자가 있었는데 파일 산출물은 정확했다. 자기 신고를 게이트로 삼지 말라는 규칙의 표본이다).

게이트가 없으므로 `gpt-worker`는 백엔드 로직 잡부 전용이고 프론트엔드에는 어떤 형태로든 투입하지 않는다. 그리는 일은 `astra-worker`가 받는다(SKILL_ko.md의 역할 경계 규정).

## 4. 메인 루프 모델 (`tools/gpt-cc.ps1`)

Claude Code 전체를 GPT로 돌린다. 프록시가 Anthropic Messages API를 codex responses로 실시간 변환한다. 게이트가 없으니 사용자가 직접 감독한다.

**윈도우는 `-Base`를 따라간다.** Daybreak Blue 세션은 500k에서 압축하고(`CLAUDE_CODE_AUTO_COMPACT_WINDOW=500000`, settings 키 `autoCompactWindow`와 같은 노브), ASTRA 세션은 1M을 들고 860k에서 압축한다(`CLAUDE_CODE_MAX_CONTEXT_TOKENS=1000000`과 `CLAUDE_CODE_AUTO_COMPACT_WINDOW=860000`). 둘 다 Claude Code가 인식하지 못하는 슬러그라, 이 설정이 없으면 미인식 모델용 기본 윈도우로 떨어진다. 런처는 지금 띄우는 base에 맞춰 값을 새로 쓰므로, 같은 셸에서 앞서 띄운 세션의 값이 남아 이번 세션의 윈도우를 어긋나게 만들지 않는다.

Codex 쪽(하네스가 아니라 CLI와 데스크탑 앱)은 같은 숫자를 프로파일 파일에 넣고 `codex -p <이름>`으로 얹는다. `model`, `model_context_window`, `model_auto_compact_token_limit`, 그리고 `model_auto_compact_token_limit_scope = "total"`이다. 계정 카탈로그에 없는 모델도 `model_catalog_json`에 항목을 더하면 쓸 수 있고, 그 항목의 `context_window`가 선택기와 압축 계산에 쓰인다.

**원격 조종 브릿지와는 양립하지 않는다(2026-07-31 실측).** `claude remote-control`은 기동할 때 `ANTHROPIC_BASE_URL`을 검사하고, api.anthropic.com이 아니면 exit 1로 거절한다.

```
Error: Remote Control is only available when using Claude via api.anthropic.com.
ANTHROPIC_BASE_URL is set and does not point at api.anthropic.com ...
```

이는 혼합 세션(`-Main claude`)에도 똑같이 적용된다. 브릿지 세션은 프록시를 못 물린다. **브릿지 세션에서 도구 쥔 GPT가 필요하면 형태 2(`gpt-agent.ps1`)가 유일한 방법이다**(자식 claude는 브릿지가 아니므로 제약이 없다).

## 모델 이름과 두 문법

모델은 Daybreak Blue(`gpt-daybreak-blue`)와 ASTRA(`gpt-6-astra`) 둘이고, effort는 `high`(기본이자 스윗스팟), `xhigh`, `max` 세 단을 연다. Daybreak에서 `max`는 절망적으로 어려운 문제 전용이고, ASTRA는 high 위의 두 단이 열려 있으나 아직 측정하지 않았다. 그런데 **형태마다 지정 문법이 다르다.** 섞어 쓰면 조용히 기본값으로 떨어지거나 404가 난다.

**릴레이**는 프롬프트 첫 줄에 지시 줄로 준다. 모델 이름에 effort를 붙이지 않는다.

```
GPT-MODEL: gpt-daybreak-blue
GPT-EFFORT: high
```

생략하면 릴레이 기본값이 그대로 daybreak-blue/high라 방침과 일치한다. 화면이나 디자인, i18n 카탈로그에 대한 소견이 필요하면 `GPT-MODEL: gpt-6-astra`로 준다.

**직접 워커·워커·메인**은 모델 이름 하나에 effort를 접미사로 붙인다.

```
gpt-daybreak-blue-<effort>      예: gpt-daybreak-blue-high, gpt-daybreak-blue-max
gpt-6-astra-<effort>            예: gpt-6-astra-high, gpt-6-astra-max
```

`gpt-worker`와 `astra-worker`의 frontmatter `model:`, 런처와 `gpt-agent.ps1`이 세팅하는 `ANTHROPIC_MODEL`이 이 형태다(직접 워커는 `-Model daybreak|astra`와 `-Effort high|xhigh|max`로 받아 슬러그를 만든다). 접미사를 빼면 프록시가 환경변수 `GPT_EFFORT`(기본 high)를 쓴다. 엔드포인트는 두 모델 모두 `ultra`를 HTTP 400으로 거절한다(ultra는 effort 값이 아니라 Codex 클라이언트 쪽 모드다). ASTRA는 프록시가 낡은 codex 버전을 적어 보내면 아예 답하지 않으므로 `GPT_CODEX_VERSION`을 최신으로 둔다.

**메인 모델은 `/model`로 바꿀 수 없다.** 모델을 고르는 일이 아니라 엔드포인트를 갈아끼우는 일이기 때문이다. 런처는 `ANTHROPIC_BASE_URL`을 프록시로 돌린 뒤 `claude`를 띄우고, 그 값은 프로세스 시작 시점에 정해진다. 이미 돌고 있는 일반 세션에서 `/model gpt-daybreak-blue-high`를 쳐도 요청이 진짜 Anthropic으로 가 404가 난다. GPT를 메인으로 쓰려면 런처로 **새 세션**을 띄운다.

## 역할별로 형태를 고르기

**백엔드 구현은 시키지 않아도 형태 2/3이 맡는다.** 릴레이 GPT는 도구가 없어 코드베이스도 웹도 뒤지지 못한다. 형태 2/3에는 WebSearch와 WebFetch가 있다. 일반 세션이면 `gpt-agent.ps1`, 프록시 세션이면 `gpt-worker`가 맡는다. Claude(Explore)와 분담해도 된다.

**프론트엔드가 이미 서 있다면, 간단하지 않은 그림도 시키지 않아도 ASTRA가 맡는다(2026-09-05).** 새 뷰, 컴포넌트 묶음, 레이아웃이나 스타일 체계, 목업, 갤러리 페이지, i18n 키 뭉치는 Claude가 설계 방향을 정한 뒤 일반 세션이면 `gpt-agent.ps1 -Model astra`, 프록시 세션이면 `astra-worker`로 넘긴다. **맨땅에서 세우는 프론트엔드는 예외다.** 골조(구조, 컴포넌트 관례, 토큰, 본이 되는 첫 화면)는 Claude가 세우고, 그 안에서 할 일이 생긴 뒤에야 ASTRA가 이어받는다. 디프 검토와 게이트는 Claude가 하고, 문구 하나나 색 하나 같은 사소한 수정은 Claude가 직접 한다.

**릴레이는 검수, 아니면 GPT가 쓰면 안 되는 일에 쓴다.** 붙여 준 코드나 디프의 리뷰·교차검증·2차 의견, 그리고 GPT에 쓰기 권한을 주면 안 되는 과제. 그런 일에는 자식 claude를 띄울 이유가 없다. 구현을 릴레이로 받지는 않는다.

**Workflow에 꽂을 때는 `agentType: 'gpt'`를 쓴다.** 정상 작동하며 StructuredOutput 스키마도 채워 돌아온다. 반환물은 알림 텍스트가 아니라 `journal.jsonl`에서 꺼낸다. (프록시 세션이라면 `agentType: 'gpt-worker'`도 된다.)

## 고르는 법 요약

- 일반 세션(브릿지 포함)에서 GPT가 파일을 직접 뒤지고 고쳐야 한다 → **직접 워커(`gpt-agent.ps1`)**.
- 붙여 준 코드에 대한 소견·교차검증만 필요하다 → **릴레이**.
- 로컬에서 새 세션을 띄울 수 있고, 대화 안에서 Agent()로 GPT와 병렬 협업하고 싶다 → **혼합 세션(`gpt-cc.ps1 -Main claude`) + 워커**.
- 이미 선 프론트엔드에서 사소하지 않은 그림이나 i18n 노동이다 → **ASTRA**(`gpt-agent.ps1 -Model astra`, 프록시 세션이면 `astra-worker`). 설계 방향은 Claude가 먼저 정하고 디프도 Claude가 본다.
- 맨땅에서 프론트엔드를 세운다 → **Claude**. 골조와 첫 화면이 설 때까지는 Claude가 한다. Daybreak는 애초에 화면에 손대지 않는다.
- 세션 전체를 GPT로 굴려보고 싶다 → **메인 모델(`gpt-cc.ps1`)**.
