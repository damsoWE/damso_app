---

description: "F2 문의 접수·긴급 분류 화면 구현 작업 목록"
---

# Tasks: 문의 접수·긴급 분류 화면 (F2)

**Input**: `specs/002-inquiry-intake-urgent/` 설계 문서 (plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md)

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/api-usage.md, contracts/routes.md, quickstart.md

**Tests**: plan.md Project Structure와 research R15가 테스트 파일을 명시하므로 포함한다. 각 Phase의 테스트를 먼저 작성하고 실패를 확인한 뒤 구현한다. 테스트 패키지는 추가하지 않는다(`flutter_test`만).

**Organization**: User Story별로 묶는다. Phase 순서는 spec 우선순위를 따른다: US1 → US2 → US3 (P1) → US4 → US5 → US6 → US8 (P2) → US7 (P3).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: 다른 파일이고 미완료 작업에 의존하지 않아 병렬 가능
- **[Story]**: 해당 User Story (US1~US8)
- 모든 경로는 레포 루트 기준

## 공통 규칙 (모든 작업에 적용)

- **Figma**: 화면 ID 옆 `Figma 216-5213` 표기는 `https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/?node-id=216-5213` 프레임이다(`docs/ia.md`). 화면을 만들기 전에 프레임을 확인하고, 색·글꼴은 `lib/core/theme/app_theme.dart` 토큰만 쓴다.
- **아키텍처**: 위젯 → ViewModel(Riverpod `Notifier`/`AsyncNotifier`) → Repository 인터페이스. `domain`은 Flutter·dio·Firebase import 금지. 구현 선택은 provider 한 곳에서 `Env.useMock`으로. FCM도 `lib/core/push` 인터페이스 뒤에만 둔다.
- **API**: 엔드포인트·필드는 백엔드 원본 명세 0.5.0 기준(research R1, `contracts/api-usage.md`). `docs/api/openapi.yaml`은 수정하지 않는다. 응답 해석 오류는 `mapDioErrors`가 일반 안내로 바꾼다.
- **오류**: 화면에는 `AppException.message`만. 입력 화면은 실패해도 쓴 내용을 지우지 않는다(FR-006, SC-010).
- **민감정보**: 문의 본문·원문·알림 데이터·FCM 토큰을 `print`·`debugPrint`·`log`·기기 저장소에 남기지 않는다(원칙 III·VI). 원문은 화면 메모리에만.
- **고정 문구**: 접수·지연·긴급·번호 안내는 `lib/features/inquiry/domain/notice_text.dart` 상수만 쓴다. 서버·AI 문장을 안내로 쓰지 않는다(원칙 V, FR-012).
- **비동기 ViewModel**: `await` 뒤에 `state`·`ref`를 쓰는 autoDispose ViewModel은 F1 리뷰 반영대로 `final link = ref.keepAlive();` + `finally { link.close(); }`로 감싼다.
- **mock**: `quickstart.md` "mock 데모 입력" 표가 기준. mock 지연 300ms. 학부모·교사 mock은 `mock_inquiry_store.dart`를 공유한다.
- **글자 수**: `trim()` 뒤 `runes.length`(research R4).
- **공통 화면 상태**: 조회 화면은 `AsyncView`(로딩·빈 목록·오류+다시 시도), 진행 버튼은 요청 중 비활성.

---

## Phase 1: Setup

**Purpose**: 승인된 패키지·설정·상수 준비 (2026-10-26 사용자 승인)

- [X] T001 `pubspec.yaml`에 `firebase_core: ^4.15.0`, `firebase_messaging: ^16.7.0`, `url_launcher: ^6.3.2` 추가 후 `flutter pub get`(research R9·R11). 다른 의존성 버전은 바꾸지 않는다.
- [X] T002 [P] `.gitignore`에 `secrets/*.json`과 예외 `!secrets/*.example.json` 추가, `secrets/firebase.example.json` 생성 — 키 `FIREBASE_PROJECT_ID`, `FIREBASE_MESSAGING_SENDER_ID`, `FIREBASE_ANDROID_APP_ID`, `FIREBASE_IOS_APP_ID`, `FIREBASE_API_KEY`, `FIREBASE_IOS_BUNDLE_ID`를 빈 문자열로(research R10). 실제 값은 커밋하지 않는다.
- [X] T003 [P] `lib/core/config/env.dart`에 위 6개 값을 `String.fromEnvironment`로 읽는 상수와 `static bool get hasFirebase`(필수 값이 모두 비어 있지 않음) 추가. 클래스 주석의 "시크릿은 앱에 넣지 않는다" 아래에 Firebase 값은 `secrets/firebase.json`으로 빌드 때만 주입한다는 한 줄 추가.
- [X] T004 [P] `lib/core/error/error_codes.dart`에 `noHomeroomTeacher = 'NO_HOMEROOM_TEACHER'` 추가(`conflict`·`notFound`는 기존 상수 확인).
- [X] T005 [P] `lib/core/util/uuid.dart` 생성 — `String uuidV4()`(`Random.secure()`, 버전·변이 비트 설정)와 `bool isUuid(String)`(research R3). `test/core/uuid_test.dart`: 형식 정규식, 1,000개 중복 없음, `isUuid` 참·거짓.

---

## Phase 2: Foundational (탭 셸·문의 공통 모델 — 모든 Story의 선행 조건)

**Purpose**: 하단 탭 셸, 문의 domain·data 뼈대, 공통 위젯, 기존 뼈대 정리

**⚠️ CRITICAL**: 이 Phase가 끝나기 전에는 어떤 User Story도 시작하지 않는다. 끝날 때 F1 테스트 전부가 통과해야 한다.

### Tests (먼저 작성, 실패 확인)

