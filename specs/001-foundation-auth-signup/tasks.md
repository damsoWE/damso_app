---

description: "F0·F1 공통 기반 및 인증·회원가입·학급 연결 화면 구현 작업 목록"
---

# Tasks: 공통 기반 반영 및 인증·회원가입·학급 연결 화면 (F0·F1)

**Input**: `specs/001-foundation-auth-signup/` 설계 문서 (plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md)

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/api-usage.md, contracts/routes.md, quickstart.md

**Tests**: plan.md의 Project Structure·구현 순서와 research R12가 테스트 파일을 명시하므로 포함한다. 각 Phase의 테스트를 먼저 작성하고 실패를 확인한 뒤 구현한다. 새 테스트 패키지는 추가하지 않는다(`flutter_test`만, 시간 경과는 `testWidgets` + `tester.pump(Duration)`으로 확인).

**Organization**: User Story별로 묶는다. Phase 순서는 spec 우선순위(P1 → P2 → P3)를 따른다: US1 → US2 → US3 → US4 → US5 → US6 → US8 → US7.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: 다른 파일이고 미완료 작업에 의존하지 않아 병렬 가능
- **[Story]**: 해당 User Story (US1~US8)
- 모든 경로는 레포 루트 기준

## 공통 규칙 (모든 작업에 적용)

- **Figma**: 화면 ID 옆 `Figma 224-1169` 표기는 `https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/?node-id=224-1169` 프레임이다(`docs/ia.md`). 색·글꼴은 `lib/core/theme/app_theme.dart` 토큰만 쓴다.
- **아키텍처**: 위젯 → ViewModel(Riverpod `Notifier`/`AsyncNotifier`) → Repository 인터페이스. 위젯은 Repository를 직접 부르지 않는다. `domain`은 Flutter·dio·저장소 import 금지. 구현 선택은 `*_repository_provider.dart` 한 곳에서 `Env.useMock`으로.
- **오류**: data 계층은 `mapDioErrors`로 `DioException` → `AppException` 변환. 화면에는 `AppException.message`만 표시하고 `e.toString()`·스택트레이스는 절대 표시하지 않는다. 분기는 `AppException.code`(`lib/core/error/error_codes.dart` 상수)로 한다.
- **로그 금지**: `print`·`debugPrint`·`log`로 비밀번호·코드·토큰·입력값을 내보내지 않는다.
- **경로 문자열**: 엔드포인트는 `docs/api/openapi.yaml` 문자열 그대로(`/api/v1/...`) 쓴다(research R1). openapi.yaml은 수정하지 않는다.
- **mock 데모 입력**: `quickstart.md`의 "mock 데모 입력" 표가 기준이다. mock 지연은 300ms. mock 로그인은 `TokenStore.accessToken`에 `mock:<이메일 @앞부분>`(예: `mock:parent`)만 넣고 보안 저장소에는 쓰지 않는다 → 다른 기능의 mock은 이 값으로 데모 계정을 구분한다(새 공유 상태 파일 없음). mock 재시작 시 세션 없음.
- **글자 수**: `String.runes.length`(코드 포인트)로 센다.
- **공통 화면 상태(FR-041)**: 조회 화면은 `AsyncView`(로딩·빈 목록·오류+다시 시도), 진행 버튼은 요청 중 비활성.
- **입력 화면의 네트워크 오류(spec Edge Case)**: `AppException.isNetworkError`면 입력값을 지우지 않고 네트워크 고정 안내를 보이며, 같은 진행 버튼을 다시 눌러 재시도할 수 있게 한다. 가입·로그인·비밀번호 재설정·자녀 추가·학급/학생 등록·프로필·계정 정보·탈퇴 ViewModel 모두 해당.

---

## Phase 1: Setup

**Purpose**: 설정값·상수 준비

- [X] T001 `env/dev.json`·`env/prod.json`의 `API_BASE_URL`이 호스트만 담고 `/api/v1`이 없는지 확인한다(research R1). 현재 값(`http://10.0.2.2:8080`, `https://api.example.com`)이면 수정하지 않는다.
- [X] T002 [P] ErrorCode 상수 파일 `lib/core/error/error_codes.dart` 생성: `abstract final class ErrorCodes`에 `invalidInput='INVALID_INPUT'`, `unauthorized='UNAUTHORIZED'`, `forbidden='FORBIDDEN'`, `notFound='NOT_FOUND'`, `conflict='CONFLICT'`, `invalidInviteCode='INVALID_INVITE_CODE'`, `invalidVerificationCode='INVALID_VERIFICATION_CODE'`, `invalidCredentials='INVALID_CREDENTIALS'`, `tooManyAttempts='TOO_MANY_ATTEMPTS'`, `classroomHasTeacher='CLASSROOM_HAS_TEACHER'`, `studentHasGuardian='STUDENT_HAS_GUARDIAN'` (data-model §1).

---

## Phase 2: Foundational (F0 공통 기반 — 모든 Story의 선행 조건)

**Purpose**: 오류 타입, 세션 상태, 토큰 갱신, 라우터 가드, 공통 위젯, AuthRepository, splash·시작 화면, 역할 홈 자리

**⚠️ CRITICAL**: 이 Phase가 끝나기 전에는 어떤 User Story도 시작하지 않는다.

### Tests (먼저 작성, 실패 확인)

- [X] T003 [P] `test/core/app_exception_test.dart` 작성 — `AppException.fromDio` 검증: (a) 응답 `message`가 있으면 그 문구, 없거나 빈 문자열이면 고정 일반 안내, (b) `code` 전달, (c) `fieldErrors` 배열 → `Map<String,String>`(field→reason), 같은 field가 두 번 오면 첫 번째만, (d) 429 + `Retry-After: 30` → `retryAfter == Duration(seconds: 30)`, 헤더 없음·숫자 아님 → null, (e) `connectionTimeout`·`receiveTimeout`·`connectionError`(응답 없음) → `isNetworkError == true`이고 message는 네트워크 고정 안내, (f) `statusCode` 전달.
- [X] T004 [P] `test/core/auth_interceptor_test.dart` 작성 — 테스트 파일 안에 가짜 `HttpClientAdapter`를 직접 구현(패키지 추가 금지), `FlutterSecureStorage.setMockInitialValues({})`로 `TokenStore` 사용. 케이스: (a) accessToken이 있으면 `Authorization: Bearer <at>` 주입, (b) 보호 경로 401 → `POST /api/v1/auth/token/refresh` 1회(본문 `{"refreshToken": <rt>}`) → 새 토큰 저장 → 원 요청 1회 재시도 성공, (c) 동시 401 3건 → 갱신 호출 정확히 1회, 3건 모두 각 1회 재시도, (d) 공개 경로(`/api/v1/auth/login`, `/api/v1/auth/signup`, `/api/v1/auth/signup/verify`, `/api/v1/auth/signup/resend`, `/api/v1/auth/password-reset`, `/api/v1/auth/password-reset/verify`, `/api/v1/auth/password-reset/confirm`, `/api/v1/auth/token/refresh`)의 401은 갱신 없이 그대로 전달, (e) 응답 `code == INVALID_CREDENTIALS`인 401(탈퇴 비밀번호 불일치)은 갱신 없이 전달, (f) 갱신이 401 → `TokenStore` 비워짐 + `onSessionExpired` 1회 호출, (g) 재시도한 요청이 다시 401 → 두 번째 갱신 없음, (h) 저장된 갱신 토큰 없음 → 갱신 호출 없이 `onSessionExpired`.
- [X] T005 [P] `test/core/router_redirect_test.dart` 작성 — 순수 함수 `resolveRedirect(SessionState, String location)`(T025)를 contracts/routes.md "redirect 규칙" 1~5 전체로 검증: `checking`·`unreachable` → `/splash`; `SignedOut()` + 보호 경로 → `/`, `SignedOut(sessionExpired: true)` + 보호 경로(`/splash` 포함) → `/login`, 공개 경로(`/`, `/login`, `/signup`, `/signup/account`, `/signup/verify`, `/password-reset`, `/password-reset/code`, `/password-reset/new`, `/password-reset/done`, `/terms`) → null; `signedIn(justSignedUp: true)` → `/welcome`; 역할 3종 × (`/`, `/login`, `/signup`, `/splash`) → 자기 역할 홈; 역할 3종 × 다른 역할 접두(`/parent`, `/teacher`, `/admin` 하위) → 자기 역할 홈(SC-002); SUPER_ADMIN + `/me/withdraw` → `/admin/me`; 로그인 상태 `/password-reset`·`/terms`·`/me/account` → null; PARENT·TEACHER + `/inquiries` → null, SUPER_ADMIN + `/inquiries` → `/admin`(FR-037).
- [X] T006 [P] `test/core/validators_test.dart` 작성 — T013의 경계값: 초대 코드(`' parentcde2 '` → `PARENTCDE2` 통과, 9자·11자·`0`/`O`/`1`/`I`/`L` 포함 실패), 이름(빈 값·공백만 실패, 20자 통과, 21자 실패, 이모지 1개 = 1자), 이메일(`a@b.c` 통과, `a@b`·254자 초과 실패), 가입 비밀번호(`abcdefgh` 실패, `12345678` 실패, `abcd1234` 통과, 7자·65자 실패), 로그인 비밀번호(빈 값 실패, 64자 통과, 65자 실패), 6자리 코드(`' 123456'` 통과, `12345`·`12345a` 실패).

