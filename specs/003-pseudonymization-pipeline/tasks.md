---

description: "F3 가명화·정제 파이프라인 화면 구현 작업 목록"
---

# Tasks: 가명화·정제 파이프라인 화면 (F3)

**Input**: `specs/003-pseudonymization-pipeline/` 설계 문서 (plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md)

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/api-usage.md, contracts/routes.md, quickstart.md

**Tests**: plan.md Project Structure와 research R11이 테스트 파일을 명시하므로 포함한다. 각 Phase의 테스트를 먼저 작성하고 실패를 확인한 뒤 구현한다. 테스트 패키지는 추가하지 않는다(`flutter_test`만).

**Organization**: User Story별로 묶는다. Phase 순서는 spec 우선순위를 따른다: US1 → US2 → US3 (P1) → US4 → US5 → US6 (P2).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: 다른 파일이고 미완료 작업에 의존하지 않아 병렬 가능
- **[Story]**: 해당 User Story (US1~US6)
- 모든 경로는 레포 루트 기준

## 공통 규칙 (모든 작업에 적용)

- **Figma**: `Figma 216-5607` 표기는 `https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/?node-id=216-5607` 프레임이다(`docs/ia.md`). 화면을 만들기 전에 프레임을 확인하고, 색·글꼴·간격은 `lib/core/theme/app_theme.dart` 토큰만 쓴다(정서강도 색은 `AppColors.emotionLow/Mid/High`·`emotion*Text`). Figma와 다르게 정한 곳은 research R7 표를 따른다.
- **아키텍처**: 위젯 → ViewModel(Riverpod `AsyncNotifier`) → `TeacherInquiryRepository` 인터페이스. `domain`은 Flutter·dio import 금지. 구현 선택은 기존 `teacherInquiryRepositoryProvider` 한 곳.
- **API**: `docs/api/openapi.yaml`(api-v0.4)과 `contracts/api-usage.md`. 사본은 수정하지 않는다. 응답 해석 오류는 `mapDioErrors`가 일반 안내로 바꾼다.
- **오류**: 화면에는 `AppException.message`만. 예외 객체·스택트레이스 표시 금지.
- **민감정보**: 번역본·원문을 `print`·`debugPrint`·`log`·기기 저장소에 남기지 않는다(원칙 III·VI). ViewModel 메모리에만.
- **학부모 정보**: F3 화면에 학부모 이름·이메일·연락처를 넣지 않는다. 상세 화면(F3-2·F3-3·F3-3a·정리 중)의 머리 줄은 `${studentName} · ${formatDateTime(submittedAt)} 접수 · ${NoticeText.stage(stage)}`(F2 상세 + 현재 처리 단계, FR-004·FR-019). F3-6 머리 줄은 단계 없이 `${studentName} · ${formatDateTime(submittedAt)}`.
- **고정 문구**: 화면 안내는 `lib/features/inquiry/domain/notice_text.dart` 상수만(data-model "고정 문구" 표). 서버 문장은 오류 `message`만.
- **렌더링**: 번역본·원문은 일반 `Text`만. `SelectableText`·링크·HTML 렌더 금지(FR-007).
- **비동기 ViewModel**: `await` 뒤에 `state`·`ref`를 쓰는 autoDispose ViewModel 메서드는 `final link = ref.keepAlive();` + `finally { link.close(); }`로 감싼다(F1·F2 리뷰 반영 규칙).
- **답변 작성 버튼 없음**: F3-2·F3-3·F3-6의 "답변 작성"은 F4가 더한다(FR-023). 하단 버튼 영역은 F4가 버튼을 더하기 쉽게 `Column`으로 둔다.
- **자동 조회 금지**: `Timer`·주기 조회를 쓰지 않는다. 상태 확인은 "다시 확인" 버튼·당겨서 새로 고침만(FR-012).

---

## Phase 1: Setup

**Purpose**: 공통 상수 준비. 새 패키지·설정 없음.

- [X] T001 [P] `lib/core/error/error_codes.dart`에 `refinementNotReady = 'REFINEMENT_NOT_READY'`, `refinementRetryUnavailable = 'REFINEMENT_RETRY_UNAVAILABLE'` 추가(contracts/api-usage.md "오류 코드").
- [X] T002 [P] `lib/features/inquiry/domain/notice_text.dart`에 data-model "고정 문구 (`NoticeText` 추가)" 표의 문자열 상수 전부 추가(`refinedBadge` ~ `recheckButton`). 정서 이름 함수는 enum이 생긴 뒤 T015에서 더한다. 이 시점에는 `pendingDetail`을 지우지 않는다(T040에서).

---

## Phase 2: Foundational (모델·Repository·mock 저장소 — 모든 Story의 선행 조건)

**Purpose**: 번역본·재시도 데이터를 실서버·mock에서 모두 받을 수 있게 한다.

**⚠️ CRITICAL**: 이 Phase가 끝나기 전에는 어떤 User Story도 시작하지 않는다. 끝날 때 기존 F1·F2 테스트 전부가 통과해야 한다.

### Tests (먼저 작성, 실패 확인)