- [X] T006 [P] `test/core/router_redirect_test.dart` 보강(contracts/routes.md): PARENT로 `/parent/inquiries`·`/parent/inquiries/new` → null, TEACHER로 `/teacher/inquiries`·`/teacher/settings/notifications` → null, 다른 역할이 위 경로 → 자기 역할 홈, `/inquiries`(와 하위) → PARENT `/parent/inquiries`·TEACHER `/teacher/inquiries`·SUPER_ADMIN `/admin`. 기존 `/inquiries` → null 케이스는 새 규칙으로 바꾼다.
- [X] T007 [P] `test/features/inquiry/submit_outcome_test.dart` 작성 — data-model §1 "안내 화면 선택" 표 전체: 긴급 + `[109]`·`[112]`·`[]`·`[112,109]`·`[모르는 값]`·`[모르는 값, 109]`(→ 109만), 일반 + `DEFERRED` 포함 → 지연, 일반 + `RECEIVED`만 → 접수, 모르는 안내 코드 무시.
- [X] T008 [P] `test/features/inquiry/inquiry_repository_impl_test.dart` 작성 — 테스트 안 가짜 `HttpClientAdapter`: (a) `submit`이 `POST /api/v1/parent/inquiries`에 `Idempotency-Key` 헤더와 `{studentId, content}`를 보냄, (b) 201 응답의 `notices`·`hotlines` 코드 해석, (c) `stage` 모르는 값 → `AppException`(일반 안내), (d) 교사 `list(page: 1)`이 `?page=1&size=20`, (e) 429 `Retry-After` → `retryAfter`.

### Implementation

- [X] T009 `lib/features/inquiry`·`lib/features/reply`·`lib/features/history` 기존 뼈대 삭제(2026-10-26 승인, research R13). `lib/app/router.dart`의 `InquiryListPage` import·`/inquiries` 경로와 `test/helpers/test_app.dart`의 `inquiryRepositoryProvider` override, `test/widget_test.dart`의 뼈대 문의 목록 테스트를 함께 정리한다.
- [X] T010 [P] `lib/features/inquiry/domain/models.dart` 생성(data-model §1~3): `InquiryStage`(+ `fromServer`, 모르는 값은 `FormatException`), `StageEvent`, `Notice`, `Hotline`(+ 전화번호 `'109'`/`'112'`), `InquirySubmitted`, `ParentInquirySummary`, `ParentInquiryDetail`, `RefinementStatus`, `TeacherInquirySummary`(+ `isUnconfirmedUrgent`), `TeacherInquiryPage`(+ `hasMore`), `SubmitOutcome`(sealed: `ReceivedNotice`·`DeferredNotice`·`UrgentNotice(hotlines)`)와 `SubmitOutcome.from(urgent, notices, hotlines)`(research R5 규칙). Flutter import 금지.
- [X] T011 [P] `lib/features/inquiry/domain/notice_text.dart` 생성 — 원본 명세 그대로의 고정 문구: 안내 3종("문의가 접수되었습니다." · "선생님께 바로 전달했어요." · "선생님 응답 가능 시간에 전달됩니다."), 번호 2종("자살예방 상담전화 109" · "아동학대 신고 112"), 단계 이름 5종(data-model §1 표), 열람 기록 안내, 담임 없음 안내. 시간 초과 안내("보낸 문의 목록에서 접수됐는지 먼저 확인해 주세요.")도 여기에 둔다.
- [X] T012 [P] `lib/features/inquiry/domain/parent_inquiry_repository.dart`·`teacher_inquiry_repository.dart` 인터페이스(contracts/api-usage.md 메서드 그대로).
- [X] T013 [P] `lib/features/inquiry/data/parent_inquiry_repository_impl.dart`·`teacher_inquiry_repository_impl.dart` — dio + `mapDioErrors`, 경로·헤더는 contracts/api-usage.md. 응답의 `content`(학부모 상세)는 모델에 담지 않는다.
- [X] T014 `lib/features/inquiry/data/mock_inquiry_store.dart` 생성 — 학부모·교사 mock이 공유하는 메모리 저장소(research R14): 초기 교사 목록 데이터(긴급 확인 전·후, "정리 중"(두 번째 조회부터 정리 완료), "원문 확인 필요", 정리 완료 25건), 학부모 `parent@damso.test`의 초기 문의 몇 건과 "권한 확인(데모)" 카드, 제출 결과 규칙(본문 단어 → 긴급 4종·지연), 학부모별 마지막 일반 제출 시각(1분 제한), `Idempotency-Key` → 결과 캐시. 계정 구분은 F1처럼 `TokenStore.accessToken`의 `mock:<계정>`. 문의마다 단계 이력을 한 곳에만 두어 교사 목록·학부모 목록·학부모 상세가 같은 값을 읽는다. "정리 중" 데모 문의는 `parent@damso.test`가 보낸 문의로 두고, 교사 두 번째 조회 때 정리 상태 PENDING→REFINED와 함께 단계 이력에 REFINING(정제)을 덧붙인다(US8-2).
- [X] T015 `lib/features/inquiry/data/mock_parent_inquiry_repository.dart`·`mock_teacher_inquiry_repository.dart` — T014 사용. 담임 없는 자녀(김두리) → 409 `NO_HOMEROOM_TEACHER`, 1분 제한 → 429 + `retryAfter`, 같은 키·다른 내용 → 409 `CONFLICT`, "권한 확인(데모)" 상세 → 403, `refresh@` 계정의 첫 목록 조회는 F1 방식으로 갱신 흉내 후 정상.
- [X] T016 `lib/features/inquiry/data/inquiry_repository_providers.dart` — `parentInquiryRepositoryProvider`, `teacherInquiryRepositoryProvider`(구현 선택 한 곳, mock 둘은 같은 `mockInquiryStoreProvider` 공유).
- [X] T017 [P] `lib/core/widgets/system_notice.dart` — 시스템 안내 카드(아이콘 + 고정 문구, 교사 메시지와 구분되는 스타일, 원칙 V). `lib/core/widgets/stage_timeline.dart` — `List<StageEvent>` + 긴급 여부로 단계 순서를 그리고 지나온 단계는 시각, 아직 오지 않은 단계는 흐리게(FR-015).
- [X] T018 `lib/app/shells/parent_shell.dart`·`teacher_shell.dart` 생성 — `StatefulNavigationShell`을 받아 하단 탭 3개(홈·문의·마이페이지, 아이콘·라벨은 Figma F2-1·F3-4 탭 바) 표시, 같은 탭을 다시 누르면 그 탭의 처음 화면으로(research R2). 다른 탭에서 탭을 바꿀 때 호출되는 `onTabSelected(index)` 콜백을 셸 생성자로 받는다(목록 새로 고침은 T040·T046이 연결, FR-019·FR-020a).
- [X] T019 `lib/app/router.dart` 개편(contracts/routes.md): 루트 `navigatorKey`, 학부모·교사 `StatefulShellRoute.indexedStack`(탭별 `StatefulShellBranch`), 기존 F1 경로(`/parent/children/select` 홈 탭, `/parent/children`·`/add`·`/parent/me` 마이페이지 탭, `/teacher/profile`·`/teacher/links`·`/teacher/me` 마이페이지 탭)를 경로 문자열 그대로 탭 안으로 옮김. 문의 탭 경로는 자리 화면으로 우선 연결. `resolveRedirect`에 규칙 4-b(`/inquiries` → 역할 문의 탭) 추가. 기존 화면의 `context.push('/parent/me')` 등 탭으로 옮긴 경로를 여는 버튼은 탭 이동(`go`)으로 바꾸거나 없앤다(Figma 기준).
- [X] T020 `test/helpers/test_app.dart` 갱신 — 새 provider mock override(`mockInquiryStoreProvider`는 테스트마다 새 인스턴스), 탭 이동 헬퍼 `tapTab(tester, '문의')`. F1 테스트 전체가 새 탭 구조에서 통과하도록 탭으로 옮긴 화면의 진입 방식만 고친다.