### Implementation

- [X] T007 `lib/core/error/app_exception.dart` 확장(research R4, data-model §1 AppException): 필드 `fieldErrors`(`Map<String,String>`, 기본 `const {}`), `retryAfter`(`Duration?`), `isNetworkError`(`bool`, 기본 false) 추가. `fromDio`에서 `ErrorResponse.fieldErrors[]`(field→reason, 첫 번째 우선), 응답 헤더 `retry-after`(정수 초), 응답 없음(`connectionTimeout`·`sendTimeout`·`receiveTimeout`·`connectionError`) 판정. 고정 안내 2종: 일반 `요청을 처리하지 못했습니다. 잠시 후 다시 시도해 주세요.`, 네트워크 `네트워크 연결을 확인한 뒤 다시 시도해 주세요.` 클래스 주석의 "fieldErrors 는 openapi.yaml 확정 후 추가한다" 문구 삭제. 원문 응답 객체는 보관하지 않는다.
- [X] T008 [P] `lib/core/session/role.dart` 생성: `enum Role { superAdmin, teacher, parent }` + `static Role fromServer(String value)`(`SUPER_ADMIN`/`TEACHER`/`PARENT`, 모르는 값은 `FormatException` — 호출부는 로그아웃 처리).
- [X] T009 [P] `lib/core/session/session_state.dart` 생성: `sealed class SessionState` — `SessionChecking`, `SessionUnreachable`, `SignedOut({bool sessionExpired = false})`(true = 갱신 거부로 로그아웃 → 로그인 화면), `SignedIn(Role role, {bool justSignedUp = false})` (data-model §1 SessionState).
- [X] T010 `tokenStoreProvider`를 `lib/core/network/dio_provider.dart`에서 `lib/core/storage/token_store.dart`로 옮기고, 이를 import하던 `lib/features/auth/data/auth_repository_provider.dart`와 다른 사용처의 import를 맞춘다(session ↔ network 순환 import 방지).
- [X] T011 `lib/core/session/session_controller.dart` 생성: `class SessionController extends Notifier<SessionState>` + `sessionControllerProvider`. `build()` → `SessionChecking`. 메서드: `signIn(Role role, {bool justSignedUp = false})`, `acknowledgeWelcome()`(`justSignedUp`만 false로), `markUnreachable()`, `retryRestore()`(→ `SessionChecking`), `signOut()`(`TokenStore.clear()` 후 `SignedOut()` → 시작 화면; 로그아웃·탈퇴·비밀번호 재설정 완료용), `expire()`(이미 `SignedOut`이면 무시, 아니면 `TokenStore.clear()` 후 `SignedOut(sessionExpired: true)` → 로그인 화면; 갱신 거부용, constitution). 역할·이메일은 저장하지 않는다(research R2). (depends on T008, T009, T010)
- [X] T012 `lib/core/network/auth_interceptor.dart` 보완(research R3): 생성자에 `required void Function() onSessionExpired` 추가. 갱신 경로 `/api/v1/auth/token/refresh`, 본문 `{'refreshToken': rt}`, 응답 `TokenResponse`의 `accessToken`(메모리)·`refreshToken`(보안 저장소) 저장. 공개 경로 집합(T004-d 목록)은 Authorization 주입·갱신 대상에서 제외. 응답 `code == ErrorCodes.invalidCredentials`인 401은 그대로 전달. 진행 중 갱신을 `Future<bool>? _refreshing` 하나로 공유해 동시 401은 같은 결과를 기다린 뒤 각자 1회만 재시도(`extra['auth_retried']`). 갱신이 401로 거부되거나 갱신 토큰이 없으면 `TokenStore.clear()` + `onSessionExpired()`; 갱신 중 네트워크 오류면 토큰을 지우지 않고 원 오류를 전달. 갱신 호출은 인터셉터 없는 별도 `Dio`로. (depends on T002, T010)
- [X] T013 [P] `lib/core/validation/validators.dart` 생성(순수 Dart, 두 개 이상 기능이 공유 — auth·parent·me): `normalizeInviteCode`(공백 제거 + 대문자) / `validateInviteCode`(`^[A-HJKMNP-Z2-9]{10}$`), `validateName`(trim 후 1~20자, 공백만 불가), `validateEmail`(trim, `x@y.z` 형태, 254자 이하), `validateNewPassword`(8~64자, `[A-Za-z]` 1자 이상 + `[0-9]` 1자 이상), `validateCurrentPassword`(1~64자), `normalizeSixDigitCode`/`validateSixDigitCode`(`^[0-9]{6}$`). 각 함수는 오류 시 사용자 안내 문구(String), 통과 시 null을 반환. 글자 수 = `runes.length` (data-model §2 검증 표).
- [X] T014 [P] `lib/core/widgets/cooldown.dart` 생성(research R6, data-model §1 Cooldown): 불변 값 `Cooldown`(`until: DateTime?`, `remaining: Duration`, `isActive`), ViewModel이 쓰는 `CooldownTimer`(`start(Duration?, void Function(Cooldown) onTick)` — 1초 `Timer.periodic`, 0이 되면 정지, `cancel()`; ViewModel은 `ref.onDispose(timer.cancel)`), 표시 위젯 `CooldownNotice`(남은 시간을 `m분 s초`/`s초`로 표시, `retryAfter`가 없던 잠금이면 `잠시 후 다시 시도해 주세요.`만 표시). 고정 횟수·시간 문구("5회", "10분")는 넣지 않는다.
- [X] T015 [P] `lib/core/widgets/async_view.dart` 생성: `AsyncView<T>`(`AsyncValue<T> value`, `Widget Function(T) data`, `bool Function(T)? isEmpty`, `WidgetBuilder? empty`, `VoidCallback onRetry`) — 로딩 표시 / 빈 상태 / 오류 시 `AppException`이면 `message`, 그 외 오류는 일반 고정 안내 + "다시 시도" 버튼.
- [X] T016 [P] `lib/core/widgets/field_error_text.dart` 생성: 입력란 아래 안내 한 줄(`String? message`, null이면 빈 공간). 서버 `fieldErrors`가 앱 검증 결과보다 우선하도록 `serverError ?? clientError`를 받는 생성자 제공(research R9).
- [X] T017 `lib/features/auth/domain/models.dart`·`lib/features/auth/domain/auth_repository.dart` 작성(data-model §2, contracts/api-usage.md auth 표): 모델 `enum InviteRole { teacher, parent }`, `SignupForm(inviteCode, name, email, password, termsAgreed)`, `PendingSignup(pendingSignupId, codeExpiresIn: Duration)`, `AuthResult(role: Role)`. 인터페이스 메서드: `Future<InviteRole?> checkInviteCode(String code)`, `Future<PendingSignup> startSignup(SignupForm form)`, `Future<AuthResult> verifySignup(String pendingSignupId, String code)`, `Future<void> resendSignupCode(String pendingSignupId)`, `Future<AuthResult> login({required String email, required String password})`, `Future<Role?> restoreSession()`(저장된 토큰 없음 → null, 401 → `AppException(statusCode: 401)` throw, 네트워크 오류 → `AppException(isNetworkError)` throw), `Future<void> logout()`, `Future<void> requestPasswordReset(String email)`, `Future<void> verifyPasswordResetCode(String email, String code)`, `Future<void> confirmPasswordReset(String email, String code, String newPassword)`. 기존 `lib/features/auth/presentation/login_view_model.dart`는 새 `login` 반환형에 맞춰 컴파일만 되게 고친다(US2에서 전면 교체). (depends on T008)
- [X] T018 `lib/features/auth/data/auth_repository_impl.dart` 재작성: contracts/api-usage.md auth 표의 엔드포인트·성공 코드 그대로. 요청 본문 필드명은 openapi.yaml(`SignupRequest`, `ResetCodeRequest` 등)을 따른다. `login`·`verifySignup`·`restoreSession` 성공 시 `TokenResponse`의 accessToken은 메모리, refreshToken은 보안 저장소에 저장하고 `Role.fromServer(role)` 반환. `restoreSession`: 저장된 RT 없으면 서버 호출 없이 null, 401이면 `TokenStore.clear()` 후 `AppException`을 그대로 throw. `checkInviteCode`: 계약 확정 전이므로 서버를 호출하지 않고 null 반환 + `contracts/invite-code-check.proposal.md`를 가리키는 주석(research R5). `logout`: `POST /api/v1/auth/logout`(본문은 openapi 정의) 결과와 무관하게 `finally`에서 `TokenStore.clear()`. `confirmPasswordReset`: 204 후 `TokenStore.clear()`. 모든 호출은 `mapDioErrors`로 감싼다. (depends on T007, T017)
- [X] T019 `lib/features/auth/data/mock_auth_repository.dart` 재작성(quickstart "mock 데모 입력"): 계정 — 비밀번호 `damso1234`; `parent@`·`newparent@`·`expired@`·`refresh@damso.test` → PARENT, `teacher@`·`noclass@damso.test` → TEACHER, `admin@damso.test` → SUPER_ADMIN; `wait@damso.test`(비밀번호 무관) → 429 `TOO_MANY_ATTEMPTS`, `retryAfter: 30s`; 그 밖 → 401 `INVALID_CREDENTIALS` `이메일 또는 비밀번호가 올바르지 않습니다.` 로그인 성공 시 `TokenStore.accessToken = 'mock:<@앞부분>'`만 설정. 초대 코드 — `PARENTCDE2` → parent, `TEACHERCD2` → teacher, `ZZZZZZZZZZ` → 429 `retryAfter: 600s`, 그 밖 → 400 `INVALID_INVITE_CODE` `코드를 확인해 주세요.`. 가입 — 이메일 `invalid@damso.test`이면 400 `INVALID_INPUT` + `fieldErrors {'email': '사용할 수 없는 이메일 형식입니다.'}`(US1-7 재현용), 그 밖 202 → `PendingSignup('mock-pending', 10분)`; 인증 코드 `123456` 성공(코드의 역할로 `AuthResult`, accessToken `mock:signup-<role>`), `999999` → `INVALID_INVITE_CODE`, `000000` → 429 `retryAfter: 600s`, 그 밖 → `INVALID_VERIFICATION_CODE` `인증 코드가 올바르지 않습니다.`; 재발송은 항상 성공. 재설정 — 요청은 항상 성공, 코드 `123456` 성공, `000000` → 429 `retryAfter: 600s`, 그 밖 → `INVALID_VERIFICATION_CODE`. `restoreSession` → null. `logout` → `TokenStore.clear()`. 상태는 메모리 전용. (depends on T017)
- [X] T020 `lib/features/auth/data/auth_repository_provider.dart` 수정: mock도 `tokenStoreProvider`를 받도록 생성자 인자 전달. 구현체 참조는 이 파일에만. (depends on T018, T019)
- [X] T021 `lib/core/network/dio_provider.dart` 수정: `AuthInterceptor(dio, ref.watch(tokenStoreProvider), onSessionExpired: () => ref.read(sessionControllerProvider.notifier).expire())`. (depends on T011, T012)
- [X] T022 `lib/features/auth/presentation/splash_view_model.dart`·`splash_page.dart` 생성: 세션이 `SessionChecking`일 때 `authRepository.restoreSession()` 1회 호출 → Role이면 `signIn(role)`, null이면 `signOut()`(시작 화면), 401 `AppException`이면 `expire()`(로그인 화면), `isNetworkError`면 `markUnreachable()`(토큰 유지, research R2). 화면은 로딩 표시, `SessionUnreachable`이면 `서버에 연결할 수 없습니다.` + "다시 시도"(→ `retryRestore()` 후 재호출). (depends on T011, T020)
- [X] T023 [P] `lib/features/auth/presentation/start_page.dart` 생성 — C-0 시작(Figma 216-5016): "로그인" → `/login`, "초대코드로 가입하기" → `/signup`.
- [X] T024 [P] 역할 홈 자리 화면 생성(각 Story에서 내용 채움): `lib/features/parent/presentation/parent_home_page.dart`(`ParentHomePage`, 제목 "학부모 홈"), `lib/features/teacher/presentation/teacher_home_page.dart`(`TeacherHomePage`, 제목 "교사 홈"), `lib/features/admin/presentation/admin_home_page.dart`(`AdminHomePage`, 제목 "관리자 홈"). 빈 `Scaffold` + `AppBar`만.
- [X] T025 `lib/app/router.dart` 재작성(research R7, contracts/routes.md): 최상위 순수 함수 `String? resolveRedirect(SessionState state, String location)`(redirect 규칙 1~5, 역할 홈 `/parent`·`/teacher`·`/admin`)를 export하고 `GoRouter.redirect`는 이것만 호출. `refreshListenable`은 `sessionControllerProvider` 변화를 `ref.listen`으로 받는 `ChangeNotifier`. `initialLocation: '/splash'`. 이 Phase의 경로: `/splash`, `/`, `/parent`, `/teacher`, `/admin`, 기존 `/inquiries`(PARENT·TEACHER만 임시 허용, SUPER_ADMIN 차단 FR-037, FR-013). 이후 Story는 이 파일에 경로를 추가한다. (depends on T011, T022, T023, T024)