- [X] T003 [P] `test/features/inquiry/inquiry_repository_impl_test.dart`에 그룹 "F3" 추가 — 기존 가짜 `HttpClientAdapter` 사용: (a) `detail`이 `retryAvailable: true`를 읽음, (b) `refinement(id)`가 `GET /api/v1/teacher/inquiries/{id}/refinement`를 부르고 `title·facts·requests·emotionLevel·emotionLabels·refinedAt`을 해석, (c) `requests: ""` 그대로 빈 문자열, (d) `emotionLevel: "EXTREME"` → `null`, (e) `emotionLabels: ["ANGER","UNKNOWN","ANGER","WORRY","SADNESS"]` → `[anger, worry]`(모르는 값 제거 → 중복 제거 → 앞에서 2개), (f) `retryRefinement(id)`가 `POST …/refinement/retry`(본문 없음), 202 `{refinementStatus: "PENDING"}` → `RefinementStatus.pending`, (g) 409 `REFINEMENT_NOT_READY`·`REFINEMENT_RETRY_UNAVAILABLE` → `AppException.code`가 각 상수.
- [X] T004 [P] `test/features/mock_scenarios_test.dart`에 그룹 "F3 mock 저장소 규칙" 추가 — `MockInquiryStore` 직접 사용: (a) `REFINED` 아닌 문의의 `refinementForTeacher` → 409 `refinementNotReady`, (b) 정제 단계 문의의 번역본 첫 열람 → 단계 `teacherConfirmed`, 두 번째 열람은 이력 그대로, (c) `NEEDS_ORIGINAL`·단계 `received` 문의의 원문 첫 열람 → `teacherConfirmed`, 번역본 있는 문의의 원문 열람은 단계 그대로, (d) 재시도 가능 문의 `retryRefinement` → `pending`·`retryAvailable false`, 두 번째 호출 → 409 `refinementRetryUnavailable`, (e) 긴급 문의 `retryRefinement` → 409.

### Implementation

- [X] T005 `lib/features/inquiry/domain/models.dart` 수정(data-model "새 모델"·"기존 모델 변경"): `TeacherInquiryDetail`에 `required this.retryAvailable`(`bool`) 추가. `enum EmotionLevel { low('LOW'), medium('MEDIUM'), high('HIGH') }`·`enum EmotionLabel { anxiety('ANXIETY'), dissatisfaction('DISSATISFACTION'), anger('ANGER'), worry('WORRY'), frustration('FRUSTRATION'), sadness('SADNESS') }` — 각 `static … ? fromServer(Object? value)`는 모르는 값·null이면 **null**(예외 아님, research R8). `class InquiryRefinement { inquiryId, title, facts, requests, EmotionLevel? emotionLevel, List<EmotionLabel> emotionLabels, DateTime refinedAt }` — 주석에 "`requests`는 없으면 빈 문자열", "`emotionLabels` 0~2개", "화면 메모리에만" 명시.
- [X] T006 `lib/features/inquiry/domain/teacher_inquiry_repository.dart`에 `Future<InquiryRefinement> refinement(String inquiryId);`(주석: `REFINED`일 때만 부른다, 첫 열람에 "교사 확인", 409 `REFINEMENT_NOT_READY`)와 `Future<RefinementStatus> retryRefinement(String inquiryId);`(주석: 1건당 1회, 409 `REFINEMENT_RETRY_UNAVAILABLE`) 추가. `content` 주석을 "긴급 상세(F3-5)와 원문 열람(F3-6)에서 화면당 한 번"으로 고친다.
- [X] T007 `lib/features/inquiry/data/inquiry_json.dart` 수정: `teacherDetail`에 `retryAvailable: j['retryAvailable'] as bool`, `static InquiryRefinement refinement(Map<String, dynamic> j)` 추가 — 라벨은 `fromServer` → `whereType` → 순서 유지 중복 제거 → `take(2)`(T003 (e)).
- [X] T008 `lib/features/inquiry/data/teacher_inquiry_repository_impl.dart`에 `refinement`(`GET …/refinement`)·`retryRefinement`(`POST …/refinement/retry`, `RefinementStatus.fromServer(res.data!['refinementStatus'])`) 추가. 모두 `mapDioErrors`로 감싼다.
- [X] T009 `lib/features/inquiry/data/mock_inquiry_store.dart` 수정(research R10): `_MockInquiry`에 `InquiryRefinement? refinement`, `bool retryAvailable`, `bool? retrySucceeds`(재시도 결과 미리 정함), `bool retryPending`, `bool refineOnSecondDetailRead`, `int detailReads` 추가. (1) `detailForTeacher`가 `retryAvailable`을 넣고, `detailReads++` 후 — `refineOnSecondDetailRead` 문의(`…000a`)는 **자기 상세의 두 번째 교사 조회**에서 정리 완료(목록 조회 횟수와 무관, analyze G1), `retryPending` 문의는 다음 상세 조회에서 `retrySucceeds`대로 정리 완료(`REFINED`, 번역본 넣음) 또는 `NEEDS_ORIGINAL`(`retryAvailable false`)로. 정리 완료 시 단계가 이미 `teacherConfirmed`면 "정제"를 더하지 않는다(spec Edge, 단계는 앞으로만). (2) `refinementForTeacher(id)` — `REFINED` 아니면 409 `refinementNotReady`, 마지막 단계가 `refined`면 `teacherConfirmed` 추가. (3) `retryForTeacher(id)` — 긴급·`retryAvailable false`면 409 `refinementRetryUnavailable`(메시지 `다시 정리할 수 없는 문의입니다.`), 아니면 `retryAvailable = false`, `retryPending = true`, 상태 `pending` 반환. (4) `contentForTeacher` — 일반 문의가 `needsOriginal`이고 마지막 단계가 `received`면 `teacherConfirmed` 추가. (5) `_refinePending`(목록 두 번째 조회, `refinePending` 문의 — `…0003`과 학부모가 새로 보낸 문의, F2 동작 그대로이며 `refineOnSecondDetailRead` 문의는 건드리지 않음)과 (1)이 같은 정리 완료 함수를 쓰고 고정 mock 번역본(제목 `친구 관계 관련 문의`, 정서 보통·걱정)을 넣는다. (6) 기존 정리 완료 시드(`…0005`, `b2…` 25건)에 번역본을 넣는다(`…0005`: 보통·걱정).
- [X] T010 `lib/features/inquiry/data/mock_inquiry_store.dart` `_seed()`에 research R10 데모 추가: `…0004`(박서준)는 `retryAvailable: true, retrySucceeds: true`로 바꾸고, `a1000000-0000-4000-8000-000000000006`(이도윤, 원문 확인 필요, `retryAvailable: true, retrySucceeds: false`, 6시간 전), `…0007`(박서준, 원문 확인 필요, `retryAvailable: false`, 1일 전), `…0008`(이도윤, 정리 완료·단계 정제·교사 확인 없음, 번역본 높음·`[anger, frustration]`, 1시간 전), `…0009`(김하나, 정리 완료·단계 정제, 번역본 `requests: ''`·라벨 없음·낮음, 4시간 전, parentAccount `parent`), `a1000000-0000-4000-8000-00000000000a`(김하나, 정리 중, `refineOnSecondDetailRead: true`, `refinePending: false`, 3시간 전, parentAccount `parent`). `…0003`은 바꾸지 않는다(F2 테스트용). 원문 확인 필요 데모 제목은 `원문 확인 필요`, 정리 완료 데모 제목은 번역본 제목과 같게.
- [X] T011 `lib/features/inquiry/data/mock_teacher_inquiry_repository.dart`에 `refinement`·`retryRefinement` 추가 — 기존 메서드처럼 `_delay` 후 `_checkClassroom()` 뒤 저장소 호출.