**Checkpoint**: `flutter analyze` 0건, `flutter test` 전부 통과(F1 포함), mock 실행에서 학부모·교사 탭 3개 이동.

---

## Phase 3: User Story 1 - 학부모가 자녀를 고르고 문의를 보낸다 (Priority: P1) 🎯 MVP

**Goal**: 홈에서 고른 자녀로 문의 작성 → 보내기 → 접수 안내(F2-5).

**Independent Test**: quickstart 시나리오 2·3·4·5·10·11.

### Tests for User Story 1

- [X] T021 [P] [US1] `test/features/inquiry/compose_view_model_test.dart` — (a) 길이: 빈 값·공백만 → 보내기 불가, 2,000자(이모지 포함 코드 포인트) 가능, 2,001자 불가, (b) 같은 (자녀, 본문)으로 두 번 보내면 같은 `Idempotency-Key`, 본문을 바꾸면 새 키, 성공 뒤 키 버림, (c) 보내는 중 두 번째 호출 무시, (d) 429 → `cooldown` 시작·`errorMessage`·키 유지, (e) 409 `NO_HOMEROOM_TEACHER`·`CONFLICT`·네트워크 오류 → `errorMessage`, `isSubmitting` false, (f) 요청 중 dispose돼도 예외 없음. (g) 응답 없이 끝난 실패(`isNetworkError`) → 네트워크 안내 + 시간 초과 안내, 같은 내용 재시도 시 같은 키.
- [X] T022 [P] [US1] `test/features/inquiry/inquiry_flow_test.dart`(위젯) — 학부모 로그인 → 홈 "문의 작성" → 본문 입력 → 보내기 → "문의가 접수되었습니다." → "보낸 문의 보기" → 문의 탭 맨 위에 새 문의, 뒤로 가기로 작성 화면이 나오지 않음. 김두리 선택 후 "문의 작성" → 작성 화면 대신 담임 없음 안내. 글 쓰고 뒤로 가기 → 확인 대화상자.

### Implementation for User Story 1

- [X] T023 [US1] `lib/features/inquiry/presentation/parent/compose_view_model.dart` — `NotifierProvider.autoDispose.family<…, Child>`. 상태는 data-model §2 `ComposeState`. `submit(content)`: 검증 → 키 고르기(research R3) → `keepAlive` 감싸기 → 성공 시 `parentInquiriesViewModelProvider` 무효화 후 `SubmitOutcome` 반환, 실패 시 상태만 갱신하고 null 반환. 429는 F1 `CooldownTimer`. 응답 없이 끝난 실패(`isNetworkError`, 시간 초과 포함)는 네트워크 안내 뒤에 시간 초과 안내(T011)를 붙인다(research R3).
- [X] T024 [US1] `lib/features/inquiry/presentation/parent/compose_page.dart` (F2-2, Figma 216-5213) — 대상 자녀(이름·학년·반) 표시, 여러 줄 입력, 글자 수 `n / 2,000`(넘으면 안내 색), 보내기 버튼(요청 중 로딩), `CooldownNotice`, 오류 문구. `PopScope`로 내용이 있으면 "작성한 내용이 사라집니다" 확인(FR-007). 성공하면 `context.go('/parent/inquiries/submitted', extra: outcome)`로 교체(FR-013). 시간 초과 안내에는 "보낸 문의 보기" 링크(문의 탭으로 이동, 작성 화면은 닫지 않음)를 함께 둔다.
- [X] T025 [US1] `lib/features/inquiry/presentation/parent/submitted_page.dart` (F2-5, Figma 216-5227) — `SubmitOutcome`별로 화면 고름: 이 Story는 `ReceivedNotice`만, 나머지는 US2·US5가 채운다(자리 분기만 둠). `SystemNotice` + "보낸 문의 보기"(`go('/parent/inquiries')`). `extra`가 없으면 문의 탭으로.
- [X] T026 [US1] `lib/features/parent/presentation/parent_home_page.dart` — "문의 작성" 버튼(Figma F2-1 위치). 선택한 자녀에 담임이 없으면 작성 화면 대신 담임 없음 안내(FR-003), 있으면 `push('/parent/inquiries/new', extra: child)`.
- [X] T027 [US1] `lib/app/router.dart`에 `/parent/inquiries/new`(루트 Navigator, `extra` 없으면 `/parent`로)·`/parent/inquiries/submitted`(루트 Navigator) 연결.