**Checkpoint**: `flutter test test/core` 통과. `flutter run --dart-define=USE_MOCK=true` → splash → 시작 화면. (기존 `test/widget_test.dart`는 US2 T039에서 새 흐름으로 고친다.)

---

## Phase 3: User Story 1 - 초대 코드로 가입하고 이메일 인증을 마친다 (Priority: P1) 🎯 MVP

**Goal**: F1-1 → F1-3/F1-3a → C-2 → C-6 → 역할 홈. 코드 오류·잠금·필드 오류·재발송 제한 포함.

**Independent Test**: mock에서 `PARENTCDE2` → 정보 입력 → `123456` → 이용 안내 → 학부모 홈. `AAAAAAAAAA`(F1-2), `ZZZZZZZZZZ`(F1-2b 카운트다운), `999999`(F1-1로 복귀), 재발송 60초 비활성 (quickstart 시나리오 1~6).

### Tests for User Story 1

- [X] T026 [P] [US1] `test/features/auth/signup_view_model_test.dart` 작성 — `ProviderContainer` + `MockAuthRepository`로 data-model §2 "가입 흐름 상태" 전이 전부: `PARENTCDE2` → accountForm(parent), `TEACHERCD2` → accountForm(teacher), `AAAAAAAAAA` → codeEntry(error `코드를 확인해 주세요.`), `ZZZZZZZZZZ` → codeEntry(attemptCooldown 600초), 이메일 `invalid@damso.test` → accountForm(fieldErrors['email']), 정상 → verifying(codeExpiresIn 10분), `123456` → `SessionController` 상태 `SignedIn(parent, justSignedUp: true)`, `999999` → codeEntry(error, 이름·이메일 입력값 유지), 그 밖 6자리 → verifying(error), `000000` → verifying(attemptCooldown 600초, 인증 비활성·재발송은 별도), resend → resendCooldown 60초.
- [X] T027 [P] [US1] `test/features/auth/signup_flow_test.dart` 위젯 테스트 — `ProviderScope`(mock override)로 앱 실행: 시작 → "초대코드로 가입하기" → 소문자 `parentcde2` 입력 시 `PARENTCDE2`로 표시 → 계정 정보(전화번호·주소 입력란 없음 확인, SC-005) → `123456` → C-6 → "확인했어요" → 학부모 홈. 약관 미동의·비밀번호 `abcdefgh`면 진행 버튼 비활성(US1-6).

### Implementation for User Story 1

- [X] T028 [US1] `lib/features/auth/presentation/signup/signup_view_model.dart` 생성: `SignupState`(step: `codeEntry|accountForm|verifying`, `inviteRole: InviteRole?`, 입력값 inviteCode·name·email, `pending: PendingSignup?`(메모리 전용, research R10), `errorMessage`, `fieldErrors`, `attemptCooldown: Cooldown`(현재 단계의 제출 버튼 잠금, 단계가 바뀌면 초기화), `resendCooldown: Cooldown`(재발송 전용 60초), `isSubmitting`). 메서드 `submitCode`, `submitAccount(name, email, password, termsAgreed)`, `verify(code)`, `resend()`(성공 시 `이전 코드는 더 이상 사용할 수 없습니다.` 안내 + 60초 쿨다운; 429면 `resendCooldown`만 `retryAfter`로 설정하고 `attemptCooldown`은 건드리지 않음), `backToCode()`. 클라이언트 검증은 `lib/core/validation/validators.dart`. 분기는 `ErrorCodes`로(`INVALID_INVITE_CODE` → codeEntry, `TOO_MANY_ATTEMPTS` → 현재 단계의 `attemptCooldown`(`retryAfter`), `INVALID_INPUT` → fieldErrors). verify 성공 시 `sessionController.signIn(role, justSignedUp: true)`. Provider는 `NotifierProvider.autoDispose`(가입 화면을 모두 벗어나면 상태 소멸). 비밀번호는 상태에 남기지 않고 제출 시에만 사용.
- [X] T029 [US1] `lib/features/auth/presentation/signup/invite_code_page.dart` 생성 — F1-1(Figma 216-5050)·F1-2(216-5060)·F1-2b(216-5069) 상태: 10자리 입력란(`TextInputFormatter`로 공백 제거·대문자 변환, 10자 제한), 형식 오류 안내, 서버 오류 안내(`코드를 확인해 주세요.`, 사유 구분 없음 FR-016), 잠금 시 `CooldownNotice` + 버튼 비활성(SC-008). 성공 시 `/signup/account`로 push.
- [X] T030 [US1] `lib/features/auth/presentation/signup/account_page.dart` 생성 — F1-3 학부모(Figma 216-5101)·F1-3a 교사(225-1553): `inviteRole`에 따라 제목·안내 문구, null이면 역할 중립 문구(research R5). 입력란은 이름·이메일·비밀번호·약관 동의 체크 + "약관 보기"(→ `/terms`)뿐(FR-014, 연락처·역할·학교 선택 없음). 각 입력란 아래 `FieldErrorText`(서버 fieldErrors 우선). 형식 미충족·약관 미동의·요청 중이면 "동의하고 계정 만들기" 비활성. 성공 시 `/signup/verify`로 push, `INVALID_INVITE_CODE`면 `/signup`으로 돌아가 안내 표시.
- [X] T031 [US1] `lib/features/auth/presentation/signup/verify_page.dart` 생성 — C-2(Figma 224-1185): 6자리 입력, `pending.codeExpiresIn` 기반 `인증 코드는 10분 동안 유효합니다.` 안내, "인증하고 가입 완료", "인증 코드 다시 받기"(60초 `CooldownNotice`, FR-018), 오류 안내, `attemptCooldown` 중에는 `CooldownNotice` + "인증하고 가입 완료" 비활성. `INVALID_INVITE_CODE`면 `/signup`으로 `go`(Edge Case). 성공 후 이동은 라우터 redirect(`/welcome`)에 맡긴다.
- [X] T032 [P] [US1] `lib/features/auth/presentation/welcome_page.dart` 생성 — C-6 담소 이용 안내(Figma 216-5082), 고정 문구(원칙 V). "확인했어요": 세션이 `justSignedUp`이면 `sessionController.acknowledgeWelcome()`(redirect가 역할 홈으로), 아니면 `pop`(관리자 마이페이지에서 열람한 경우).
- [X] T033 [P] [US1] `lib/features/auth/presentation/terms_page.dart` 생성 — C-7 이용약관·개인정보 처리방침(Figma 225-1591), 임시 문안(일반 `Text`, WebView·HTML 렌더 금지), "확인" → `pop`.
- [X] T034 [US1] `lib/app/router.dart`에 경로 추가: `/signup`(`InviteCodePage`), `/signup/account`, `/signup/verify`, `/welcome`, `/terms`. `/signup` 하위를 같은 상위 경로 아래 두어 가입 화면이 쌓여 있는 동안 `signupViewModelProvider`가 유지되게 한다. (depends on T029~T033)