**Checkpoint**: `flutter test` — T003·T004 통과, 기존 테스트 전부 통과(F2 mock 시나리오의 "두 번째 조회 정리 완료"도 그대로).

---

## Phase 3: User Story 1 - 교사가 정리된 "번역본"을 본다 (Priority: P1) 🎯 MVP

**Goal**: 정리 완료 일반 문의를 누르면 F3-2(Figma 216-5607)가 열리고 번역본이 보인다. 첫 열람으로 바뀐 단계가 목록에 반영된다.

**Independent Test**: mock 교사로 `…0008`(이도윤)을 열어 사실관계·요청사항·정서강도 "높음"·라벨 "분노·답답함"이 보이고, 돌아오면 목록 단계가 "교사 확인"인지 확인(quickstart 1~3).

### Tests for User Story 1

- [X] T012 [P] [US1] `test/features/inquiry/general_detail_view_model_test.dart` 작성(그룹 "정리 완료") — `ProviderContainer` + mock(필요하면 `MockTeacherInquiryRepository`를 상속한 호출 기록용 테스트 클래스, `urgent_detail_test.dart`의 `_CountingTeacherRepo` 방식): (a) `REFINED` 문의 → 상태 `Refined`, `refinement` 1회 호출, (b) `refinement`가 409 `refinementNotReady` 후 다시 읽은 상세가 `NEEDS_ORIGINAL` → 상태 `NeedsOriginal`, 상세 2회·번역본 1회, (c) 다시 읽어도 `REFINED`인데 또 409 → 오류 상태(번역본 2회에서 멈춤, 무한 반복 없음), (d) 번역본을 받은 뒤 `teacherInquiriesViewModelProvider`의 `refresh`가 불림(목록 조회 횟수 증가로 확인), (e) 상세가 긴급(`refinementStatus == null`) → `UrgentRedirect` 같은 상태로 알림(화면이 `/urgent`로 replace).
- [X] T013 [P] [US1] `test/features/inquiry/general_detail_flow_test.dart` 작성(위젯, `test/helpers/test_app.dart` mock 앱) — 교사 로그인 → 목록에서 `…0008` 제목 누름 → `NoticeText.refinedBadge`·`translationLabel`·머리 줄의 단계 "정제"(첫 열람 직후 다시 그려지면 "교사 확인"도 허용)·`factsLabel`·`requestsLabel`·`emotionLabel`·"높음"·"분노"·"답답함"·`contentViewWillLog`·"원문 보기" 보임, "답변 작성"·"준비 중" 없음, 화면 모든 `Text`에 `@` 없음(`urgent_detail_test.dart`의 `expectNoEmail` 방식). `…0009`는 `noRequests` 보이고 라벨 칩 없음.

### Implementation for User Story 1

