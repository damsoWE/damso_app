# Implementation Plan: 문의 접수·긴급 분류 화면 (F2)

**Branch**: `features/f2-inquiry-intake-urgent` (이슈 #7) | **Date**: 2026-10-26 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/002-inquiry-intake-urgent/spec.md`

**대응 백엔드 spec**: `damsoWE/damso_server` `specs/002-inquiry-intake-urgent` · **API 계약**: 백엔드 `main`의 원본 명세 0.5.0(태그 전, [research R1](./research.md#r1-api-계약-기준--태그-전-원본-명세-050)). 앱 사본 `docs/api/openapi.yaml`은 api-v0.4 그대로 두고 태그가 나오면 `/fetch-api`로 갱신한다.

## Summary

학부모가 홈에서 고른 자녀로 문의를 보내고, 서버 결과에 따라 접수·응답 가능 시간 안내·긴급 전달 안내(위기 종류별 109·112, 누르면 전화 걸기 화면)를 고정 문구로 보여 준다. 학부모는 문의 탭에서 처리 단계를 보고, 교사는 문의 탭·홈에서 긴급을 먼저 알아보고 긴급 원문을 연다. 교사는 응답 가능 시간·일반 알림을 설정하고, 로그인한 기기로 FCM 알림을 받는다.

접근 방식: F1의 MVVM + Repository 구조를 그대로 확장한다. 학부모·교사 화면을 go_router `StatefulShellRoute`로 하단 탭 3개에 담고(R2), 새 기능 `inquiry`(학부모·교사 문의)와 `notification`(설정·기기 등록)을 만든다. 기기 알림은 `lib/core/push`의 인터페이스 뒤에 FCM 구현과 빈 구현을 두어 mock·테스트가 Firebase 없이 돈다(R9). 새 패키지는 3개(`firebase_core`, `firebase_messaging`, `url_launcher`)이며 2026-10-26 사용자 승인을 받았다.

## Technical Context

**Language/Version**: Dart ^3.10.1 (Flutter 3.38.3 stable)

**Primary Dependencies**: 기존 flutter_riverpod ^3.0.3 · go_router ^17.5.0(`StatefulShellRoute`) · dio ^5.11.1 · flutter_secure_storage ^11.2.0. **추가(2026-10-26 승인)**: `firebase_core ^4.15.0`, `firebase_messaging ^16.7.0`(R9), `url_launcher ^6.3.2`(R11). 셋 다 Flutter 3.38과 맞는 것을 `flutter pub add --dry-run`으로 확인했다(최신 메이저 5.x·17.x, url_launcher 6.3.3은 각각 출시 2주 미만·Flutter 3.41 필요라 제외).

**Storage**: 추가 로컬 저장 없음. 문의 본문·원문·알림 데이터·FCM 토큰은 메모리에만(원칙 III·VI). Firebase 설정 값은 빌드 때 주입(R10)

**Testing**: flutter_test (ViewModel 단위·위젯·라우터). 가짜 `PushMessaging`·`DialLauncher`·`HttpClientAdapter`를 테스트 안에 직접 구현

**Target Platform**: Android(minSdk = Flutter 기본, Android 13+ 알림 권한) · iOS 13.0+(APNs)

**Project Type**: mobile-app (Flutter, 백엔드는 별도 레포)

**Performance Goals**: 문의 보내기 30초 이내(SC-001, 글쓰기 제외) · 긴급 안내는 보내기 결과 수신 즉시(SC-002) · 열린 앱에서 긴급 알림 후 3초 안에 홈·목록 반영(SC-011a)

**Constraints**: 본문·원문·알림 데이터 로그·저장 금지 · 안내 문구는 앱 상수만(원칙 V) · 원문 열람은 화면당 1회(감사 기록) · WebView/HTML 렌더 금지 · 일정 간격 자동 조회 금지(Clarifications Q2)

**Scale/Scope**: 새 화면 10개(학부모 F2-2 · F2-4 · 안내 F2-5/5a/3 계열 · 긴급 안내 다시 보기, 교사 F3-1 · F3-5 · 준비 중 · F3-8) + 기존 화면 4개 수정(F2-1 · F3-4 · F2-7 · F3-7) + 탭 셸 2개 · Repository 3개 · 엔드포인트 10개

## Constitution Check

*GATE: Phase 0 전 확인, Phase 1 설계 후 재확인.*

| 원칙·요건 | 이 계획에서 | 결과 |
|---|---|---|
| I. 연락처 미수집 | 문의 작성에 연락처 입력 없음. 교사 화면은 학생 이름만, 학부모 이름·이메일 없음(FR-023, 위젯 테스트로 `@` 검사) | ✅ |
| II. 가명화 게이트웨이 | 앱은 외부 AI를 부르지 않는다. 해당 없음 | ✅ (해당 없음) |
| III. 원문 보존 | 보낸 문의 수정·삭제 UI 없음. 원문은 화면 메모리에만(작성 중·교사 열람 모두), 기기 저장·캐시 없음. 교사 원문 열람은 `/content`로만, 화면당 1회(R8) | ✅ |
| IV. 긴급 우선 | 긴급 판정은 서버. 앱은 긴급 안내를 분류 결과를 기다리지 않고 즉시 표시, 긴급 알림 끄기 항목 없음(FR-028), 교사 목록 긴급 맨 위 | ✅ |
| V. 제안만·시스템 안내 | 접수·지연·긴급·번호 문구는 앱 상수(`notice_text.dart`), 서버는 코드만 준다(R5). 시스템 안내는 교사 메시지와 구분된 스타일 | ✅ |
| VI. 민감정보 비노출 | 본문·원문·FCM 토큰·알림 데이터 `print`·로그·분석 이벤트 금지. 서버 `message`만 표시 | ✅ |
| VII. 식별자·권한 | URL에는 문의 UUID만, 결과는 `extra`. 접근 제어는 `resolveRedirect` 한 곳(탭 셸 포함). 남의 문의는 서버 거부 안내 | ✅ |
| VIII. 안전한 기본값 | Firebase 설정 값은 저장소·`env/*.json`·에셋에 넣지 않고 빌드 때 주입(`secrets/firebase.json`, git 무시). **단, 빌드된 앱 안에는 들어간다** → Complexity Tracking | ✅ 예외 승인(2026-10-26, PR 리뷰에서 재확인) |
| 토큰 보관·갱신 단일 지점 | 기존 `TokenStore`·`AuthInterceptor` 그대로. 새 Repository도 같은 dio 사용 | ✅ |
| 렌더링 | 본문·원문은 일반 `Text`만(교사 원문은 길게 눌러 복사하지 않음, T038) | ✅ |
| 아키텍처 | 위젯 → ViewModel → Repository 인터페이스, domain에 Flutter·dio·Firebase 없음, provider 한 곳에서 구현 선택(`pushMessagingProvider`도 같은 방식) | ✅ |
| mock 케이스 | 401 갱신·403(남의 문의)·정리 중 → 완료·"원문 확인 필요"·긴급 4종·429·담임 없음(R14) | ✅ |
| Contract-first | 앱 사본 수정 없음. 원본 0.5.0을 참고만, 태그 후 `/fetch-api` | ✅ |
| 큰 영향 결정 확인(CLAUDE.md) | 새 패키지 3개 · 외부 시스템(FCM, Firebase 프로젝트는 팀이 생성) · Android 매니페스트 `<queries>`·알림 채널, iOS 푸시 capability · 기존 뼈대(`inquiry`·`reply`·`history`) 삭제 | ✅ 2026-10-26 사용자 승인 |

**재확인(Phase 1 후)**: data-model·contracts·quickstart 작성 후 새 위반 없음. 원칙 VIII 항목만 Complexity Tracking에 남는다.

## Project Structure

### Documentation (this feature)

```text
specs/002-inquiry-intake-urgent/
├── plan.md
├── research.md                          # R1~R15
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── api-usage.md                     # 화면 ↔ Repository ↔ 엔드포인트, FCM 데이터
│   └── routes.md                        # 탭 셸 경로·redirect 변경
├── checklists/requirements.md
└── tasks.md                             # /speckit-tasks
```

### Source Code (repository root)

```text
lib/
├── main.dart                            # 수정: Firebase 초기화(설정 있을 때만) → ProviderScope
├── app/
│   ├── router.dart                      # 수정: 학부모·교사 StatefulShellRoute, 새 경로, /inquiries 옛 경로, PendingNavigation
│   └── shells/                          # 신규
│       ├── parent_shell.dart            # 하단 탭(홈·문의·마이페이지)
│       └── teacher_shell.dart           # 하단 탭 + 앱 복귀·알림 수신 시 목록 새로 고침, 앱 안 배너
├── core/
│   ├── config/env.dart                  # 수정: FIREBASE_* dart-define 읽기(비어 있으면 null)
│   ├── error/error_codes.dart           # 수정: NO_HOMEROOM_TEACHER, CONFLICT, NOT_FOUND
│   ├── push/                            # 신규 (2개 이상 기능: 교사 F2, 학부모 F4)
│   │   ├── push_messaging.dart          # 인터페이스 + PushData(kind·inquiryId) + 경로 고르기
│   │   ├── fcm_push_messaging.dart      # firebase_messaging 구현
│   │   ├── noop_push_messaging.dart     # mock·테스트·설정 없음
│   │   ├── push_messaging_provider.dart # 구현 선택 한 곳
│   │   └── pending_navigation.dart      # 로그인 뒤 이동할 경로 1개(메모리)
│   ├── util/uuid.dart                   # 신규: Random.secure() UUID v4 (Idempotency-Key)
│   └── widgets/
│       ├── system_notice.dart           # 신규: 시스템 안내 스타일(교사 메시지와 구분, 원칙 V)
│       └── stage_timeline.dart          # 신규: 처리 단계 타임라인(학부모 카드·교사 긴급 상세)
└── features/
    ├── inquiry/                         # 기존 뼈대 삭제 후 새로 만듦(R13)
    │   ├── domain/   models.dart · notice_text.dart(고정 문구) · parent_inquiry_repository.dart · teacher_inquiry_repository.dart
    │   ├── data/     parent_inquiry_repository_impl.dart · teacher_inquiry_repository_impl.dart
    │   │             mock_inquiry_store.dart(학부모·교사 mock이 공유) · mock_parent_inquiry_repository.dart · mock_teacher_inquiry_repository.dart
    │   │             inquiry_repository_providers.dart
    │   └── presentation/
    │       parent/  compose_page.dart + compose_view_model.dart (F2-2)
    │                submitted_page.dart (F2-5/5a/3 계열, SubmitOutcome으로 고름) · urgent_notice_view.dart(번호 버튼 포함, 재사용)
    │                parent_inquiries_page.dart + parent_inquiries_view_model.dart (F2-4) · inquiry_card.dart(펼침 타임라인)
    │                home_inquiry_section.dart (F2-1 문의 영역) · urgent_notice_page.dart (긴급 안내 다시 보기)
    │       teacher/ teacher_inquiries_page.dart + teacher_inquiries_view_model.dart (F3-1, 페이지)
    │                urgent_detail_page.dart + urgent_detail_view_model.dart (F3-5, 원문 1회)
    │                pending_detail_page.dart (일반 문의 준비 중) · home_inquiry_section.dart (F3-4 긴급 카드·최근)
    │       dial_launcher.dart           # url_launcher 감싸기(테스트에서 가짜로 교체)
    ├── notification/                    # 신규
    │   ├── domain/   notification_repository.dart · models.dart(NotificationSettings·AvailabilityWindow·TimeOfDayValue·DayOfWeek)
    │   ├── data/     notification_repository_impl.dart · mock_notification_repository.dart · notification_repository_provider.dart
    │   └── presentation/
    │       settings_page.dart + settings_view_model.dart (F3-8)
    │       device_registrar.dart        # 세션 변화 구독: 교사 로그인 → 권한·등록, 로그아웃 직전 해제
    ├── parent/presentation/ parent_home_page.dart(문의 영역 추가) · parent_my_page.dart(탭 안으로)
    ├── teacher/presentation/ teacher_home_page.dart(긴급 카드·최근 문의) · teacher_my_page.dart(설정 메뉴)
    ├── me/presentation/ me_view_model.dart  # 수정: 로그아웃·탈퇴 직전 기기 등록 해제
    └── (삭제) reply/ · history/         # R13, 승인 후

android/app/src/main/
├── AndroidManifest.xml                  # 수정: <queries> tel, default_notification_channel_id
└── kotlin/.../MainActivity.kt           # 수정: 긴급 알림 채널(중요도 높음) 생성
ios/Runner/Info.plist                    # 수정: LSApplicationQueriesSchemes tel, UIBackgroundModes remote-notification
secrets/firebase.example.json            # 신규(빈 값). secrets/firebase.json 은 .gitignore
.gitignore                               # 수정: secrets/*.json, !secrets/*.example.json

test/
├── core/      router_redirect_test.dart(탭 셸·옛 경로·PendingNavigation 추가) · push_data_test.dart · uuid_test.dart
├── features/
│   ├── inquiry/  compose_view_model_test.dart · submit_outcome_test.dart · parent_inquiries_test.dart
│   │             teacher_inquiries_view_model_test.dart · urgent_detail_test.dart · inquiry_flow_test.dart(위젯)
│   │             inquiry_repository_impl_test.dart(Idempotency-Key·코드 해석)
│   ├── notification/ settings_view_model_test.dart · device_registrar_test.dart · push_navigation_test.dart
│   └── mock_scenarios_test.dart         # F2 데모 시나리오 추가
└── helpers/test_app.dart                # 수정: 새 Repository mock, 가짜 PushMessaging·DialLauncher
```

**Structure Decision**: 학부모·교사 문의는 같은 문의 데이터를 역할별로 보는 것이라 한 기능(`inquiry`)에 두고 `presentation`만 `parent/`·`teacher/`로 나눈다. mock은 두 역할이 같은 저장소(`mock_inquiry_store.dart`)를 공유해 학부모가 보낸 문의가 교사 목록에 보이게 한다. 응답 가능 시간·기기 등록은 문의와 별개인 알림 관리라 `notification` 기능으로 나눈다. FCM 감싸기는 F4에서 학부모도 쓰므로 `core/push`에 둔다. 탭 셸은 라우팅 구조라 `app/shells`에 둔다.

## Phase 0: Research

[research.md](./research.md) — R1 API 기준(원본 0.5.0) · R2 하단 탭 · R3 Idempotency-Key · R4 글자 수 · R5 안내 화면 고르기 · R6 학부모 목록 · R7 교사 페이지·다시 불러오기 · R8 원문 1회 열람 · R9 FCM · R10 Firebase 설정 보관 · R11 전화 걸기 · R12 작성 중 본문 · R13 뼈대 정리 · R14 mock · R15 테스트. 미해결 항목 없음.

## Phase 1: Design & Contracts

- [data-model.md](./data-model.md) — 단계·안내 코드 매핑, 안내 화면 선택 표, 작성 상태 전이, 교사 페이지, 알림 설정 검증, 기기 등록 상태, 알림 이동
- [contracts/api-usage.md](./contracts/api-usage.md) — Repository 메서드 ↔ 엔드포인트 ↔ 오류 분기, FCM 데이터
- [contracts/routes.md](./contracts/routes.md) — 탭 셸 경로, 루트/탭 Navigator 구분, redirect 변경
- [quickstart.md](./quickstart.md) — mock 데모 입력표, 검증 시나리오 21개 + 실기기 7개

## 구현 순서 (tasks 입력용)

1. **승인 완료(2026-10-26)**: 새 패키지 3개, 뼈대 삭제, Firebase 설정 보관 방식(Complexity Tracking), 플랫폼 설정 변경.
2. **탭 셸**: 라우터를 `StatefulShellRoute`로 바꾸고 기존 F1 화면을 탭에 담는다. F1 테스트가 그대로 통과하는지 먼저 확인.
3. **inquiry domain·data**: 모델·고정 문구·Repository(실서버·mock·공유 저장소). 안내 고르기·코드 해석 테스트 먼저.
4. **학부모**: 작성(F2-2) → 보낸 뒤 안내(F2-5/5a/3 계열, 전화 걸기) → 문의 탭(F2-4) → 홈 문의 영역(F2-1).
5. **교사**: 문의 탭(F3-1, 페이지) → 홈 긴급 카드(F3-4) → 긴급 상세(F3-5) → 준비 중.
6. **notification**: 설정(F3-8) → `core/push` 인터페이스·빈 구현 → 기기 등록·해제 → 알림 수신·이동·배너·앱 복귀 새로 고침.
7. **FCM 실구현·플랫폼 설정**: firebase 초기화(설정 있을 때만), Android 채널·매니페스트, iOS plist(확인은 Mac).
8. 뼈대 삭제, 기존 테스트 갱신, `flutter analyze`·`flutter test`, quickstart 1~21 에뮬레이터 확인, 22~28 실서버 확인(백엔드 준비 후).

## Complexity Tracking

| 위반 | 필요한 이유 | 더 단순한 대안을 쓰지 않는 이유 |
|---|---|---|
| 원칙 VIII — Firebase 클라이언트 설정(API 키 포함)이 빌드된 앱 안에 들어간다 | FCM 클라이언트 SDK는 프로젝트 ID·앱 ID·API 키 없이 초기화되지 않는다. 기기 알림은 Clarifications Q1(A안)로 이번 범위에 들어왔다 | 앱에서 값을 빼는 방법은 없다(모든 Firebase 클라이언트가 같음). 대신 ① 저장소·`env/*.json`·에셋에 넣지 않고 빌드 때 주입, ② Google Cloud 콘솔에서 키를 Android 패키지·iOS 번들 ID로 제한하고 필요한 API만 허용(팀 작업), ③ 발송 권한(서비스 계정)은 백엔드 시크릿에만 둔다(R10). 이 키는 비밀번호가 아니라 프로젝트 식별자다 — **사용자 승인 2026-10-26**, PR 리뷰에서 재확인 |

## 리스크

| 리스크 | 대응 |
|---|---|
| `api-v0.5` 태그 전 원본 명세가 바뀜 | 태그 후 `/fetch-api` → api-usage.md와 비교. 화면은 domain 모델에만 의존하므로 data 계층만 고친다 |
| iOS 기기 알림을 Windows에서 확인할 수 없음 | Android로 먼저 확인. iOS는 Mac을 쓰는 팀원이 APNs 키 등록·capability 설정 후 quickstart 22~28을 확인한다(PR에 확인 요청 항목으로 명시) |
| Dart 쪽 `FirebaseOptions` 초기화만으로 iOS FCM이 동작하는지 | Android는 문제없음. iOS에서 안 되면 `GoogleService-Info.plist`를 빌드 단계에서 생성하는 방식으로 바꾼다(R10 대안) |
| 탭 셸 도입으로 F1 화면 이동·테스트가 깨짐 | 구현 순서 2에서 F1 테스트를 먼저 통과시키고 다음으로 넘어간다 |
| 원문 열람이 의도치 않게 여러 번 기록됨 | ViewModel이 1회만 호출, 테스트로 고정(R8) |
| 학부모 타임라인 단계 이름 "정제"(서버 REFINING = 정제 완료)를 진행 중으로 오해할 수 있음 | 문구는 `notice_text.dart` 한 곳. 디자인 확인 후 "정리 완료" 등으로 바꿀지 정한다(analyze T1) |
| 학부모 목록 응답에 제목이 없어 Figma F2-4 카드와 다를 수 있음 | 긴급 표시·단계·자녀 이름으로 구성. Figma와 다르면 디자인 확인 요청 |