**Checkpoint**: T026·T027 통과, quickstart 시나리오 1~6 mock 재현.

---

## Phase 4: User Story 2 - 로그인하고 역할별 홈으로 들어가며, 세션이 조용히 유지된다 (Priority: P1)

**Goal**: C-1/C-1a 로그인·대기, 역할별 홈 진입, 세션 복구·갱신·만료 처리(F0 세션 검증).

**Independent Test**: mock에서 `parent@`/`teacher@`/`admin@damso.test` + `damso1234` → 각 역할 홈. 틀린 비밀번호·없는 이메일 → 같은 안내. `wait@damso.test` → C-1a 30초 카운트다운. 학부모로 `/admin` 이동 시 학부모 홈 (quickstart 시나리오 7, 8, 11). 401 갱신은 T004로 검증.

### Tests for User Story 2

- [X] T035 [P] [US2] `test/features/auth/login_view_model_test.dart` 작성 — 역할 3종 계정 로그인 → `SignedIn(role)`; 틀린 비밀번호·없는 이메일 → 같은 `errorMessage`(FR-020); `wait@damso.test` → `cooldown.isActive`, 대기 중 `login()` 호출해도 Repository 미호출. 카운트다운 감소·0 도달 후 재시도 허용은 `testWidgets` + `tester.pump(const Duration(seconds: 1))`로 확인(SC-008).

### Implementation for User Story 2

- [X] T036 [US2] `lib/features/auth/presentation/login_view_model.dart` 전면 교체: `LoginState`(`isSubmitting`, `errorMessage`, `fieldErrors`, `cooldown: Cooldown`). `login(email, password)` — `validateEmail`·`validateCurrentPassword` 통과 시에만 호출, 성공 시 `sessionController.signIn(result.role)`, `INVALID_CREDENTIALS` → 서버 message, `TOO_MANY_ATTEMPTS` → `CooldownTimer.start(retryAfter)`(앱은 횟수를 세지 않음, FR-021).
- [X] T037 [US2] `lib/features/auth/presentation/login_page.dart` 전면 교체 — C-1(Figma 224-1169)·C-1a(225-1512): 이메일·비밀번호 입력, "로그인"(요청 중·대기 중 비활성), "비밀번호 재설정" → `/password-reset`, "가입하기" → `/signup`. C-1a 상태는 같은 화면에서 `CooldownNotice`로 서버가 준 남은 시간 표시 — Figma의 "5회 실패, 10분" 고정 문구는 쓰지 않는다. 로그인 성공 후 이동은 redirect에 맡긴다.
- [X] T038 [US2] `lib/app/router.dart`에 `/login` 경로 추가. (depends on T037)
- [X] T039 [US2] `test/widget_test.dart` 새 흐름으로 수정: (1) splash → 시작 → 로그인 `parent@damso.test`/`damso1234` → "학부모 홈" 표시, (2) 틀린 비밀번호 → `이메일 또는 비밀번호가 올바르지 않습니다.`만 표시되고 홈으로 가지 않음, (3) 로그인 후 `GoRouter.of(context).go('/inquiries')` → 기존 mock의 `긴급 문의 예시`·`원문 확인 필요` 표시(FR-013 뼈대 유지). overrides에 `MockAuthRepository(TokenStore(...))`와 기존 `MockInquiryRepository`.

**Checkpoint**: `flutter test` 전체 통과. quickstart 시나리오 7, 8, 11 재현.

---

## Phase 5: User Story 3 - 슈퍼 관리자가 학급·학생을 등록하고 초대 코드를 발행한다 (Priority: P1)

**Goal**: ADM-1a/1b/1c/1/2/5/5a/6/3/3t + 발행 현황. 코드 원문은 발행 완료 화면에서만 1회 표시.

**Independent Test**: mock `admin@damso.test` → 학급 추가 → 학생 3명 등록 → 교사 코드 발행 → 완료 화면에서만 코드 확인 → 뒤로 → 발행 현황에 원문 없음. 미사용 코드 학생 재발행 시 ADM-6 확인 (quickstart 시나리오 12, 13).

### Tests for User Story 3

- [X] T040 [P] [US3] `test/features/admin/invite_issue_test.dart` 작성 — (a) 담임 없는 학급에서 교사 코드 발행 → 발행 완료 화면에 10자리 코드·만료 시각 표시, (b) 완료 화면을 떠난 뒤 학급 상세·발행 현황 화면 위젯 트리와 관련 ViewModel 상태 어디에도 그 코드 문자열이 없음(SC-006), (c) 미사용 코드가 있는 학생의 "재발행"은 ADM-6 확인을 거치기 전 Repository 발행 메서드를 부르지 않음, (d) 3학년 2반에서 교사 코드 발행 → `CLASSROOM_HAS_TEACHER` 서버 안내, 코드 미표시.

### Implementation for User Story 3

