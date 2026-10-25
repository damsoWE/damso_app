# [제안 · 미확정] 가입 전 초대 코드 확인 API

**상태**: 백엔드 요청 대기(2026-10-25 결정, 요청 문구는 대화에서 전달). `docs/api/openapi.yaml`에 반영되고 새 `api-vX.Y` 태그가 나오면 이 문서를 지우고 [api-usage.md](./api-usage.md)의 ⏳ 표시를 걷는다.
**근거**: spec FR-019 (Option C) · research R5

## 제안 형태

```yaml
/api/v1/auth/invite-codes/verify:
  post:
    tags: [auth]
    security: []
    requestBody:
      content:
        application/json:
          schema:
            type: object
            properties:
              inviteCode: { $ref: '#/components/schemas/InviteCodeInput' }
            required: [inviteCode]
            additionalProperties: false
    responses:
      '200':
        content:
          application/json:
            schema:
              type: object
              properties:
                role: { type: string, enum: [TEACHER, PARENT] }
              required: [role]
      '400': INVALID_INPUT · INVALID_INVITE_CODE (사유 구분 없음)
      '429': TOO_MANY_ATTEMPTS + Retry-After
```

- 코드를 소모하지 않는다. `signup`은 지금처럼 다시 검증한다.
- 학급·학생 이름 등 대상 정보는 돌려주지 않는다.

## 백엔드 결정 대기

1. 실패 횟수 기준 — 이 단계에는 이메일이 없다. 이메일을 함께 받을지(그러면 F1-1에 이메일 입력 추가) 다른 기준을 쓸지.
2. 코드 존재 여부 노출 검토.

## 앱 쪽 처리 (확정 전)

- mock: 데모 코드로 역할·오류·잠금을 돌려준다([quickstart](../quickstart.md)).
- 실서버: 호출하지 않고 `null`(역할 모름) → 중립 문구의 계정 만들기 화면 → 코드 검증은 `signup` 응답으로.
- 확정되면 `AuthRepositoryImpl.checkInviteCode`만 바꾼다. 요청에 이메일이 추가되면 F1-1 화면·ViewModel도 바꾼다.
