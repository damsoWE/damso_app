# Implementation Plan: 공통 기반 반영 및 인증·회원가입·학급 연결 화면 (F0·F1)

**Branch**: `features/f0-f1-auth-signup` (이슈 #5) | **Date**: 2026-10-25 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/001-foundation-auth-signup/spec.md`

**대응 백엔드 spec**: `damsoWE/damso_server` `specs/000-foundation`, `specs/001-auth-signup` · **API 계약**: `docs/api/openapi.yaml` (api-v0.3)

## Summary

모든 화면이 따르는 공통 기반(오류 표시, 세션 복구·갱신·만료, 역할별 화면 접근 제어, mock 실행)을 api-v0.3에 맞추고, 그 위에 F1 화면을 만든다: 초대 코드 가입(코드 확인 → 계정 정보 → 이메일 인증), 로그인·대기, 비밀번호 재설정, 학부모 홈·자녀 추가, 교사 프로필·연결 현황, 슈퍼 관리자 학급·학생·초대 코드 관리, 마이페이지.

접근 방식: 기존 MVVM + Repository 구조를 그대로 확장한다. 세션은 `lib/core/session`의 `SessionController` 하나가 쥐고, 라우터 redirect와 `AuthInterceptor`가 이를 참조한다. 기능은 `auth`·`me`·`parent`·`teacher`·`admin` 다섯 feature로 나누고, 각 Repository는 실서버(dio)·mock 구현을 provider 한 곳에서 `USE_MOCK`으로 고른다. 가입 첫 단계는 api-v0.4의 초대 코드 확인 API로 역할을 받는다(research R5). 새 패키지는 추가하지 않는다.

## Technical Context

**Language/Version**: Dart ^3.10.1 (Flutter stable, `pubspec.yaml` 기준)

**Primary Dependencies**: flutter_riverpod ^3.0.3 (Notifier/AsyncNotifier, 수동 provider 선언), go_router ^17.5.0, dio ^5.11.1, flutter_secure_storage ^11.2.0 — 모두 기존. 새 패키지 없음

**Storage**: 갱신 토큰 1개만 OS 보안 저장소(Keychain/Keystore). 접근 토큰·역할·가입 대기 ID·발행 코드는 메모리. 그 밖의 로컬 저장 없음

**Testing**: flutter_test (단위·ViewModel·위젯). 가짜 `HttpClientAdapter`는 테스트 코드 안에 직접 구현

**Target Platform**: Android(minSdk = Flutter 기본) · iOS 13.0+

**Project Type**: mobile-app (Flutter, 백엔드는 별도 레포)

**Performance Goals**: 화면 전환·입력 반응은 Flutter 기본 60fps. 가입 전체 3분 이내(SC-001, 사용자 작업 시간 기준)

**Constraints**: 본문·코드·토큰 로그 출력 금지 · 서버 `message`만 표시 · 토큰 갱신 직렬화(갱신 토큰 1회용) · WebView/HTML 렌더 금지 · 릴리스 `--obfuscate --split-debug-info`

**Scale/Scope**: 화면 약 35개(공개 15 · 학부모 5 · 교사 4 · 관리자 8 · 공통 3), Repository 5개, 엔드포인트 24개

## Constitution Check

*GATE: Phase 0 전 확인, Phase 1 설계 후 재확인.*

| 원칙·요건 | 이 계획에서 | 결과 |
|---|---|---|
| I. 연락처 미수집 | 가입·프로필·마이페이지에 전화·주소 입력 없음. 다른 사용자 이메일 표시 없음(학부모 홈 담임 카드, 교사 연결 현황은 이름·여부만) | ✅ |
| III. 원문 보존 | F1에는 문의·답변 없음. 수정·삭제 UI 해당 없음 | ✅ (해당 없음) |
| IV. 긴급 우선 | 해당 없음(F2) | ✅ (해당 없음) |
| V. 제안만 | 이용 안내·시스템 안내는 고정 문구 | ✅ |
| VI. 민감정보 비노출 | 로깅 인터셉터 없음, `print` 금지, 서버 `message`만 표시, `AppException`에 원문 응답 보관 안 함 | ✅ |
| VII. 식별자·권한 | 라우터 redirect 한 곳(contracts/routes.md), URL에는 UUID만, 권한 최종 판단은 서버(403 안내) | ✅ |
| VIII. 안전한 기본값 | `env/*.json`에 호스트만, 기본 계정 없음. mock 데모 계정은 mock 구현 안에만 있고 실서버 빌드에 쓰이지 않음 | ✅ |
| 토큰 보관 | 갱신 토큰 보안 저장소, 접근 토큰 메모리 (`TokenStore` 유지) | ✅ |
| 토큰 주입·갱신 단일 지점 | `AuthInterceptor`만. 갱신 실패 시 토큰 삭제 + 로그인 화면(`SignedOut(sessionExpired)` → `/login`) | ✅ |
| 렌더링 | WebView·HTML 렌더 미사용 | ✅ |
| 아키텍처 | 위젯 → ViewModel → Repository 인터페이스, domain에 Flutter·dio 없음, provider 한 곳에서 구현 선택, DioException → AppException | ✅ |
| mock 케이스 | 401 갱신(테스트), 세션 만료·403·입력 오류·429(앱 mock) — research R8 | ✅ |
| Contract-first | `openapi.yaml` 직접 수정 없음(`/fetch-api`로만 갱신, 현재 api-v0.4) | ✅ |

**재확인(Phase 1 후)**: data-model·contracts·quickstart 작성 후 위반 없음. Complexity Tracking 해당 없음.

## Project Structure

### Documentation (this feature)

```text
specs/001-foundation-auth-signup/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── api-usage.md                     # 화면 ↔ Repository ↔ 엔드포인트
│   └── routes.md                        # 경로·redirect 규칙
├── checklists/requirements.md
└── tasks.md                             # /speckit-tasks
```

### Source Code (repository root)

```text
lib/
├── main.dart
├── app/
│   ├── app.dart
│   └── router.dart                      # 경로 + redirect(SessionState) — 수정
├── core/
│   ├── config/env.dart
│   ├── error/
│   │   ├── app_exception.dart           # fieldErrors · retryAfter · isNetworkError — 수정
│   │   └── error_codes.dart             # 신규
│   ├── network/
│   │   ├── auth_interceptor.dart        # 갱신 경로·직렬화·공개 경로 제외·expire — 수정
│   │   └── dio_provider.dart
│   ├── session/                         # 신규
│   │   ├── role.dart
│   │   ├── session_state.dart
│   │   └── session_controller.dart
│   ├── storage/token_store.dart
│   ├── theme/app_theme.dart
│   ├── validation/validators.dart       # 신규: 초대 코드·이름·이메일·비밀번호·6자리 코드 (auth·parent·me 공유)
│   └── widgets/                         # 신규: 2개 이상 기능이 쓰는 위젯
│       ├── cooldown.dart                # 남은 시간 상태 + 표시
│       ├── async_view.dart              # 로딩·빈 목록·오류(다시 시도)
│       ├── field_error_text.dart
│       ├── form_layout.dart             # 입력 화면 틀·안내 문구·진행 버튼
│       └── invite_code_formatter.dart   # 초대 코드 대문자·공백 제거 (가입·자녀 추가)
└── features/
    ├── auth/
    │   ├── domain/   auth_repository.dart · models.dart
    │   ├── data/     auth_repository_impl.dart · mock_auth_repository.dart · auth_repository_provider.dart
    │   └── presentation/
    │       start_page.dart (C-0) · splash_page.dart + splash_view_model.dart · login_page.dart + login_view_model.dart (C-1/C-1a)
    │       signup/ invite_code_page.dart (F1-1/2/2b) · account_page.dart (F1-3/3a) · verify_page.dart (C-2) · signup_view_model.dart
    │       password_reset/ email_page.dart (C-3) · code_page.dart (C-3b/3c) · new_password_page.dart (C-4) · done_page.dart (C-5) · password_reset_view_model.dart
    │       welcome_page.dart (C-6) · terms_page.dart (C-7)
    ├── me/
    │   ├── domain/   me_repository.dart · me.dart
    │   ├── data/     me_repository_impl.dart · mock_me_repository.dart · me_repository_provider.dart
    │   └── presentation/ account_page.dart (C-9) · withdraw_page.dart (C-8) · me_view_model.dart · my_page_parts.dart (역할별 마이페이지 공통 조각)
    ├── parent/
    │   ├── domain/   parent_repository.dart · child.dart
    │   ├── data/     parent_repository_impl.dart · mock_parent_repository.dart · parent_repository_provider.dart
    │   └── presentation/ parent_home_page.dart (F2-1/1b) · child_select_page.dart (F2-1a) · parent_my_page.dart (F2-7) · children_page.dart (F1-4) · add_child_page.dart (F1-5) · view models
    ├── teacher/
    │   ├── domain/   teacher_repository.dart · models.dart · validators.dart
    │   ├── data/     teacher_repository_impl.dart · mock_teacher_repository.dart · teacher_repository_provider.dart
    │   └── presentation/ teacher_home_page.dart (F3-4) · teacher_my_page.dart (F3-7) · profile_edit_page.dart (F3-9) · links_page.dart (F3-10) · view models
    ├── admin/
    │   ├── domain/   admin_repository.dart · models.dart · validators.dart
    │   ├── data/     admin_repository_impl.dart · mock_admin_repository.dart · admin_repository_provider.dart
    │   └── presentation/ admin_home_page.dart (ADM-1a/1b) · classroom_new_page.dart (ADM-1c) · classroom_detail_page.dart (ADM-1/ADM-2) · students_new_page.dart (ADM-5/5a) · invite_codes_page.dart · reissue_confirm_page.dart (ADM-6) · invite_issued_page.dart (ADM-3/3t) · admin_my_page.dart (ADM-7) · format.dart · view models
    ├── inquiry/ · history/ · reply/     # 기존 뼈대, 이 작업에서 동작 유지만 (FR-013)

test/
├── core/      app_exception_test.dart · auth_interceptor_test.dart · router_redirect_test.dart · validators_test.dart
├── features/
│   ├── mock_scenarios_test.dart          # US8 mock 시연 시나리오
│   ├── auth/   login_view_model_test.dart · signup_view_model_test.dart · password_reset_view_model_test.dart · signup_flow_test.dart
│   ├── parent/ parent_home_test.dart
│   ├── teacher/ profile_edit_test.dart
│   ├── admin/  invite_issue_test.dart
│   └── me/     my_page_test.dart         # quickstart 19·20
├── helpers/test_app.dart                # 모든 Repository mock override + 공용 조작
└── widget_test.dart                     # 기존, 새 진입 흐름에 맞게 수정
```

**Structure Decision**: 기존 feature-first 구조를 따른다. 역할별 화면은 역할 이름의 feature(`parent`, `teacher`, `admin`)로, 역할 공통 계정 기능은 `me`로, 로그인 전 흐름은 `auth`로 나눈다. 세션·오류·공통 위젯은 두 개 이상 기능이 쓰므로 `core`에 둔다. 기존 `/inquiries` 경로는 PARENT·TEACHER에게만 임시로 열어 두고(SUPER_ADMIN은 FR-037에 따라 차단), F2에서 역할별 경로로 옮긴다.

## Phase 0: Research

[research.md](./research.md) — R1 기본 경로 · R2 세션·역할 · R3 갱신 직렬화 · R4 오류 타입 · R5 초대 코드 확인 API · R6 카운트다운 · R7 라우터 가드 · R8 mock 401/403 · R9 검증 · R10 가입 대기 ID · R11 코드 1회 표시 · R12 테스트. 미해결 항목 없음.

## Phase 1: Design & Contracts

- [data-model.md](./data-model.md) — 세션 상태 전이, AppException, 기능별 모델·검증, 가입·재설정 상태 전이
- [contracts/api-usage.md](./contracts/api-usage.md) — Repository 메서드 ↔ 엔드포인트 ↔ 오류 분기
- [contracts/routes.md](./contracts/routes.md) — 경로·화면 ID·redirect 규칙
- [quickstart.md](./quickstart.md) — mock 데모 입력표, 검증 시나리오 21개

## 구현 순서 (tasks 입력용)

1. **F0 core**: AppException 확장·error_codes → SessionController → AuthInterceptor 보완 → 라우터 redirect·splash. 테스트 먼저(interceptor·fromDio·redirect).
2. **auth**: Repository(실서버·mock) → 로그인·대기 → 가입 3단계 → 비밀번호 재설정 → 이용 안내·약관.
3. **admin**: 학급·학생 → 코드 발행·1회 표시·재발행 확인 → 발행 현황. (가입 시연에 코드가 필요하므로 auth 다음)
4. **parent**: 홈·자녀 선택 → 연결된 자녀·자녀 추가.
5. **teacher**: 홈(진입) → 프로필 편집 → 연결 현황.
6. **me**: 마이페이지 3종 → 계정 정보·로그아웃·탈퇴.
7. 기존 위젯 테스트 갱신, `flutter analyze`·`flutter test`, quickstart 시나리오 수동 확인.

## 리스크

| 리스크 | 대응 |
|---|---|
| 초대 코드 확인 API 계약 변경 | api-v0.4에서 확정(요청에 이메일 포함)되어 반영 완료(R5). 이후 변경은 `/fetch-api` → 수정 |
| Figma 로그인 잠금 문구("5회, 10분")와 서버 단계적 대기 불일치 | 서버 `Retry-After`만 표시(FR-021). 디자인에 문구 수정 요청 |
| 갱신 토큰 재사용 탐지로 인한 의도치 않은 로그아웃 | 갱신 직렬화(R3) + 동시 401 테스트 |
| Figma 프레임 링크가 화면별로 아직 spec에 없음 | `docs/ia.md` 링크를 tasks 항목에 붙인다 |