- [X] T041 [P] [US3] `lib/features/admin/domain/models.dart` 작성(data-model §6): `AdminClassroom(classroomId, grade, classNumber, homeroomAssigned, studentCount)`, `AdminStudent(studentId, name, guardianLinked)`, `IssuedInviteCode(inviteCodeId, code, expiresAt)` — 주석 "화면 전달만, 보관 금지", `enum InviteCodeKind { teacher, parent }`, `enum InviteCodeState { unused, used, expired, revoked }`, `InviteCodeStatus(inviteCodeId, kind, studentId?, studentName?, status, issuedAt, expiresAt, usedAt?)`.
- [X] T042 [P] [US3] `lib/features/admin/domain/validators.dart` 작성(순수 Dart): `validateGrade`(1~6), `validateClassNumber`(1~20), `parseStudentNames(String raw)` — "줄바꿈으로 구분한 이름 목록 → 앞뒤 공백 제거·빈 줄 제외 → 1~40명, 각 1~20자"(data-model §6), 위반 시 안내 문구.
- [X] T043 [US3] `lib/features/admin/domain/admin_repository.dart` 작성: contracts/api-usage.md admin 표 7개 메서드 — `listClassrooms()`, `createClassroom(int grade, int classNumber)`, `listStudents(String classroomId)`, `registerStudents(String classroomId, List<String> names)`, `issueTeacherInvite(String classroomId)` → `IssuedInviteCode`, `issueParentInvite(String studentId)` → `IssuedInviteCode`, `listInviteCodes(String classroomId)`. (depends on T041)
- [X] T044 [P] [US3] `lib/features/admin/data/admin_repository_impl.dart` 작성: api-usage.md admin 표의 경로 그대로(`/api/v1/admin/classrooms`, `/api/v1/admin/classrooms/{id}/students`, `/api/v1/admin/classrooms/{id}/teacher-invite`, `/api/v1/admin/students/{id}/parent-invite`, `/api/v1/admin/invite-codes?classroomId=`), 응답 → 도메인 모델 변환(시각은 `DateTime.parse(...).toLocal()`), `mapDioErrors`. (depends on T043)
- [X] T045 [P] [US3] `lib/features/admin/data/mock_admin_repository.dart` 작성(quickstart "관리자"): 초기 데이터 — 3학년 2반(담임 있음, 학생 `김하나`(보호자 연결됨), `박서준`(미사용 학부모 코드 있음), `이도윤`(보호자·코드 없음)), 1학년 1반(담임 없음, 학생 0명). 3학년 2반 추가 → 409 `CONFLICT`, 담임 있는 학급 교사 코드 → 409 `CLASSROOM_HAS_TEACHER`, 보호자 있는 학생 학부모 코드 → 409 `STUDENT_HAS_GUARDIAN`, 그 밖 발행 → 허용 문자(`A-HJKMNP-Z2-9`) 랜덤 10자리·만료 24시간 후, 같은 대상의 이전 UNUSED 코드는 REVOKED로. UUID 형식 ID 사용. 메모리 상태. (depends on T043)
- [X] T046 [US3] `lib/features/admin/data/admin_repository_provider.dart` 작성: `Env.useMock`으로 mock/실서버 선택. (depends on T044, T045)
- [X] T047 [P] [US3] `lib/features/admin/presentation/format.dart` 작성: `formatDateTime(DateTime)` → 기기 현지 시간 `yyyy.MM.dd HH:mm`(Dart 코어로 직접, 새 패키지 금지), `inviteStateLabel` — UNUSED "미사용" · USED "사용됨" · EXPIRED "만료" · REVOKED "무효".
- [X] T048 [US3] `lib/features/admin/presentation/admin_home_view_model.dart` 작성 + `admin_home_page.dart` 내용 채움 — ADM-1a(Figma 216-5699)·ADM-1b(216-5716): `AsyncView`로 학급 목록(학년·반, 담임 연결 여부, 학생 수), 빈 상태 안내, "학급 추가" → `/admin/classrooms/new`, 학급 탭 → `/admin/classrooms/:classroomId`. 문의 관련 정보 없음(FR-037). (depends on T046)
- [X] T049 [US3] `lib/features/admin/presentation/classroom_new_page.dart` + `classroom_new_view_model.dart` 작성 — ADM-1c(Figma 225-1862): 학년 1~6·반 1~20 선택, `CONFLICT` 등 서버 message 표시, 성공 시 목록 provider invalidate 후 `pop`. (depends on T042, T046)
- [X] T050 [US3] `lib/features/admin/presentation/classroom_detail_page.dart` + `classroom_detail_view_model.dart` 작성 — ADM-1(Figma 224-1343)·ADM-2(224-1374): 학생 명단(이름·보호자 연결 여부), 담임 없음이면 "교사 초대코드 발행" 버튼, 보호자 미연결 학생마다 "학부모 코드 발행" 버튼; 해당 대상에 UNUSED 코드가 있으면(`listInviteCodes` 결과로 판단) 버튼이 "재발행"이 되어 `/admin/invite/confirm`으로 이동, 없으면 바로 발행 후 `/admin/invite/issued`로 `extra` 전달. "학생 등록" → `.../students/new`, "발행 현황" → `.../invite-codes`. ViewModel 상태에 `IssuedInviteCode`를 담지 않는다(발행 메서드는 결과를 반환만). (depends on T046)
- [X] T051 [US3] `lib/features/admin/presentation/students_new_page.dart` + `students_new_view_model.dart` 작성 — ADM-5(Figma 216-5736) 여러 줄 입력(`parseStudentNames`), ADM-5a(216-5748) 등록 완료 상태(등록된 이름 목록, "학급 명단으로"). 성공 시 학생 목록·학급 목록 invalidate. (depends on T042, T046)
- [X] T052 [US3] `lib/features/admin/presentation/reissue_confirm_page.dart` 작성 — ADM-6(Figma 216-5761): `extra`로 대상(교사 코드: classroomId / 학부모 코드: studentId·학생 이름) 수신, `이전 코드는 즉시 무효가 됩니다.` 안내, "새 코드 발행" → ViewModel 경유 발행 → `/admin/invite/issued`로 `pushReplacement`(뒤로 가기로 확인 화면에 돌아오지 않게), "취소" → `pop`. 학생 이름·코드는 URL에 넣지 않는다. (depends on T050)
- [X] T053 [US3] `lib/features/admin/presentation/invite_issued_page.dart` 작성 — ADM-3 학부모(Figma 216-5828)·ADM-3t 교사(227-1743): `GoRouterState.extra`의 `IssuedInviteCode`만 사용(Provider·저장소 보관 금지, research R11). 코드 10자리·만료 시각(`formatDateTime`), `이 화면을 떠나면 코드를 다시 볼 수 없습니다.` 안내, "복사"(`Clipboard.setData` 후 스낵바 `복사했습니다.`), "목록으로" → 학급 상세로. `extra`가 없으면(재진입·딥링크) `다시 볼 수 없는 코드입니다.`와 뒤로 버튼만. (depends on T047)
- [X] T054 [US3] `lib/features/admin/presentation/invite_codes_page.dart` + `invite_codes_view_model.dart` 작성 — 발행 현황: 코드별 종류·대상 학생·상태 라벨·발행·만료·사용 시각(`format.dart`), 코드 원문 없음(FR-036). `AsyncView` 사용. (depends on T046, T047)
- [X] T055 [US3] `lib/app/router.dart`에 관리자 경로 추가: `/admin/classrooms/new`, `/admin/classrooms/:classroomId`, `/admin/classrooms/:classroomId/students/new`, `/admin/classrooms/:classroomId/invite-codes`, `/admin/invite/confirm`, `/admin/invite/issued`. (depends on T048~T054)

**Checkpoint**: T040 통과, quickstart 시나리오 12, 13 재현.

---

## Phase 6: User Story 4 - 학부모가 홈에서 담임을 보고, 자녀를 추가로 연결한다 (Priority: P2)

**Goal**: F2-1/F2-1b 학부모 홈(자녀·담임 카드), F2-1a 자녀 선택, F2-7 마이페이지(연결된 자녀 진입), F1-4 연결된 자녀, F1-5 자녀 추가.

**Independent Test**: mock `parent@` → 자녀 2명, 한 명은 담임 없음 안내, 이메일 미표시. `newparent@` → 빈 상태. 연결된 자녀에서 `PARENTCDE2` 추가 / `TEACHERCD2` 같은 실패 안내 / `ZZZZZZZZZZ` 잠금 (quickstart 시나리오 14, 15).

### Tests for User Story 4

- [X] T056 [P] [US4] `test/features/parent/parent_home_test.dart` 작성 — (a) `mock:parent` 세션: 자녀 이름·학년·반, 담임 표시 이름·소개, 담임 없는 자녀 카드에 `담임 선생님이 아직 연결되지 않았습니다.`, 화면 어디에도 `@` 문자 없음(FR-038, SC-005), (b) 자녀 선택으로 표시 자녀 변경, (c) `mock:newparent`: 자녀 추가 안내, (d) 자녀 추가 `TEACHERCD2` → `코드를 확인해 주세요.`.

### Implementation for User Story 4

- [X] T057 [P] [US4] `lib/features/parent/domain/child.dart` 작성(data-model §4): `ClassroomRef(classroomId, grade, classNumber)`, `TeacherPublicProfile(displayName, introduction)`, `Child(studentId, studentName, classroom, teacher: TeacherPublicProfile?)` — teacher null = 담임 없음.
- [X] T058 [US4] `lib/features/parent/domain/parent_repository.dart` 작성: `Future<List<Child>> listChildren()`, `Future<Child> linkChild(String inviteCode)` (api-usage.md parent 표). (depends on T057)
- [X] T059 [P] [US4] `lib/features/parent/data/parent_repository_impl.dart` 작성: `GET /api/v1/parent/children`, `POST /api/v1/parent/children`(본문 필드명은 openapi), `mapDioErrors`. (depends on T058)
- [X] T060 [P] [US4] `lib/features/parent/data/mock_parent_repository.dart` 작성: 생성자 `(TokenStore tokens, void Function() onSessionExpired)`. `tokens.accessToken` 기준 — `mock:parent`(및 `mock:signup-parent`): 자녀 `김하나`(3학년 2반, 담임 `이담임` / 소개 `아이들과 천천히 이야기 나누는 담임입니다.`), `김두리`(1학년 1반, 담임 없음); `mock:newparent`: 0명; `mock:expired`: `onSessionExpired()` 호출 후 401 `UNAUTHORIZED` throw(research R8, US8-2); `mock:refresh`: 첫 `listChildren` 호출에서만 600ms 추가 지연 후 `parent@`와 같은 자녀 목록 반환(갱신 성공 재현, US8-2·US2-5). 갱신 여부는 mock 내부 `_refreshSimulated` 플래그로만 기록하고 `TokenStore`는 바꾸지 않는다(토큰 갱신은 인터셉터 한 곳에서만, research R8). `linkChild`: `PARENTCDE2` → 새 자녀 추가, `ZZZZZZZZZZ` → 429 `retryAfter: 600s`, 그 밖(교사 코드 포함) → 400 `INVALID_INVITE_CODE` `코드를 확인해 주세요.`. 이메일 필드 없음. (depends on T058)
- [X] T061 [US4] `lib/features/parent/data/parent_repository_provider.dart` 작성: mock에 `tokenStoreProvider`와 `() => ref.read(sessionControllerProvider.notifier).expire()` 전달. (depends on T059, T060)
- [X] T062 [US4] `lib/features/parent/presentation/parent_home_view_model.dart` 작성 + `parent_home_page.dart` 내용 채움 — F2-1(Figma 216-5162)·F2-1b(216-5199): `AsyncNotifier`로 자녀 목록, 선택 자녀(기본 첫 번째, 메모리), 선택 자녀 카드(이름·학년·반, 탭 → `/parent/children/select`), 담임 카드(표시 이름·소개) 또는 담임 없음 안내, 자녀 0명이면 자녀 추가 안내(→ `/parent/children/add`). 문의 작성·최근 문의 영역은 두지 않는다(FR-028). AppBar 마이페이지 → `/parent/me`. (depends on T061)
- [X] T063 [US4] `lib/features/parent/presentation/child_select_page.dart` 작성 — F2-1a(Figma 216-5183): 자녀 목록에서 선택 → `parentHomeViewModel`의 선택 자녀 변경 후 `pop`, "자녀 추가 연결" → `/parent/children/add`. (depends on T062)
- [X] T064 [US4] `lib/features/parent/presentation/parent_my_page.dart` 작성 — F2-7(Figma 224-1228) 1차: "연결된 자녀" → `/parent/children` 메뉴만. 나머지 메뉴는 US7 T094에서 추가, 알림 설정은 F2.
- [X] T065 [US4] `lib/features/parent/presentation/children_page.dart` + `children_view_model.dart` 작성 — F1-4(Figma 224-1210): `AsyncView`로 자녀 목록(이름·학년·반, 담임 표시 이름), "초대코드로 자녀 추가" → `/parent/children/add`. (depends on T061)
- [X] T066 [US4] `lib/features/parent/presentation/add_child_page.dart` + `add_child_view_model.dart` 작성 — F1-5(Figma 225-1692): 초대 코드 입력(`normalizeInviteCode`·`validateInviteCode`, 대문자·공백 제거 formatter), `INVALID_INVITE_CODE`는 사유 구분 없는 같은 안내(FR-016·FR-027), 429는 `CooldownTimer` + `CooldownNotice`, 성공 시 자녀 목록·홈 provider invalidate 후 `pop`. (depends on T061)
- [X] T067 [US4] `lib/app/router.dart`에 `/parent/children/select`, `/parent/me`, `/parent/children`, `/parent/children/add` 추가. (depends on T062~T066)

