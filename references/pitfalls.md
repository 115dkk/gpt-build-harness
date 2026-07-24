# 함정 (검증된 것)

GPT 잡부를 붙여 굴리며 실제로 밟은 것만 근거와 함께 적었다. SKILL.md 요약의 원본이다.

## 릴레이 형태

**릴레이는 PowerShell 도구(pwsh 7)로만 실행한다.**
Bash 도구가 부르는 `powershell.exe`는 Windows PowerShell 5.1이고, 그 네트워크 스택은 이 머신에서 chatgpt.com에 막혀 무한 대기한다. `gpt-relay.ps1`은 pwsh 7 전용인 `-SkipHttpErrorCheck`도 쓴다. `gpt` 에이전트 정의가 PowerShell 도구를 강제하는 이유다.

**릴레이 출력은 PowerShell `>` 리다이렉션으로 잡히지 않는다.**
릴레이가 답을 `[Console]::Out.Write`로 콘솔 핸들에 직접 쓰기 때문에 PowerShell 성공 스트림을 거치지 않는다. `... > out.txt`를 걸면 **빈 파일**이 남고 답은 사라진다. 배경 실행의 태스크 출력 파일에는 정상적으로 담기므로 그쪽을 읽는다. 굳이 파일로 받아야 하면 자식 프로세스로 띄워(`pwsh -File ...`) 프로세스 수준에서 리다이렉트한다.

**릴레이는 도구 없는 오라클이다.**
GPT는 파일을 못 읽고 못 쓰고 아무것도 실행하지 못한다. 맥락(기존 코드, 스펙, 로그)을 프롬프트 본문에 자기완결로 붙여야 한다. 붙이지 않은 저장소 사실을 물으면 지어낸다(`prompt-rules.md` 규칙 1). 반환물의 적용·빌드·판정은 Claude가 한다.

**effort를 생략하면 가장 비싼 쪽으로 간다.**
`gpt-relay.ps1`의 `-Effort` 기본값이 `xhigh`다. 실측에서 xhigh는 medium과 같은 소견을 내면서 시간과 토큰을 9배 썼다. 호출할 때 effort를 항상 명시한다.

## 에이전트·Workflow 결과 전달

**HTML 엔티티 이스케이프는 표시 계층 현상이다. 손으로 복원하지 말 것.**
서브에이전트나 Workflow의 결과가 알림·결과 텍스트로 전달될 때 코드의 `<` `>` `&`가 `&lt;` `&gt;` `&amp;`로 바뀐다. 두 가지를 실측으로 바로잡았다.

- **GPT 릴레이 전용이 아니다.** 같은 Workflow에 넣은 **Claude 에이전트의 반환값도** `&lt;=`로 깨져 왔다. 원인은 모델이 아니라 전달 계층이다.
- **`journal.jsonl`에는 원문이 그대로 있다.** 저널에서 꺼낸 코드는 엔티티가 0개였고 그대로 컴파일돼 테스트를 통과했다.

그러니 복원 절차를 만들지 말고 **저널에서 읽는다.** 위치는 `<transcriptDir>/journal.jsonl`이고, `type == "result"`인 줄의 `result` 필드가 에이전트의 실제 반환값이다. 큰 코드를 육안으로 복원하는 것은 위험할 뿐 아니라 애초에 불필요하다.

## 프록시 / 워커 / 메인 형태

**워커·메인 형태는 프록시 세션 전용이다.**
`gpt-worker` 서브에이전트나 메인 모델 GPT는 `ANTHROPIC_BASE_URL`이 `gpt-proxy.mjs`를 가리켜야 작동한다. 일반 Claude 세션에서 `gpt-5.6-*` 모델을 부르면 진짜 Anthropic으로 가 404가 난다. "하네스를 굴리는 세션"과 "GPT가 실행되는 세션"은 다르다.

**프록시의 도구 호출 변환은 작동한다(확인함).**
프록시를 띄워 Anthropic Messages API 형식으로 직접 요청했을 때, 평문 요청은 200으로 정상 응답했고 도구 정의를 준 요청은 `stop_reason: "tool_use"`와 함께 올바른 인자로 도구 호출을 반환했다. 프록시 세션에서 GPT가 실제로 탐색·편집을 수행할 수 있다는 뜻이다.

**codex responses는 `max_output_tokens`를 거부한다.**
프록시가 Anthropic `max_tokens`를 그대로 넘기면 HTTP 400 `Unsupported parameter`가 난다. 전달하지 않는다(codex가 자체 관리).

**자동 캐시는 `session_id` 헤더에 묶인다.**
같은 대용량 접두라도 session_id가 매 요청 랜덤이면 캐시 히트가 0이라 매 턴 시스템 프롬프트를 풀차지한다. 프록시가 대화별 안정 session_id를 써야 히트가 걸린다.

## 실행 환경

**`--dangerously-skip-permissions`는 auto mode 분류기가 차단한다.**
부모 Claude 세션 안에서 자식 `claude`를 위험 모드로 띄우려는 시도를 거부한다.

**자식 `claude`가 cwd를 프로젝트 루트로 되돌린다.**
`Set-Location`으로 폴더를 바꿔도 자식이 cwd를 부모 워크트리 루트로 리셋한다. 파일은 절대경로로 지정한다.

**`claude -p`가 stdin을 3초 기다린다.**
`$null | & claude -p ...`로 빈 stdin을 파이프하면 기다리지 않는다.

**cmd에서 인용 경로 끝의 역슬래시가 따옴표를 먹는다.**
`/Fo:"...\obj\"`처럼 역슬래시로 끝나는 인용 경로는 닫는 따옴표를 이스케이프해 명령줄 전체가 깨진다(cl이 `D8003 소스 파일 이름이 없습니다`로 죽는다). 해당 디렉터리로 이동해 상대 경로를 쓰거나 끝 역슬래시를 뺀다.

## 배포 (토이에서 얻은 것)

**토이(공개 대상)와 스킬(내부 인프라)을 같은 브랜치에 커밋하지 않는다.**
내부 GPT 도구가 공개 repo에 섞이면 auto-mode 분류기가 push를 차단한다.

**create-tauri-app이 Windows 사용자명을 identifier에 박는다.**
`com.<한글 사용자명>.…`이 되어 `generate_context!`가 non-ASCII identifier를 거부할 수 있다. ASCII reverse-DNS로 교정한다.