- [X] T014 [US1] `lib/features/inquiry/presentation/teacher/general_detail_view_model.dart` 생성 — data-model "화면 상태"의 `sealed class GeneralDetail`(`Refined(detail, refinement)`, `NeedsOriginal(detail)`, `Refining(detail, afterRetry)`) + 긴급 확인용 `UrgentRedirect`. 이를 감싸는 `GeneralDetailState { GeneralDetail view; bool isRetrying; bool isRechecking; String? message }`(`copyWith` 포함, 보조 값은 US2에서 쓴다). `GeneralDetailViewModel extends AsyncNotifier<GeneralDetailState>`(생성자 `inquiryId`, `AsyncNotifierProvider.autoDispose.family<…, String>` = `generalDetailViewModelProvider`). `build()`는 `ref.read(teacherInquiryRepositoryProvider)`(watch 아님, `UrgentDetailViewModel`과 같은 이유)로 data-model "상태 전이"의 build 부분을 구현: `detail` → `REFINED`면 `refinement`(409 `refinementNotReady`면 상세 1회만 다시 읽고 다시 고름) → 번역본을 받으면 `Future.microtask`로 `teacherInquiriesViewModelProvider.notifier.refresh()`(긴급 상세 ViewModel과 같은 방식). 이 Phase에서는 `PENDING`→`Refining(afterRetry: false)`, `NEEDS_ORIGINAL`→`NeedsOriginal`까지만 고르고 화면은 US2·US4에서 채운다.
- [X] T015 [P] [US1] `notice_text.dart`에 `static String emotionLevel(EmotionLevel)`(낮음·보통·높음)·`static String emotionLabel(EmotionLabel)`(불안·불만·분노·걱정·답답함·슬픔) `switch` 추가, 그리고 `lib/features/inquiry/presentation/teacher/refinement_view.dart` 생성 — `RefinementView({required InquiryRefinement refinement})`: Figma 216-5607 카드 배치. 사실관계 카드·요청사항 카드(`AppColors.bgSurface`, 테두리 `borderDefault`, 제목 `subtitle`, 본문 `small`·`textSecondary`), 요청사항이 빈 문자열이면 `NoticeText.noRequests`. 정서 카드(Figma "빠른 회신 권장" 자리, 배경 `statusInfoSoft`): 제목 `NoticeText.emotionLabel` + 단계 표시(`emotionLevel`별 `emotionLow/Mid/High` 점·`emotion*Text` 글자) + 라벨 칩(`Wrap`, `pill`). `emotionLevel == null`이면 단계 표시 줄만 숨기고 라벨이 있으면 카드는 보인다. 라벨이 비면 칩 줄 숨김. 둘 다 없으면 정서 카드 전체 숨김(FR-005a, research R8). F4가 다시 쓸 수 있게 화면 의존(라우터·ViewModel) 없이 만든다.
- [X] T016 [US1] `lib/features/inquiry/presentation/teacher/general_detail_page.dart` 생성 — `ConsumerWidget`, `AppBar` 제목 "문의 상세", 본문 `AsyncView`(`onRetry: ref.invalidate`). `Refined`: 배지(`refinedBadge`, `statusInfoSoft`·`statusInfo`, `pill`) + `translationLabel` → 제목(`display`) → 머리 줄(공통 규칙) → `RefinementView` → `contentViewWillLog`(`small`·`textSecondary`) → 하단 `OutlinedButton` "원문 보기". 원문 이동은 페이지 안 private 함수 `_openContent(context, ref)` **한 곳**에만 둔다: `await context.push('/teacher/inquiries/$id/content')` 뒤 `ref.read(generalDetailViewModelProvider(id).notifier).recheck()`(돌아오면 상태 다시 읽기, FR-018). `recheck()`는 T021에서 생기므로 이 Phase에서는 `ref.invalidate(generalDetailViewModelProvider(id))`로 두고 T021에서 `recheck()`로 바꾼다. `UrgentRedirect`면 `WidgetsBinding.instance.addPostFrameCallback`으로 `context.replace('/teacher/inquiries/$id/urgent')`. 다른 상태는 US2·US4가 채울 자리로 `switch`에 남겨 두되 임시로 `SizedBox.shrink()` 금지 — 최소한 머리 줄과 원문 보기는 보이게.
- [X] T017 [US1] `lib/app/router.dart`에 `GoRoute(path: '/teacher/inquiries/:inquiryId/general', builder: … GeneralDetailPage(inquiryId: …))`를 `/urgent` 옆(루트 Navigator)에 추가. 기존 `/pending` 경로는 T040까지 남긴다.
- [X] T030 [US1] `lib/app/router.dart`에 `GoRoute(path: '/teacher/inquiries/:inquiryId/content', …)` 추가(`/general` 옆, 루트 Navigator). ContentPage는 US3(T028)에서 생기므로 이 Phase에서는 builder를 임시 `Scaffold(appBar: AppBar(title: Text('원문')))`로 두고, T028이 `ContentPage(inquiryId: …)`로 바꾼다(analyze O1 — MVP에서 원문 보기를 눌러도 경로 오류가 나지 않게).
- [X] T018 [US1] `lib/features/inquiry/presentation/teacher/teacher_inquiry_tile.dart`의 `pathOf`: 일반 문의 → `'/teacher/inquiries/${item.inquiryId}/general'`, 주석을 "긴급은 원문 상세(F3-5), 일반은 상태별 상세(F3-2·F3-3·F3-3a, F3 spec FR-001)"로. `home_inquiry_section.dart`는 `pathOf`를 쓰므로 수정 없음(확인만).

**Checkpoint**: US1 독립 확인 — quickstart 1~3, T012·T013 통과.

---

## Phase 4: User Story 2 - 정리 실패 문의: 실패 안내·원문 확인·다시 정리하기 (Priority: P1)

**Goal**: `NEEDS_ORIGINAL` 문의는 F3-3(Figma 216-5627), 다시 정리하기를 받아들이면 F3-3a(Figma 216-5640), 다시 확인으로 결과를 본다.

**Independent Test**: mock `…0004`(성공)·`…0006`(실패)·`…0007`(사용함)으로 quickstart 6~11 확인.

### Tests for User Story 2