**Checkpoint**: T056 통과, quickstart 시나리오 14, 15 재현.

---

## Phase 7: User Story 5 - 교사가 공개 프로필을 관리하고 학부모 연결 현황을 본다 (Priority: P2)

**Goal**: F3-4 교사 홈(진입), F3-7 마이페이지(프로필·연결 현황 진입), F3-9 공개 프로필 편집, F3-10 연결 현황.

**Independent Test**: mock `teacher@` → 프로필 저장 후 다시 열면 반영, 소개 61자 저장 불가·글자 수 표시, 연결 현황 연결됨·미연결. `noclass@` → 연결 현황 403 서버 안내 (quickstart 시나리오 16, 17).

### Tests for User Story 5

- [X] T068 [P] [US5] `test/features/teacher/profile_edit_test.dart` 작성 — (a) 소개 61자 입력 시 초과 글자 수 표시 + 저장 버튼 비활성(US5-2), (b) 표시 이름 1~20자·소개 60자 저장 → 화면 재진입 시 값 유지, (c) `mock:noclass` 세션에서 연결 현황 → 서버 `FORBIDDEN` message 표시, (d) 연결 현황에 학부모 이름·`@` 없음(FR-030).

### Implementation for User Story 5

- [X] T069 [P] [US5] `lib/features/teacher/domain/models.dart`·`validators.dart` 작성(data-model §5): `TeacherProfile(displayName, introduction)`, `StudentLink(studentId, name, guardianLinked)`, `MyClassroom(classroom: ClassroomRef 동등 필드 grade·classNumber·classroomId, students)`; `validateDisplayName`(1~20자), `validateIntroduction`(0~60자, `runes.length`). 다른 feature 모델을 import하지 않고 필요한 필드를 이 파일에 정의한다.
- [X] T070 [US5] `lib/features/teacher/domain/teacher_repository.dart` 작성: `getProfile()`, `updateProfile(TeacherProfile)`, `getMyClassroom()` (api-usage.md teacher 표). (depends on T069)
- [X] T071 [P] [US5] `lib/features/teacher/data/teacher_repository_impl.dart` 작성: `GET`/`PUT /api/v1/teacher/profile`, `GET /api/v1/teacher/classroom`, `mapDioErrors`. (depends on T070)
- [X] T072 [P] [US5] `lib/features/teacher/data/mock_teacher_repository.dart` 작성: 생성자 `(TokenStore tokens)`. 프로필 초기값 `이담임` / `아이들과 천천히 이야기 나누는 담임입니다.`(메모리에서 수정 반영), 담당 학급 3학년 2반 학생 `김하나`(연결됨)·`박서준`(미연결)·`이도윤`(미연결). `tokens.accessToken == 'mock:noclass'`이면 `getMyClassroom`이 403 `FORBIDDEN` `권한이 없습니다.`(openapi `Forbidden` 예시) throw(research R8). (depends on T070)
- [X] T073 [US5] `lib/features/teacher/data/teacher_repository_provider.dart` 작성. (depends on T071, T072)
- [X] T074 [US5] `lib/features/teacher/presentation/teacher_home_page.dart` 내용 채움 — F3-4(Figma 216-5567) 진입 화면만: 인사 문구, AppBar 마이페이지 → `/teacher/me`. 문의 관련 영역 없음(FR-031).
- [X] T075 [US5] `lib/features/teacher/presentation/teacher_my_page.dart` 작성 — F3-7(Figma 224-1263) 1차: "공개 프로필" → `/teacher/profile`, "학부모 연결 현황" → `/teacher/links`. 나머지 메뉴는 US7 T095, 응답 가능 시간·알림은 F2.
- [X] T076 [US5] `lib/features/teacher/presentation/profile_edit_page.dart` + `profile_edit_view_model.dart` 작성 — F3-9(Figma 224-1317): 표시 이름·소개 입력, 소개 글자 수 `n/60`(초과 시 강조), 검증 실패·요청 중 저장 비활성, `INVALID_INPUT` fieldErrors 표시, 저장 성공 시 `pop`. 사진 없음(FR-029). (depends on T069, T073)
- [X] T077 [US5] `lib/features/teacher/presentation/links_page.dart` + `links_view_model.dart` 작성 — F3-10(Figma 216-5666): 담당 학급(학년·반), 학생별 연결됨·미연결, 안내 문구 `코드 재발행이 필요하면 학교 관리자에게 요청해 주세요.`(요청 버튼 없음, F3-10a 범위 밖). `AsyncView`로 403 서버 message 표시. 학부모 이름·이메일 없음. (depends on T073)
- [X] T078 [US5] `lib/app/router.dart`에 `/teacher/me`, `/teacher/profile`, `/teacher/links` 추가. (depends on T074~T077)

**Checkpoint**: T068 통과, quickstart 시나리오 16, 17 재현.

---

## Phase 8: User Story 6 - 비밀번호를 재설정한다 (Priority: P2)

**Goal**: C-3 → C-3b/C-3c → C-4 → C-5. 로그인 상태에서 진입했으면 완료 후 이 기기도 로그아웃.

**Independent Test**: mock에서 아무 이메일 → 같은 안내 → `123456` → 새 비밀번호 → 완료. 틀린 코드 안내, `000000` → C-3c (quickstart 시나리오 18).

### Tests for User Story 6

- [X] T079 [P] [US6] `test/features/auth/password_reset_view_model_test.dart` 작성 — data-model §2 "비밀번호 재설정 상태" 전이: 이메일 제출 → codeEntry, `123456` → newPassword, 그 밖 → codeEntry(error), `000000` → expiredOrLocked, 새 비밀번호 `abcd1234` → done; 시작 시 세션이 `SignedIn`이면 done 후 `SignedOut`, `SignedOut`이면 그대로.

### Implementation for User Story 6

- [X] T080 [US6] `lib/features/auth/presentation/password_reset/password_reset_view_model.dart` 작성: 상태(step `emailEntry|codeEntry|expiredOrLocked|newPassword|done`, email, 확인된 code(메모리), `errorMessage`, `fieldErrors`, `isSubmitting`, `cooldown`). `requestReset(email)`(가입 여부와 무관하게 성공 안내 `입력한 이메일로 안내를 보냈습니다.`, FR-023), `verifyCode(code)`, `resendCode()`(→ `requestPasswordReset` 재호출 후 codeEntry), `confirm(newPassword)`(`validateNewPassword`, 성공 시 세션이 `SignedIn`이면 `sessionController.signOut()`, FR-025; `INVALID_VERIFICATION_CODE`·`TOO_MANY_ATTEMPTS`면 그사이 코드가 만료된 것으로 보고 expiredOrLocked(C-3c)). `NotifierProvider.autoDispose`.
- [X] T081 [US6] `lib/features/auth/presentation/password_reset/email_page.dart` 작성 — C-3(Figma 216-5029): 이메일 입력, "재설정 코드 받기" → 성공 안내 후 `/password-reset/code`.
- [X] T082 [US6] `lib/features/auth/presentation/password_reset/code_page.dart` 작성 — C-3b(Figma 216-5039)·C-3c(216-5143): 6자리 입력·"코드 확인" → `/password-reset/new`; expiredOrLocked 상태면 C-3c 안내 + "코드 다시 받기"(`resendCode`)·"로그인으로"(→ `/`) (FR-024).
- [X] T083 [US6] `lib/features/auth/presentation/password_reset/new_password_page.dart` 작성 — C-4(Figma 216-5115): 새 비밀번호(정책 안내 `영문과 숫자를 포함해 8~64자`), `FieldErrorText`, "비밀번호 변경" → `/password-reset/done`(`go`).
- [X] T084 [US6] `lib/features/auth/presentation/password_reset/done_page.dart` 작성 — C-5(Figma 216-5128): `모든 기기에서 로그아웃되었습니다. 새 비밀번호로 다시 로그인해 주세요.` 안내, "로그인하기" → `/`.
- [X] T085 [US6] `lib/app/router.dart`에 `/password-reset`, `/password-reset/code`, `/password-reset/new`, `/password-reset/done` 추가 — 로그인·비로그인 모두 접근 가능(contracts/routes.md, T005 규칙과 일치). (depends on T081~T084)

