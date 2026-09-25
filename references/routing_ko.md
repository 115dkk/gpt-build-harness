> `references/routing.md`의 한국어 역본이다. 모델이 읽을 때 토큰이 훨씬 덜 드는 영어를 정본으로 삼으며, 한국어 역본은 저장소에만 두고 설치하지 않는다.

# 라우팅

예전 `setup.md`와 `three-forms.md`를 대체한다. GPT 잡부를 부르는 방식은 더 이상 네 가지가 아니다. 라우터 하나와 호출 방식 하나로 통일했다.

## 구성 요소와 위치

| 구성 요소 | 위치 | 하는 일 |
|---|---|---|
| 라우터 | 백그라운드 서비스, 127.0.0.1:8790 | `api.anthropic.com` 연결을 받아 처리한다. 매핑한 모델은 해당 제공자에게 보내고, 나머지는 바이트 하나 바꾸지 않고 통과시킨다. |
| 연결 설정 | `~/.claude/settings.json`, `env.HTTPS_PROXY`와 `env.NODE_EXTRA_CA_CERTS` | 키는 둘이다. 모든 Claude Code 프로세스가 이 값을 읽으므로 어느 세션에서나 라우터를 거치며 런처가 필요 없다. |
| 라우터 설정 | `~/.clauderipple/config.json` | 제공자, 모델, `gpt-` 직접 라우팅 규칙과 `/model` 항목을 정의한다. mtime이 바뀌면 다시 불러온다. |
| 모델 목록 | `~/.claude/settings.json`, `availableModels`와 `modelPicker` | Claude Code에서 선택할 수 있는 모델을 정한다. |
| 인증 정보 | `~/.codex/auth.json` | ChatGPT 구독 토큰을 빌려 쓰며 라우터는 갱신하지 않는다. ChatGPT 데스크톱 앱이 갱신하므로, 인증이 만료되면 그 앱을 실행한다. |

api.openai.com에는 과금하지 않는다. 호출에는 구독 쿼터를 쓴다.

## 모델 요청을 제공자에게 보내는 방식

`direct`에는 접두사 `gpt-`를 chatgpt 제공자에게 연결하는 규칙 하나가 있다. 모델 id가 `gpt-`로 시작하면 id를 바꾸지 않고 그 제공자에게 보낸다. 따라서 새 슬러그를 추가할 때는 선택할 수 있게 등록하는 것 외에 설정을 바꿀 필요가 없다.

effort는 id에 `@high`, `@xhigh`, `@max`로 붙인다. 엔드포인트가 `ultra`를 거부하므로, 이 값은 그대로 보내지 않고 `max`로 바꾼다.

작업서 첫 줄의 표식은 그 호출에서만 모델과 effort를 바꾼다.

```
[[gpt: <model>@<effort>]]
```

짧은 이름 `daybreak`와 `astra`는 설정의 `aliases`에서 가져온다.

## 모델을 선택할 수 있게 등록하기

별개의 조건 둘을 모두 만족해야 한다.

- 라우터 설정의 `cli.extraModels`는 CLI가 받아 오는 부트스트랩에 항목을 추가한다. 그래야 `/model`이 그 id를 받는다. 에이전트 frontmatter의 id는 자동으로 수집한다. 라우터가 `~/.claude/agents/*.md`의 `model:`을 검색해 라우팅할 수 있는 id를 모두 추가한다.
- `settings.json`의 `availableModels`는 허용 목록이다. `/model`, `--model`, `ANTHROPIC_MODEL`, 서브에이전트 frontmatter, 스킬과 명령의 frontmatter에 적용한다. 목록 밖의 모델은 선택기에 표시하지 않는다.

**`availableModels`에 슬러그가 없어도 오류가 나지 않는다.** 서브에이전트를 알림 없이 Claude 모델로 실행한다. 워커의 결과물을 Claude가 쓴 듯하면 여기를 먼저 확인한다.

`modelPicker.options`는 각 항목의 표시 이름을 지정한다. `replaceBuiltInOptions`는 끈 채로 둔다. 그래야 Claude 모델 목록을 유지하고 새 모델이 나올 때 자동으로 반영한다.

선택기 항목의 `behavesAs`는 Claude Code가 모르는 id에, 이미 아는 모델의 클라이언트 처리 방식(프롬프트 프로파일, 지원 기능, effort 기본값)을 적용한다. 이 설정으로 이전 하네스의 `not a model this version recognizes` 경고를 막는다.

## 호출을 라우팅하지 못할 때

- **`clauderipple status`**로 연결 구성을 확인한다. **`GET /readyz`**는 200을 반환하거나, 요청이 모델에 도달하지 못하는 이유를 목록으로 적어 503과 함께 반환한다.
- **`clauderipple logs -f`**는 요청마다 한 줄을 출력한다. 요청자, 응답 모델, 입력·캐시·출력 토큰 수, 지연 시간과 상태를 표시한다. 로그 앞부분에 제공자의 오류 본문을 남기므로 401이나 400의 원인도 알 수 있다.
- 업스트림 연결이 거듭 실패하면 라우터가 스스로 종료하고 supervisor가 다시 실행한다. 재시작할 때는 진행 중인 호출을 끊지 않고 완료될 때까지 기다린다.
- Claude Code 자체가 작동하지 않으면 라우터부터 의심한다. 이제 Claude 요청을 포함해 모든 요청이 라우터를 거친다.

## 원래 상태로 되돌리기

`clauderipple uninstall`은 백업에서 `settings.json`을 복구하고 인증서와 예약 작업을 제거한다. 그다음 `availableModels`와 `modelPicker`를 제거하면 기본 Claude Code 상태로 돌아간다.
