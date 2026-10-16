---
description: 백엔드 API 명세(openapi.yaml)를 지정한 태그 기준으로 받아 오고, 바뀐 점과 프론트에서 고칠 곳을 요약한다
argument-hint: <태그, 예: api-v0.1>
allowed-tools: Bash(bash scripts/fetch-openapi.sh:*), Bash(npx -y @redocly/cli@1.34.5 lint:*), Bash(git diff:*), Bash(git status:*), Bash(gh auth status:*), Read, Grep, Glob
---

백엔드가 공지한 태그 `$ARGUMENTS` 기준으로 API 명세를 받아 온다. 이 명령은 **파일을 받아 오고 요약만** 한다. 커밋·코드 수정은 하지 않는다.

## 1. 확인

- `$ARGUMENTS`가 비어 있으면 멈추고 "받을 태그를 알려 주세요 (예: `/fetch-api api-v0.1`)"라고 묻는다.
- `git status --short docs/api/openapi.yaml`로 사본을 직접 고친 흔적이 있는지 본다. 있으면 멈추고 알린다 — 이 파일은 사본이라 직접 수정하지 않는다.
- `gh auth status`가 실패하면 멈추고 안내한다: 백엔드 레포가 비공개라 `! gh auth login`으로 먼저 로그인해야 한다.

## 2. 받기

```bash
bash scripts/fetch-openapi.sh $ARGUMENTS
```

실패하면(태그가 없음, 권한 없음 등) 오류 내용을 그대로 보여 주고 멈춘다. 기존 파일은 그대로 남는다.

## 3. 형식 검사

```bash
npx -y @redocly/cli@1.34.5 lint docs/api/openapi.yaml
```

오류가 있으면 백엔드 담당에게 알려야 한다고 안내한다. 경고 중 `no-unused-components`(공통 스키마)는 정상이다.

## 4. 바뀐 점 요약

`git diff -- docs/api/openapi.yaml`을 읽고 한국어로 요약한다. 처음 받는 경우(이전이 빈 사본)는 전체 내용을 요약한다.

| 구분 | 적을 내용 |
|---|---|
| API | 새로 생긴 / 바뀐 / 사라진 엔드포인트 (메서드·경로·인증 필요 여부) |
| 요청·응답 | 추가·삭제·이름 변경된 필드, 필수 여부·타입 변경 |
| 에러 | 새 에러 코드 (`ErrorCode` enum 변경) |
| 버전 | `info.version` 이전 → 이후 |

## 5. 프론트에서 고칠 곳

`lib/features/*/data`, `lib/features/*/domain`을 검색해 영향받는 파일을 목록으로 보여 준다. 고치지는 않는다.

mock에 아래 케이스가 빠져 있으면 함께 알린다 (정상 응답만 넣지 않는다):
- 401 `UNAUTHORIZED` (토큰 만료 → 갱신)
- 403 `FORBIDDEN` (남의 문의)
- 정제 진행 중 → 완료 상태 전이
- "원문 확인 필요" (정제 실패)
- 긴급 문의 표시

## 6. 마무리

마지막 줄에 다음 할 일 하나를 적는다. 예: "변경을 확인했으면 `docs/api/openapi.yaml`을 커밋하세요 (커밋 메시지 예: `chore: API 명세 api-v0.1 반영`)."
