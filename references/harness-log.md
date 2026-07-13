# 하네스 형성 로그

토이: EqualizerAPO-XT의 Qt Editor를 Tauri 웹뷰로 포팅. **목적은 결과물이 아니라 하네스 스킬을 벼리는 것.** 절대 실사용 안 함. 격리 브랜치에서만 굴린다.

시간순으로 쌓는다. 교훈이 여물면 `pitfalls.md` / `three-forms.md` / `orchestration.md`로 승격한다.

---

## 세션 1 (2026-07-13)

### 셋업 결정
- **격리**: `archive/tauri-harness-toy` 브랜치를 main(6a4d0d9)에서 분기하고, `.claude/worktrees/tauri-harness-toy`에 **별도 워크트리**로 체크아웃. 현재 작업 워크트리(eqxt-bridge)는 다른 브랜치에 locked이라 건드리지 않는다. main 불침범.
- **작업 산출물 위치**: 워크트리 안 `tauri-port/`(앱), `harness-skill/`(형성 중 스킬). 스킬이 여물면 별도 repo로 추출해 MIT 배포.
- **Rust 미설치** 확인 → 사용자가 "실빌드까지" 선택 → rustup(minimal, per-user)로 설치. MSVC 링커는 기존 VS 빌드툴로 충족.

### 교훈 (형성 중)

**1. "하네스를 굴리는 세션"과 "GPT가 실행되는 세션"은 다르다.**
이 오케스트레이터 세션은 정상 Anthropic(프록시 base_url 아님)으로 돈다. 그래서 방금 만든 `gpt-worker`(직접 도구를 쥐는 서브에이전트)를 여기서 부르면 `gpt-5.6-*` 모델이 진짜 Anthropic으로 가 404가 난다. 워커/메인 형태를 쓰려면 `gpt-cc.ps1`로 띄운 프록시 세션이어야 한다. → 일반 세션에서 GPT 잡부를 붙이는 정석은 **오라클 릴레이**(`gpt` 에이전트, 어디서나 pwsh로 직접 호출)다.

**2. 릴레이 오케스트레이션이 house rule과 맞물린다.**
Tauri 포팅은 프론트엔드다. house rule은 "프론트 설계를 GPT에 맡기지 말 것". 릴레이 형태는 GPT가 도구 없는 오라클이라, Claude가 설계·적용·검증을 반드시 쥔다. 게이트가 구조적으로 강제된다. 워커 형태(GPT 자율)는 이 게이트가 없어 프론트에 부적합 — 백엔드 로직 잡부로만.

**3. 토이의 범위는 슬라이스로 좁힌다.**
Editor는 소스 300+, 필터 GUI 20여 종, 스킨 5개로 방대하다. "거의 등가"를 전부 재현하려 들면 하네스 연습이 아니라 대장정이 된다. 대표 슬라이스로 좁혔다 — config.txt 로드/저장, 필터 목록 파싱, Preamp/BiQuad/GraphicEQ 편집, 주파수 응답 그래프. 이만큼이면 "설계(Claude)→구현 위임(GPT)→적용·빌드·실패 재질의"의 사이클을 여러 바퀴 돌리기에 충분하다.