**Checkpoint**: quickstart 2·3·4·5·10·11 통과.

---

## Phase 4: User Story 2 - 긴급 문의는 "바로 전달했어요"와 맞는 번호를 보여 준다 (Priority: P1)

**Goal**: 긴급 판정 결과 화면(F2-3 계열)과 109·112 전화 걸기 화면 열기.

**Independent Test**: quickstart 시나리오 6·7·8.

### Tests for User Story 2

- [X] T028 [P] [US2] `test/features/inquiry/urgent_notice_test.dart`(위젯) — `UrgentNotice` 4종(109만·112만·없음·112+109)마다 "선생님께 바로 전달했어요."와 정확한 번호 버튼만 보임, 번호 버튼 → 가짜 `DialLauncher`에 `tel:109`·`tel:112` 전달, 런처가 "열 수 없음"이면 번호 글자만 보이고 버튼 비활성.

### Implementation for User Story 2

- [X] T029 [P] [US2] `lib/features/inquiry/presentation/dial_launcher.dart` — `abstract class DialLauncher { Future<bool> canDial(); Future<void> dial(String number); }` + `url_launcher` 구현(`Uri(scheme: 'tel', path: number)`, 다이얼 화면만 엶) + `dialLauncherProvider`. 위젯 테스트는 가짜로 교체(research R11).
- [X] T030 [US2] `lib/features/inquiry/presentation/parent/urgent_notice_view.dart` — F2-3(Figma 216-5319)·F2-3b(216-5360)·F2-3c(216-5332)·F2-3d(216-5346): `SystemNotice`("선생님께 바로 전달했어요.") + 번호 버튼 목록(`notice_text` 문구, `canDial` 거짓이면 비활성). 교사 판단·약속처럼 보이는 문구 없음.
- [X] T031 [US2] `lib/features/inquiry/presentation/parent/submitted_page.dart`에 `UrgentNotice` 분기 연결(T030 사용).
- [X] T032 [P] [US2] Android `android/app/src/main/AndroidManifest.xml`에 `<queries><intent><action android:name="android.intent.action.DIAL"/><data android:scheme="tel"/></intent></queries>` 추가. iOS `ios/Runner/Info.plist`에 `LSApplicationQueriesSchemes` = [`tel`]. `CALL_PHONE` 권한은 추가하지 않는다.

**Checkpoint**: quickstart 6·7·8 통과(8은 에뮬레이터 다이얼 화면).

---

## Phase 5: User Story 3 - 교사가 긴급을 먼저 알아보고 원문을 확인한다 (Priority: P1)

**Goal**: 교사 문의 탭(F3-1, 페이지), 홈 긴급 카드(F3-4), 긴급 상세(F3-5), 일반 문의 준비 중, 앱 복귀 시 새로 고침.

**Independent Test**: quickstart 시나리오 14·15·16·17·18.

### Tests for User Story 3

- [X] T033 [P] [US3] `test/features/inquiry/teacher_inquiries_view_model_test.dart` — 0페이지 20건 → `loadMore`로 이어 붙임 → 마지막 페이지에서 `nextPage == null`, 다음 페이지 실패 시 기존 목록 유지 + `loadMoreError`, `refresh` 중 이전 목록 유지, 홈 긴급 카드는 `isUnconfirmedUrgent`만.
- [X] T034 [P] [US3] `test/features/inquiry/urgent_detail_test.dart` — 긴급 상세를 열면 `content` 호출 정확히 1회(다시 그리기·탭 이동 후에도 1회), 닫았다 다시 열면 1회 더, 일반 문의 준비 중 화면은 `content` 호출 0회, 화면 글자에 `@` 없음(FR-023).

### Implementation for User Story 3

- [X] T035 [US3] `lib/features/inquiry/presentation/teacher/teacher_inquiries_view_model.dart` — data-model §3 `TeacherInquiriesState`, `loadMore()`, `refresh()`(0페이지부터, 이전 값 유지). provider는 교사 홈과 문의 탭이 공유.
- [X] T036 [US3] `lib/features/inquiry/presentation/teacher/teacher_inquiries_page.dart` (F3-1, Figma 216-5587) — 항목: 긴급 표시·학생 이름·서버 제목·접수 시각·단계. 당겨서 새로 고침, 끝 근처에서 `loadMore`, 빈 상태·오류. 긴급 → `/teacher/inquiries/:id/urgent`, 일반 → `/teacher/inquiries/:id/pending`.
- [X] T037 [US3] `lib/features/inquiry/presentation/teacher/home_inquiry_section.dart` + `lib/features/teacher/presentation/teacher_home_page.dart` (F3-4, Figma 216-5567) — 확인 전 긴급 카드(누르면 긴급 상세), 최근 문의 3건, "문의 목록 보기"(문의 탭으로).
- [X] T038 [US3] `lib/features/inquiry/presentation/teacher/urgent_detail_view_model.dart` + `urgent_detail_page.dart` (F3-5, Figma 224-1245) — family(inquiryId) autoDispose. 열 때 `detail`·`content` 각 1회(research R8), 원문은 `SelectableText`가 아닌 `Text`로, 타임라인(`StageTimeline`), 열람 기록 안내(`notice_text`). 화면을 닫을 때 목록 provider 무효화.
- [X] T039 [P] [US3] `lib/features/inquiry/presentation/teacher/pending_detail_page.dart` — 일반 문의용 "정리된 내용과 원문 보기는 준비 중입니다" 안내와 학생 이름·제목·단계만. 원문 호출 없음(FR-024).
- [X] T040 [US3] `lib/app/shells/teacher_shell.dart`에 `AppLifecycleListener(onResume:)`와 `onTabSelected`(홈·문의 탭으로 돌아올 때) → 교사 문의 provider `refresh()`(research R7, FR-020a). `lib/app/router.dart`에 교사 문의 탭 실제 화면·`/teacher/inquiries/:inquiryId/urgent`·`/pending`(루트 Navigator) 연결.

