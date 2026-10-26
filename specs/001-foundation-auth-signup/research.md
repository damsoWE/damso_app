# Research: 공통 기반 반영 및 인증·회원가입·학급 연결 화면 (F0·F1)

**Feature**: [spec.md](./spec.md) · **Plan**: [plan.md](./plan.md) · **Date**: 2026-10-25

새 패키지는 추가하지 않는다. 기존 의존성(`flutter_riverpod` 3, `go_router` 17, `dio` 5, `flutter_secure_storage` 11)과 Dart 코어 라이브러리로 해결한다.

---

## R1. API 기본 경로 `/api/v1`을 어디에 붙이나

- **Decision**: `API_BASE_URL`은 호스트(예: `http://10.0.2.2:8080`)만 담고, 코드의 경로는 `openapi.yaml`에 적힌 그대로(`/api/v1/auth/login`) 쓴다.
- **Rationale**: 명세의 경로 문자열을 코드에서 그대로 검색할 수 있어 계약 변경 추적이 쉽다. 명세에 `/actuator/health`처럼 `/api/v1` 밖의 경로도 있어 base URL에 넣으면 예외가 생긴다.
- **Alternatives**: base URL에 `/api/v1` 포함 — 경로가 짧아지지만 health 경로를 따로 다뤄야 하고 명세와 문자열이 달라진다.

## R2. 세션 상태와 역할은 어디서 관리하나

- **Decision**: `lib/core/session/`에 세션 상태(`SessionState`: 확인 중 / 로그아웃 / 로그인(role))와 이를 관리하는 `SessionController`(Riverpod `Notifier`)를 둔다. 라우터·인터셉터·여러 기능(auth, me)이 함께 쓰므로 core에 둔다.
  - 역할은 저장하지 않는다. 앱 시작 시 저장된 갱신 토큰으로 `POST /api/v1/auth/token/refresh`를 호출해 새 토큰과 `role`을 함께 받는다(`TokenResponse.role`).
  - 시작 시 저장된 갱신 토큰이 없으면 로그아웃 상태(시작 화면)로, 갱신이 **401**이면 세션 만료 상태(로그인 화면)로, **네트워크 오류**면 저장된 토큰을 지우지 않고 "연결할 수 없음 + 다시 시도" 화면을 보인다(오프라인일 때 로그인이 풀리지 않게).
- **Rationale**: 역할을 기기에 저장하면 서버와 어긋날 수 있다. 응답의 role이 유일한 기준이다(원칙 VII: 권한 최종 판단은 서버).
- **Alternatives**: 역할을 보안 저장소에 저장 — 시작이 빠르지만 탈퇴·역할 변경과 어긋나고 저장 항목이 늘어난다.

## R3. 401 → 갱신 → 재시도, 동시 요청

- **Decision**: 기존 `AuthInterceptor`를 유지·보완한다.
  - 갱신 경로를 `/api/v1/auth/token/refresh`로 바꾼다.
  - 진행 중인 갱신 `Future<bool>?`를 하나 두어, 동시에 401을 받은 요청들은 같은 갱신 결과를 기다린 뒤 각자 한 번만 재시도한다(갱신 토큰은 1회용이라 두 번 갱신하면 재사용 탐지로 세션이 폐기된다).
  - 공개 경로(`/api/v1/auth/login`, `signup*`, `password-reset*`, `token/refresh`)의 401과, 응답 `code`가 `INVALID_CREDENTIALS`인 401(회원 탈퇴 비밀번호 불일치)은 갱신하지 않고 그대로 넘긴다.
  - 갱신이 거부되면 토큰을 지우고 `SessionController.expire()`를 호출한다 → 라우터가 로그인 화면(`/login`)으로 보낸다(constitution "갱신이 실패하면 저장된 토큰을 지우고 로그인 화면으로"). 로그아웃·탈퇴·비밀번호 재설정 완료는 `signOut()`으로 시작 화면에 간다.
- **Rationale**: constitution "토큰 주입·갱신 단일 지점" 요건. 재사용 탐지(FR-025)와 충돌하지 않게 갱신을 직렬화한다.
- **Alternatives**: `QueuedInterceptorsWrapper` — 모든 요청을 직렬화해 느려진다. 별도 패키지(`dio_smart_retry` 등) — 새 패키지 추가가 필요하다.

## R4. 공통 오류 타입 확장