### 사이클 1 — config.txt 파서 (GPT 위임)
- **분담**: 인터페이스(FilterLine 모델 + load/save_config_text command)는 Claude가 프롬프트에 못박고, 파싱/직렬화 구현 노동을 GPT(Luna xhigh)에 위임. 프론트 UI(파싱→카드→직렬화 왕복)는 Claude가 병렬로 작성. house rule 실연.
- **GPT 산출물 품질**: config.rs 1벌 + 유닛 테스트 4개(round-trip, gain/Q 옵셔널, 소문자+인덱스, Raw/Comment 보존)를 스스로 붙여 반환. `f64::to_string`이 정수값에 `.0`을 안 붙이는 성질을 이용해 텍스트 round-trip까지 성립시킴 — 스펙을 정확히 못박으면 Luna가 백엔드 파서는 잘 짠다.
- **교훈 (승격 후보 → pitfalls)**: **릴레이 반환물의 HTML 엔티티 이스케이프.** `gpt` 릴레이 서브에이전트의 답이 task-notification 결과로 실려 올 때 코드의 `<` `>` `&`가 `&lt;` `&gt;` `&amp;`로 이스케이프된다(Rust `Option<f64>`, `&str`, `->`, `collect::<Vec<_>>()`가 전부 깨짐). **파일로 심기 전 복원 필수.** 원인은 GPT/릴레이가 아니라 에이전트 결과 전달 계층의 HTML 이스케이프 — 직접 `gpt-relay.ps1` stdout을 파일로 받으면 안 생긴다. 큰 코드일수록 육안 복원이 위험하니, 릴레이로 코드를 받을 땐 (a) 코드 블록만 뽑아 자동 unescape하거나 (b) 오라클에 "파일 경로에 직접 쓰지 말고 순수 텍스트로" 대신 워커 형태(프록시 세션)를 고려.
- **스캐폴딩 함정**: create-tauri-app이 Windows 사용자명을 identifier에 그대로 넣어 `com.<한글>.eqxt-tauri`가 됨 → `generate_context!`가 non-ASCII identifier를 거부할 수 있어 `com.eqxtxt.tauritoy`로 교정.

### 사이클 1 결과 — GREEN
`cargo test` 4/4 통과(round-trip, gain/Q 옵셔널, 인덱스, Raw/Comment 보존), 첫 빌드 1m01s. **GPT 파서가 첫 시도에 통과 — 재질의 루프는 이번엔 안 돌았다.** HTML 엔티티 복원과 identifier 교정만으로 됐다. 잘 못박은 스펙엔 릴레이 잡부가 정확히 응답한다. 재질의 루프의 실연은 더 까다로운 사이클(DSP 수학 등)에서 나올 것.

### push 정책 (사용자 지시 2026-07-13)
토이가 완성되면 archive 브랜치를 **push까지 하되 PR은 만들지 않는다(NO PR)**. "Tauri 사랑꾼이 주워다 쓰라"는 공개 보관 취지.

### 사이클 2 결과 — GREEN
주파수 응답(response.rs): SOL medium이 RBJ cookbook 계수(PK/LP/HP/BP/notch/AP/shelf) + 손으로 푼 복소수 나눗셈 + 로그 그리드 + 물리성질 테스트 3개를 반환. 심고 lib.rs 등록 후 `cargo test` 7/7(파서 4 + DSP 3) GREEN, 증분 6.75s. 프론트 그래프(Claude)는 canvas 로그축 ±24dB, 파싱 시 frequency_response 호출해 곡선 갱신.

**관찰(중요) — 두 사이클 모두 재질의 루프 0회.** Luna 파서도 SOL DSP도 첫 시도 GREEN. 잘 정의된 표준 알고리즘(파서, RBJ)은 릴레이 잡부가 스펙만 정확하면 1샷으로 낸다. 적용 쪽 잔손질(HTML 엔티티 복원, identifier 교정, lib.rs 등록)만 Claude가 했다. 재질의 루프는 스펙이 모호하거나 프로젝트 특수 규약(빌드 플래그, 사내 API)이 얽힐 때 나올 것 — 토이의 교과서적 조각들에선 안 나온 게 오히려 하네스에 대한 데이터다. 시사점: **위임 프롬프트에 인터페이스를 못박는 투자(Claude가 타입/시그니처/테스트 기준을 명세)가 재질의 횟수를 0으로 눌렀다.** 하네스의 비용은 재질의가 아니라 선(先)명세에 있다.

