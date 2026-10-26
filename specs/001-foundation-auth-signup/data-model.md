# Data Model: 공통 기반 반영 및 인증·회원가입·학급 연결 화면 (F0·F1)

**Feature**: [spec.md](./spec.md) · **Date**: 2026-10-25

앱 안의 모델(도메인 모델·화면 상태)이다. 서버 스키마는 `docs/api/openapi.yaml`이 원본이며, 여기서는 앱이 쓰는 필드와 검증·상태 전이만 적는다. 모든 식별자는 UUID 문자열이다.

---

## 1. core (여러 기능 공유)

### Role
`SUPER_ADMIN` · `TEACHER` · `PARENT` (openapi `Role`). 서버 문자열 → enum, 모르는 값은 오류로 처리(로그아웃).

### SessionState (`lib/core/session`)

| 상태 | 의미 | 라우터 동작 |
|---|---|---|
| `checking` | 앱 시작 직후, 저장된 갱신 토큰으로 복구 중 | `/splash` |
| `unreachable` | 복구 중 네트워크 오류·5xx·429(토큰은 유지) | `/splash`에 다시 시도 버튼 |
| `signedOut` | 세션 없음 | 공개 경로만. 보호 경로면 `/` |
| `signedOut(sessionExpired)` | 갱신이 거부되어 로그아웃됨 | 공개 경로만. 보호 경로면 `/login` |
| `signedIn(role, justSignedUp)` | 로그인됨 | 역할 경로 + `/me/**`. `justSignedUp`이면 `/welcome` 먼저 |

전이:
```
checking ──refresh 성공──▶ signedIn(role)
checking ──토큰 없음──▶ signedOut
checking ──refresh 400·401·403──▶ signedOut(sessionExpired)
checking ──네트워크 오류·5xx·429──▶ unreachable
checking ──저장소·응답 형식 오류──▶ signedOut ──다시 시도──▶ checking
signedOut ──login / signup verify 성공──▶ signedIn(role[, justSignedUp=true])
signedIn ──logout / 탈퇴 / 본인 계정 비밀번호 재설정 완료(signOut)──▶ signedOut
signedIn ──갱신 거부(expire)──▶ signedOut(sessionExpired)
signedIn(justSignedUp) ──이용 안내 확인──▶ signedIn(justSignedUp=false)
```

### TokenStore (기존, 유지)
- `accessToken`: 메모리 전용.
- 갱신 토큰: 보안 저장소 키 `refresh_token` 하나. 역할·이메일은 저장하지 않는다.

### AppException (기존, 확장)

| 필드 | 타입 | 출처 |
|---|---|---|
| `message` | String | `ErrorResponse.message`, 없으면 고정 일반 안내 |
| `code` | String? | `ErrorResponse.code` (ErrorCode) |
| `statusCode` | int? | HTTP 상태 |
| `fieldErrors` | Map<String, String> | `ErrorResponse.fieldErrors[].field → reason` (INVALID_INPUT일 때만) |
| `retryAfter` | Duration? | 429 `Retry-After` 헤더(초) |
| `isNetworkError` | bool | 응답 없음(연결 실패·시간 초과) |

ErrorCode 상수(F0·F1 사용분): `INVALID_INPUT`, `UNAUTHORIZED`, `FORBIDDEN`, `NOT_FOUND`, `CONFLICT`, `INVALID_INVITE_CODE`, `INVALID_VERIFICATION_CODE`, `INVALID_CREDENTIALS`, `TOO_MANY_ATTEMPTS`, `CLASSROOM_HAS_TEACHER`, `STUDENT_HAS_GUARDIAN`.

### Cooldown (화면 상태 조각)
- `until`: DateTime? — 다시 시도 가능 시각. null이면 대기 없음.
- `remaining`: Duration — 1초마다 갱신, 0이면 버튼 활성.
- 쓰는 곳: 로그인 대기, 초대 코드 잠금, 인증 코드 잠금·재발송(60초), 재설정 코드 잠금, 자녀 추가 코드 잠금.

---

## 2. auth

### 모델

| 모델 | 필드 | 비고 |
|---|---|---|
| `InviteRole` | `teacher` · `parent` | 코드 확인 결과(`InviteCodeCheckResponse.role`) |
| `SignupForm` | `inviteCode`, `name`, `email`, `password`, `termsAgreed` | `SignupRequest` |
| `PendingSignup` | `pendingSignupId`, `codeExpiresIn` (Duration) | `PendingSignupResponse`. 메모리 전용 |
| `AuthResult` | `role` | `TokenResponse`에서 토큰은 Repository가 저장하고 역할만 위로 올린다 |

### 검증 (`lib/core/validation/validators.dart` — auth·parent·me 공유, 글자 수 = 코드 포인트)

| 입력 | 규칙 | 정규화 |
|---|---|---|
| 초대 코드 | `^[A-HJKMNP-Z2-9]{10}$` | 공백 제거, 대문자 변환 |
| 이름 | 1~20자, 공백만은 불가 | 앞뒤 공백 제거 |
| 이메일 | `x@y.z` 형태, 254자 이하 | 앞뒤 공백 제거(소문자 변환은 서버) |
| 비밀번호(가입·재설정) | 8~64자, 영문 1자 이상 + 숫자 1자 이상 | 없음 |
| 비밀번호(로그인·탈퇴 확인) | 1~64자 | 없음 |
| 인증·재설정 코드 | `^[0-9]{6}$` | 공백 제거 |
| 약관 | true 필수 | — |

