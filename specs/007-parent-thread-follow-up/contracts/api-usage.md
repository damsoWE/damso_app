# API 사용: 학부모 스레드·이어서 묻기·알림 설정

계약: 앱 사본 `docs/api/openapi.yaml` api-v0.11. 모든 요청은 Authorization(학부모 토큰)을 `AuthInterceptor`가 붙인다. 오류는 data 계층에서 `AppException`으로 바꾸고, 화면은 서버 `message`만 보인다.

## ParentInquiryRepository (inquiry 기능)

| 메서드 | 엔드포인트 | 성공 | 오류 분기 |
|---|---|---|---|
| `detail(inquiryId)` (확장) | `GET /api/v1/parent/inquiries/{inquiryId}` | 200 `ParentInquiryDetail` — content·followUps·answers까지 해석 | 401 갱신(인터셉터) · 403/404 서버 안내(스레드 화면 오류 상태) · 형식 오류 → 일반 안내 |
| `submitFollowUp({inquiryId, content, idempotencyKey})` (새) | `POST /api/v1/parent/inquiries/{inquiryId}/follow-ups` · 헤더 `Idempotency-Key` · body `{content}` | 201 `FollowUpSubmitted` | 400 `INVALID_INPUT`(fieldErrors) · 403 · 404 · 409 `NO_HOMEROOM_TEACHER`·`CONFLICT`·`THREAD_CLOSED` · 429 + `Retry-After` → 대기 |

- `inquiryId`는 스레드 루트 ID(처음 문의). 라우터가 UUID만 통과시킨다(PR #25).
- 409 `CONFLICT` 가운데 "다른 요청이 같은 문의를 처리하는 중"은 같은 키로 다시 보내도 된다 — 키를 유지하므로 사용자가 다시 누르면 된다.
- 기존 `MockParentInquiryRepository.submitFollowUp`은 호출 시 "이 실행에서는 지원하지 않습니다" `AppException`(R9).

## ParentNotificationRepository (notification 기능, 새)

| 메서드 | 엔드포인트 | 성공 | 오류 분기 |
|---|---|---|---|
| `getSettings()` | `GET /api/v1/parent/notification-settings` | 200 `{answerNotifyEnabled}` (설정 없으면 true) | 401 갱신 · 그 밖 서버 안내 + 다시 시도 |
| `saveSettings(enabled)` | `PUT /api/v1/parent/notification-settings` body `{answerNotifyEnabled}` | 200 같은 모양 → 확정 | 400 · 401 갱신 · 그 밖 서버 안내, 원래 값으로 되돌림 |

provider는 실서버 구현만 고른다(mock 분기 없음, R9).

## NotificationRepository (기존, 학부모도 사용)

| 메서드 | 엔드포인트 | 이 기능에서 |
|---|---|---|
| `registerDevice({token, platform})` | `PUT /api/v1/me/devices` | 학부모 로그인·토큰 갱신 때도 호출(R8) |
| `unregisterCurrentDevice()` | `DELETE /api/v1/me/devices/current` | 학부모 로그아웃·탈퇴 때도 호출(PR #25 흐름) |

## 기기 알림 데이터 (서버 → 앱)

`data.kind = "ANSWER"`, `data.inquiryId = <스레드 루트 UUID>`. 제목·본문은 서버 고정 문구("답변이 도착했습니다" / "문의 상세에서 답변을 확인해 주세요."). 앱은 저장·로그하지 않는다.