**Checkpoint**: T079 통과, quickstart 시나리오 18 재현.

---

## Phase 9: User Story 8 - 서버 없이 mock으로 모든 상태를 시연한다 (Priority: P2)

**Goal**: US1~US7의 정상·오류·잠금·권한 없음·세션 만료 상태를 mock 실행만으로 재현(FR-012, SC-007).

**Independent Test**: quickstart 데모 입력표의 모든 행이 mock에서 문서대로 동작한다. `expired@` → 로그인 화면, `refresh@` → 오류 없이 홈, `noclass@` → 403 안내.

### Tests for User Story 8

- [X] T086 [P] [US8] `test/features/mock_scenarios_test.dart` 위젯 테스트 작성 — 앱 전체를 mock override로 실행: (a) `expired@damso.test` 로그인 → 학부모 홈 조회 중 세션 만료 → 로그인 화면(C-1), 다시 `/parent` 이동 시 로그인 화면 유지(US8-2), (b) `noclass@damso.test` 로그인 → 마이페이지 → 학부모 연결 현황 → `권한이 없습니다.`(openapi `Forbidden` 예시)(US8-3), (c) `wait@damso.test` → 대기 안내, (d) 가입 `ZZZZZZZZZZ` → 잠금 안내(US8-1), (e) `refresh@damso.test` 로그인 → 학부모 홈에 자녀 목록 표시, 오류 안내 없음, 세션은 `SignedIn(parent)` 유지(US8-2 갱신 성공).

### Implementation for User Story 8

- [X] T087 [US8] mock 구현 4종(`lib/features/auth/data/mock_auth_repository.dart`, `lib/features/admin/data/mock_admin_repository.dart`, `lib/features/parent/data/mock_parent_repository.dart`, `lib/features/teacher/data/mock_teacher_repository.dart`)을 `specs/001-foundation-auth-signup/quickstart.md` "mock 데모 입력" 표와 행 단위로 대조하고, 빠진 분기를 채운다(재설정 코드 확인에서 `999999`는 일반 `INVALID_VERIFICATION_CODE`로 처리 — `INVALID_INVITE_CODE`는 가입 인증 전용).
- [X] T088 [US8] `specs/001-foundation-auth-signup/quickstart.md` "mock 데모 입력"에 구현에서 정한 값을 추가: 가입 이메일 `invalid@damso.test` → 400 `INVALID_INPUT` fieldErrors(US1-7), mock 초기 학급·학생 이름(3학년 2반 `김하나`·`박서준`·`이도윤`, 1학년 1반).

**Checkpoint**: T086 통과, quickstart 시나리오 1~18 mock 재현.

---

## Phase 10: User Story 7 - 마이페이지에서 내 정보·로그아웃·탈퇴를 관리한다 (Priority: P3)

**Goal**: C-9 계정 정보(이름 수정), 로그아웃, C-8 탈퇴, 역할별 마이페이지 메뉴 완성(F2-7·F3-7·ADM-7).

**Independent Test**: mock에서 이름 수정 반영, 로그아웃 → 시작 화면, 탈퇴 틀린 비밀번호 → 안내 / `damso1234` → 시작 화면, 관리자 마이페이지에 탈퇴 메뉴 없음 (quickstart 시나리오 19, 20).

### Implementation for User Story 7

- [X] T089 [P] [US7] `lib/features/me/domain/me.dart`·`me_repository.dart` 작성(data-model §3): `Me(userId, name, email, role: Role)` — email은 본인 것만; 인터페이스 `getMe()`, `updateName(String name)` → `Me`, `withdraw(String password)`.
- [X] T090 [P] [US7] `lib/features/me/data/me_repository_impl.dart` 작성: `GET`/`PATCH /api/v1/me`, `POST /api/v1/me/withdrawal`(204 후 `TokenStore.clear()`), `mapDioErrors`. (depends on T089)
- [X] T091 [P] [US7] `lib/features/me/data/mock_me_repository.dart` 작성: 생성자 `(TokenStore tokens)`, `accessToken`의 `mock:<이름>`으로 데모 계정의 이름·이메일·역할 반환(예: `mock:parent` → `김학부모`, `parent@damso.test`, PARENT; `mock:refresh`·`mock:expired`·`mock:newparent` → 학부모, 이메일 `<이름>@damso.test`; `mock:signup-parent`/`mock:signup-teacher` → `가입한 학부모`/`가입한 교사`, `signup@damso.test`), 이름 수정 메모리 반영, 탈퇴 비밀번호 `damso1234` 성공 / 그 밖 401 `INVALID_CREDENTIALS` / SUPER_ADMIN이면 403 `FORBIDDEN`. (depends on T089)
- [X] T092 [US7] `lib/features/me/data/me_repository_provider.dart` 작성. (depends on T090, T091)
- [X] T093 [US7] `lib/features/me/presentation/me_view_model.dart` 작성: `AsyncNotifier<Me>` — `updateName(name)`(`validateName`), `logout()`(`authRepository.logout()`을 `try`, `finally`에서 `sessionController.signOut()` — 서버 실패해도 기기 세션 삭제, FR-022), `withdraw(password)`(`validateCurrentPassword`, 성공 시 `sessionController.signOut()`, `INVALID_CREDENTIALS`면 서버 message). (depends on T092)
- [X] T094 [US7] `lib/features/parent/presentation/parent_my_page.dart` 메뉴 완성 — F2-7(Figma 224-1228): 상단에 본인 이름·이메일·역할(`meViewModelProvider`) + 연결된 자녀의 학년·반(`childrenViewModelProvider`, T065 재사용), 메뉴 "계정 정보"(→ `/me/account`), "연결된 자녀", "비밀번호 변경"(→ `/password-reset`, FR-040), "약관"(→ `/terms`), "로그아웃", "회원 탈퇴"(→ `/me/withdraw`). (depends on T093)
- [X] T095 [US7] `lib/features/teacher/presentation/teacher_my_page.dart` 메뉴 완성 — F3-7(Figma 224-1263): 상단 본인 정보(`meViewModelProvider`) + 담당 학급(`linksViewModelProvider`, T077 재사용; 403이면 학급 표시 생략), 메뉴 "계정 정보", "공개 프로필", "학부모 연결 현황", "비밀번호 변경", "약관", "로그아웃", "회원 탈퇴". (depends on T093)
- [X] T096 [US7] `lib/features/admin/presentation/admin_my_page.dart` 작성 — ADM-7(Figma 216-5790): 메뉴 "계정 정보", "비밀번호 재설정"(→ `/password-reset`), "담소 이용 안내"(→ `/welcome` push), "로그아웃". **탈퇴 메뉴 없음**(FR-039). `admin_home_page.dart` AppBar에 마이페이지 → `/admin/me` 버튼 추가. (depends on T093)
- [X] T097 [US7] `lib/features/me/presentation/account_page.dart` 작성 — C-9(Figma 225-1658): 이름·이메일·역할 표시, 이름 수정(1~20자, `FieldErrorText`, 요청 중 비활성), 전화번호·주소 입력란 없음. (depends on T093)
- [X] T098 [US7] `lib/features/me/presentation/withdraw_page.dart` 작성 — C-8(Figma 225-1623): 임시 안내 문안, 현재 비밀번호 입력, "취소" → `pop`, "탈퇴하기"(요청 중 비활성), 오류 시 서버 message. (depends on T093)
- [X] T099 [US7] `lib/app/router.dart`에 `/me/account`, `/me/withdraw`, `/admin/me` 추가. (depends on T096~T098)

**Checkpoint**: quickstart 시나리오 19, 20 재현.

---

## Phase 11: Polish & Cross-Cutting Concerns

- [X] T100 [P] 민감정보 출력 점검: `lib/`에서 `print(`, `debugPrint(`, `log(`, `toString()`을 화면 문자열로 쓰는 곳 검색 → 없어야 한다(FR-005, SC-004). 결과를 PR 설명에 적는다.
- [X] T101 [P] 연락처·타인 이메일 점검: `lib/features/`에서 `phone`, `전화`, `주소`, `address` 입력란 0개, 다른 사용자 이메일 표시 0개(SC-005) 확인.
- [X] T102 [P] 계약 점검: `lib/features/*/data/*_repository_impl.dart`의 경로 문자열이 contracts/api-usage.md와 일치하는지 대조, `git diff --stat main -- docs/api/openapi.yaml`이 비어 있는지 확인(FR-011).
- [X] T103 [P] 설계 문서 대조: 실제로 만든 파일 목록과 `specs/001-foundation-auth-signup/plan.md` Project Structure를 비교해 차이가 있으면 plan을 갱신한다(검증 함수 위치·splash ViewModel·admin/teacher validators·format·테스트 경로는 2026-10-26에 이미 반영됨).
- [X] T104 `flutter analyze` 실행 → 경고·오류 0. 실패는 숨기지 않고 보고한다.
- [X] T105 `flutter test` 실행 → 전부 통과.
- [X] T106 `flutter run --dart-define=USE_MOCK=true`로 `quickstart.md` 검증 시나리오 1~20을 수동 확인하고 결과(통과/실패·사유)를 PR 설명에 적는다.

