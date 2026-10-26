# Quickstart: F0·F1 검증 가이드

**Feature**: [spec.md](./spec.md) · 경로·화면: [contracts/routes.md](./contracts/routes.md) · API: [contracts/api-usage.md](./contracts/api-usage.md)

## 준비

```bash
flutter pub get
flutter analyze
flutter test
```

실행:

```bash
flutter run --dart-define=USE_MOCK=true                 # mock (서버 불필요)
flutter run --dart-define-from-file=env/dev.json        # 실서버 (Android 에뮬레이터: http://10.0.2.2:8080)
```

`env/dev.json`의 `API_BASE_URL`은 호스트만 적는다(`/api/v1` 없이, research R1).

## mock 데모 입력

mock 상태는 앱 실행 동안 메모리에만 있고, 재시작하면 초기값으로 돌아간다.

### 계정 (비밀번호는 모두 `damso1234`)

| 이메일 | 결과 |
|---|---|
| `parent@damso.test` | 학부모 · 자녀 2명(한 명은 담임 없음) |
| `newparent@damso.test` | 학부모 · 자녀 0명(빈 상태) |
| `teacher@damso.test` | 교사 · 담당 학급 있음 |
| `noclass@damso.test` | 교사 · 담당 학급 조회 시 403 `FORBIDDEN` |
| `admin@damso.test` | 슈퍼 관리자 |
| `expired@damso.test` | 학부모 · 로그인 성공 → 홈 첫 조회에서 세션 만료 → 로그인 화면 |
| `refresh@damso.test` | 학부모 · 홈 첫 조회에서 접근 권한 만료 → 갱신 → 재시도 성공(오류 안내 없이 홈 표시) |
| `wait@damso.test` (비밀번호 무관) | 429 `TOO_MANY_ATTEMPTS`, `Retry-After: 30` |
| 위 계정 + 틀린 비밀번호 / 없는 이메일 | 401 `INVALID_CREDENTIALS` (같은 안내) |

### 초대 코드 (가입 F1-1 · 자녀 추가 F1-5)

| 코드 | 결과 |
|---|---|
| `PARENTCDE2` | 학부모 코드 → F1-3 (자녀 추가에서는 새 자녀 연결) |
| `TEACHERCD2` | 교사 코드 → F1-3a (자녀 추가에서는 `INVALID_INVITE_CODE`) |
| `ZZZZZZZZZZ` | 429 잠금, `Retry-After: 600` → F1-2b |
| 그 밖의 형식 맞는 코드 | `INVALID_INVITE_CODE` → F1-2 |

### 가입 이메일 (F1-1에서 코드와 함께 입력)

| 입력 | 결과 |
|---|---|
| 이메일 `invalid@damso.test` | 400 `INVALID_INPUT` + 이메일 필드 안내(서버 fieldErrors, US1-7) |
| 그 밖의 형식 맞는 이메일 | 코드 확인 → 계정 정보(이메일 고정) → 202 → 이메일 인증(C-2), 코드 유효 10분 |

### 6자리 코드 (이메일 인증 C-2 · 비밀번호 재설정 C-3b)

| 코드 | 결과 |
|---|---|
| `123456` | 성공 |
| `999999` | (가입 인증만) `INVALID_INVITE_CODE` — 그사이 초대 코드 재발행 → F1-1로 |
| `000000` | 429 잠금 (재설정은 C-3c) |
| 그 밖 | `INVALID_VERIFICATION_CODE` |

### 관리자

초기 데이터: 3학년 2반(담임 있음 · 학생 `김하나`(보호자 연결됨) · `박서준`(미사용 학부모 코드 있음 → 재발행) · `이도윤`(코드 없음)), 1학년 1반(담임 없음 · 학생 0명).

| 동작 | 결과 |
|---|---|
| 3학년 2반 추가 | 409 `CONFLICT` (이미 있음) |
| 담임 있는 학급(3-2)에서 교사 코드 발행 | 409 `CLASSROOM_HAS_TEACHER` |
| 보호자 있는 학생에게 학부모 코드 발행 | 409 `STUDENT_HAS_GUARDIAN` |
| 그 밖의 발행 | 랜덤 10자리 코드, 만료 24시간 후 |

탈퇴 확인 비밀번호: `damso1234`면 성공, 그 밖은 401 `INVALID_CREDENTIALS`.

## 검증 시나리오

