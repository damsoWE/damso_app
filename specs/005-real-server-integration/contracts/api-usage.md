# Contract: 앱이 쓰는 API와 검증 범위

기준: `docs/api/openapi.yaml` `api-v0.6`(research R1). 앱이 실제로 부르는 경로 30개 전부가 대상이다. quickstart 시나리오 ID로 어디서 확인하는지 적는다.

## F1 인증·회원가입·학급 연결

| 경로 | Repository | 확인 시나리오 |
|---|---|---|
| `POST /api/v1/auth/invite-codes/verify` | Auth | Q2-1, Q2-3 |
| `POST /api/v1/auth/signup` · `/signup/verify` · `/signup/resend` | Auth | Q2-1 |
| `POST /api/v1/auth/login` | Auth | Q1-1, Q1-4 |
| `POST /api/v1/auth/token/refresh` | Auth(인터셉터) | Q1-3, Q1-5 |
| `POST /api/v1/auth/logout` | Auth | Q1-6 |
| `POST /api/v1/auth/password-reset` · `/verify` · `/confirm` | Auth | Q1-7 |
| `GET /api/v1/me` · `POST /api/v1/me/withdrawal` | Me | Q1-2, Q1-8 |
| `GET·POST /api/v1/parent/children` | Parent | Q2-2, Q2-4 |
| `GET /api/v1/teacher/classroom` · `GET·PUT /api/v1/teacher/profile` | Teacher | Q2-2 |

## 관리자

| 경로 | Repository | 확인 시나리오 |
|---|---|---|
| `GET·POST /api/v1/admin/classrooms` | Admin | Q2-1 |
| `GET·POST /api/v1/admin/classrooms/{id}/students` | Admin | Q2-1 |
| `POST /api/v1/admin/classrooms/{id}/teacher-invite` | Admin | Q2-1 |
| `POST /api/v1/admin/students/{id}/parent-invite` | Admin | Q2-1, Q2-3 |
| `GET /api/v1/admin/invite-codes` | Admin | Q2-3 |

## F2 문의 접수·긴급 분류

| 경로 | Repository | 확인 시나리오 |
|---|---|---|
| `GET·POST /api/v1/parent/inquiries` | ParentInquiry | Q3-1, Q3-2 |
| `GET /api/v1/parent/inquiries/{id}` | ParentInquiry | Q3-3, Q3-5 |
| `GET /api/v1/teacher/inquiries` | TeacherInquiry | Q3-1, Q3-2 |
| `GET /api/v1/teacher/inquiries/{id}` | TeacherInquiry | Q3-2, Q4-1 |
| `GET /api/v1/teacher/inquiries/{id}/content` | TeacherInquiry | Q3-2(긴급), Q4-4 |

## F3 정리 결과

| 경로 | Repository | 확인 시나리오 |
|---|---|---|
| `GET /api/v1/teacher/inquiries/{id}/refinement` | TeacherInquiry | Q4-1, Q4-2 |
| `POST /api/v1/teacher/inquiries/{id}/refinement/retry` | TeacherInquiry | Q4-3 |

## 알림(범위 밖이지만 실패해도 안전해야 함, FR-014)

| 경로 | 확인 시나리오 |
|---|---|
| `GET·PUT /api/v1/teacher/notification-settings` | Q6-2 |
| `PUT /api/v1/me/devices` · `DELETE /api/v1/me/devices/current` | Q6-2(Firebase 없음 → 호출 안 됨) |

## 쓰지 않는 v0.6 경로 (범위 밖)

`/parent/inquiries/{id}/follow-ups`, `/teacher/inquiries/{id}/answer-reviews`, `/answers`, `/close`, `/parent/notification-settings` — F4 별도 이슈.

## 오류 분기 (기존 그대로)

| 상황 | 앱 동작 |
|---|---|
| 응답 없음(연결 실패·시간 초과) | `AppException.networkMessage` + 다시 시도 |
| `ErrorResponse` 있음 | 서버 `message`, 입력 오류는 `fieldErrors`를 입력란 아래에 |
| 401(접근 토큰 만료) | 인터셉터가 1회 갱신 후 재요청. 갱신이 400/401/403이면 세션 만료 → 로그인 |
| 403 | 서버 `message`, 내용 미표시 |
| 응답 모양이 계약과 다름 | `AppException.fallbackMessage`(research R6) |