- [X] T019 [P] [US2] `test/features/inquiry/general_detail_view_model_test.dart`에 그룹 "원문 확인 필요·다시 정리하기" 추가: (a) `NEEDS_ORIGINAL`+`retryAvailable` → `NeedsOriginal`, 번역본 호출 0회, (b) `retry()` 202 `pending` → `Refining(afterRetry: true)`, (c) `retry()`를 await 없이 두 번 → Repository `retryRefinement` 1회, `isRetrying` 동안 true, (d) 409 `refinementRetryUnavailable` → `retryMessage`(스낵바용 일회성 값)에 서버 메시지, 상세 다시 읽어 `retryAvailable false`, (e) 네트워크 오류(`AppException`, code 없음) → 메시지, 상태 `NeedsOriginal` 그대로·`retryAvailable` 그대로·`isRetrying false`, (f) 202인데 응답 상태가 `REFINED` → 상세 다시 읽어 `Refined`, (g) `Refining(afterRetry: true)`에서 `recheck()` → mock 성공 문의는 `Refined`, 실패 문의는 `NeedsOriginal`(`retryAvailable false`), (h) `recheck()` 중에도 `state.value`가 이전 값 유지.
- [X] T020 [P] [US2] `test/features/inquiry/general_detail_flow_test.dart`에 추가: `…0006` 열기 → `refinementFailed`·"원문 보기"·`retryButton` 보임, 번역본 글자 없음 → `retryButton` 탭 → `retryingBadge`·`retryingHeading`·`retryRemainingNone`·`recheckButton`·"문의 목록으로" → `recheckButton` 탭 → `retryButton` 없고 `retryLimitReached` 보임. `…0004`는 같은 흐름 끝에 번역본(`factsLabel`) 보임.

### Implementation for User Story 2

- [X] T021 [US2] `general_detail_view_model.dart`에 `retry()`·`recheck()`·`clearMessage()` 추가(data-model "상태 전이", research R4·R5). 보조 값은 T014의 `GeneralDetailState` 필드를 쓴다. `retry()`: `NeedsOriginal`·`retryAvailable`·`!isRetrying`일 때만, `keepAlive` 규칙, 결과는 data-model 표대로. `_afterRetry` 플래그를 ViewModel 필드로 두고 `PENDING`이면 `Refining(afterRetry: _afterRetry)`. `recheck()`: `isRechecking`만 켜고 이전 `view` 유지, 끝나면 새 상태. `message`는 화면이 스낵바로 보인 뒤 `clearMessage()`로 지운다. 끝으로 `general_detail_page.dart`의 `_openContent`(T016)에서 임시 `ref.invalidate(…)`를 `recheck()`로 바꾼다.
- [X] T022 [US2] `general_detail_page.dart`에 `NeedsOriginal` 본문(Figma 216-5627): 배지 `needsOriginalBadge`(`statusWarningSoft`·`statusWarning`) → 제목 `needsOriginalHeading` → 머리 줄 → `SystemNotice(NoticeText.refinementFailed, icon: Icons.warning_amber_outlined)` → "원문 보기"(OutlinedButton) → `retryAvailable`이면 `OutlinedButton(NoticeText.retryButton)`(요청 중 비활성·진행 표시), 아니면 `SystemNotice(NoticeText.retryLimitReached)` → `contentViewWillLog`. 정리 결과 위젯은 어떤 형태로도 두지 않는다(FR-010, 원칙 IV).
- [X] T023 [US2] `general_detail_page.dart`에 `Refining(afterRetry: true)` 본문(Figma 216-5640): 배지 `retryingBadge`(`statusInfoSoft`) → 제목 `retryingHeading` → `SystemNotice(NoticeText.refiningGuide)` → "원문 보기" → `OutlinedButton(NoticeText.recheckButton)`(`isRechecking` 동안 비활성) → 카드 `retryRemainingNone`(`bgSubtle`) → 하단 `FilledButton` "문의 목록으로"(`context.go('/teacher/inquiries')`). `ref.listen`으로 `message`가 생기면 `ScaffoldMessenger` 스낵바 후 `clearMessage()`.
- [X] T024 [US2] `general_detail_page.dart` 본문 전체를 `RefreshIndicator(onRefresh: notifier.recheck)` + 항상 스크롤 가능한 `ListView`(`AlwaysScrollableScrollPhysics`)로 감싼다(research R5). 모든 상태에서 당겨서 새로 고침이 된다.

**Checkpoint**: US2 독립 확인 — quickstart 6~11, T019·T020 통과.

---

## Phase 5: User Story 3 - 원문 열람(F3-6)과 열람 기록 안내 (Priority: P1)

**Goal**: 원문 보기를 누르면 F3-6(Figma 216-5653)이 열리고 원문이 화면당 1회 열람된다.

**Independent Test**: 정리 완료·정리 중·원문 확인 필요 문의에서 원문을 열어 quickstart 12~14 확인.

### Tests for User Story 3

- [X] T025 [P] [US3] `test/features/inquiry/content_view_model_test.dart` 작성(`urgent_detail_test.dart`의 호출 기록 mock 방식): (a) 화면 하나에서 `content` 1회, 다시 그리기·`ref.watch` 반복에도 1회, (b) 상세만 실패 → 다시 시도(`ref.invalidate`) 때 `content` 재호출 없음·원문 재사용, (c) `content` 실패 → 오류 상태, 원문 없음, 다시 시도하면 `content` 다시 호출, (d) 원문을 받은 뒤 목록 `refresh` 호출, (e) Provider를 dispose하고 새로 만들면(새 화면) `content` 다시 호출(FR-016).
- [X] T026 [P] [US3] `test/features/inquiry/general_detail_flow_test.dart`에 추가: `…0007`(재시도 사용함) 열기 → "원문 보기" → 제목·"작성한 원문"·원문 글자·`contentViewedLogged`·"문의 상세로" 보임, `@`·"답변 작성" 없음 → "문의 상세로" → 상세로 돌아옴, 목록으로 가면 그 문의 단계 "교사 확인"(원문 확인 필요 첫 열람).

