# gpt-build-harness

OpenAI GPT-5.6을 ChatGPT **구독 쿼터**로(별도 API 과금 없이) 잡부로 부려, 큰 구현·포팅을 저비용으로 굴리는 Claude Code 스킬. Claude가 설계·적용·검증을 쥐고, GPT가 구현 노동을 낸다.

## 무엇인가
GPT를 세 형태로 세운다.
- **오라클 릴레이** — 도구 없는 추론. 어느 세션에서나 즉시. Claude가 맥락을 프롬프트에 담아 주고 반환 코드를 적용한다.
- **워커 서브에이전트** — GPT 자체가 서브에이전트의 LLM이라 파일을 직접 만진다(프록시 세션 전용).
- **메인 루프 모델** — Claude Code 전체를 GPT로 돌린다.

방법론은 [SKILL.md](SKILL.md)와 [references/](references/)에 있다. 프론트엔드 디자인·CI/CD는 GPT에 맡기지 않는다(감각·안정성 문제) — 그 게이트를 구조로 강제한다.

## 설치
실행 도구(릴레이·프록시·런처·서브에이전트)는 이 소스 트리에 없다. 최신 **[Releases](../../releases)**에서 `gpt-build-harness-tools.zip`을 받아 안의 설치 스크립트를 실행한다.

- **Claude Code (전역)** — `install/install-claude-code.ps1`. `~/.claude/skills/`, `~/.claude/tools/`, `~/.claude/agents/`에 배치한다. 새 세션부터 `gpt` / `gpt-worker` 서브에이전트와 스킬이 잡힌다.
- **Codex (전역)** — `install/install-codex.ps1`. Codex의 전역 지침 위치에 스킬 요약을 배치한다.
- **Claude 앱 (claude.ai)** — `install/claude-app-skill.zip`을 claude.ai의 스킬(capabilities) 업로드에 넣는다.

도구는 로컬 ChatGPT 구독 로그인(codex 인증 캐시)을 쓴다. 자기 구독·도구를 준비해야 한다.

## 어디서 왔나
이 스킬은 Qt 데스크톱 앱(Equalizer APO의 에디터)의 한 조각을 Tauri 웹뷰로 포팅하는 토이를 굴리며 벼려졌다. 그 형성 과정과 밟은 함정은 [references/harness-log.md](references/harness-log.md)에 시간순으로 남아 있다.

## 라이선스
MIT. [LICENSE](LICENSE) 참조. 이 저장소는 방법론 문서이며, 구독·도구는 사용자가 준비한다.
