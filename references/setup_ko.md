# 셋업 (개요)

실행 도구(릴레이·프록시·런처·에이전트)는 이 저장소 **소스에 없다**. 릴리즈 에셋 `gpt-build-harness-tools.zip`에 들어 있으며, 설치 스크립트가 Claude Code / Codex / Claude 앱에 배치한다. codex 백엔드를 호출하는 구체적 프로토콜·엔드포인트는 그 도구 안에 담겨 있고, 이 문서는 방법론만 다룬다.

## 인증 / 과금
도구는 로컬의 ChatGPT **구독 토큰**(codex 로그인 캐시)을 쓴다. api.openai.com 종량 과금이 아니라 구독 쿼터를 소비한다. 토큰은 실행 중인 ChatGPT 데스크톱 앱이 주기적으로 갱신한다. 인증이 만료되면 데스크톱 앱을 실행해 로그인 세션을 되살린다.

## 네 형태 (요약)
- **오라클 릴레이**: 도구 없는 추론. 어느 세션에서나 즉시 된다. 손은 Claude가 쥔다. 순수 소견 전용.
- **직접 워커(`gpt-agent.ps1`)**: 자식 claude로 GPT가 도구를 쥔다. 웹 검색도 쥔다(프록시가 codex 웹 검색으로 실행한다). 어느 세션에서나(브릿지 포함) 된다. 일반 세션의 기본 잡부.
- **워커 서브에이전트**: GPT가 직접 도구를 쥔다. 프록시 세션 전용(혼합 세션 `gpt-cc -Main claude` 포함). `gpt-worker`가 Daybreak, `astra-worker`가 ASTRA다.
- **메인 루프 모델**: 세션 전체를 GPT로 돌린다. 윈도우는 런처가 모델에 맞춰 건다. Daybreak Blue는 500k 자동압축, ASTRA는 1M 윈도우에 860k 압축이다.

자세한 판단은 `three-forms_ko.md`.

## 모델 운용
SKILL_ko.md의 모델 방침(Model policy)을 따른다. 요약하면 모델은 둘이다. `gpt-daybreak-blue`(GPT-5.6 Sol의 튜닝판, 슬러그 2026-08-19 실측 확인)가 백엔드 노동을 하고, `gpt-6-astra`(GPT-6 Astra, 슬러그 2026-09-05 실측 확인)가 화면과 i18n 카탈로그, 그리고 Daybreak가 막히는 문제를 맡는다. effort는 high가 기본이자 스윗스팟이고, 그 위로 `xhigh`와 `max`가 있다. Daybreak에서 max는 절망적으로 어려운 문제 전용이고 ASTRA의 두 단은 아직 측정하지 않았다. `low`와 `medium`은 쓰지 않는다. 릴레이·프록시·런처·직접 워커의 기본값이 전부 daybreak-blue/high다. ASTRA는 프록시의 `version` 헤더까지 최신이어야 하므로 codex CLI를 갱신해 둔다.

## 설치
릴리즈에서 도구 zip을 받아 install 스크립트를 실행한다. 대상별 배치 위치와 절차는 README의 '설치'를 따른다. 도구의 상세 동작은 설치된 스크립트의 주석에 있다.