### Implementation for User Story 3

- [X] T027 [US3] `lib/features/inquiry/presentation/teacher/content_view_model.dart` 생성 — `ContentView { TeacherInquiryDetail detail; String content }`, `ContentViewModel extends AsyncNotifier<ContentView>`(family `inquiryId`, autoDispose, `contentViewModelProvider`). `UrgentDetailViewModel`과 같은 규칙: `ref.read`로 Repository, `_content` 필드에 받은 원문 보관, `content`를 먼저 부르고 받은 뒤 `Future.microtask`로 목록 `refresh()`, 그다음 `detail`(research R6). 클래스 주석에 "원문 호출마다 감사 기록이 남으므로 화면당 1회".
- [X] T028 [US3] `lib/features/inquiry/presentation/teacher/content_page.dart` 생성 — Figma 216-5653: `AppBar` 제목 "원문", 제목(`display`, 상세의 서버 제목) → 머리 줄(공통 규칙, "접수" 없이 시각만 Figma와 같게 해도 됨) → 카드(`bgSurface`, 테두리 `borderDefault`) 제목 "작성한 원문"(`subtitle`) + 원문 `Text`(`small`) → `SystemNotice(NoticeText.contentViewedLogged, icon: Icons.shield_outlined)`(`statusSystemSoft`) → 하단 `OutlinedButton` "문의 상세로"(`context.pop()`). `AsyncView` 오류 시 서버 메시지 + 다시 시도. 끝으로 `lib/app/router.dart`의 `/content` 임시 builder(T030)를 `ContentPage(inquiryId: s.pathParameters['inquiryId']!)`로 바꾼다.
- [X] T029 [US3] `general_detail_page.dart`의 모든 "원문 보기" 버튼(`Refined`·`NeedsOriginal`·`Refining`)이 T016의 `_openContent` 하나만 부르는지 확인하고, 다른 곳에 `context.push(…/content)`가 있으면 `_openContent`로 바꾼다(research R6, FR-015·018). 이동 코드는 파일 안에 한 곳뿐이어야 한다.

**Checkpoint**: US3 독립 확인 — quickstart 12~14, T025·T026 통과.

---

## Phase 6: User Story 4 - 정리 중인 문의도 열고 다시 확인한다 (Priority: P2)

**Goal**: `PENDING`(첫 정리) 문의는 정리 중 화면(Figma 없음, 216-5640 배치)과 다시 확인으로 결과를 본다.

**Independent Test**: mock `…000a`(김하나 · 정리 중, 3시간 전)을 열어 quickstart 4~5 확인. `…0003`은 F2 데모라 쓰지 않는다(analyze G1).

### Tests for User Story 4

- [X] T031 [P] [US4] `test/features/inquiry/general_detail_view_model_test.dart`에 그룹 "정리 중" 추가: (a) 첫 상세가 `PENDING` → `Refining(afterRetry: false)`, 번역본 호출 0회, (b) 아무것도 안 하면 상태 그대로(타이머 없음 — `fakeAsync`로 1분 흘려도 Repository 호출 수 그대로), (c) `…000a`: `recheck()` → mock 두 번째 상세 조회에서 `Refined`, (d) `…000a`를 열기 전에 교사 목록을 여러 번 새로 고쳐도 `…000a`는 정리 중 그대로(목록 조회 횟수와 무관, analyze G1).
- [X] T032 [P] [US4] `test/features/inquiry/general_detail_flow_test.dart`에 추가: 먼저 `…0008`을 열고 돌아온 뒤(목록 새로 고침이 일어난 상태) `…000a` 열기 → `refiningBadge`·`refiningHeading`·`refiningGuide`·"원문 보기"·`recheckButton` 보임, 번역본 없음 → `recheckButton` 탭 → 번역본(`factsLabel`) 보임. 당겨서 새로 고침(`tester.fling` 아래로)으로도 같은 결과(별도 문의 또는 새 앱에서).

### Implementation for User Story 4

- [X] T033 [US4] `general_detail_page.dart`에 `Refining(afterRetry: false)` 본문: T023과 같은 배치에 배지 `refiningBadge`·제목 `refiningHeading`, `retryRemainingNone` 카드 없음. 공통 부분(안내·원문 보기·다시 확인·문의 목록으로)은 T023과 같은 private 위젯으로 묶어 중복을 없앤다.

**Checkpoint**: US4 독립 확인 — quickstart 4~5·11, T031·T032 통과.

---

## Phase 7: User Story 5 - 학부모는 정리 결과 없이 처리 단계만 본다 (Priority: P2)

**Goal**: F2 학부모 타임라인이 F3 단계(정제·교사 확인)를 맞게 보이고, 정리 결과는 어디에도 없다. 새 화면 없음.

**Independent Test**: quickstart 16~17.