- **Decision**: `AppException`에 다음을 추가한다.
  - `fieldErrors`: `Map<String, String>`(field → reason). 같은 필드가 여러 번 오면 첫 번째를 쓴다.
  - `retryAfter`: `Duration?`. 429의 `Retry-After` 헤더(초)를 읽는다. 없거나 숫자가 아니면 null.
  - `isNetworkError`: 응답이 없는 경우(연결 실패·시간 초과).
  - `code`는 서버 `ErrorCode` 문자열 그대로 두고, 화면 분기는 `code`로 한다(`INVALID_INVITE_CODE`, `TOO_MANY_ATTEMPTS` 등). 상수는 `lib/core/error/error_codes.dart`에 모은다.
- **Rationale**: spec FR-001~004. 화면은 `message`만 보여 주고, 분기 판단은 code로 한다.
- **Alternatives**: 에러 코드별 sealed class 계층 — 정확하지만 F1 범위에서 과하다. 필요해지면 나중에 바꾼다.

## R5. 초대 코드 확인 API가 없는 상태에서 F1-1 → F1-3/F1-3a 흐름

- **Decision**: `AuthRepository.checkInviteCode(code)`를 둔다. 반환은 `InviteRole?`(TEACHER / PARENT / 알 수 없음=null).
  - **mock**: 데모 코드에 따라 역할을 돌려주거나 `INVALID_INVITE_CODE`·`TOO_MANY_ATTEMPTS`를 던진다.
  - **실서버(계약 확정 전)**: 서버를 호출하지 않고 `null`을 돌려준다. 화면은 역할 중립 문구의 계정 만들기 화면을 보이고, 코드 검증은 `POST /api/v1/auth/signup` 응답으로 한다(두 역할 모두 이름이 필수라 입력 항목은 같다).
  - 계약이 확정되면 실서버 구현만 바꾼다. 화면·ViewModel은 그대로다.
- **Rationale**: spec FR-019(Option C) + Assumptions. 백엔드가 막혀도 실서버 가입이 동작한다.
- **Alternatives**: 제안 경로를 미리 호출 — 서버가 기본 거부로 401을 줘 오동작한다.
- 요청 문구: [contracts/invite-code-check.proposal.md](./contracts/invite-code-check.proposal.md)

## R6. 대기·잠금 카운트다운

- **Decision**: 429를 받은 ViewModel이 `retryUntil`(현재 시각 + `retryAfter`)을 상태에 담고, 1초 `Timer.periodic`으로 남은 초를 갱신한다. 0이 되면 버튼을 다시 연다. `retryAfter`가 없으면 일반 안내만 보이고 버튼은 바로 연다(서버가 다시 판단). 화면이 사라지면 Timer를 취소한다(`ref.onDispose`).
  - 로그인 대기(C-1a)·코드 잠금(F1-2b)·재설정 코드 잠금(C-3c)·인증 코드 재발송(60초)에 같은 상태 조각(`Cooldown`)을 쓴다.
- **Rationale**: FR-003·FR-021, SC-008. 횟수·규칙은 서버만 안다.
- **Alternatives**: 앱에서 실패 횟수를 세어 대기 시간 계산 — 서버 규칙과 어긋나고 가입 여부 추측 차단 설계를 흉내 낼 수 없다.

## R7. 화면 접근 제어(라우터 가드)

- **Decision**: `GoRouter.redirect` 한 곳에서 `SessionState`를 보고 이동을 정한다. `refreshListenable`에 세션 변화를 연결한다.
  - 확인 중 → `/splash`, 로그아웃 → 공개 경로만(`/`, `/login`, `/signup/**`, `/password-reset/**`), 로그인 → 자기 역할 경로(`/parent/**`, `/teacher/**`, `/admin/**`)와 공통(`/me/**`)만.
  - 가입 직후에는 이용 안내(`/welcome`)를 한 번 거친다(세션의 `justSignedUp` 플래그).
- **Rationale**: constitution "화면 접근 제어는 go_router 리다이렉트 한 곳에서". spec FR-010.
- **Alternatives**: 화면마다 가드 — 누락 위험.

## R8. mock에서 401·403·세션 만료를 어떻게 재현하나

