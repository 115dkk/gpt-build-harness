# gpt-build-harness

OpenAI 모델 둘을 ChatGPT **구독 쿼터**로(별도 API 과금 없이) 잡부·감사관으로 부려, 큰 구현·검증 노동을 저비용으로 굴리는 Claude Code 스킬. 백엔드 노동은 Daybreak Blue가 하고, 화면과 i18n은 ASTRA가 한다. Claude는 아키텍처와 설계 방향, 적용, 판정을 쥔다.

## 무엇인가

GPT를 **네 형태**로 부린다. 어느 형태를 쓸지는 *GPT가 도구를 직접 쥐어야 하는가*와 *지금 세션이 프록시 base_url을 쓰는가*가 정한다.

| 형태 | 도구 | 어디서 | 언제 |
|---|---|---|---|
| 오라클 릴레이 | 없음(추론만) | 어느 세션에서나 | 붙여 준 코드·로그에 대한 리뷰·교차검증·2차 의견 |
| 직접 워커 (`gpt-agent.ps1`) | Read/Edit/Write/Grep/Glob/WebSearch/WebFetch (+Bash·MCP 옵트인) | 어느 세션에서나(원격 조종 브릿지 포함) | 일반 세션에서 도구 쥔 백엔드 잡부가 필요할 때의 **기본 선택** |
| 워커 서브에이전트 (`gpt-worker`, `astra-worker`) | Read/Write/Edit/Bash/… | 프록시 세션(혼합 세션 포함) | 네이티브 `Agent()` UX로 병렬·백그라운드 협업. 그리는 쪽은 `astra-worker` |
| 메인 루프 모델 | Claude Code 전체 도구 | 프록시 세션 | 세션 전체를 GPT로 굴리는 실험 |

방법론은 [SKILL.md](SKILL.md)와 [references/](references/)에 있다. 한국어로 읽으려면 [SKILL_ko.md](SKILL_ko.md)와 각 문서의 `_ko` 짝을 본다.

- 형태 고르기: [three-forms.md](references/three-forms.md) ([한국어](references/three-forms_ko.md))
- 검증된 함정: [pitfalls.md](references/pitfalls.md) ([한국어](references/pitfalls_ko.md))
- 셋업 개요: [setup.md](references/setup.md) ([한국어](references/setup_ko.md))

## 문서 언어

**모델이 읽는 문서는 영어가 정본이다.** 스킬 문서와 에이전트 정의는 세션마다 모델의 맥락에 올라가는데, 한국어는 같은 내용에 토큰이 훨씬 많이 든다. 그래서 설치·배포되는 `SKILL.md`, `references/*.md`, `tools/agents/*.md`를 영어로 두었다.

한국어 역본은 사람이 읽으라고 저장소에 나란히 남긴다. `SKILL_ko.md`, `references/*_ko.md`, 그리고 에이전트 정의의 한국어 사본 [agents/](agents/)가 그것이고, 설치·배포에는 들어가지 않는다. 이 README는 사람이 읽는 문서라 한국어가 정본이다. `references/legacy/`는 폐기한 구판 기록이라 손대지 않고 한국어 그대로 둔다.

## 방침 (2026-08-19 개정)

- **모델은 둘이다.** 백엔드 노동은 Daybreak Blue(`gpt-daybreak-blue`), 화면과 i18n과 가장 어려운 문제는 ASTRA(`gpt-6-astra`, GPT-6 Astra, 2026-09-03 공개, 슬러그 2026-09-05 실측 확인). effort는 `high`가 기본이고 절망적으로 어려운 문제에만 `max`를 쓴다. 컨텍스트는 Daybreak가 500k 압축, ASTRA가 1M 윈도우에 860k 압축이다.
- **Daybreak는 프론트엔드에 쓰지 않는다.** 미감이 파멸적이라 사람이 쓸 수 없는 결과가 나온다.
- **간단하지 않은 그림은 Claude가 손으로 그리지 않는다(2026-09-05 추가).** 설계 방향(배치 의도, 상태, 토큰, 인터페이스 id)은 Claude가 정하고, 그리기와 i18n 카탈로그 노동은 ASTRA에 맡긴 뒤 디프와 게이트로 판정한다. 문구 하나나 색 하나 같은 사소한 수정만 Claude가 직접 한다.
- **아키텍처·기획·CI/CD 설계는 Claude가 쥔다.** Daybreak는 전체 맥락을 보는 데 어려움이 있다. 인터페이스를 못박아 자기완결 명세로 넘기고, 적용·빌드·테스트·판정은 Claude가 한다. GPT의 자기 신고는 게이트가 아니다.
- **백엔드 구현은 시키지 않아도 워커에 맡긴다(2026-09-04 추가).** Claude가 설계와 작업서, 검토와 게이트를 쥐고 구현은 직접 워커(`gpt-agent.ps1`)나 `gpt-worker`가 한다. 릴레이는 검수(리뷰·교차검증·2차 의견)나 GPT에 쓰기 권한을 주면 안 되는 일에만 쓴다.
- 구판(luna/sol/terra 티어표, effort 실측표, 프롬프트 A/B 배터리)은 [references/legacy/](references/legacy/)에 보존만 해 두었다. 모델 라인업이 하나로 정리되면서 지침으로서는 폐기했다.

## 설치

실행 도구(릴레이·프록시·런처·직접 워커·서브에이전트)는 이 소스 트리에 없다. 최신 **[Releases](../../releases)** 에서 `gpt-build-harness-tools.zip`을 받아 안의 설치 스크립트를 실행한다.

- **Claude Code (전역)**: `install/install-claude-code.ps1`. `~/.claude/skills/`, `~/.claude/tools/`, `~/.claude/agents/`에 배치한다. 새 세션부터 스킬과 `gpt` / `gpt-worker` / `astra-worker` 서브에이전트가 잡힌다.
- **Claude 앱 (claude.ai)**: `install/claude-app-skill.zip`을 claude.ai의 스킬 업로드에 넣는다(방법론 문서만).
- **Codex: 설치하지 않는다.** Codex 위의 GPT가 지침 계층 맨 위에서 'GPT를 잡부로 부리는 하네스'를 읽고 자기 자신을 부리려 드는 재귀 혼란이 난다. `install-codex.ps1`은 기록으로 남겨 두었을 뿐 실행하지 않는다.

도구는 로컬 ChatGPT 구독 로그인(codex 인증 캐시)을 쓴다. 구독과 로그인은 사용자가 준비해야 한다.

## 어디서 왔나

Qt 데스크톱 앱(Equalizer APO 에디터)의 한 조각을 Tauri 웹뷰로 포팅하는 토이에서 벼렸고, 이후 Tauri 2 + Rust 안드로이드 앱의 백엔드를 통째로 위임하며 실전에서 다듬었다. 형성 과정과 밟은 함정은 [references/pitfalls.md](references/pitfalls.md)와 [references/legacy/harness-log.md](references/legacy/harness-log.md)에 있다.

## 라이선스

MIT. [LICENSE](LICENSE) 참조. 이 저장소는 방법론 문서이며, 구독·도구는 사용자가 준비한다.