**Checkpoint**: quickstart 14~18 통과.

---

## Phase 6: User Story 4 - 학부모가 처리 단계를 확인한다 (Priority: P2)

**Goal**: 학부모 문의 탭(F2-4)과 홈 문의 영역(F2-1/F2-1b), 카드 펼침 타임라인, 긴급 안내 다시 보기.

**Independent Test**: quickstart 시나리오 12·13·21.

### Tests for User Story 4

- [X] T041 [P] [US4] `test/features/inquiry/parent_inquiries_test.dart` — 목록 최신순, 카드 펼치면 상세 1회 호출 후 타임라인(일반·긴급 단계 순서), 다시 접고 펼쳐도 추가 호출 없음, "권한 확인(데모)" 펼치기 → 서버 안내, 홈 영역은 선택한 자녀 문의만 최대 3건, 문의 없음 → 빈 상태와 "문의 작성", 마이페이지 탭에 갔다가 문의 탭으로 돌아오면 목록을 다시 불러옴(FR-019).

### Implementation for User Story 4

- [X] T042 [US4] `lib/features/inquiry/presentation/parent/parent_inquiries_view_model.dart` — 목록 `AsyncNotifier` + 펼친 카드 상세 캐시(`Map<id, AsyncValue<ParentInquiryDetail>>`, 화면 생존 동안, research R6), `refresh()`.
- [X] T043 [US4] `lib/features/inquiry/presentation/parent/inquiry_card.dart` + `parent_inquiries_page.dart` (F2-4, Figma 216-5272) — 카드: 자녀 이름·"긴급 문의" 표시·접수 시각·현재 단계, 펼치면 `StageTimeline`. 긴급 카드 누르기 → `/parent/inquiries/:id/urgent`. 당겨서 새로 고침, 빈 상태·오류, "새 문의 작성".
- [X] T044 [US4] `lib/features/inquiry/presentation/parent/urgent_notice_page.dart` — 상세의 `notices`·`hotlines`로 `SubmitOutcome`을 만들어 `UrgentNoticeView` 재사용(FR-018).
- [X] T045 [US4] `lib/features/inquiry/presentation/parent/home_inquiry_section.dart` + `lib/features/parent/presentation/parent_home_page.dart` (F2-1 Figma 216-5162, F2-1b 216-5199) — 선택한 자녀의 최근 3건 카드, 없으면 빈 상태.
- [X] T046 [US4] `lib/app/router.dart`에 학부모 문의 탭 실제 화면·`/parent/inquiries/:inquiryId/urgent`(루트 Navigator) 연결. `parent_shell.dart`의 `onTabSelected`(홈·문의 탭으로 돌아올 때) → 학부모 문의 provider `refresh()`(FR-019).

**Checkpoint**: quickstart 12·13·21 통과.

---

## Phase 7: User Story 5 - 응답 가능 시간 밖 일반 문의 안내 (Priority: P2)

**Goal**: 지연 접수 안내(F2-5a).

**Independent Test**: quickstart 시나리오 9.

- [X] T047 [US5] `lib/features/inquiry/presentation/parent/submitted_page.dart`에 `DeferredNotice` 분기(F2-5a, Figma 216-5258): `SystemNotice`("선생님 응답 가능 시간에 전달됩니다.") + "문의 목록으로". `test/features/inquiry/inquiry_flow_test.dart`에 `밤늦게` 본문 → 지연 안내, 같은 단어 + `긴급` → 긴급 안내(US5-3) 케이스 추가.

**Checkpoint**: quickstart 9 통과.

---

## Phase 8: User Story 6 - 교사가 응답 가능 시간과 일반 알림을 설정한다 (Priority: P2)

**Goal**: 응답 가능 시간·알림 설정(F3-8).

**Independent Test**: quickstart 시나리오 19·20.

### Tests for User Story 6

- [X] T048 [P] [US6] `test/features/notification/settings_view_model_test.dart` — 설정 전(빈 목록) 안내 상태, 월 09:00~17:00 저장 → 다시 불러오면 같은 값, 시작 ≥ 종료 → 그 요일 오류·저장 요청 없음, 종료 `24:00` 허용, 서버 400 `fieldErrors` → 요일 아래, 일반 알림 끄기 저장.

### Implementation for User Story 6

- [X] T049 [P] [US6] `lib/features/notification/domain/models.dart`(`NotificationSettings`, `AvailabilityWindow`, `TimeOfDayValue`(`HH:mm`·`24:00` 변환), `DayOfWeek`) + `notification_repository.dart`(contracts/api-usage.md notification 표).
- [X] T050 [P] [US6] `lib/features/notification/data/notification_repository_impl.dart` · `mock_notification_repository.dart`(메모리 저장, 시작 ≥ 종료면 400 `INVALID_INPUT` + fieldErrors, 기기 등록·해제 호출 기록) · `notification_repository_provider.dart`.
- [X] T051 [US6] `lib/features/notification/presentation/settings_view_model.dart` + `settings_page.dart` (F3-8, Figma 224-1287) — 요일별 "응답 가능" 스위치 + 시작·종료 시각 선택, 일반 알림 스위치, "긴급 알림은 항상 받습니다" 안내(끄는 항목 없음, FR-028), 설정 전 안내(FR-029), 저장 버튼. 기기 알림 권한 꺼짐 안내 자리는 US7(T058)이 채운다.
- [X] T052 [US6] `lib/features/teacher/presentation/teacher_my_page.dart`에 "응답 가능 시간 · 알림" 메뉴, `lib/app/router.dart`에 `/teacher/settings/notifications`(루트 Navigator) 연결.

**Checkpoint**: quickstart 19·20 통과.

---

## Phase 9: User Story 8 - 서버 없이 mock으로 모든 상태를 시연한다 (Priority: P2)

