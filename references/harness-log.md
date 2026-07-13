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

### 사이클 4 — Matrix 스킨 위임 경계 실험 (2026-07-14)
- **물음(사용자)**: GPT에게 어디까지 맡겨도 되나. 스킨 헌법만 주면 slop이 나오는지부터
  시작해 명세를 계단식으로 좁혀, 어디까지 줘야 잡부가 무너지지 않는지 재기. "이걸 하면
  된다"가 아니라 "뭐가 안 되는지"를 하나씩 본다. **컨닝 방지**가 제약 — 제시하지 않은
  기존 Qt 구현을 GPT가 보면 몰래 베낀다(reward hacking).
- **설계**: 같은 대상(Matrix 필터 카드 행 canvas 함수), 같은 모델(luna xhigh) 고정, 명세
  수준만 L0~L4로 계단화. 클린룸은 오라클 릴레이(`tools=[]` → GPT 파일 접근 원천 봉쇄).
  실제 Qt 구현·토큰은 Claude만 정답지로 보고 채점·L3/L4 명세 재료로만 씀. 채점은
  node-canvas 헤드리스 PNG + 정적 린트, 판정 기준은 스킨 헌법의 불변규칙/금지항목.
- **실행**: 릴레이 5개를 병렬 background로. `gpt-relay.ps1`은 `[Console]::Out.Write`로 답을
  내보내는데 이건 pwsh `1>` 파일 리다이렉트를 우회한다 → 답은 background 태스크의 `.output`
  파일에 캡처됨(함정, pitfalls 승격 후보).
- **결과 요약**:
  - **L0(이름만) = 유일한 slop.** 예쁘지만 헌법 정면 위반 — 게인 값 앰버 채색(색 배급제),
    LED 글로우(shadowBlur), 알약 배지(라운드 0), 곡선 그래프+피크 원, 좌표 없음("01/SLOT"),
    크기 위계. '발광 플러그인' prior로 회귀.
  - **L1(헌법만) = slop 아님.** 오히려 가장 풍부 — 헌법의 노브 Annex K까지 읽어 LED 링
    노브(gain 바이폴라 중앙 점등, freq/Q 유니폴라)를 구현. 정적 린트의 곡률·그림자 플래그는
    오탐(노브 곡선=합법, shadowBlur=0=끄는 코드).
  - **L2(+부품) = 의도 정합.** 노브→값셀 수렴, 단색, 좌표 박스.
  - **L3(+토큰) = 픽셀 정확.** 실측 색·치수.
  - **L4(+순서) = 결정론.** L3 대비 품질 향상 미미(한계효용 낮음).
- **교훈 → 신규 `references/delegation-boundary.md`로 승격**:
  1. **slop을 막는 건 명세량이 아니라 철학 문서(헌법)의 존재.** L0→L1 도약이 유일한 상전이.
     픽셀 명세보다 철학 한 장에 먼저 투자하라.
  2. **명세 층위마다 막는 실패가 다르다**: 헌법=slop / 부품=의도정합 / 토큰=픽셀 / 순서=결정론.
     이전 로그의 "선명세가 비용"을 정교화 — 선명세엔 계단이 있다.
  3. **GPT 실패 = '못 그림'이 아니라 '다른 미감으로 그림'**(훈련 분포 평균으로 회귀).
  4. **디자인 위임 vs 렌더 번역은 이분법 아닌 연속체** — "얼마나 강한 사전을 줬나"가 축.
  5. **컨닝 봉쇄엔 릴레이(tools=[])가 필수.** worker는 Grep으로 정답을 훔쳐본다.
  6. **정적 린트는 스크리닝, 육안 PNG가 판정**(shadowBlur=0·합법 곡선 오탐).
- **후속 축 — 헌법 압축(사용자 지시)**: matrix.md는 규범과 판례(이슈#·AR/M라운드·되돌린 히스토리)가
  섞여 있다. 헌법의 압축 수준만 바꿔 재측정 — C0(이름)/C1(정체성 서술)/C2(불변 규칙만, 판례 제거)/
  C3(전문=L1). 결과(정정): **C2는 C3와 동등하지 않았다** — 노브를 축약하며 구체 규칙(14/15
  세그먼트·디텐트·px)을 판례로 오인해 버려 IC칩 비슷한 실사용 불가 렌더가 됨. C1은 노브를 아예 잃음
  (값셀만). C3만 제대로 된 LED 링. 입력 토큰은 C3~10,600→C2~2,000이나 **압축 대가는 규범 오제거
  위험**. 판례(이슈#·히스토리)와 구체 규범(렌더 규칙)은 겉보기 같아 가르기 어렵다 — rich 컴포넌트가
  먼저 깨진다. 처음에 'C2≈C3'로 본 건 나의 관대한 오판, 사람 육안이 반박. → delegation-boundary.md
  발견 5(정정판).

### 사이클 5 — 백엔드 로직 safe-Rust 동등성 실험 (2026-07-14, 사용자 지시)
- **물음**: EQ APO 백엔드 중 safe Rust로 짤 수 있는 순수·복잡 조각 10개(T1~T10)를, 명세 상세도를
  R1(한두 줄)→R4(세부 동작)로 올려가며 "cargo build + clippy -D warnings + C++ 동등 골든 테스트" 세
  게이트를 모두 통과하는 임계 R을 잰다. 하나라도 터지면 실패. 컨닝 봉쇄(릴레이 tools=[], C++ 원본
  미노출; Claude만 정답지로 골든 작성).
- **인프라**: 조각별 독립 crate(clippy 격리), judge.ps1(코드블록 추출→모듈 심기→build/clippy/test),
  골든은 공식/차분방정식/왕복 불변식으로 독립 산출. 함정: `[Console]::Out.Write`는 pwsh `1>`를 우회해
  답이 background `.output`에 캡처됨(pitfalls 후보). PowerShell 변수는 대소문자 무구분($J=$j 충돌).
- **결과(10/10)**: 모든 조각 임계 **R4**. R1~R3만으로 통과한 조각 0. luna R4 동등성 10/10 중 clippy까지
  통과 7, 미달 3(T1·T2·T5, 전부 Rust 1.97 신규 manual_* 린트)→SOL high 재시도 전부 PASS.
- **SOL R1~R3 재시도(T4·T7·T8·T9)**: 전부 luna와 동일 지점 실패. T4는 R2·R3까지 줘도 실패.
- **교훈 → delegation-boundary.md 백엔드 절 승격**: (1) 표준 알고리즘은 R1로도 되나 도메인 특례(특례·
  규약·공식·이스케이프·되감기)는 R4에서만. (2) 명세 필요량=도메인 특유도(복잡도 아님: T1 최복잡 6/7 vs
  T9 단순 1/6). (3) 검증은 이중 게이트—동등성('무엇')+관용성('어떻게'). (4) 지능은 관용성을 메우나(SOL이
  clippy 뚫음) 도메인 사실은 티어·긴 설명으로도 못 메움(컨닝 봉쇄 정당성). 상세 표=backend-exp/results.md.