### 가입 흐름 상태 (`SignupViewModel`)
```
codeEntry ──checkInviteCode(code, email) 성공──▶ accountForm(role, email 고정)   (F1-1 → F1-3 / F1-3a)
codeEntry ──INVALID_INPUT──▶ codeEntry(fieldErrors)
codeEntry ──INVALID_INVITE_CODE──▶ codeEntry(error)          (F1-2)
codeEntry ──TOO_MANY_ATTEMPTS──▶ codeEntry(attemptCooldown)   (F1-2b)
accountForm ──signup 202──▶ verifying(pending)                (C-2)
accountForm ──INVALID_INVITE_CODE──▶ codeEntry(error)         (입력값 유지)
accountForm ──INVALID_INPUT──▶ accountForm(fieldErrors)
accountForm ──TOO_MANY_ATTEMPTS──▶ accountForm(attemptCooldown)
verifying ──verify 201──▶ 완료 → Session.signedIn(justSignedUp) → /welcome (C-6)
verifying ──INVALID_VERIFICATION_CODE──▶ verifying(error)
verifying ──TOO_MANY_ATTEMPTS──▶ verifying(attemptCooldown)        (C-2 잠금, 인증 버튼 비활성)
verifying ──INVALID_INVITE_CODE──▶ codeEntry(error)           (그사이 재발행·만료)
verifying ──resend──▶ verifying(resendCooldown 60s)
verifying ──resend TOO_MANY_ATTEMPTS──▶ verifying(resendCooldown = retryAfter)   (인증 버튼은 잠그지 않음)
```

### 비밀번호 재설정 상태 (`PasswordResetViewModel`)
```
emailEntry ──202──▶ codeEntry                                 (C-3 → C-3b)
codeEntry ──204──▶ newPassword                                (C-4)
codeEntry ──INVALID_VERIFICATION_CODE──▶ codeEntry(error)
codeEntry ──TOO_MANY_ATTEMPTS──▶ expiredOrLocked              (C-3c: 코드 다시 받기 / 로그인으로)
newPassword ──INVALID_VERIFICATION_CODE / TOO_MANY_ATTEMPTS──▶ expiredOrLocked   (그사이 코드 만료, C-3c)
newPassword ──204──▶ done → 로그인한 본인 계정이었다면 Session.signedOut  (C-5)
```

---

## 3. me (마이페이지 공통)

| 모델 | 필드 | 출처 |
|---|---|---|
| `Me` | `userId`, `name`, `email`(본인), `role` | `MeResponse` |

- 이름 수정: 1~20자. 탈퇴: 비밀번호 1~64자, 슈퍼 관리자는 메뉴 없음.

---

## 4. parent

| 모델 | 필드 | 출처 |
|---|---|---|
| `ClassroomRef` | `classroomId`, `grade`, `classNumber` | `ClassroomRef` |
| `TeacherPublicProfile` | `displayName`, `introduction` | `TeacherProfile` |
| `Child` | `studentId`, `studentName`, `classroom`, `teacher` (nullable = 담임 없음) | `ChildResponse` |

- 홈의 "선택한 자녀"는 화면 상태(메모리)다. 기본값은 목록 첫 번째.

---

## 5. teacher

| 모델 | 필드 | 출처 |
|---|---|---|
| `TeacherProfile` | `displayName`(1~20), `introduction`(0~60) | `TeacherProfile` |
| `StudentLink` | `studentId`, `name`, `guardianLinked` | `StudentSummary` |
| `MyClassroom` | `classroom`(ClassroomRef), `students` | `TeacherClassroomResponse` |

---

## 6. admin

| 모델 | 필드 | 출처 |
|---|---|---|
| `AdminClassroom` | `classroomId`, `grade`(1~6), `classNumber`(1~20), `homeroomAssigned`, `studentCount` | `AdminClassroom` |
| `AdminStudent` | `studentId`, `name`, `guardianLinked` | `StudentSummary` |
| `IssuedInviteCode` | `inviteCodeId`, `code`, `expiresAt` | `IssuedInviteCode`. **화면 전달만, 보관 금지** |
| `InviteCodeStatus` | `inviteCodeId`, `kind`(TEACHER/PARENT), `studentId?`, `studentName?`, `status`(UNUSED/USED/EXPIRED/REVOKED), `issuedAt`, `expiresAt`, `usedAt?` | `InviteCodeStatus` |

- 학생 등록 입력: 줄바꿈으로 구분한 이름 목록 → 앞뒤 공백 제거·빈 줄 제외 → 1~40명, 각 1~20자.
- 상태 표시 문구: UNUSED "미사용" · USED "사용됨" · EXPIRED "만료" · REVOKED "무효".
- 시각 표시: 기기 현지 시간, `yyyy.MM.dd HH:mm` (Dart 코어로 직접 포맷, 새 패키지 없음).
