# API 사용 계약: 화면 ↔ Repository ↔ 엔드포인트

**원본**: `docs/api/openapi.yaml` (api-v0.3). 이 문서는 앱이 **어떤 엔드포인트를 어디서 쓰는지**만 정한다. 요청·응답 스키마는 원본을 따른다.

🔓 = 공개 경로(Authorization 헤더 없음, 401이어도 토큰 갱신 안 함).

## auth — `AuthRepository`

| 메서드 | 엔드포인트 | 성공 | 화면에서 분기할 오류 | 화면 |
|---|---|---|---|---|
| `checkInviteCode(code)` | ⏳ 제안: 🔓 `POST /api/v1/auth/invite-codes/verify` ([proposal](./invite-code-check.proposal.md)) | `InviteRole?` | `INVALID_INVITE_CODE` · 429 | F1-1/F1-2/F1-2b |
| `startSignup(form)` | 🔓 `POST /api/v1/auth/signup` | 202 → `PendingSignup` | `INVALID_INPUT`(fieldErrors) · `INVALID_INVITE_CODE` · 429 | F1-3/F1-3a |
| `verifySignup(id, code)` | 🔓 `POST /api/v1/auth/signup/verify` | 201 → 토큰 저장, `role` | `INVALID_VERIFICATION_CODE` · `INVALID_INVITE_CODE` · 429 | C-2 |
| `resendSignupCode(id)` | 🔓 `POST /api/v1/auth/signup/resend` | 202 | 429 | C-2 |
| `login(email, pw)` | 🔓 `POST /api/v1/auth/login` | 200 → 토큰 저장, `role` | `INVALID_CREDENTIALS`(401) · `INVALID_INPUT` · 429 | C-1/C-1a |
| `restoreSession()` | 🔓 `POST /api/v1/auth/token/refresh` | 200 → 토큰 저장, `role` | 저장된 토큰 없음 → null(시작 화면) · 401 → 토큰 삭제 후 `AppException` throw(세션 만료 → 로그인 화면) · 네트워크 → unreachable | splash |
| `logout()` | `POST /api/v1/auth/logout` | 204 | 실패해도 기기 토큰 삭제 | 마이페이지 |
| `requestPasswordReset(email)` | 🔓 `POST /api/v1/auth/password-reset` | 202 | `INVALID_INPUT` | C-3 |
| `verifyPasswordResetCode(email, code)` | 🔓 `POST /api/v1/auth/password-reset/verify` | 204 | `INVALID_VERIFICATION_CODE` · 429 | C-3b/C-3c |
| `confirmPasswordReset(email, code, newPw)` | 🔓 `POST /api/v1/auth/password-reset/confirm` | 204 → 기기 토큰 삭제 | `INVALID_INPUT` · `INVALID_VERIFICATION_CODE` · 429 | C-4/C-5 |

토큰 갱신(401 처리)은 Repository가 아니라 `AuthInterceptor`가 `POST /api/v1/auth/token/refresh`로 한다. `restoreSession()`은 앱 시작 시 1회만 호출한다.

## me — `MeRepository`

| 메서드 | 엔드포인트 | 성공 | 분기할 오류 | 화면 |
|---|---|---|---|---|
| `getMe()` | `GET /api/v1/me` | `Me` | — | F2-7/F3-7/ADM-7, C-9 |
| `updateName(name)` | `PATCH /api/v1/me` | `Me` | `INVALID_INPUT` | C-9 |
| `withdraw(password)` | `POST /api/v1/me/withdrawal` | 204 → 기기 토큰 삭제 | `INVALID_CREDENTIALS`(401) · `FORBIDDEN` | C-8 |

⚠️ 탈퇴의 `INVALID_CREDENTIALS`는 401이다. 인터셉터는 응답 `code`가 `INVALID_CREDENTIALS`인 401은 갱신하지 않고 그대로 넘긴다.

## parent — `ParentRepository`

| 메서드 | 엔드포인트 | 성공 | 분기할 오류 | 화면 |
|---|---|---|---|---|
| `listChildren()` | `GET /api/v1/parent/children` | `List<Child>` | — | F2-1/F2-1a/F1-4 |
| `linkChild(code)` | `POST /api/v1/parent/children` | 201 → `Child` | `INVALID_INVITE_CODE` · `INVALID_INPUT` · 429 | F1-5 |

## teacher — `TeacherRepository`

| 메서드 | 엔드포인트 | 성공 | 분기할 오류 | 화면 |
|---|---|---|---|---|
| `getProfile()` | `GET /api/v1/teacher/profile` | `TeacherProfile` | — | F3-9 |
| `updateProfile(p)` | `PUT /api/v1/teacher/profile` | `TeacherProfile` | `INVALID_INPUT` | F3-9 |
| `getMyClassroom()` | `GET /api/v1/teacher/classroom` | `MyClassroom` | `FORBIDDEN`(담당 학급 없음) | F3-10, F3-7 |

## admin — `AdminRepository`

| 메서드 | 엔드포인트 | 성공 | 분기할 오류 | 화면 |
|---|---|---|---|---|
| `listClassrooms()` | `GET /api/v1/admin/classrooms` | `List<AdminClassroom>` | — | ADM-1a/ADM-1b |
| `createClassroom(grade, no)` | `POST /api/v1/admin/classrooms` | 201 | `INVALID_INPUT` · `CONFLICT`(중복) | ADM-1c |
| `listStudents(classroomId)` | `GET /api/v1/admin/classrooms/{id}/students` | `List<AdminStudent>` | `NOT_FOUND` | ADM-1 |
| `registerStudents(classroomId, names)` | `POST /api/v1/admin/classrooms/{id}/students` | 201 | `INVALID_INPUT` · `NOT_FOUND` | ADM-5/ADM-5a |
| `issueTeacherInvite(classroomId)` | `POST /api/v1/admin/classrooms/{id}/teacher-invite` | 201 → `IssuedInviteCode` | `CLASSROOM_HAS_TEACHER`(409) | ADM-2/ADM-3t |
| `issueParentInvite(studentId)` | `POST /api/v1/admin/students/{id}/parent-invite` | 201 → `IssuedInviteCode` | `STUDENT_HAS_GUARDIAN`(409) | ADM-3, ADM-6 |
| `listInviteCodes(classroomId)` | `GET /api/v1/admin/invite-codes?classroomId=` | `List<InviteCodeStatus>` | `NOT_FOUND` | 발행 현황 |

## 공통

- 모든 보호 경로에서 401은 인터셉터가 처리한다. 화면까지 올라온 401(갱신 실패)은 이미 `SessionController.expire()`가 처리했으므로 화면은 별도 안내를 하지 않는다.
- 403 `FORBIDDEN`은 화면에 서버 `message`를 보인다.
- 사용하지 않는 엔드포인트(F2 이후): `/api/v1/parent/inquiries*`, `/api/v1/teacher/inquiries*`, `/api/v1/teacher/notification-settings`, `/api/v1/me/devices*`.
