# 함정 (검증된 것)

GPT 잡부를 붙여 굴리며 실제로 밟은 것만 근거와 함께 적었다. SKILL.md 요약의 원본이다.

## 릴레이 형태

**릴레이는 PowerShell 도구(pwsh 7)로만 실행한다.**
Bash 도구가 부르는 `powershell.exe`는 Windows PowerShell 5.1이고, 그 네트워크 스택은 이 머신에서 chatgpt.com에 막혀 무한 대기한다. `gpt-relay.ps1`은 pwsh 7 전용인 `-SkipHttpErrorCheck`도 쓴다. `gpt` 에이전트 정의가 PowerShell 도구를 강제하는 이유다.

**릴레이 출력은 PowerShell `>` 리다이렉션으로 잡히지 않는다.**
릴레이가 답을 `[Console]::Out.Write`로 콘솔 핸들에 직접 쓰기 때문에 PowerShell 성공 스트림을 거치지 않는다. `... > out.txt`를 걸면 **빈 파일**이 남고 답은 사라진다. 배경 실행의 태스크 출력 파일에는 정상적으로 담기므로 그쪽을 읽는다. 굳이 파일로 받아야 하면 자식 프로세스로 띄워(`pwsh -File ...`) 프로세스 수준에서 리다이렉트한다.

**릴레이는 도구 없는 오라클이다.**
GPT는 파일을 못 읽고 못 쓰고 아무것도 실행하지 못한다. 맥락(기존 코드, 스펙, 로그)을 프롬프트 본문에 자기완결로 붙여야 한다. 붙이지 않은 저장소 사실을 물으면 지어낼 수 있다 — "확인할 수 없으면 확인할 수 없다고 답하라"는 탈출구를 준다. 반환물의 적용·빌드·판정은 Claude가 한다.

**모델 슬러그는 `gpt-daybreak-blue`다(2026-08-19 실측).**
버전 접두사를 붙인 변형(`gpt-5.6-daybreak-blue`, `gpt-5.6-daybreak`, `gpt-5.6-sol-daybreak-blue` 등)은 codex responses 백엔드가 전부 HTTP 400으로 거부한다. 릴레이·프록시·런처의 기본값이 이미 이 슬러그라 생략하면 안전하다.

## 에이전트·Workflow 결과 전달

**HTML 엔티티 이스케이프는 표시 계층 현상이다. 손으로 복원하지 말 것.**
서브에이전트나 Workflow의 결과가 알림·결과 텍스트로 전달될 때 코드의 `<` `>` `&`가 `&lt;` `&gt;` `&amp;`로 바뀐다. 두 가지를 실측으로 바로잡았다.

- **GPT 릴레이 전용이 아니다.** 같은 Workflow에 넣은 **Claude 에이전트의 반환값도** `&lt;=`로 깨져 왔다. 원인은 모델이 아니라 전달 계층이다.
- **`journal.jsonl`에는 원문이 그대로 있다.** 저널에서 꺼낸 코드는 엔티티가 0개였고 그대로 컴파일돼 테스트를 통과했다.

그러니 복원 절차를 만들지 말고 **저널에서 읽는다.** 위치는 `<transcriptDir>/journal.jsonl`이고, `type == "result"`인 줄의 `result` 필드가 에이전트의 실제 반환값이다. 큰 코드를 육안으로 복원하는 것은 위험할 뿐 아니라 애초에 불필요하다.

## 프록시 / 워커 / 메인 형태

**워커·메인 형태는 프록시 세션 전용이다.**
`gpt-worker` 서브에이전트나 메인 모델 GPT는 `ANTHROPIC_BASE_URL`이 `gpt-proxy.mjs`를 가리켜야 작동한다. 일반 Claude 세션에서 `gpt-daybreak-blue-*` 모델을 부르면 진짜 Anthropic으로 가 즉시 죽는다(2026-08-20 실측: "model may not exist" API 오류로 에이전트 종료). "하네스를 굴리는 세션"과 "GPT가 실행되는 세션"은 다르다. 일반 세션에서 도구 쥔 GPT가 필요하면 `gpt-agent.ps1`(자식 claude 직접 워커)로 우회한다.