### 사이클 완료 + 배포 (2026-07-13)
- 토이 통합 빌드 GREEN(`tauri build --no-bundle`, release exe 9MB, 1m18s). 유닛 7/7.
- **토이 push 함정**: 스킬과 섞어 push하려다 auto-mode classifier가 차단 — 내부 GPT 도구(gpt-proxy/relay)가 공개 repo에 섞였기 때문. **교훈: 토이(공개 대상)와 스킬(내부 인프라)을 같은 브랜치에 커밋하지 말 것.** 분리해 `eqxt-tauri`만 담은 `archive/tauri-toy`를 main 기준 새 브랜치로 push(NO PR). harness-skill은 로컬 archive 브랜치에만 남긴다.
- **스킬 배포 방식(사용자 지시)**: 방법론은 public MIT, codex 비공개 responses API를 직접 호출하는 도구는 소스에 노출하지 않고 **릴리즈 에셋(zip)으로 배포**("모두 배포하되 보여주지 않음"). public 소스엔 codex 엔드포인트/프로토콜 세부를 넣지 않는다. 릴리즈 에셋은 URL로는 받을 수 있으나 코드 브라우징엔 안 드러남.

### 배포 (완료)
- 별도 repo(public MIT) `github.com/115dkk/gpt-build-harness`: 방법론(SKILL.md/references, setup 민감부 제거판)만.
- 릴리즈 `v0.1.0`의 `gpt-build-harness-tools.zip`: 도구(gpt-relay/proxy/cc, agents) + 완전판 문서 + install 스크립트.
- 설치 3종: Claude Code(~/.claude, 검증), Codex(~/.codex/skills+AGENTS.md, 검증), Claude 앱(claude-app-skill.zip 수동).

### 사이클 3 — Rack 스킨 통째 Tauri 목업 (2026-07-13)
- EqualizerAPO의 **Rack 스킨**(하드웨어 랙 룩)을 Tauri 웹뷰로 통째 재현. 5스킨 중 가장 복잡 — 브러시드 faceplate+sheen, 랙 이어/machined groove, 슬롯 각도 제각각인 스크류, halo+specular dome LED, 270° 스윕 노브(패널 틱·bipolar 각인·중앙 detent), 인광 스코프(겹쳐칠 글로우), 각인 텍스트, patchbay jack, VST 황동 명판, 빈 베이 스텐실.
- **분담**: Rack의 시각 디자인은 이미 Qt QPainter로 확정돼 있다. Claude는 레이아웃·색 토큰·CSS 강철 캐비닛을 확정하고, GPT(SOL high)에는 **확정된 Qt 페인터를 canvas 2D로 렌더 번역**하는 것만 위임. rack-chrome.js(faceplate/ears/screws/LED/jack/명판)와 rack-controls.js(knob/scope)를 **2병렬 위임**. 색·alpha·gradient stop·정수 해시(Math.imul)까지 충실.
- **GUI 없이 시각 검증**: (1) node --check로 ESM 문법, (2) 스텁 canvas Proxy로 렌더 함수 스모크(모든 kind/finish/state 무예외), (3) **node-canvas 헤드리스로 전체 랙 PNG 렌더** → dark/cream 두 finish 실측. `tauri build`도 GREEN(24s). 실제 WebView 창은 못 띄웠지만 렌더 정확성을 PNG로 확인.
- **결과**: 두 finish 모두 rack 하드웨어 충실 재현(faceplate sheen/brushing, LED halo, 노브 포인터/amber 중앙 detent, 인광 beam, disabled 유닛 powered-down film, GRAPHIC 세로 각인). preview PNG는 eqxt-tauri/preview/.
- **교훈(승격 → orchestration)**:
  1. **"디자인 위임"과 "렌더 번역"은 다르다.** 확정된 디자인(Qt 페인터)을 다른 런타임(canvas)으로 옮기는 건 프론트라도 GPT 위임이 정당하다 — house rule은 디자인 결정을 막는 것이지 구현 번역을 막는 게 아니다. 이게 프론트 무거운 작업에서 GPT를 쓰는 정답.
  2. **GUI 없는 시각 검증**: 렌더 함수를 순수하게(ctx만 받게) 유지하면 스텁/헤드리스 canvas로 창 없이 PNG로 시각을 확인할 수 있다. computer-use 불필요.
  3. 병렬 위임(chrome/controls 동시)으로 대기 시간 겹침 — 하네스를 더 빨리 굴린다.