- [X] T034 [P] [US5] `test/features/mock_scenarios_test.dart` 그룹 "F3 mock 저장소 규칙"에 추가: 교사가 `…0009` 번역본을 연 뒤 `detailForParent('parent', …0009)` 타임라인이 접수 → 정제 → 교사 확인.
- [X] T035 [P] [US5] `test/features/inquiry/parent_inquiries_test.dart`에 추가(위젯): 학부모로 `…0009` 카드 펼침 → "정제" 보임, "번역본"·"정서강도"·"자동 정리"·"원문 확인 필요" 글자 없음. 정리 중인 `…000a` 카드 펼침 → "접수"만, "정리 중" 글자 없음.

**Checkpoint**: US5 확인 — T034·T035 통과. `lib/` 수정 없음이 정상(수정이 필요하면 원인을 기록하고 진행).

---

## Phase 8: User Story 6 - 서버 없이 mock으로 모든 상태 시연 (Priority: P2)

**Goal**: quickstart 데모 문의표가 mock에서 그대로 재현된다.

**Independent Test**: `flutter run --dart-define=USE_MOCK=true`로 quickstart 1~20.

- [X] T036 [US6] `test/features/mock_scenarios_test.dart`에 그룹 "F3 데모 문의" 추가 — research R10 표 행마다: `…000a` 상세 1번째 `pending`·2번째 `refined`(사이에 목록 조회 3번을 끼워도 같음), `…0003`은 F2 규칙 그대로(목록 2번째 조회에 `refined`), `…0004` 재시도 → 다음 상세 `refined`·번역본 있음·단계 정제, `…0006` 재시도 → 다음 상세 `needsOriginal`·`retryAvailable false`, `…0007` `retryAvailable false`, `…0008` 번역본 `high`·`[anger, frustration]`, `…0009` `requests == ''`·라벨 없음·`low`, `noclass` 계정 `refinement`·`retryRefinement` → 403.
- [ ] T037 [US6] `quickstart.md`의 mock 데모 문의표와 실제 목록 순서·제목이 맞는지 에뮬레이터로 확인하고, 다르면 quickstart를 고친다(코드가 기준이 아니라 research R10이 기준 — 코드가 R10과 다르면 코드를 고친다).

**Checkpoint**: US6 확인 — T036 통과, quickstart 표와 앱이 일치.

---

## Phase 9: Polish & Cross-Cutting Concerns

- [X] T038 [P] `test/core/router_redirect_test.dart`: `Role.teacher` 경로 목록의 `/teacher/inquiries/<uuid>/pending`을 `/general`로 바꾸고 `/content`를 추가한다. 이 목록은 기존 테스트가 "본인 역할 → null, 다른 역할 → 그 역할의 `homePath`"로 이미 검사하므로 목록만 고치면 된다(T040 전에 하면 `/pending`도 잠시 함께 둔다).
- [X] T039 [P] F3 화면 점검(위젯 테스트 `general_detail_flow_test.dart`에 한 케이스로): 정리 완료·원문 확인 필요·정리 중·원문 열람 네 화면에서 `@` 없음, "학부모" 글자 없음, "답변 작성" 없음, "준비 중" 없음(FR-019·023, SC-006·008).
- [X] T040 **사용자 승인 후** `lib/features/inquiry/presentation/teacher/pending_detail_page.dart`·`pending_detail_view_model.dart` 삭제, `lib/app/router.dart`의 `/pending` 경로·import 삭제, `notice_text.dart`의 `pendingDetail` 삭제(research R9). 승인이 없으면 이 작업만 남기고 진행 상황에 적는다.
- [X] T041 [P] 민감정보 점검: `grep -rn "print(\|debugPrint(\|log(" lib/features/inquiry`에 번역본·원문 출력이 없는지, `SelectableText`·`Html`·`WebView`가 `lib/`에 없는지 확인.
- [X] T042 `flutter analyze` 경고 0, `flutter test` 전부 통과. 실패는 숨기지 않고 원인과 함께 보고.
- [ ] T043 에뮬레이터 mock 실행으로 quickstart 1~20 확인(Android). 결과를 이 파일 끝 "구현 메모"에 적는다.
- [X] T044 [P] F2 문서 정리: `specs/002-inquiry-intake-urgent/spec.md` FR-024 끝에 "(F3에서 대체: specs/003 FR-001~002)" 한 줄 추가. 그 외 F2 문서는 바꾸지 않는다.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: 없음.
- **Phase 2 (Foundational)**: Phase 1 뒤. 모든 Story를 막는다.
- **US1 (Phase 3)**: Phase 2 뒤. `general_detail_view_model.dart`·`general_detail_page.dart`를 만든다 → US2·US3·US4가 같은 파일을 고치므로 US1이 먼저.
- **US2 (Phase 4)**: US1 뒤(같은 파일). T021이 ViewModel 상태 타입을 바꾼다.
- **US3 (Phase 5)**: Phase 2 뒤 `content_view_model.dart`·`content_page.dart`(T025·T027·T028)는 US1과 병렬 가능. 단 T028 끝의 라우터 교체는 T030(US1) 뒤. T029는 US1·US2 뒤(같은 페이지 파일).
- **작업 번호**: T030은 analyze O1로 US1(T017 다음)으로 옮겨 번호 순서와 실행 순서가 다르다. 실행은 이 파일에 적힌 줄 순서를 따른다.
- **US4 (Phase 6)**: US2 뒤(T023의 공통 위젯 재사용).
- **US5 (Phase 7)**: Phase 2 뒤 언제든(테스트만).
- **US6 (Phase 8)**: Phase 2 뒤. T037은 US1~US4 화면이 있어야 에뮬레이터 확인 가능.
- **Polish (Phase 9)**: 모든 Story 뒤. T040은 승인 필요.