| # | 시나리오 | 기대 결과 | spec |
|---|---|---|---|
| 1 | 시작 → 초대코드로 가입 → `PARENTCDE2` + 이메일 → 정보 입력(이메일 고정) → `123456` | C-6 이용 안내 → 학부모 홈 | US1 |
| 2 | 가입에서 `TEACHERCD2` | 교사용 F1-3a 문구 → 가입 후 교사 홈 | US1 |
| 3 | 가입에서 `AAAAAAAAAA` / `ZZZZZZZZZZ` | F1-2 같은 안내 / F1-2b 남은 시간 감소 | US1-3,4 |
| 4 | 가입 정보에서 비밀번호 `abcdefgh`, 약관 미동의 | 입력란 안내, 버튼 비활성 | US1-6 |
| 5 | 인증 화면 재발송 | 60초 동안 재발송 비활성 | US1-5 |
| 6 | 인증 코드 `999999` | F1-1로 돌아가고 "코드를 확인해 주세요" | Edge |
| 7 | 역할별 로그인(parent/teacher/admin) | 각 역할 홈 | US2-1 |
| 8 | 틀린 비밀번호 / `wait@damso.test` | 같은 실패 안내 / C-1a 30초 카운트다운 | US2-2,3 |
| 9 | 로그인 후 앱 재시작 (mock: 재시작 시 세션 없음 → 시작 화면이 정상) · 실서버: 홈으로 바로 | 실서버에서 홈 복구 | US2-4 |
| 10 | `expired@damso.test` 로그인 | 로그인 화면으로 이동, 다시 로그인 필요 | US2-6, US8-2 |
| 11 | 학부모로 로그인 후 주소창/딥링크로 `/admin` | 학부모 홈으로 | US2-8 |
| 12 | 관리자: 학급 추가 → 학생 3명 등록 → 교사 코드 발행 → 뒤로 | 발행 완료 화면에서만 코드 보임, 현황에 원문 없음 | US3 |
| 13 | 관리자: 미사용 코드 학생 재발행 | ADM-6 확인 후 새 코드 | US3-6 |
| 14 | `parent@damso.test` 홈 | 자녀 2명, 담임 없음 안내, 이메일 없음 | US4-1,2 |
| 15 | 연결된 자녀 → `PARENTCDE2` / `TEACHERCD2` | 자녀 추가 / 같은 실패 안내 | US4-4,5 |
| 16 | 교사 프로필 소개 61자 | 저장 불가, 글자 수 표시 | US5-2 |
| 17 | `noclass@damso.test` 연결 현황 | 403 서버 안내 | US8-3 |
| 18 | 비밀번호 재설정 → `123456` → 새 비밀번호 | C-5 완료, 로그인 상태였다면 시작 화면 | US6 |
| 19 | 마이페이지 이름 수정 / 로그아웃 / 탈퇴(틀린·맞는 비밀번호) | 반영 / 시작 화면 / 안내·시작 화면 | US7 |
| 20 | 관리자 마이페이지 | 탈퇴 메뉴 없음 | FR-039 |
| 21 | `refresh@damso.test` 로그인 | 학부모 홈이 잠깐 늦게 뜨지만 오류 안내 없이 자녀 목록 표시 | US2-5, US8-2 |

## 자동 테스트로 확인하는 것

- `AuthInterceptor`: 401 → 갱신 1회 → 재시도, 동시 401 3건에도 갱신 1회, 공개 경로·`INVALID_CREDENTIALS` 401은 갱신 안 함, 갱신 실패 시 토큰 삭제 + `expire()` → 로그인 화면 (US8-2, SC-003)
- `AppException.fromDio`: fieldErrors·Retry-After·네트워크 오류·message 없을 때 일반 안내 (FR-001~004)
- validators 경계값 (FR-015)
- 라우터 redirect 규칙 전체 (SC-002)
- 발행 코드가 완료 화면 밖 상태에 남지 않음 (SC-006)

## 실서버 확인 시 주의

- 초대 코드 확인은 api-v0.4의 `POST /api/v1/auth/invite-codes/verify`를 쓴다. 실패 횟수는 이메일 기준으로 가입 1단계와 합산되므로, 같은 이메일로 코드 확인·가입을 섞어 5회 틀리면 10분 잠긴다.
- 슈퍼 관리자 계정은 서버 운영자가 만든다. 앱에는 기본 계정이 없다.