- **Decision**:
  - mock Repository는 dio를 거치지 않으므로, **401 → 갱신 → 재시도**는 `AuthInterceptor` 단위 테스트에서 가짜 `HttpClientAdapter`(테스트 코드 안에 직접 구현, 패키지 없음)로 검증한다.
  - 앱 mock 실행에서는 **갱신 실패 → 로그인 화면**을 데모 계정 `expired@damso.test`로 재현한다: 로그인은 성공하지만 이후 보호된 조회에서 mock이 `SessionController.expire()`를 호출하고 401을 던진다.
  - **403**은 데모 교사 계정 `noclass@damso.test`(담당 학급 없음 → `FORBIDDEN`)로 재현한다.
  - **401 → 갱신 → 재시도 성공**은 데모 계정 `refresh@damso.test`로 재현한다: 학부모 홈 첫 조회에서 mock이 갱신 지연(600ms)을 흉내 낸 뒤 정상 응답한다. 갱신을 거쳤는지는 mock 내부 플래그로만 기록하고 `TokenStore`는 건드리지 않는다(토큰 갱신은 `AuthInterceptor` 한 곳에서만 — constitution). 사용자에게는 오류가 보이지 않는다(실제 인터셉터 동작은 `AuthInterceptor` 단위 테스트가 검증).
  - 전체 데모 입력표는 [quickstart.md](./quickstart.md).
- **Rationale**: constitution "mock에는 401(갱신)·403 포함", spec FR-012·US8. 아키텍처 규칙(mock = Repository 구현) 유지.
- **Alternatives**: mock 모드에서도 dio를 쓰고 어댑터만 바꿈 — 갱신 흐름까지 앱에서 보이지만, "provider 한 곳에서 구현 선택" 규칙과 겹쳐 구조가 둘이 된다.

## R9. 입력 검증과 글자 수

- **Decision**: 검증 함수는 순수 Dart로 둔다. 두 개 이상 기능이 쓰는 것(초대 코드·이름·이메일·비밀번호·6자리 코드 — auth·parent·me)은 `lib/core/validation/validators.dart`에, 한 기능만 쓰는 것은 그 기능의 `domain`(`admin/domain/validators.dart`, `teacher/domain/validators.dart`)에 둔다(CLAUDE.md "core는 두 개 이상 기능이 쓰는 코드만").
  - 글자 수는 `String.runes.length`(코드 포인트)로 센다. 서버도 코드 포인트로 센다(openapi `Content` 설명).
  - 초대 코드: 공백 제거 + 대문자 변환 후 `^[A-HJKMNP-Z2-9]{10}$`.
  - 비밀번호: 8~64자, `[A-Za-z]`와 `[0-9]` 각각 1자 이상.
  - 이메일: 간단한 형식 검사(`x@y.z`)만 하고 최종 판단은 서버.
  - 서버 `fieldErrors`가 오면 앱 검증 결과보다 우선 표시한다.
- **Rationale**: FR-015. domain은 Flutter·dio 의존이 없어야 한다.

## R10. 대기 중인 가입 식별자 보관

- **Decision**: `pendingSignupId`는 가입 흐름 ViewModel 상태(메모리)에만 둔다. 앱을 다시 열면 가입 입력부터 다시 시작한다.
- **Rationale**: spec Edge Case. 기기에 남길 이유가 없다.

## R11. 발행 코드 원문 1회 표시

- **Decision**: 발행 응답(`IssuedInviteCode`)은 발행 완료 화면에 라우트 extra로만 넘기고, 어떤 Provider 상태·저장소에도 남기지 않는다. 화면을 떠나면 사라진다. 클립보드 복사 버튼은 둔다(학교가 전달해야 하므로). 복사 후 안내만 보인다.
- **Rationale**: FR-035, SC-006.
- **Alternatives**: 목록 상태에 보관 — 다시 볼 수 있는 경로가 생긴다.

## R12. 테스트 전략

- **Decision**: `flutter_test`만 쓴다.
  - 단위: `AppException.fromDio`(fieldErrors·Retry-After·네트워크), `AuthInterceptor`(갱신 1회·동시 요청·공개 경로 제외·실패 시 expire), validators.
  - ViewModel: `ProviderContainer` + mock Repository override로 상태 전이(로그인 대기 카운트다운, 가입 2단계, 재설정 3단계).
  - 위젯: 라우터 가드(역할별 홈, 비로그인 차단), 가입 흐름, 관리자 코드 1회 표시.
  - 기존 `test/widget_test.dart`는 새 흐름에 맞게 고친다(로그인 후 이동 대상이 바뀜).
- **Rationale**: constitution 검증 게이트(`flutter analyze`, `flutter test`).
