# 함정 (검증된 것)

GPT 잡부를 붙여 굴리며 실제로 밟은 함정들. 근거와 함께 둔다. SKILL.md 요약의 원본.

## 릴레이 형태

**릴레이는 PowerShell 도구(pwsh 7)로만 실행한다.**
Bash 도구가 부르는 `powershell.exe`는 Windows PowerShell 5.1이고, 그 WinINET 스택은 이 머신에서 chatgpt.com에 막혀 무한 대기한다. `gpt-relay.ps1`은 `-SkipHttpErrorCheck`(pwsh 7 전용)도 쓴다. `gpt` 에이전트 정의가 PowerShell 도구를 강제하는 이유.

**릴레이 반환 코드의 HTML 엔티티 이스케이프.**
`gpt` 릴레이 서브에이전트의 답이 에이전트 결과(task-notification)로 전달될 때 코드의 `<` `>` `&`가 `&lt;` `&gt;` `&amp;`로 이스케이프된다. Rust `Option<f64>`, `&str`, `->`, `collect::<Vec<_>>()`가 전부 깨진 채로 온다. **파일로 심기 전 복원 필수.** 원인은 GPT/릴레이가 아니라 결과 전달 계층의 HTML 이스케이프 — `gpt-relay.ps1` stdout을 직접 파일로 받으면 안 생긴다. 큰 코드는 육안 복원이 위험하니, 코드 블록만 뽑아 자동 unescape하거나 워커 형태(프록시 세션에서 GPT가 파일에 직접 쓰기)를 고려.

**릴레이는 도구 없는 오라클이다.**
GPT는 파일을 못 읽고 못 쓴다. 맥락(기존 코드, 스펙, 로그)을 프롬프트 본문에 자기완결로 붙여야 한다. 반환물의 적용·빌드·검증은 Claude가 한다. 이게 house rule(프론트/CICD 게이트)과 맞물린다.

## 프록시 / 워커 / 메인 형태

**워커·메인 형태는 프록시 세션 전용이다.**
`gpt-worker` 서브에이전트나 메인 모델 GPT는 `ANTHROPIC_BASE_URL`이 `gpt-proxy.mjs`를 가리켜야 작동한다. 일반 Claude 세션(정상 Anthropic)에서 `gpt-5.6-*` 모델을 부르면 진짜 Anthropic으로 가 404. "하네스를 굴리는 세션"과 "GPT가 실행되는 세션"을 구분하라. 일반 세션에서 GPT를 붙이는 정석은 릴레이.

**codex responses는 `max_output_tokens`를 거부한다.**
프록시가 Anthropic `max_tokens`를 그대로 넘기면 HTTP 400 `Unsupported parameter: max_output_tokens`. 전달하지 말 것(codex가 자체 관리).

**자동 캐시는 `session_id` 헤더에 묶인다(prefix 아님).**
같은 대용량 접두라도 session_id가 매 요청 랜덤이면 캐시 히트 0 — 매 턴 시스템 프롬프트를 풀차지한다. 프록시가 대화별 **안정 session_id**(system+첫 메시지 해시)를 써야 98% 히트. usage의 `cached_tokens`→Anthropic `cache_read_input_tokens`로 매핑해 가시화.

## 에이전트/실행 환경

**`--dangerously-skip-permissions`는 auto mode 분류기가 차단한다.**
부모 Claude 세션 안에서 자식 `claude`를 위험 모드로 띄우는 걸 "Create Unsafe Agents"로 거부한다. 검증은 `--allowedTools "Read"` 같은 읽기 전용 화이트리스트로 우회 아닌 정공법.

**자식 `claude`가 cwd를 프로젝트 루트로 되돌린다.**
`Set-Location`으로 작업 폴더를 바꿔도 자식 claude가 cwd를 부모 워크트리 루트로 리셋해 상대경로 파일을 못 찾는다("Shell cwd was reset to ..."). 파일은 절대경로로 지정.

**`claude -p`가 stdin을 3초 기다린다.**
"no stdin data received in 3s" 경고 후 진행하지만, 확실히 하려면 `$null | & claude -p ...`로 빈 stdin을 파이프.

## Tauri 스캐폴딩 (토이 특정)

**create-tauri-app이 Windows 사용자명을 identifier에 박는다.**
`com.<한글 사용자명>.eqxt-tauri`가 되어 `generate_context!`가 non-ASCII identifier를 거부할 수 있다. `tauri.conf.json`의 identifier를 ASCII reverse-DNS로 교정.