**구독 OAuth는 커스텀 base URL을 통과한다(2026-08-20 실측).**
Claude Code는 `ANTHROPIC_BASE_URL`이 프록시여도 구독 OAuth bearer를 그대로 보내고, 프록시 패스스루가 api.anthropic.com에 200으로 전달된다 — 혼합 세션(`gpt-cc.ps1 -Main claude`)에 API 키가 필요 없다. 단 `ANTHROPIC_AUTH_TOKEN`을 세팅하면 OAuth를 **덮어써** 패스스루가 401 난다. 혼합 모드에서는 절대 세팅하지 말 것(GPT 메인 모드의 더미 토큰은 그대로 둔다).

**`claude -p`의 `--allowedTools`는 가변 인자라 위치 프롬프트를 삼킨다.**
`claude -p --allowedTools "Read Write" "과제..."`는 과제까지 도구 목록으로 먹혀 "Input must be provided either through stdin or as a prompt argument"로 죽는다(실측). 과제는 stdin으로 파이프한다 — `"과제" | claude -p --allowedTools "Read,Write"`. `gpt-agent.ps1`이 이 방식을 쓴다.

**미인식 모델 경고는 무해하다.**
`gpt-daybreak-blue-*`로 자식 claude를 띄우면 "not a model this version recognizes" 경고가 찍힌다. 윈도우는 `CLAUDE_CODE_AUTO_COMPACT_WINDOW`/`CLAUDE_CODE_MAX_CONTEXT_TOKENS`로 고정하면 되고, 경고가 제안하는 `modelOverrides` 설정은 "알려진 Anthropic ID → 프로바이더 ID" 매핑(관리형 설정용)이라 이 용도에 맞지 않는다.

**워커의 자기 보고와 산출물은 별개다(실측 표본).**
혼합 세션 검증에서 gpt-worker가 파일에는 정확한 결과("ykseulb")를 쓰고 보고 문장에는 오탈자("ykseulba")를 냈다. 판정은 항상 산출물을 직접 열어 한다 — 채팅 보고를 게이트로 삼지 않는다.

**프록시의 도구 호출 변환은 작동한다(확인함).**
프록시를 띄워 Anthropic Messages API 형식으로 직접 요청했을 때, 평문 요청은 200으로 정상 응답했고 도구 정의를 준 요청은 `stop_reason: "tool_use"`와 함께 올바른 인자로 도구 호출을 반환했다. 프록시 세션에서 GPT가 실제로 탐색·편집을 수행할 수 있다는 뜻이다.

**codex responses는 `max_output_tokens`를 거부한다.**
프록시가 Anthropic `max_tokens`를 그대로 넘기면 HTTP 400 `Unsupported parameter`가 난다. 전달하지 않는다(codex가 자체 관리).

**자동 캐시는 `session_id` 헤더에 묶인다.**
같은 대용량 접두라도 session_id가 매 요청 랜덤이면 캐시 히트가 0이라 매 턴 시스템 프롬프트를 풀차지한다. 프록시가 대화별 안정 session_id를 써야 히트가 걸린다.

**메인 세션의 자동압축 500k는 런처가 건다.**
`gpt-daybreak-blue-*`는 Claude Code가 인식하지 못하는 슬러그라, `CLAUDE_CODE_AUTO_COMPACT_WINDOW`(또는 settings 키 `autoCompactWindow`)를 명시하지 않으면 미인식 모델용 기본 윈도우로 떨어진다. `gpt-cc.ps1`이 미설정일 때 500000을 세팅한다.

## 실행 환경

**`--dangerously-skip-permissions`는 auto mode 분류기가 차단한다.**
부모 Claude 세션 안에서 자식 `claude`를 위험 모드로 띄우려는 시도를 거부한다.

**자식 `claude`가 cwd를 프로젝트 루트로 되돌린다.**
`Set-Location`으로 폴더를 바꿔도 자식이 cwd를 부모 워크트리 루트로 리셋한다. 파일은 절대경로로 지정한다.