### 같은 파일을 고치는 작업 (병렬 금지)

| 파일 | 작업 |
|---|---|
| `general_detail_view_model.dart` | T014 → T021 |
| `general_detail_page.dart` | T016 → T021(`_openContent`만) → T022 → T023 → T024 → T029 → T033 |
| `general_detail_view_model_test.dart` | T012 → T019 → T031 |
| `general_detail_flow_test.dart` | T013 → T020 → T026 → T032 → T039 |
| `mock_inquiry_store.dart` | T009 → T010 |
| `mock_scenarios_test.dart` | T004 → T034 → T036 |
| `lib/app/router.dart` | T017 → T030(US1, 임시 builder) → T028(ContentPage로 교체) → T040 |

### Parallel Opportunities

- Phase 1: T001 ∥ T002
- Phase 2 테스트: T003 ∥ T004
- US1: T012 ∥ T013 ∥ T015
- US1 진행 중 US3의 T025·T027·T028 병렬 가능(다른 파일)
- US5 전체(T034·T035)는 Phase 2 뒤 아무 때나
- Polish: T038 ∥ T039 ∥ T041 ∥ T044

## Parallel Example: User Story 1

```text
T012 general_detail_view_model_test.dart (정리 완료 그룹)
T013 general_detail_flow_test.dart (F3-2 위젯)
T015 refinement_view.dart
→ 그다음 T014 → T016 → T017 → T030 → T018
```

## Implementation Strategy

### MVP First (Phase 1 → 2 → US1)

정리 완료 문의의 번역본이 보이면 F3의 핵심 가치가 확인된다. 이때 정리 실패·정리 중 문의는 머리 줄과 원문 보기만 보이는 임시 상태다(T016).

### 시연 가능한 최소 묶음 (P1 전부: US1 → US2 → US3)

번역본·정리 실패·원문 열람이 모두 동작한다. 정리 중(US4)은 드문 경우라 그다음.

### Incremental Delivery

1. Phase 1~2 → 기존 테스트 통과 확인
2. US1 → quickstart 1~3
3. US2 → quickstart 6~11
4. US3 → quickstart 12~14
5. US4 → quickstart 4~5
6. US5·US6 → quickstart 16~17, 데모표 일치
7. Polish → 승인 후 준비 중 삭제, analyze·test, 에뮬레이터 1~20

## Notes

- 총 44개 작업. [P] 표시는 같은 Phase 안에서 다른 파일·미완료 의존 없음일 때만.
- 커밋은 사용자 요청 때만, 메시지는 `Feat : <요약>`(CLAUDE.md).
- 실서버 확인(quickstart 21~24)은 F3 백엔드 배포 후 별도로 한다.

## 구현 메모 (2026-10-27, 계획과 달라진 점)

- **문구 상수 이름**: data-model의 `emotionLabel`(정서 카드 제목)은 `NoticeText.emotionTitle`로 바꿨다 — 라벨 이름 함수 `NoticeText.emotionLabel(EmotionLabel)`과 이름이 겹친다. `retryRemainingNone`은 제목 `retryRemainingTitle`("남은 재요청 0회")과 본문 `retryRemainingNone`으로 나눴다.
- **작업 묶음**: `general_detail_view_model.dart`는 T014와 T021(다시 정리하기·다시 확인)을, `general_detail_page.dart`는 T016·T022·T023·T024·T033을 한 번에 작성했다. T030은 `ContentPage`를 같은 묶음에서 만들어 임시 builder 없이 바로 연결했다. 원문 이동은 `_contentButton()` 한 곳에서 `push` 후 `recheck()`.
- **번역본 첫 열람 뒤 상세 다시 읽기**: 머리 줄 단계(FR-004)가 "교사 확인"으로 맞게 보이도록, 정제 단계에서 번역본을 받으면 상세를 한 번 더 읽는다(`_refined`). 그 뒤 목록을 새로 고친다.
- **F3-3 실패 안내 모양**: Figma의 따뜻한 경고 상자 대신 공통 `SystemNotice`(회색, 경고 아이콘)를 썼다 — 원칙 V 시스템 안내 스타일을 한 가지로 유지.
- **테스트**: `fake_async`는 프로젝트 의존성이 아니라서(새 패키지 금지) "자동 조회 없음"은 실제 2초 대기로 확인한다. 위젯 테스트 환경에서는 끌기 제스처가 `RefreshIndicator`를 작동시키지 않아, 당겨서 새로 고침은 `RefreshIndicatorState.show()`로 `onRefresh → recheck` 연결을 확인한다.
- **기존 테스트 수정**: `urgent_detail_test.dart`(원문 확인 필요 → "준비 중" 대신 F3-3 실패 안내), `teacher_inquiries_view_model_test.dart`(가짜 Repository에 새 메서드 2개), `router_redirect_test.dart`(`/pending` → `/general`·`/content`).
- **T040**: 2026-10-27 사용자 승인 후 준비 중 화면 2개·`/pending` 경로·`pendingDetail` 문구를 삭제했다.
- **결과**: `flutter analyze` 문제 0건, `flutter test` 235개 통과. **T037·T043(에뮬레이터 확인)은 하지 않았다** — quickstart 1~20은 위젯·ViewModel·mock 테스트로 자동 확인했고, 화면 모양(배치·색)은 에뮬레이터에서 사람이 확인해야 한다.