**Goal**: quickstart 데모 입력 전부를 자동 테스트로 고정.

**Independent Test**: `flutter test test/features/mock_scenarios_test.dart`.

- [X] T053 [US8] `test/features/mock_scenarios_test.dart`에 F2 시나리오 추가 — 본문 단어별 결과 6종, 60초 안 두 번째 일반 문의 429·긴급은 통과, 김두리 409, 학부모가 보낸 문의가 교사 목록에 보임(공유 저장소), 교사 목록 두 번째 조회에서 "정리 중" → 정리 완료, 같은 문의를 학부모 문의 탭에서 다시 불러오면 단계가 접수 → 정제로 보임, "원문 확인 필요" 존재, 25건 이상 페이지, "권한 확인(데모)" 403, `refresh@` 계정 문의 탭 정상.

**Checkpoint**: quickstart 1~21 전부 mock으로 재현.

---

## Phase 10: User Story 7 - 교사 기기로 문의 알림을 받는다 (Priority: P3)

**Goal**: FCM 등록·해제, 알림 수신 배너·새로 고침, 알림 눌러 이동, 로그인 뒤 이동.

**Independent Test**: 가짜 `PushMessaging` 위젯 테스트 + quickstart 22~28(실기기, iOS는 Mac 팀원).

### Tests for User Story 7

- [X] T054 [P] [US7] `test/core/push_data_test.dart` — `PushData.fromMap`: 4종 `kind` + `inquiryId` → 경로(data-model §5), `inquiryId`가 UUID 아님·없음 → `/teacher/inquiries`, 모르는 `kind` → `/teacher/inquiries`.
- [X] T055 [P] [US7] `test/features/notification/device_registrar_test.dart` — 교사 `SignedIn` → 권한 허용 시 `registerDevice(token, platform)` 1회, 토큰 갱신 → 다시 등록, 학부모·관리자 로그인 → 등록 없음, 권한 거부 → 등록 없음, 권한이 이미 허용·거부된 상태면 교사 홈에 들어와도 다시 묻지 않음·"정하지 않음"이면 1회 요청(FR-031a), 로그아웃·탈퇴 직전 `unregisterCurrentDevice` 호출(실패해도 로그아웃 진행).
- [X] T056 [P] [US7] `test/features/notification/push_navigation_test.dart`(위젯, 가짜 `PushMessaging`) — 열린 상태 긴급 수신 → 앱 안 배너 고정 문구 + 교사 목록 새로 고침, 배너 "보기" → 긴급 상세, 알림으로 열기 → 경로 이동, 로그아웃 상태에서 알림으로 열기 → 교사 로그인 뒤 긴급 상세(`PendingNavigation`), 학부모로 로그인하면 버림. 마이페이지 탭에서 홈·문의 탭으로 돌아오면 교사 목록을 다시 불러옴(FR-020a). `test/core/router_redirect_test.dart`에 규칙 4-a 케이스 추가.

### Implementation for User Story 7

- [X] T057 [US7] `lib/core/push/push_messaging.dart`(인터페이스: `requestPermission()`, `permissionStatus()`(정하지 않음·허용·거부), `getToken()`, `onTokenRefresh`, `onForegroundMessage`, `onMessageOpened`, `initialMessage()` + `PushData`) · `noop_push_messaging.dart` · `pending_navigation.dart`(Notifier, 경로 1개) · `push_messaging_provider.dart`(`Env.useMock || !Env.hasFirebase` → noop).
- [X] T058 [US7] `lib/features/notification/presentation/device_registrar.dart` — `sessionControllerProvider` 구독: `SignedIn(teacher)` → (권한 허용 상태면) 토큰 등록 + `onTokenRefresh` 구독, 그 밖 → 구독 해제. 권한 요청은 교사 홈에 들어왔을 때 기기 권한이 "정하지 않음"인 경우에만 한다(FR-031a). 요청 여부를 앱이 저장하지 않고 `permissionStatus()`(정하지 않음·허용·거부)로 판단한다. 설정 화면(T051)에 권한 꺼짐 안내와 "기기 설정에서 켜 주세요" 문구 연결.
- [X] T059 [US7] `lib/features/me/presentation/me_view_model.dart`의 `logout`·`withdraw`에서 세션을 지우기 전에 `unregisterCurrentDevice()`를 부르고 실패는 무시(FR-031).
- [X] T060 [US7] `lib/app/shells/teacher_shell.dart`에 `onForegroundMessage` → `MaterialBanner`(서버 고정 제목·본문 + "보기"·"닫기") + 교사 문의 `refresh()`, `onMessageOpened`·`initialMessage` → 로그인 상태면 `go(경로)`, 아니면 `PendingNavigation`에 저장. `lib/app/router.dart` `resolveRedirect`에 규칙 4-a.
- [X] T061 [US7] `lib/core/push/fcm_push_messaging.dart` — `firebase_messaging` 구현(`setForegroundNotificationPresentationOptions`는 iOS에서 배너 중복을 피하도록 alert false). 알림 데이터·토큰을 로그·저장하지 않는다. `lib/main.dart`: `Env.hasFirebase`일 때만 `Firebase.initializeApp(options: FirebaseOptions(...Env 값))`, 실패해도 앱은 noop으로 계속(research R10). 백그라운드 핸들러는 두지 않는다(시스템 알림만 쓰므로 불필요).
- [X] T062 [P] [US7] Android: `MainActivity.kt`에서 채널 `damso_urgent`(중요도 높음, 이름 "긴급 문의 알림") 생성, `AndroidManifest.xml`에 `com.google.firebase.messaging.default_notification_channel_id` = `damso_urgent`. iOS: `Info.plist` `UIBackgroundModes`에 `remote-notification`. Xcode capability(Push Notifications)·APNs 키 등록은 Mac 팀원 작업으로 PR에 적는다.

