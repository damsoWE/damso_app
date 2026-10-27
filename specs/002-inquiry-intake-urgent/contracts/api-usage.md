# API 사용 계약: 화면 ↔ Repository ↔ 엔드포인트 (F2)

**원본**: 백엔드 `main`의 `docs/api/openapi.yaml` `info.version: 0.5.0`(태그 전, [research R1](../research.md#r1-api-계약-기준--태그-전-원본-명세-050)). `api-v0.5` 태그가 나오면 `/fetch-api api-v0.5`로 앱 사본을 갱신하고 이 표와 비교한다. 이 문서는 앱이 **어떤 엔드포인트를 어디서 쓰는지**만 정한다. 요청·응답 스키마는 원본을 따른다.

모든 경로는 로그인 필요(Authorization 헤더, 401은 `AuthInterceptor`가 갱신·재시도). 남의 문의는 서버가 404(또는 403)로 거부하고, 앱은 서버 `message`만 보인다.

## inquiry(학부모) — `ParentInquiryRepository`

| 메서드 | 엔드포인트 | 성공 | 화면에서 분기할 오류 | 화면 |
|---|---|---|---|---|
| `submit(studentId, content, idempotencyKey)` | `POST /api/v1/parent/inquiries` + 헤더 `Idempotency-Key` | 201 → `InquirySubmitted` | `INVALID_INPUT`(본문 오류) · `NO_HOMEROOM_TEACHER`(409) · `CONFLICT`(409, 같은 키·다른 내용) · `TOO_MANY_ATTEMPTS`(429, `Retry-After`) · 404(연결 안 된 자녀) | F2-2 → F2-5 / F2-5a / F2-3 계열 |
| `list()` | `GET /api/v1/parent/inquiries` | 200 → `List<ParentInquirySummary>`(최신순) | — | F2-4, F2-1 문의 영역 |
| `detail(inquiryId)` | `GET /api/v1/parent/inquiries/{inquiryId}` | 200 → `ParentInquiryDetail`(타임라인·안내 코드) | 404 | F2-4 카드 펼침, 긴급 안내 다시 보기 |

- `Idempotency-Key`는 (자녀, 본문) 한 쌍마다 하나, 재시도 때 같은 값([research R3](../research.md#r3-중복-제출-방지--idempotency-key)).
- 같은 키 재전송도 201(처음 결과 그대로)이므로 앱은 결과를 구분하지 않는다.
- 상세 응답의 `content`·`followUps`·`answers`는 이번에 쓰지 않는다(F4).

## inquiry(교사) — `TeacherInquiryRepository`

| 메서드 | 엔드포인트 | 성공 | 분기할 오류 | 화면 |
|---|---|---|---|---|
| `list(page, size = 20)` | `GET /api/v1/teacher/inquiries?page=&size=` | 200 → `TeacherInquiryPage`(긴급 먼저, 그다음 최신순) | `FORBIDDEN`(담임 학급 없음) | F3-1, F3-4 |
| `detail(inquiryId)` | `GET /api/v1/teacher/inquiries/{inquiryId}` | 200 → 타임라인(본문 없음) | 404 | F3-5 |
| `content(inquiryId)` | `GET /api/v1/teacher/inquiries/{inquiryId}/content` | 200 → 원문. **열람 기록이 남고, 긴급은 첫 열람 때 `TEACHER_CONFIRMED`** | 404 | F3-5(긴급만) |

- `content`는 긴급 문의 상세를 열 때만, 화면당 1회 부른다([research R8](../research.md#r8-교사-긴급-문의-상세와-원문-열람)). 일반 문의에서는 부르지 않는다(F3 범위, 열람 기록 방지).
- 이번에 쓰지 않는 교사 경로: `/refinement`, `/refinement/retry`(F3) · `/answer-reviews`, `/answers`, `/close`(F4).

## notification — `NotificationRepository`

| 메서드 | 엔드포인트 | 성공 | 분기할 오류 | 화면 |
|---|---|---|---|---|
| `getSettings()` | `GET /api/v1/teacher/notification-settings` | 200 → `NotificationSettings`(설정 전: 일반 알림 켜짐, 응답 가능 시간 없음) | — | F3-8 |
| `saveSettings(settings)` | `PUT /api/v1/teacher/notification-settings` | 200 → 저장된 설정 | `INVALID_INPUT`(시작 ≥ 종료·요일 중복·형식, fieldErrors) | F3-8 |
| `registerDevice(token, platform)` | `PUT /api/v1/me/devices` | 204 | 실패는 화면에 보이지 않고 다음 계기에 다시 시도 | (교사 로그인·토큰 갱신) |
| `unregisterCurrentDevice()` | `DELETE /api/v1/me/devices/current` | 204(등록 없어도 204) | 실패 무시(FR-031) | 로그아웃·탈퇴 직전 |

- 학부모 알림 설정(`/parent/notification-settings`)은 F4에서 쓴다.
- 기기 등록·해제는 `DeviceRegistrar`(세션 변화 구독)가 부르고 화면은 부르지 않는다.

## 기기 알림 데이터 (서버 → 앱, FCM)

| 키 | 값 | 앱의 사용 |
|---|---|---|
| (알림 제목·본문) | 서버 고정 문구 | 시스템 알림 / 앱 안 배너에 그대로 표시 |
| `kind` | `URGENT` · `URGENT_REMINDER` · `GENERAL` · `GENERAL_DIGEST`(· `ANSWER`, F4) | 이동할 화면 고르기 |
| `inquiryId` | UUID(묶음 알림에는 없음) | 긴급 문의 상세 경로 |
| `count` | 묶음 건수 | 사용하지 않음(문구에 이미 들어 있음) |

근거: 백엔드 `notification.adapter.out.fcm.FcmPayload`, `PushMessage`(main 브랜치). 앱은 이 값을 저장·로그하지 않는다(FR-031c).

## 오류 코드 추가 (`lib/core/error/error_codes.dart`)

`NO_HOMEROOM_TEACHER`, `CONFLICT`(기존 공통 코드 확인), `NOT_FOUND`. 화면은 코드로 분기하지 않고 서버 `message`를 보이되, `NO_HOMEROOM_TEACHER`는 작성 화면에 머물고 홈의 자녀 선택으로 안내하며, `TOO_MANY_ATTEMPTS`는 남은 시간 표시를 켠다.