**`claude -p`가 stdin을 3초 기다린다.**
`$null | & claude -p ...`로 빈 stdin을 파이프하면 기다리지 않는다.

**cmd에서 인용 경로 끝의 역슬래시가 따옴표를 먹는다.**
`/Fo:"...\obj\"`처럼 역슬래시로 끝나는 인용 경로는 닫는 따옴표를 이스케이프해 명령줄 전체가 깨진다(cl이 `D8003 소스 파일 이름이 없습니다`로 죽는다). 해당 디렉터리로 이동해 상대 경로를 쓰거나 끝 역슬래시를 뺀다.

**Bash 도구의 heredoc은 작은따옴표를 품은 코드에서 깨진다.**
`&'static` 같은 조각이 든 heredoc을 Bash 도구로 쓰면 셸 인용 파싱이 어긋나 `unexpected EOF while looking for matching` 로 죽는다. 그런 파일은 Write 도구로 쓴다(Rust 수명 표기, PowerShell 리터럴 문자열 등이 자주 걸린다).

**Bash 도구의 cwd는 믿지 않는다.**
이전 호출의 `cd` 가 그대로 살아 있기도 하고, 도구가 프로젝트 루트로 되돌리기도 한다. 어느 쪽이든 경로는 항상 절대경로로 쓴다.

## 배포 (토이에서 얻은 것)

**토이(공개 대상)와 스킬(내부 인프라)을 같은 브랜치에 커밋하지 않는다.**
내부 GPT 도구가 공개 repo에 섞이면 auto-mode 분류기가 push를 차단한다.

**create-tauri-app이 Windows 사용자명을 identifier에 박는다.**
`com.<한글 사용자명>.…`이 되어 `generate_context!`가 non-ASCII identifier를 거부할 수 있다. ASCII reverse-DNS로 교정한다.

## 실전 — 백엔드 전부 위임 (2026-08-30, Tauri 2 + Rust)

안드로이드 앱의 코어(도메인·슬롯 계산·저장소·PNG 렌더·내보내기)를 `gpt-agent.ps1` 직접 워커에 통째로 맡기고, 화면(Svelte)은 Claude가 전담한 첫 실전에서 얻은 것. 결과물은 릴리즈까지 갔고 코어 테스트 56개가 붙었다.

**검색 권한을 함께 준다.**
WebSearch·WebFetch와 검색 MCP를 워커의 허용 도구에 넣으면 모르는 크레이트 API를 찍는 환각이 줄어든다. 확인하지 못한 것을 지어내게 두는 것보다, 워커가 직접 문서를 확인하게 하는 편이 싸다. 대신 Bash를 열어 줄지는 의식적으로 정한다(무감독 셸이다).

**워커가 서브에이전트와 워크트리를 스스로 벌인다.**
직접 워커는 자식 `claude` 세션이라 자기 판단으로 서브에이전트를 띄우고, 별도 워크트리에 산출물을 만들고, 다른 세션에 메시지까지 보낼 수 있다(실측). **완료 보고가 아니라 작업 트리를 직접 확인**하고, 메인 트리 밖에 만들어진 산출물은 복사해 온다. 위임 과제에 산출물의 절대경로를 못박아 두면 흩어짐이 줄어든다.

**게이트는 언제나 Claude가 다시 돌린다.**
워커가 통과했다고 보고해도 포맷·린트·테스트를 Claude가 직접 돌린다. 실제로 워커 산출물에서 `cargo fmt --check` 가 깨져 있었다(커밋 전 `cargo fmt --all` 로 교정). 컴파일과 테스트가 도는 것과 신고가 정직한 것은 별개다.

**구현과 감사는 형태를 바꿔 두 번 본다.**
완성된 코어를 이번에는 릴레이(도구 없는 오라클)에 붙여 감사시키자 실제 결함을 짚었다 — 파일 생성 경로에서 id 충돌 탐색과 저장이 같은 잠금 안에 있지 않아 동시 생성 시 경쟁이 가능했다. 같은 모델이라도 형태를 바꾸면 다른 시야가 나온다. 구현은 워커, 감사는 릴레이가 싸다.