**Checkpoint**: 자동 테스트 통과, Android 실기기·에뮬레이터(Google Play 이미지)에서 quickstart 22~28 확인. iOS는 Mac 팀원 확인 요청.

---

## Phase 11: Polish & Cross-Cutting Concerns

- [X] T063 [P] 화면 글자 점검 테스트 보강 — 교사 화면 전체(홈·목록·긴급 상세·준비 중)에 `@` 없음, 학부모 안내 화면 문구가 `notice_text` 상수와 정확히 일치(SC-006·SC-007). 학부모·교사 화면 어디에도 수정·삭제·발송 예약 버튼이나 문구가 없음(SC-005, FR-008).
- [X] T064 [P] 로그 금지 점검 — `grep -rn "print(\|debugPrint(\|log(" lib/`에 새 코드가 없음을 확인하고 결과를 PR에 적는다(SC-009).
- [X] T065 `docs/ia.md`에 하단 탭 구조 반영 여부 확인(이미 표에 있음, 변경 시에만 수정), `specs/002-inquiry-intake-urgent/quickstart.md`의 데모 입력이 구현과 같은지 확인.
- [X] T066 `api-v0.5` 태그가 공개되면 `/fetch-api api-v0.5` → `contracts/api-usage.md`와 차이를 비교해 data 계층만 수정(research R1). 태그 전이면 PR에 "원본 0.5.0 기준"을 명시.
- [X] T067 `flutter analyze` 0건, `flutter test` 전부 통과, mock 에뮬레이터로 quickstart 1~21 확인 후 결과를 PR 본문에 적는다.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: 의존 없음.
- **Foundational (Phase 2)**: Setup 후. **모든 Story를 막는다.** 끝날 때 F1 테스트 전부 통과.
- **US1 (Phase 3)**: Foundational 후.
- **US2 (Phase 4)**: US1의 `submitted_page.dart`(T025) 뒤.
- **US3 (Phase 5)**: Foundational 후. US1·US2와 독립(mock 공유 저장소만 같이 씀).
- **US4 (Phase 6)**: Foundational 후. T044는 US2의 `urgent_notice_view.dart`(T030) 뒤.
- **US5 (Phase 7)**: US1 T025 뒤.
- **US6 (Phase 8)**: Foundational 후, 독립.
- **US8 (Phase 9)**: US1~US6의 mock이 있어야 의미가 있다.
- **US7 (Phase 10)**: US3(교사 목록·긴급 상세)·US6(설정 화면) 뒤.
- **Polish (Phase 11)**: 원하는 Story 완료 후.

### User Story Dependencies

| Story | 선행 | 비고 |
|---|---|---|
| US1 (P1) | Phase 2 | MVP |
| US2 (P1) | US1 T025 | 안내 화면 분기 공유 |
| US3 (P1) | Phase 2 | |
| US4 (P2) | Phase 2, US2 T030 | 긴급 안내 다시 보기 재사용 |
| US5 (P2) | US1 T025 | |
| US6 (P2) | Phase 2 | |
| US8 (P2) | US1~US6 | |
| US7 (P3) | US3, US6 | |

### Within Each Story

- 테스트 작성 → 실패 확인 → 모델·Repository → ViewModel → 화면 → 라우터 경로 연결.

### 같은 파일을 고치는 작업 (병렬 금지)

- `lib/features/inquiry/` 폴더: T009(기존 뼈대 삭제) → T010·T011·T012·T013(새로 생성)
- `test/helpers/test_app.dart`: T009 → T020
- `lib/app/router.dart`: T009 → T019 → T027 → T040 → T046 → T052 → T060
- `lib/features/inquiry/presentation/parent/submitted_page.dart`: T025 → T031 → T047
- `lib/features/parent/presentation/parent_home_page.dart`: T026 → T045
- `lib/app/shells/teacher_shell.dart`: T018 → T040 → T060
- `lib/features/notification/presentation/settings_page.dart`: T051 → T058
- `android/app/src/main/AndroidManifest.xml`: T032 → T062
- `ios/Runner/Info.plist`: T032 → T062
- `test/core/router_redirect_test.dart`: T006 → T056
- `test/features/inquiry/inquiry_flow_test.dart`: T022 → T047

### Parallel Opportunities

- Phase 1: T002·T003·T004·T005 동시.
- Phase 2: T006·T007·T008(테스트) 동시, T009가 끝난 뒤 T010·T011·T012·T013·T017 동시.
- Foundational 후 US1 → US2와 US3·US6을 각각 다른 사람이 병렬 진행 가능(라우터 경로 추가만 순서대로 병합).

---

## Parallel Example: Phase 2 (Foundational)

```text
Task: "T006 test/core/router_redirect_test.dart"
Task: "T007 test/features/inquiry/submit_outcome_test.dart"
Task: "T008 test/features/inquiry/inquiry_repository_impl_test.dart"

Task: "T010 lib/features/inquiry/domain/models.dart"
Task: "T011 lib/features/inquiry/domain/notice_text.dart"
Task: "T012 lib/features/inquiry/domain/*_repository.dart"
Task: "T017 lib/core/widgets/system_notice.dart · stage_timeline.dart"
```

## Parallel Example: User Story 6

```text
Task: "T048 test/features/notification/settings_view_model_test.dart"
Task: "T049 lib/features/notification/domain/*"
Task: "T050 lib/features/notification/data/*"
```

---

## Implementation Strategy

### MVP First (Phase 1 → 2 → US1)

1. Setup·Foundational 완료 → F1 테스트 전부 통과 확인.
2. US1(문의 보내기·접수 안내) 완료 → quickstart 2~5·10·11 확인.

### 시연 가능한 최소 묶음 (P1 전부)

US1 + US2 + US3: 학부모가 일반·긴급 문의를 보내고, 교사가 긴급을 먼저 보고 원문을 연다.

### Incremental Delivery

1. P1(US1·US2·US3) → mock 시연
2. P2(US4·US5·US6·US8) → 처리 단계·지연 안내·설정·mock 전체
3. P3(US7) → 실서버·Firebase 설정 후 Android 실기기 알림, iOS는 Mac 팀원 확인