---

## Phase 12: api-v0.4 초대 코드 확인 API 반영

**Purpose**: `POST /api/v1/auth/invite-codes/verify`(요청 `inviteCode`·`email` 필수, 응답 `role`, 실패는 이메일 기준으로 가입 1단계와 합산) 실서버 연결. spec FR-019·Clarifications 2026-10-26.

- [X] T107 `lib/features/auth/domain/auth_repository.dart`: `checkInviteCode({required String code, required String email})` → `Future<InviteRole>`(null 제거). `lib/features/auth/domain/models.dart` 주석 갱신.
- [X] T108 `lib/features/auth/data/auth_repository_impl.dart`: 🔓 `POST /api/v1/auth/invite-codes/verify` 본문 `{inviteCode, email}` 호출, `role` → `InviteRole`. `lib/features/auth/data/mock_auth_repository.dart`: 시그니처 변경, `invalid@damso.test` 필드 오류를 코드 확인 단계에서도 재현.
- [X] T109 `lib/core/network/auth_interceptor.dart` 공개 경로에 `/api/v1/auth/invite-codes/verify` 추가, `test/core/auth_interceptor_test.dart` 공개 경로 목록 갱신.
- [X] T110 `lib/features/auth/presentation/signup/signup_view_model.dart`: `submitCode(code:, email:)`(이메일 검증·보관), `submitAccount`는 보관한 이메일 사용(이메일 인자 제거).
- [X] T111 `lib/features/auth/presentation/signup/invite_code_page.dart`(F1-1)에 이메일 입력 추가, `account_page.dart`(F1-3/F1-3a)는 이메일을 읽기 전용으로 표시하고 역할 모름(중립) 문구 제거.
- [X] T112 테스트 갱신: `test/features/auth/signup_view_model_test.dart`, `test/features/auth/signup_flow_test.dart`, `test/features/mock_scenarios_test.dart`.
- [X] T114 에뮬레이터 E2E에서 발견: 인증 중 초대 코드 무효 → F1-1 복귀를 `context.go('/signup')`으로 하면 스택이 교체되어 시작 화면이 사라지고 시스템 뒤로 가기에 앱이 닫힘. `verify_page.dart`가 `pop(SignupOutcome.backToCode)`를 돌려주고 `account_page.dart`가 이어서 pop 하도록 수정.
- [X] T113 설계 문서 갱신: spec FR-019·Assumptions·Clarifications, research R5, data-model 가입 상태, contracts/api-usage.md·routes.md, quickstart, plan.md. 확정된 제안 문서 `contracts/invite-code-check.proposal.md`는 삭제(원본 계약은 `docs/api/openapi.yaml`).

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: 의존 없음.
- **Foundational (Phase 2)**: Setup 후. **모든 Story를 막는다.**
- **US1 (Phase 3), US2 (Phase 4), US3 (Phase 5)**: Foundational 후 시작 가능. 서로 독립(공유 파일은 `lib/app/router.dart`뿐 — 경로 추가 작업만 순서 조정).
- **US4 (Phase 6), US5 (Phase 7), US6 (Phase 8)**: Foundational 후 시작 가능. US1~US3과 독립.
- **US8 (Phase 9)**: US1~US6의 mock 구현이 있어야 의미가 있다(T086은 US2·US4·US5 화면 사용).
- **US7 (Phase 10)**: Foundational 후 가능하지만 T094·T095는 US4의 `parent_my_page.dart`(T064)·US5의 `teacher_my_page.dart`(T075)를 확장하므로 그 뒤.
- **Polish (Phase 11)**: 원하는 Story 완료 후.

### User Story Dependencies

| Story | 선행 | 비고 |
|---|---|---|
| US1 (P1) | Phase 2 | 역할 홈은 T024 자리 화면으로 확인 가능 |
| US2 (P1) | Phase 2 | T039가 `widget_test.dart`를 새 흐름으로 고침 |
| US3 (P1) | Phase 2 | 관리자 마이페이지 진입은 US7 T096 |
| US4 (P2) | Phase 2 | |
| US5 (P2) | Phase 2 | |
| US6 (P2) | Phase 2 | 마이페이지 진입 링크는 US7 |
| US8 (P2) | US2, US4, US5 (+ US1·US3 mock) | |
| US7 (P3) | Phase 2, US4 T064, US5 T075 | |

### Within Each Story

- 테스트 작성 → 실패 확인 → 모델 → Repository 인터페이스 → 구현(실서버·mock) → provider → ViewModel → 화면 → 라우터 경로 추가.

### 같은 파일을 고치는 작업 (병렬 금지)

- `lib/app/router.dart`: T025 → T034 → T038 → T055 → T067 → T078 → T085 → T099
- `lib/features/auth/presentation/login_view_model.dart`: T017(컴파일 맞춤) → T036
- `lib/features/parent/presentation/parent_my_page.dart`: T064 → T094
- `lib/features/teacher/presentation/teacher_my_page.dart`: T075 → T095
- `lib/features/admin/presentation/admin_home_page.dart`: T024 → T048 → T096
- `lib/core/network/dio_provider.dart`: T010 → T021

### Parallel Opportunities

- Phase 2: T003·T004·T005·T006(테스트) 동시, T008·T009·T013·T014·T015·T016 동시.
- Foundational 후 US1·US2·US3·US4·US5·US6을 각각 다른 사람이 병렬 진행 가능(라우터 경로 추가만 순서대로 병합).
- Story 내부: `[P]` 표시된 모델·실서버 구현·mock 구현·테스트.

---

## Parallel Example: Phase 2 (Foundational)

```text
# 테스트 4개 동시 작성
Task: "T003 test/core/app_exception_test.dart"
Task: "T004 test/core/auth_interceptor_test.dart"
Task: "T005 test/core/router_redirect_test.dart"
Task: "T006 test/core/validators_test.dart"

# 서로 독립인 core 파일 동시 작성
Task: "T008 lib/core/session/role.dart"
Task: "T009 lib/core/session/session_state.dart"
Task: "T013 lib/core/validation/validators.dart"
Task: "T014 lib/core/widgets/cooldown.dart"
Task: "T015 lib/core/widgets/async_view.dart"
Task: "T016 lib/core/widgets/field_error_text.dart"
```

## Parallel Example: User Story 3

```text
Task: "T040 test/features/admin/invite_issue_test.dart"
Task: "T041 lib/features/admin/domain/models.dart"
Task: "T042 lib/features/admin/domain/validators.dart"
# T043 이후
Task: "T044 lib/features/admin/data/admin_repository_impl.dart"
Task: "T045 lib/features/admin/data/mock_admin_repository.dart"
Task: "T047 lib/features/admin/presentation/format.dart"
```

## Parallel Example: User Story 4

```text
Task: "T056 test/features/parent/parent_home_test.dart"
Task: "T057 lib/features/parent/domain/child.dart"
# T058 이후
Task: "T059 lib/features/parent/data/parent_repository_impl.dart"
Task: "T060 lib/features/parent/data/mock_parent_repository.dart"
```

---

## Implementation Strategy

### MVP First (Phase 1 → 2 → US1)

1. Phase 1 Setup
2. Phase 2 Foundational — `test/core` 통과까지
3. Phase 3 US1 — mock 가입 → 이용 안내 → 학부모 홈(자리 화면)
4. **멈추고 확인**: T026·T027 통과, quickstart 1~6

### 시연 가능한 최소 묶음 (P1 전부)

US1 + US2 + US3까지 끝내면 "관리자 코드 발행(1회 표시)", "데모 코드 `PARENTCDE2`·`TEACHERCD2`로 가입 → 역할 홈", "역할별 로그인"을 mock으로 시연할 수 있다. mock끼리 상태를 공유하지 않으므로 관리자가 발행한 코드로는 mock 가입이 되지 않는다(실서버에서는 된다).

### Incremental Delivery

1. Setup + Foundational → 기반 완료
2. US1 → US2 → US3 (P1, 시연 묶음)
3. US4 → US5 → US6 (P2)
4. US8 (mock 시나리오 전수 확인)
5. US7 (P3)
6. Polish → PR (`Closes #5`)

---

## Notes

- 초대 코드 확인 API는 api-v0.4에서 확정되어 Phase 12에서 반영했다(요청에 이메일 필수 → F1-1에서 함께 입력).
- 기존 뼈대(`lib/features/inquiry`, `history`, `reply`)는 고치지 않는다(FR-013). `/inquiries` 경로만 PARENT·TEACHER에게 임시로 열어 둔다.
- 커밋은 작업 또는 논리 묶음 단위로, 사용자 요청이 있을 때만 `Feat : <요약>` 형식으로 한다.