---

## Notes

- `[P]` = 다른 파일, 미완료 작업 의존 없음.
- 각 작업 또는 논리 묶음 후 커밋은 사용자가 요청할 때만 한다.
- 기존 뼈대 삭제(T009)·새 패키지(T001)·플랫폼 설정(T032·T062)은 2026-10-26 승인 범위다. 그 밖의 파일 삭제는 다시 묻는다.

## 구현 메모 (2026-10-26, 계획과 달라진 점)

| 작업 | 달라진 점 | 이유 |
|---|---|---|
| T017 | `StageTimeline`을 `lib/core/widgets` 대신 `lib/features/inquiry/presentation/stage_timeline.dart`에 둠 | 문의 기능 안에서만 쓰고, core 는 기능을 참조하지 않는다 |
| T023·T024 | 1분 제한 중에도 보내기 버튼을 막지 않음(남은 시간만 표시). spec FR-005·US1-7 수정 | 긴급 문의는 제한이 없으므로 앱이 막으면 안전 사안 전달이 늦어진다(원칙 IV) |
| T024 | 시간 초과 안내에 "보낸 문의 보기" 링크를 두지 않고 문구만 | 작성 화면(탭 위)에서 탭 안 목록으로 가면 쓴 글을 잃는다 |
| T024·T025 | 안내 화면은 `go` 대신 `pushReplacement`로 작성 화면을 교체 | `go`로 바꾸면 뒤로 가기에 앱이 닫힌다. 교체만으로 작성 화면 재진입을 막는다(FR-013) |
| T018 | 홈이 아닌 탭 첫 화면에서 기기 뒤로 가기 → 홈 탭으로(앱 종료 아님) | 에뮬레이터 E2E 에서 발견. 탭 Navigator 의 "뒤로 갈 곳 없음" 알림을 셸에서 바로잡음 |
| T038 | 긴급 상세는 원문(`content`)을 먼저, 상세(`detail`)를 뒤에 부름 | 첫 열람으로 바뀐 "교사 확인"이 타임라인에 바로 보이도록 |
| T051 | 요일별 시각 대신 "고른 요일 + 공통 시작·종료"(Figma F3-8). 저장은 요일당 한 구간 | Figma 기준. API 는 요일마다 같은 시각으로 보냄 |
| T059 | 기기 등록 해제는 로그아웃 때만. 탈퇴는 서버가 세션을 모두 끝내 알림이 가지 않음 | 탈퇴 실패(비밀번호 틀림) 때 등록이 풀리는 것을 막는다 |
| T060 | 알림 수신·이동을 교사 탭 셸이 아니라 앱 루트(`lib/app/push_listener.dart`)에서 처리 | 로그인 전에 알림을 눌러 열어도 받아야 한다(FR-031b) |
| T062 | 채널 ID `damso_inquiry`("문의 알림", 중요도 높음) 하나 | 서버가 채널을 지정하지 않아 모든 문의 알림이 기본 채널로 온다 |
| 화면 문구 | 안내 제목은 Figma 문구 대신 원본 명세의 고정 문구(예: "문의가 접수되었습니다.") | 원칙 V·SC-006. Figma 와 다른 문구는 디자인 확인 필요 |
| F3-5 | Figma 의 "○○ 학부모" 표시와 "답변 작성" 버튼은 넣지 않음 | 학부모 이름 비노출(FR-023), 답변은 F4 |
| F2-4 | Figma 의 상단 필터(전체·진행 중·답변 완료)는 넣지 않음 | spec 범위 밖(답변 상태는 F4) |
| T066 | `api-v0.5` 태그가 아직 없어 원본 명세 0.5.0 기준으로 구현 | 태그 공개 후 `/fetch-api api-v0.5`로 비교 |

## 코드 리뷰 반영 (2026-10-26, PR #8)

| # | 위치 | 고친 내용 |
|---|---|---|
| P0-1 | `compose_page.dart` | 보내는 중에는 뒤로 가기로 작성 화면을 닫지 않는다 — 긴급 안내·109·112를 반드시 보인다 |
| P0-2 | `teacher_inquiries_page.dart`·`_view_model.dart` | 다음 페이지가 실패하면 자동으로 다시 부르지 않고 "다시 시도"로만(무한 요청 방지) |
| P0-3 | `device_registrar.dart`·`push_listener.dart` | 토큰·권한 조회 오류를 잡고, 등록 실패·뒤늦은 권한 허용은 앱이 다시 앞으로 올 때 다시 등록 |
| P1-4 | `teacher_inquiries_view_model.dart` | 새로 고침과 다음 페이지가 겹치면 늦게 온 응답을 버린다(세대 번호) |
| P1-5 | `urgent_detail_view_model.dart` | 원문은 화면당 한 번만 — 상세만 실패해 다시 시도해도 원문은 다시 부르지 않음. 원문을 연 즉시 목록 새로 고침 |
| P1-6 | `router.dart`·`teacher_shell.dart`·`push_listener.dart` | 알림으로 연 긴급 상세를 교사 탭 셸 위에 띄움(뒤로 가면 탭 화면). 교사가 아니거나 가입 직후면 경로를 버림 |
| P1-7 | `urgent_notice_view_model.dart`·`pending_detail_view_model.dart` | 위젯 파일의 FutureProvider 를 ViewModel(AsyncNotifier)로 옮김(CLAUDE.md 의존 방향) |
| P1-8 | `settings_view_model.dart`·`settings_page.dart` | 요일마다 다른 시각은 시각을 바꾸지 않으면 그대로 저장, 다르다는 안내 표시 |
| P2-9 | `teacher_inquiries_view_model.dart` | 페이지를 이어 붙일 때 문의 ID 로 중복 제거 |
| P2-10 | `parent_shell.dart` | 탭 복귀 때 펼친 카드 상세 캐시도 비워 최신 타임라인을 다시 불러옴 |

