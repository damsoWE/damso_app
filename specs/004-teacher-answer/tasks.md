---
description: "Task list for 교사 답변 작성·점검·전송 화면 (F4 교사)"
---

# Tasks: 교사 답변 작성·점검·전송 화면 (F4 교사)

**Input**: Design documents from `specs/004-teacher-answer/`

**Prerequisites**: [plan.md](./plan.md) · [spec.md](./spec.md) · [research.md](./research.md) · [data-model.md](./data-model.md) · [contracts/](./contracts/) · [quickstart.md](./quickstart.md)

**Tests**: 포함한다. constitution "검증"(`flutter analyze`·`flutter test` 통과)과 F2·F3 방식(ViewModel 단위·위젯 흐름·라우터)을 따른다. 각 Story에서 테스트를 먼저 쓰고 실패를 확인한 뒤 구현한다.

**Organization**: spec의 User Story(US1~US5)별 Phase. Setup·Foundational은 모든 Story의 선행 조건.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: 다른 파일이고 앞선 미완료 작업에 기대지 않아 동시에 할 수 있음
- **[Story]**: User Story Phase 작업만 붙인다(US1~US5)

## 공통 규칙 (모든 작업에 적용)

- **수정 허락 범위**: 사용자가 허락한 범위는 `lib/features/reply/`다. 그 밖의 파일(`lib/app/router.dart`, `lib/core/error/error_codes.dart`, `lib/features/inquiry/**`, `test/**`)은 **구현 시작 전에 plan.md "reply 밖 수정" 목록으로 한 번 승인**받는다. 승인 전에는 그 파일을 건드리는 작업을 하지 않는다.
- 위젯 → ViewModel(Riverpod `Notifier`/`AsyncNotifier`) → Repository 인터페이스. 위젯은 Repository를 직접 부르지 않는다. `reply/domain`은 Flutter·dio를 import하지 않는다.
- 구현 선택은 `lib/features/reply/data/answer_repository_provider.dart` 한 곳(`Env.useMock`).
- data 계층은 모든 dio 호출을 `mapDioErrors`로 감싼다. 화면 오류는 `userMessageOf(e)` / `AppException.message`만.
- 답변 본문·점검 결과(`excerpt`·`reason`·`suggestion`)를 `print`·`debugPrint`·로그·분석 이벤트로 내보내지 않는다(원칙 VI). 일반 `Text`로만 그린다.
- 화면 문구는 `lib/features/reply/domain/answer_text.dart` 상수만 쓴다(data-model §5). 색·글자·간격은 `AppColors`·`AppTextStyles`·`AppSpacing`·`AppRadius`.
- 점검 결과를 자동 반영하거나 자동 전송하는 코드를 두지 않는다(원칙 V, spec FR-006·FR-010).
- 점검·전송 경로의 `inquiryId`는 언제나 **스레드 루트 ID**(research R4).
- URL에는 UUID만. 학생 이름·제목·요청사항은 `extra`(`AnswerTarget`)로만.
- 파일 맨 위 주석에 화면 ID와 Figma 노드(예: `/// F4-2a 답변 작성 (Figma 216-5381)`).

---

## Phase 1: Setup

**Purpose**: 상수·고정 문구

- [X] T001 [P] `lib/core/error/error_codes.dart`에 `static const threadClosed = 'THREAD_CLOSED';` 추가(contracts/api-usage.md). `INQUIRY_NOT_READY_TO_CLOSE`는 추가하지 않는다(종료 API 미사용).
- [X] T002 [P] `lib/features/reply/domain/answer_text.dart` 생성 — `abstract final class AnswerText`에 data-model §5 표의 모든 키를 문구 그대로 상수로. 값이 들어가는 문구는 함수로: `recipient(String studentName)` → `'$studentName 학부모에게'`, `suggestionCount(int n)` → `'확인할 제안 $n개'`, `appliedCount(int n)` → `'제안 $n개 적용함'`, `suggestionTitle(int n, {required bool applied})` → `applied ? '제안 $n · 바꿈' : '제안 $n'`, `recipientLine(String studentName, String title)` → `'$studentName 학부모 · $title'`, `parentCardTitle(String studentName, {required bool followUp})` → `'$studentName 학부모 · ${followUp ? '재문의' : '요청사항'}'`, `answerCardTitle(String? displayName)` → `displayName == null || displayName.isEmpty ? '선생님 · 직접 전송' : '$displayName 선생님 · 직접 전송'`, `followUpTitle(String rootTitle)` → `'$rootTitle - 재문의'`, `followUpHeader(String studentName, DateTime at)` → `'$studentName 학부모 · {M/d HH:mm} 접수'`. 시각 문구(`· 전송 완료`, `· 재문의 받음 · 눌러서 확인`)는 시각 형식을 받는 함수로 두고 형식은 `lib/features/inquiry/presentation/format.dart`의 기존 함수와 같은 `M/d HH:mm`을 쓴다.

---

## Phase 2: Foundational (모델·Repository·mock — 모든 Story의 선행 조건)

**Purpose**: `inquiry` 상세에 재문의·답변을 담고, `reply`의 점검·전송 Repository(실서버·mock)를 만든다.

**⚠️ CRITICAL**: 이 Phase가 끝나야 Story 작업을 시작한다.

### Tests for Foundational

- [X] T003 [P] `test/features/inquiry/inquiry_repository_impl_test.dart`에 그룹 "F4 상세" 추가(기존 가짜 `HttpClientAdapter`): (a) `detail`이 `followUps`(`inquiryId·urgent·title·stage·submittedAt`)와 `answers`(`answerId·content·reviewed·sentAt`)를 시간순 그대로 해석, (b) 둘 다 `[]`이면 빈 목록, (c) 재문의 `stage`가 모르는 값이면 `AppException`(fallbackMessage, F2 규칙), (d) `threatFlagged`가 있어도 무시하고 해석 성공.
- [X] T004 [P] `test/features/reply/answer_repository_impl_test.dart` 작성(F2 `inquiry_repository_impl_test.dart`의 가짜 어댑터 방식): (a) `review('r1', '본문')` → `POST /api/v1/teacher/inquiries/r1/answer-reviews`, body `{"content":"본문"}`, 200 `{available:true, highlights:[{excerpt,reason,suggestion}×2]}` 해석, (b) `{available:false, highlights:[]}` → `available false`, (c) `send('r1','본문', reviewed: true)` → `POST …/r1/answers`, body `{"content":"본문","reviewed":true}`, 201 `{answerId,inquiryId,sentAt}` 해석, (d) 409 `{code:"THREAD_CLOSED", message:"이미 종료된 문의입니다."}` → `AppException.code == ErrorCodes.threadClosed`·message 그대로, (e) 400 `INVALID_INPUT` + `fieldErrors[{field:"content"}]` → `fieldErrors['content']`, (f) 응답 형식이 틀리면(필드 누락) fallbackMessage.
- [X] T005 [P] `test/features/mock_scenarios_test.dart`에 그룹 "F4 mock 저장소" 추가(`MockInquiryStore` 직접): (a) 답변 데모 문의 상세 `answers` 1건, (b) 재문의 데모 문의 `followUps` 1건이 마지막 답변보다 늦음, (c) `sendAnswerForTeacher` 후 상세 `answers`가 1건 늘고 학부모 상세 단계는 바뀌지 않음(종료 아님), (d) ~~종료 데모 문의 전송 → 409~~(2026-10-28 제거, api-v0.8), (e) 점검: 본문에 `큰 문제는 아니` → 제안 2개(Figma 예시 excerpt·reason·suggestion), `점검실패` → `available false`, 그 밖 → 제안 0개, (f) 전송 본문에 `전송실패` → 네트워크 오류(`AppException(isNetworkError: true)`), 답변 늘지 않음.

### Implementation for Foundational

- [X] T006 `lib/features/inquiry/domain/models.dart` 수정(data-model §1): `class TeacherFollowUp { inquiryId, urgent, title, InquiryStage stage, DateTime submittedAt }`(주석: 본문 없음), `class SentAnswer { answerId, content, reviewed, DateTime sentAt }`(주석: `reviewed`는 "점검 요청 여부"일 뿐 안전 확인이 아님). `TeacherInquiryDetail`에 `required this.followUps`·`required this.answers`(둘 다 `List`, 시간순) 추가, 파생 `bool get hasAnswers => answers.isNotEmpty;`·`bool get isClosed => summary.stage == InquiryStage.answered;`. 이 생성자를 쓰는 기존 코드(mock 저장소 등)는 `const []`로 맞춘다.
- [X] T007 `lib/features/inquiry/data/inquiry_json.dart` 수정: `teacherDetail`에 `followUps: (j['followUps'] as List).cast<Map<String,dynamic>>().map(teacherFollowUp).toList()`, `answers: … map(sentAnswer)`. `static TeacherFollowUp teacherFollowUp(Map)`·`static SentAnswer sentAnswer(Map)` 추가. 파일 주석의 "followUps·answers 는 읽지 않는다"는 학부모 상세에만 해당하도록 고친다. `threatFlagged`는 읽지 않는다.
- [X] T008 [P] `lib/features/reply/domain/models.dart` 생성(data-model §2): `Highlight { excerpt, reason, suggestion }`, `AnswerReview { bool available; List<Highlight> highlights }`(주석: `available false`면 highlights 무시), `AnswerSent { answerId, inquiryId, DateTime sentAt }`, `AnswerTarget { inquiryId(스레드 루트), studentName, title, String? requests, bool fromThread = false }`(주석: URL에 넣지 않고 `extra`로만, `fromThread`면 전송 뒤 스레드까지 pop — research R14), `FollowUpArgs { rootId, studentName, rootTitle, TeacherFollowUp followUp }`(research R13, `inquiry/domain/models.dart`의 `TeacherFollowUp` import — 기존 기능 간 참조 패턴).
- [X] T009 [P] `lib/features/reply/domain/answer_repository.dart` 생성 — `abstract class AnswerRepository { Future<AnswerReview> review(String inquiryId, String content); Future<AnswerSent> send(String inquiryId, String content, {required bool reviewed}); }`. 주석: `inquiryId`는 스레드 루트, 409 `THREAD_CLOSED`, 멱등키 없음(자동 재전송 금지).
- [X] T010 `lib/features/reply/data/answer_repository_impl.dart` 생성 — `AnswerRepositoryImpl(Dio)`, contracts/api-usage.md 표대로 두 경로. 모두 `mapDioErrors`. 해석은 파일 안 private 함수(필드 이름 그대로).
- [X] T011 `lib/features/inquiry/data/mock_inquiry_store.dart` 수정(research R11): `_MockInquiry`에 `List<SentAnswer> answers`, `List<_MockFollowUp> followUps`(`inquiryId, urgent, title, stage, submittedAt, InquiryRefinement? refinement`), 추가(`bool closed`는 2026-10-28 api-v0.8에 따라 제거). `detailForTeacher`가 둘을 넣는다. 메서드 추가: `AnswerReview reviewAnswerForTeacher(String inquiryId, String content)`(T005 (e) 규칙, 제안 2개는 Figma 문구 그대로: excerpt `어제 일은 확인해 보니 큰 문제는 아니었습니다.`·reason `걱정을 가볍게 여기는 말로 읽힐 수 있어요.`·suggestion `걱정 많으셨겠어요. 어제 상황을 아이들과 확인하고 있습니다.` / excerpt `확인되는 대로 연락드리겠습니다.`·reason `“이번 주 안 회신” 요청에 대한 설명이 빠져 있어요.`·suggestion `확인한 내용을 이번 주 금요일까지 안내드리겠습니다.`), `AnswerSent sendAnswerForTeacher(String inquiryId, String content, {required bool reviewed})`(`전송실패` 포함 → 네트워크 오류, 공백만·2,000자 초과 → 400 `invalidInput`, 그 밖 → `answers`에 추가), 재문의 번역본·원문 조회가 되도록 `refinementForTeacher`·`contentForTeacher`가 재문의 ID도 찾게 한다(재문의 원문 열람도 열람 기록 규칙은 F3과 같게). 담당 학급 밖·403 데모 ID는 기존 규칙(403)을 그대로 따른다.
- [X] T012 `mock_inquiry_store.dart` `_seed()`에 데모 추가(research R11, 학생은 3학년 2반, parentAccount `parent`): `a1000000-0000-4000-8000-00000000000b`(김하나, 정리 완료, 답변 1건 — Figma F4-3 본문 `걱정 많으셨겠어요. 어제 상황을 확인하고 이번 주 금요일까지 안내드리겠습니다.`, 2시간 전), `…000c`(박서준, 정리 완료, 답변 1건 + 그 뒤 재문의 1건(ID `a1000000-0000-4000-8000-00000000c001`) — 재문의 번역본: 사실관계 `보호자가 금요일 안내 전에 지금까지 확인된 상황을 알고 싶어 해요.`, 요청사항 `금요일 안내 전에 중간 상황도 알려 주실 수 있는지 문의`, 정서 보통·걱정, 재문의 원문 `금요일에 안내 주신다고 하셨는데, 그 전에 지금까지 확인된 내용만이라도 먼저 알려 주실 수 있을까요?`(Figma 323-1843·323-1863 문구), 30분 전). (`…000d` 종료 데모는 2026-10-28 api-v0.8에 따라 제거.) 기존 데모 ID·동작은 바꾸지 않는다.
- [X] T013 [P] `lib/features/reply/data/mock_answer_repository.dart` 생성 — `MockAnswerRepository(TokenStore, MockInquiryStore)`, 기존 `MockTeacherInquiryRepository`처럼 `_delay` 300ms 후 `noclass` 토큰이면 403, 그다음 저장소 호출.
- [X] T014 `lib/features/reply/data/answer_repository_provider.dart` 생성 — `final answerRepositoryProvider = Provider<AnswerRepository>((ref) => Env.useMock ? MockAnswerRepository(ref.watch(tokenStoreProvider), ref.watch(mockInquiryStoreProvider)) : AnswerRepositoryImpl(ref.watch(dioProvider)));` 주석 "구현체를 고르는 유일한 지점".
- [X] T015 `test/helpers/test_app.dart`의 `mockRepositoryOverrides`에 `answerRepositoryProvider.overrideWith((ref) => MockAnswerRepository(ref.watch(tokenStoreProvider), ref.watch(mockInquiryStoreProvider)))` 추가(교사 문의 mock과 같은 저장소 공유).

**Checkpoint**: T003~T005 통과, `flutter analyze` 깨끗.

---

## Phase 3: User Story 1 - 답변을 작성하고 점검을 거쳐 직접 전송한다 (Priority: P1) 🎯 MVP

**Goal**: F3 상세의 "답변 작성" → F4-2a/2a-2 → 답변 점검(F4-2b) → 결과 화면의 "직접 전송" → F4-2g → 스레드. 실패 F4-2h.

**Independent Test**: mock에서 정리 완료 문의 → 답변 작성 → 입력 → 답변 점검 → (제안 없음 본문) 직접 전송 → 스레드에 답변 카드. 입력 직후 전송 버튼 없음, 전송 실패 안내(quickstart 1~4·10·13~15·20·21·24).

### Tests for User Story 1

- [X] T016 [P] [US1] `test/features/reply/answer_compose_view_model_test.dart` 작성(그룹 "작성·전송"): `ProviderContainer` + `MockAnswerRepository`를 상속한 호출 기록 클래스. (a) 처음 `Editing`, 빈 본문·공백만이면 `canReview false`, (b) `review()` → `Reviewing` 동안 `review` 1회, 본문 잠김 → 결과 상태로, (c) `Editing`에서 `send()`는 아무것도 하지 않음(입력 직후 전송 불가, Clarifications Q1), (d) 결과 상태에서 `send()`를 await 없이 두 번 → `send` 1회, 성공하면 `sent`(화면이 스레드로 replace할 값) 설정, (e) 전송 `reviewed`는 점검 요청 뒤 true, (f) 네트워크 오류 → `SendFailed(canResend: true)`, 본문 그대로, `maybeSent` 안내 표시, (g) 409 `threadClosed` → `SendFailed(canResend: false)`, 서버 message, (h) 400 → 입력 오류 메시지, 상태 `EditedAfterReview`(수정 가능), (i) `resend()` → 같은 본문으로 다시 1회, (j) 화면 provider를 전송 중 dispose해도 응답 처리 완료(`keepAlive`), (k) family 키가 같은 `inquiryId`면 화면을 다시 그려도 같은 ViewModel·본문 유지(analyze U1), (l) `init(target)`를 두 번 불러도 본문이 지워지지 않음, (m) 세션이 `SignedOut(sessionExpired: true)`가 되고 본문이 있으면 `sessionExpiredNotice` 값이 설정됨(R15).
- [X] T017 [P] [US1] `test/features/reply/answer_flow_test.dart` 작성(위젯, `test_app.dart`): 교사 로그인 → 목록에서 답변 없는 정리 완료 문의(`…0008`) → F3-2 하단 "답변 작성" → `AnswerText.recipient('이도윤')`·제목·`requestsLabel`·`placeholder`·`notSentHint` 보임, "답변 점검" 비활성, "직접 전송" 없음 → 본문 입력 → "답변 점검" → `reviewingNotice`·`reviewingButton` → 결과 화면 → "직접 전송" → `sendingHeading` → 스레드 화면에 보낸 본문·`sentNotice`·`toListButton` 보임, 화면 모든 `Text`에 `@` 없음. 별도 케이스: 본문을 입력한 뒤 뒤로 가기 → `AnswerText.discardConfirm` 대화상자 → 취소하면 본문 유지, 나가기하면 이전 화면(analyze G2).

### Implementation for User Story 1

- [X] T018 [US1] `lib/features/reply/presentation/answer_compose_view_model.dart` 생성 — data-model §3 상태 기계. `sealed class ComposeStep`(`Editing`, `Reviewing`, `Reviewed(AnswerReview review, Map<int, ({String original, String replaced})> applied)`, `ReviewFailed`, `EditedAfterReview`, `Sending`, `SendFailed({String message, bool canResend, bool maybeSent})`), `ComposeState { ComposeStep step; String text; bool reviewRequested; String? inputError; String? message; AnswerSent? sent }`. `AnswerComposeViewModel extends Notifier<ComposeState>`(family **`String inquiryId`**(스레드 루트), autoDispose, `answerComposeViewModelProvider` — 객체 키 금지, research R14·analyze U1). 머리 정보는 `init(AnswerTarget target)`으로 한 번만 받는다(이미 받았으면 무시). 세션 만료 감시: `ref.listen(sessionControllerProvider, …)`에서 `SignedOut(sessionExpired: true)`이고 본문이 있으면 `sessionExpiredNotice = AnswerText.sessionExpiredDraftLost`(R15). 메서드: `updateText`, `review()`, `send()`, `resend()`, `startEdit()`(→`EditedAfterReview`). `review()`/`send()`는 진행 중이면 무시, `ref.keepAlive()`로 응답 처리 완료, 오류 분기는 research R8 표. 이 Phase에서 `Reviewed`는 제안 표시 없이 `send()`만 가능하게 두고, 바꾸기·되돌리기는 US2(T025)에서 더한다. `review()`의 `available false`·오류 처리는 US3(T030)에서 채우되, 이 Phase에서도 `ReviewFailed`로 보내 전송은 가능하게 한다.
- [X] T019 [US1] `lib/features/reply/presentation/answer_compose_page.dart` 생성 — `ConsumerWidget`, `step`별 본문. 이 Phase: F4-2a/2a-2(Figma 216-5381·216-5548: 받는 사람 카드 `recipient`+제목, `requests`가 있을 때만 요청사항 상자(`bgSubtle`), 입력칸(본문 비면 `answerLabel`/있으면 `writtenLabel`), `notSentHint`, 하단 `FilledButton(reviewButton)` 비활성 규칙), F4-2b(216-5397: 받는 사람 카드, 읽기 전용 본문, `reviewingGuide`, `SystemNotice(reviewingNotice)`, 비활성 `reviewingButton`), F4-2g(216-5505: `sendingHeading`·`sendingGuide`·받는 사람 `recipientLine`·본문·`sendOnceNotice`·비활성 `sendingButton`), F4-2h(216-5520: `sendFailedHeading`·`sendFailedGuide`·`unsentLabel`+본문·`sendFailedHint`(maybeSent면 `maybeSentHint`도)·`editButton`·`canResend`면 `resendButton`), 결과 상태는 임시로 본문 + "직접 전송"만(US2·US3에서 채움). 앱바 제목은 step별(`composeTitle`/`reviewingTitle`/`resultTitle`/`editTitle`/`sendingTitle`). 화면은 `answerComposeViewModelProvider(target.inquiryId)`를 쓰고 첫 프레임에 `init(target)`. `ref.listen`으로 `sent`가 생기면 `target.fromThread`면 스레드 경로(`/teacher/inquiries/${target.inquiryId}/thread`)가 나올 때까지 `pop`하고 스레드가 다시 읽게 하고, 아니면 `context.replace('…/thread')`(research R14, analyze I1). `message`·`sessionExpiredNotice`는 루트 `ScaffoldMessenger` 스낵바(R15). 본문이 있으면 `PopScope`로 뒤로 가기 확인(`AnswerText.discardConfirm`, research R9, analyze I7). `TextField`는 `maxLength` 표시 없이 서버 판단을 따른다(spec FR-001).
- [X] T020 [US1] `lib/features/reply/presentation/thread_page.dart`·`thread_view_model.dart` 생성(최소판) — `ThreadViewModel extends AsyncNotifier<ThreadState>`(family 루트 ID, autoDispose)는 이 Phase에서 `detail`만 읽어 루트 문의 카드(요청사항 없이) + 답변 카드(`answerCardTitle(null)`, 본문, `sentAt`)를 시간순으로 만든다. 화면(Figma 216-5533): 앱바 문의 제목, 태그 `answeredTag`(답변이 있으면), 카드들, `SystemNotice(sentNotice)`, 하단 `FilledButton(toListButton)` → `context.go('/teacher/inquiries')`. "답변 완료로 닫기"는 두지 않는다(spec FR-017). 요청사항·재문의·표시 이름은 US4(T035·T036)에서 더한다.
- [X] T021 [US1] `lib/app/router.dart`에 루트 Navigator 경로 두 개 추가(contracts/routes.md): `/teacher/inquiries/:inquiryId/answer`(`redirect: (_, s) => s.extra is AnswerTarget ? null : '/teacher/inquiries/${s.pathParameters['inquiryId']}'`, builder `AnswerComposePage(target: s.extra! as AnswerTarget)`), `/teacher/inquiries/:inquiryId/thread`(`ThreadPage(inquiryId: …)`). `/teacher/inquiries/:inquiryId` 경로는 US4(T039)에서 생기므로, 그 전까지 `/answer`의 redirect 대상은 `/teacher/inquiries`로 둔다.
- [X] T022 [US1] F3 화면 4곳 하단에 "답변 작성"(`AnswerText.writeAnswerButton`, `FilledButton`) 추가(research R10) — `general_detail_page.dart`의 `Refined`(요청사항 = `refinement.requests`, 빈 문자열이면 null)·`NeedsOriginal`(요청사항 null), `content_page.dart`(요청사항 null, `summary`가 없으면 버튼 숨김), `urgent_detail_page.dart`(요청사항 null). `content_page.dart`는 재문의에서도 열리므로(research R13) 같은 파일에 `class ContentArgs { TeacherInquirySummary? summary; String? title; String? header; AnswerTarget? answerTarget }`를 두고, 라우터 `/content`의 `extra`가 `TeacherInquirySummary`(기존)면 지금처럼, `ContentArgs`면 `title`·`header`로 머리 줄을 그리고 "답변 작성"은 `answerTarget`으로 간다(`answerTarget == null`이면 버튼 숨김). `AnswerTarget` import는 `reply/domain/models.dart`(기능 간 참조). 정리 중·다시 정리 중에는 두지 않는다. `detail.isClosed`면 두지 않는다. 누르면 `context.push('/teacher/inquiries/$id/answer', extra: AnswerTarget(...))`. 각 파일 맨 위 주석의 "답변 작성은 F4 가 더한다"를 "F4(specs/004)가 더함"으로 고친다.

**Checkpoint**: T016·T017 통과. mock에서 quickstart 1~4·10·13~15·20·21·24 확인.

---

## Phase 4: User Story 2 - 점검 결과를 보고 제안을 직접 반영한다 (Priority: P1)

**Goal**: F4-2c 제안 카드("제안 N"), 바꾸기 → F4-2c-1, 되돌리기, 제안 없음 F4-2e, 수정 F4-2d. 자동 반영·자동 전송 없음.

**Independent Test**: 본문 `어제 일은 확인해 보니 큰 문제는 아니었습니다. 확인되는 대로 연락드리겠습니다.`로 점검 → "확인할 제안 2개", 제안 1 바꾸기·되돌리기, 수정하면 결과 사라짐, 다른 본문은 "점검 완료"(quickstart 5~9·11).

### Tests for User Story 2

- [X] T023 [P] [US2] `answer_compose_view_model_test.dart`에 그룹 "제안" 추가: (a) 제안 2개 결과 → `Reviewed`, `applied` 비어 있음, (b) `apply(0)` → 본문에서 excerpt가 처음 나오는 곳 하나만 suggestion으로, `applied[0]` 기록, 다른 문장 그대로, (c) `undo(0)` → 원래 본문, (d) excerpt가 본문에 없으면 `canApply(i) false`·`apply` 무시, (e) 결과 상태에서 `updateText` → `EditedAfterReview`, `applied`·결과 비움, (f) `EditedAfterReview`에서 `review()` → 다시 `Reviewing`, `send()`는 가능, (g) 제안 0개 → `Reviewed`(빈 highlights) = 제안 없음, (h) 어떤 결과든 타이머로 1분 흘려도 본문·상태 그대로(`fakeAsync`).
- [X] T024 [P] [US2] `answer_flow_test.dart`에 추가: 위 본문 점검 → `suggestionCount(2)`·`suggestionTitle(1)`·`suggestionTitle(2)`·두 reason·`rewrittenLabel`·`resultHint`·`editButton`·`sendButton` 보임, "오해할 수 있는 표현" 없음 → 제안 1 `applyButton` → `suggestionTitle(1, applied: true)`·`appliedLabel`·`undoButton`·`appliedCount(1)`·`appliedHint`, 본문 바뀜 → `undoButton` → 원래대로 → `editButton` → 본문 고침 → `editedLabel`·`editedNotice`·`recheckButton`·`sendEditedButton`, 제안 카드 없음. 다른 본문 → `noSuggestionBadge`·`noSuggestion`.

### Implementation for User Story 2

- [X] T025 [US2] `answer_compose_view_model.dart`에 `apply(int index)`·`undo(int index)`·`canApply(int index)` 추가(research R7): `apply`는 현재 본문에서 `excerpt`의 첫 위치를 `suggestion`으로 바꾸고 `(original: excerpt, replaced: suggestion)`을 기록, `undo`는 현재 본문에서 `replaced`의 첫 위치를 `original`로 되돌린다. 둘 다 결과는 유효한 채 유지(교사가 누른 제안 반영은 "수정"이 아니다). `updateText`(직접 수정)는 `EditedAfterReview`로 보내고 `applied`·결과를 비운다(spec FR-007).
- [X] T026 [US2] `lib/features/reply/presentation/suggestion_card.dart` 생성 — `SuggestionCard({index, highlight, applied, canApply, onApply, onUndo})`, Figma 216-5411·216-5439: 제목 `suggestionTitle(index+1, applied:)`(`subtitle`), reason(`small`·`textSecondary`), 내부 상자(`statusSuccessSoft`) 라벨 `rewrittenLabel`/`appliedLabel` + `OutlinedButton(applyButton/undoButton)` + `“${suggestion}”`. 첫 카드는 `statusInfoSoft` 배경, 나머지는 `bgSurface`+테두리(Figma 그대로). 분류 제목을 만들지 않는다(Clarifications Q2).
- [X] T027 [US2] `answer_compose_page.dart`에 결과 화면 채우기: `Reviewed`+제안 있음(F4-2c/2c-1: 배지 `suggestionCount`/`appliedCount`(`statusWarningSoft`), `writtenLabel`+읽기 전용 본문, `SuggestionCard` 목록, 하단 안내 `resultHint`/`appliedHint`, `OutlinedButton(editButton)`·`FilledButton(sendButton)`), `Reviewed`+제안 없음(F4-2e 216-5481: `writtenLabel`+본문, 배지 `noSuggestionBadge`, `SystemNotice(noSuggestion)`, `editButton`·`sendButton`), `EditedAfterReview`(F4-2d 216-5467: 요청사항 상자, `editedLabel`+편집 가능한 입력칸, `SystemNotice(editedNotice)`, `OutlinedButton(recheckButton)`·`FilledButton(sendEditedButton)`).

**Checkpoint**: T023·T024 통과. quickstart 5~9·11.

---

## Phase 5: User Story 3 - 점검이 실패해도 작성 내용을 잃지 않고 전송한다 (Priority: P1)

**Goal**: `available=false`·점검 요청 오류 → F4-2f, 본문 보존, 다시 점검·직접 확인 후 전송.

**Independent Test**: 본문에 `점검실패` → F4-2f, 본문 그대로, 두 버튼 모두 동작(quickstart 12).

### Tests for User Story 3

- [X] T028 [P] [US3] `answer_compose_view_model_test.dart`에 그룹 "점검 실패": (a) `available false`(highlights가 있어도) → `ReviewFailed`, 제안 없음, (b) 점검 요청 네트워크 오류 → `ReviewFailed`(오류 상태 아님), (c) 403 → 서버 message 안내 + `ReviewFailed`, (d) `ReviewFailed`에서 `review()` → `Reviewing`, `send()` → 전송 1회·`reviewed true`, (e) 본문은 모든 경우 한 글자도 바뀌지 않음.
- [X] T029 [P] [US3] `answer_flow_test.dart`에 추가: `점검실패` 본문 → `reviewFailed`·`reviewFailedGuide`·`recheckButton`·`sendAfterCheckButton` 보임, 제안 카드 없음 → `sendAfterCheckButton` → 스레드.

### Implementation for User Story 3

- [X] T030 [US3] `answer_compose_view_model.dart`의 `review()` 결과 분기 완성(contracts/api-usage.md): `available false` → `ReviewFailed`(highlights 무시, 원칙 IV·spec FR-008), `AppException`(네트워크·403·404·5xx) → `ReviewFailed` + `message`(서버 message, 네트워크면 고정 안내), 400 → `inputError`. 그리고 `answer_compose_page.dart`에 F4-2f(216-5493: 앱바 `reviewingTitle`, `writtenLabel`+본문, `SystemNotice(reviewFailed, icon: warning)`, `reviewFailedGuide`, `OutlinedButton(recheckButton)`·`FilledButton(sendAfterCheckButton)`).

**Checkpoint**: T028·T029 통과. quickstart 12.

---

## Phase 6: User Story 4 - 스레드를 보고 재문의에 이어서 답한다 (Priority: P2)

**Goal**: 답변한 문의는 목록에서 바로 F4-3, 최초 문의 카드에 요청사항·"원문 보기", 답변 카드에 표시 이름, 답변 카드 아래 재문의 카드 → 재문의 상세(F3-2 구성, "… - 재문의") → 원문 보기(F3-6) / 답변 작성(F4-2a~).

**Independent Test**: `…000b`를 목록에서 누름 → 스레드. `…000c` 스레드 → 재문의 카드 → 재문의 상세 → 원문 보기·답변 작성 → 추가 답변 전송 → 스레드 끝에 새 답변(quickstart 16~19b).

### Tests for User Story 4

- [X] T031 [P] [US4] `test/features/reply/thread_view_model_test.dart` 작성: (a) 카드 순서 = 루트 → 답변·재문의 시간순, (b) 루트 `REFINED`면 `refinement` 1회, 요청사항 채움, 빈 문자열이면 null, (c) 루트가 긴급·`NEEDS_ORIGINAL`이면 `refinement` 호출 0회, 요청사항 null, (d) 재문의 번역본 409 `refinementNotReady` → 그 카드 요청사항 null, 화면은 열림, (e) 긴급 재문의는 번역본 호출 0회, (f) `TeacherRepository.getProfile` 실패 → `teacherName null`, 화면은 열림, (g) `unanswered`는 마지막 답변보다 늦은 재문의만 true, (h) `content`(원문) 호출 0회, (i) 상세·번역본·프로필 요청이 동시에 시작됨(호출 순서 기록으로 확인).
- [X] T032 [P] [US4] **생략** — api-v0.7부터 목록 항목에 `hasAnswer`가 있어 문의 열기 화면이 필요 없다(T038 조건, research R3). 원래 내용: `test/features/inquiry/open_inquiry_test.dart` 작성: 문의 열기 화면이 (a) 답변 있는 일반 문의 → `/thread`, (b) 답변 없는 일반 → `/general`, (c) 답변 없는 긴급 → `/urgent`(이 과정에서 `content` 호출 0회), (d) 상세 403 → 권한 없음 안내 + 다시 시도, 이동 없음.
- [X] T033 [P] [US4] `answer_flow_test.dart`에 추가: 목록에서 `…000b` → 스레드(F3 상세 아님), 최초 문의 카드 `parentCardTitle('김하나', followUp: false)`+요청사항+`viewOriginalButton`, 답변 카드 `answerCardTitle('이담임')`, 하단 버튼은 `toListButton`만("답변 완료로 닫기" 없음). 최초 문의 카드 "원문 보기" → F3-6(원문) → 뒤로 → 스레드. `…000c` → 답변 카드 다음에 `parentCardTitle('박서준', followUp: true)` 카드와 "눌러서 확인" 문구 → 카드 누름 → 재문의 상세: `followUpTitle(<루트 제목>)`·`followUpHeader('박서준', …)`·사실관계·요청사항·"원문 보기"·"답변 작성" → "원문 보기" → F3-6 제목 `followUpTitle(…)` 그대로·"답변 작성" 있음 → 뒤로 → "답변 작성" → F4-2a 요청사항이 재문의 것 → 점검 → 직접 전송 → **스레드 한 겹**으로 돌아옴(뒤로 가면 목록), 끝에 새 답변 카드, "눌러서 확인" 사라짐.
- [X] T034 [P] [US4] `test/features/reply/follow_up_detail_view_model_test.dart` 작성(research R13): (a) 번역본 있음 → `Refined`, `refinement(followUpId)` 1회, (b) 409 `refinementNotReady` → `NotRefined`, (c) 긴급 재문의 → `Urgent`, `refinement` 호출 0회, (d) 어떤 경우든 `content` 호출 0회, (e) 403 → 오류 상태(서버 message), 다시 시도하면 다시 요청.

### Implementation for User Story 4

- [X] T035 [US4] `thread_view_model.dart` 완성(research R5, data-model §4): `ThreadState { title, studentName, String? teacherName, List<ThreadEntry> entries }`, `sealed class ThreadEntry`(`ParentCard(inquiryId, isFollowUp, urgent, String? requests, submittedAt, bool unanswered, TeacherFollowUp? followUp)`, `AnswerCard(content, sentAt)`). `build()`는 `Future.wait`로 루트 `detail`·`teacherRepositoryProvider.getProfile()`(실패 → null) 시작, 상세를 받은 뒤 루트(`REFINED`일 때)와 긴급이 아닌 재문의마다 `refinement`를 병렬 요청(409 `refinementNotReady` → null). 원문은 부르지 않는다. 기능 간 참조(`teacher/data/teacher_repository_provider.dart`)는 이 파일 한 곳.
- [X] T036 [US4] (전송 뒤 스레드로 돌아가기는 pop 반복 대신 `AnswerSent`를 결과로 돌려주며 작성 → 원문·재문의 상세가 차례로 닫는 방식으로 구현 — pop 반복이 스레드까지 닫는 문제) `thread_page.dart` 완성(Figma F4-3 315-1789, 재문의 스레드 315-1822): 최초 문의 카드(`parentCardTitle`, 요청사항 있으면 `small` 본문, 카드 안 맨 아래 `OutlinedButton(viewOriginalButton)` → `context.push('/teacher/inquiries/$rootId/content', extra: ContentArgs(title: 루트 제목, header: …, answerTarget: AnswerTarget(inquiryId: rootId, …, requests: 루트 요청사항, fromThread: true)))`), 답변 카드(`answerCardTitle(teacherName)`, 본문), 재문의 카드(`parentCardTitle(…, followUp: true)`, 요청사항 있으면 본문, 버튼 없음, **카드 전체** `InkWell` → `context.push('/teacher/inquiries/$rootId/follow-ups/${followUp.inquiryId}', extra: FollowUpArgs(...))`), 각 카드 뒤 시각 줄(답변 `· 전송 완료`, `unanswered` 재문의 `· 재문의 받음 · 눌러서 확인`). `RefreshIndicator`로 다시 읽기. push한 화면에서 돌아오면 다시 읽는다.
- [X] T037 [US4] (family 키는 `init` 대신 `(followUpId, urgent)` 레코드 — 긴급이면 번역본을 요청하지 않으므로 build 시점에 알아야 한다) `lib/features/reply/presentation/follow_up_detail_view_model.dart`·`follow_up_detail_page.dart` 생성(research R13, data-model §6, Figma 323-1843 "F4-3b 재문의 상세"): ViewModel `AsyncNotifier<FollowUpDetail>`(family `String followUpId`, autoDispose; `FollowUpArgs`는 화면이 `init`으로 넘김) — 긴급이면 `Urgent`, 아니면 `teacherInquiryRepositoryProvider.refinement(followUpId)` → `Refined` / 409 → `NotRefined`. 원문은 부르지 않는다. 화면(F3-2 배치): 앱바 "문의 상세", `Refined`면 배지 `NoticeText.refinedBadge`, 제목 `followUpTitle(rootTitle)`(`display`), 머리 줄 `followUpHeader(studentName, followUp.submittedAt)`, `Refined` → F3의 `RefinementView(refinement:)`(사실관계·요청사항·정서강도) / `NotRefined` → `SystemNotice(followUpNotRefined)` / `Urgent` → `SystemNotice(NoticeText.urgentDetailGuide, icon: warning)`, 그 아래 `NoticeText.contentViewWillLog`, 하단 `OutlinedButton(viewOriginalButton)`(→ `/teacher/inquiries/${followUp.inquiryId}/content`, `ContentArgs(title: followUpTitle(rootTitle), header: '$studentName 학부모 · {M/d HH:mm}', answerTarget: …)`)·`FilledButton(writeAnswerButton)`(→ `/teacher/inquiries/$rootId/answer`, `AnswerTarget(inquiryId: rootId, studentName, title: rootTitle, requests: refinement?.requests(빈 문자열이면 null), fromThread: true)`).
- [X] T038 [US4] **생략** — api-v0.7 `hasAnswer`로 `teacher_inquiry_tile.dart`의 `pathOf`가 바로 고른다(답변 있음 → `/thread`, 그 밖 긴급 → `/urgent`, 일반 → `/general`). 원래 내용: (백엔드가 목록 답변 여부 필드를 태그로 내보냈으면 이 작업과 T032를 생략하고 `pathOf`가 필드로 바로 고르게 한다 — research R3) `lib/features/inquiry/presentation/teacher/open_inquiry_page.dart` 생성(research R3) — `OpenInquiryPage(inquiryId)`: `teacherInquiryRepositoryProvider.detail` 1회(작은 `FutureProvider.autoDispose.family` 또는 ViewModel), 받으면 `hasAnswers` → `/thread`, 긴급 → `/urgent`, 그 밖 → `/general`로 `context.replace`(그리는 중 이동 금지, `ref.listen`/post-frame). 로딩 중 `CircularProgressIndicator`, 오류는 `AsyncView` 오류 + 다시 시도.
- [X] T039 [US4] (T038 생략에 따라 `/teacher/inquiries/:inquiryId`·`OpenInquiryPage` 경로는 만들지 않고, `/answer` redirect 대상은 `/teacher/inquiries` 그대로, `pathOf`는 `hasAnswer`로 고른다 — 이 부분은 반영됨) `lib/app/router.dart`에 재문의 상세 경로 `GoRoute(path: '/teacher/inquiries/:inquiryId/follow-ups/:followUpId', redirect: extra가 FollowUpArgs가 아니면 '/teacher/inquiries/:inquiryId/thread', builder: FollowUpDetailPage(args: …))`도 추가하고, `/content`의 builder가 `ContentArgs`도 받게 한다(T022). T021의 `/answer` redirect 대상을 `/teacher/inquiries/:inquiryId`로 바꾼다. `teacher_inquiry_tile.dart`의 `pathOf`를 `'/teacher/inquiries/${item.inquiryId}'` 하나로 바꾸고 주석을 "문의 열기가 답변 여부·긴급으로 고른다(specs/004 R3)"로. `home_inquiry_section.dart`는 `pathOf`를 쓰므로 확인만.

**Checkpoint**: T031~T034 통과. quickstart 16~19b.

---

## Phase 7: User Story 5 - 서버 없이 모든 상태를 시연한다 (Priority: P2)

**Goal**: spec FR-027의 경우를 mock으로 모두 재현.

**Independent Test**: quickstart 1~25를 `--dart-define=USE_MOCK=true`로 확인.

- [ ] T040 [P] [US5] `test/features/mock_scenarios_test.dart`에 그룹 "F4 시연" 추가: (a) 403 데모 카드에서 문의 열기 → 권한 없음, (b) `noclass` 계정 점검·전송 → 403, (c) 갱신 데모 계정(F1 quickstart)으로 전송 → 갱신 후 성공, (d) 데모 문의 `…000b`·`…000c`가 교사 목록에 보이고 답변 있음(`hasAnswer`)으로 표시.
- [ ] T041 [US5] T040 결과로 빠진 mock 동작이 있으면 `mock_inquiry_store.dart`·`mock_answer_repository.dart`에 채운다(FR-027 목록 대조: 점검 3종, 전송 3종, 답변 안 한/한/재문의 문의, 403, 401 갱신).

**Checkpoint**: T040 통과.

---

## Phase 7b: User Story 6 - 답변 대기 / 답변 완료 두 칸 (Priority: P2)

**Goal**: spec FR-028~031. Figma F3-1(216-5587)·F3-1b(352-1856)·`SegmentTabs`(351-1866).

**Independent Test**: mock 문의 탭 → 답변 대기에 답변 없는 문의와 재문의 데모(`…000c`, "재문의 받음"), 답변 완료에 `…000b`. 답변 대기 문의에 답변 → 목록으로 → 답변 완료로 옮겨 감.

- [X] T048 [P] [US6] 테스트: `mock_scenarios_test.dart` "F4 mock 저장소"에 (a) `…000b` 목록 항목 `needsAnswer false`, (b) `…000c` `needsAnswer true`·`lastFollowUpAt` 있음, (c) 답변 없는 문의 `needsAnswer true`, (d) `…000c`에 답변 전송 → `needsAnswer false`. `inquiry_repository_impl_test.dart`에 실서버 목록 해석 `needsAnswer == !hasAnswer`, `lastFollowUpAt null`.
- [X] T049 [P] [US6] 위젯 테스트 `test/features/inquiry/teacher_inquiry_tabs_test.dart`: 문의 탭 처음엔 "답변 대기 N" 선택, `…000b` 없음·`…000c`는 "재문의 받음"; "답변 완료" 누름 → `…000b` "답변 완료 · … 답변", 누르면 스레드. 답변 대기 문의에 답변 전송 → 목록으로 → 답변 완료에 있음.
- [X] T050 [US6] `inquiry/domain/models.dart` `TeacherInquirySummary`에 `needsAnswer`(기본 `!hasAnswer`)·`lastFollowUpAt`(nullable) 추가. `inquiry_json.dart` 실서버 해석은 `needsAnswer: !hasAnswer`, `lastFollowUpAt: null`(서버 필드가 생기면 그 값으로, FR-031). `mock_inquiry_store.dart` 요약은 답변 없음 또는 마지막 답변 뒤 재문의 → `needsAnswer true`, `lastFollowUpAt` = 마지막 재문의 시각.
- [X] T051 [US6] `teacher_inquiries_view_model.dart`에 칸 상태(`InquiryTab.waiting|answered`, 기본 waiting) provider와 `TeacherInquiriesState.waiting`/`answered` 목록 추가. `teacher_inquiries_page.dart` 상단에 두 칸 전환(Figma `SegmentTabs`), 칸별 "전체 N · 긴급 M · 일반 K"(답변 대기 `smallStrong`, 답변 완료 `subtitle` — Figma 그대로), 칸이 비면 안내 문구. `teacher_inquiry_tile.dart` 부제: 재문의 대기 "재문의 받음 · {시각}" + "재문의" 표시, 답변 완료 "답변 완료 · {시각} 답변".
- [X] T052 [US6] 답변 전송 뒤 목록으로 돌아오면 목록을 다시 불러 칸이 바로 바뀌게 한다(스레드 "문의 목록으로"·뒤로 가기).
- [X] T053 [US6] (사용자 결정 2026-10-29, FR-031) mock도 실서버처럼 `hasAnswer`만으로 나눈다: `mock_inquiry_store.dart` 요약이 `needsAnswer`·`lastFollowUpAt`을 넘기지 않음(재문의 데모 `…000c`는 답변 완료). T048·T049 테스트를 이에 맞춰 고침. 답변 완료 칸 개수 줄도 답변 대기와 같은 `smallStrong`(T051의 Figma 차이 해소). 모델 필드·카드 재문의 표시는 서버 값이 생기면 바로 쓰도록 남겨 둔다.

**Checkpoint**: T048·T049 통과, `flutter analyze` 깨끗.

---

## Phase 8: Polish & Cross-Cutting

- [ ] T042 [P] `test/core/router_redirect_test.dart`에 새 경로 4개(`/teacher/inquiries/x`, `/answer`, `/thread`, `/follow-ups/y`) 추가 — 학부모·슈퍼 관리자는 각자 홈으로, 교사는 그대로. `/answer`에 `extra` 없으면 문의 열기로.
- [ ] T043 [P] 원칙 VI 점검 — `lib/features/reply/`와 이번에 고친 파일에서 `print(`·`debugPrint(`·`log(` 검색, 답변 본문·점검 결과가 나가는 곳이 없음을 확인(SC-006). 위젯 테스트들에 `@` 검사(`expectNoEmail`)가 들어갔는지 확인.
- [ ] T044 `flutter analyze`·`flutter test` 전부 통과(실패를 숨기거나 테스트를 지우지 않는다).
- [ ] T045 quickstart 1~25를 에뮬레이터(Pixel 8, mock)로 확인하고, 실서버가 있으면 26~29 확인. 결과를 이 파일 아래 "검증 기록"에 날짜와 함께 적는다.
- [ ] T046 [P] `docs/ia.md` 갱신 — "03 · 교사" 표의 Figma 링크를 새 노드로 바꾼다(F4-3 → `node-id=315-1789`, 재문의가 있는 스레드 `315-1822`, F4-3b 재문의 상세 `323-1843`, F3-6 원문 열람 · 재문의 `323-1863`; 원래 216-5533·225-1800은 Figma에서 빠짐). F4-3a를 "쓰지 않음(spec 004 FR-017, Figma에서 삭제)"으로, F4-3 이동을 "문의 목록으로"만으로, F3-1 이동에 "답변한 문의 → F4-3" 추가, 재문의 상세(F4-3b: 재문의 카드 → 원문 보기 F3-6 / 답변 작성 F4-2a) 행 추가, "아직 정해지지 않은 것"의 닫기 이름 겹침 항목을 해결로 고친다.
- [ ] T047 PR 설명 초안에 팀 공유 사항을 적는다: 닫기 없음·점검 필수·제안 번호 제목(백엔드 `docs/decisions.md` 기록 요청), 점검 실서버 연동 여부·재문의 ID 전송 동작·멱등키 확인 요청, Figma 원본 섹션에 반영한 F4-3·재문의 스레드·F4-3b·재문의 F3-6과 빠진 F4-3a 안내. `Closes #9`.

---

## Dependencies & Execution Order

- **Phase 1 → Phase 2 → Story들**. Phase 2의 T006 → T007, T008·T009 → T010, T011 → T012, T013 → T014 → T015.
- **US1(Phase 3)**: Phase 2 완료 후. MVP.
- **US2(Phase 4)·US3(Phase 5)**: US1의 T018·T019(작성 ViewModel·화면 골격) 뒤. Phase 4·5 안에서도 테스트 → 구현 순서. 서로는 독립(같은 파일을 고치므로 순서대로 하는 것을 권장: US2 → US3).
- **US4(Phase 6)**: US1의 T020·T021 뒤. US2·US3과 독립.
- **US5(Phase 7)**: US1~US4 뒤(시연 대상이 다 있어야 함).
- **US6(Phase 7b)**: US1 뒤(답변 전송이 있어야 칸 이동을 확인). US2~US5와 독립(문의 목록 파일만 고침).
- **Polish**: 모든 Story 뒤.

## Parallel Opportunities

- Phase 1: T001 ∥ T002.
- Phase 2 테스트: T003 ∥ T004 ∥ T005. 구현: T008 ∥ T009 ∥ T013(서로 다른 파일).
- 각 Story의 테스트 작업([P])끼리는 동시에 작성 가능(예: US1 T016 ∥ T017, US4 T031 ∥ T032 ∥ T033 ∥ T034).
- US4는 US2·US3과 병렬 진행 가능(다른 파일: thread_*, follow_up_detail_*, open_inquiry_page, router).
- Polish: T042 ∥ T043 ∥ T046.

## Implementation Strategy

1. **MVP = Phase 1 + 2 + US1**: 답변을 써서 점검을 거쳐 보낼 수 있다(제안 표시는 아직 단순). 여기서 멈춰도 교사가 답할 수 있다.
2. **US2 + US3**: 점검 결과 화면 완성(제안·바꾸기·되돌리기·제안 없음·수정·실패).
3. **US4**: 스레드 완성(요청사항·표시 이름·재문의·목록에서 바로 스레드).
4. **US5 + Polish**: mock 시연 점검, 문서·PR 정리.

각 단계 끝 Checkpoint에서 `flutter analyze`·`flutter test`를 돌린다.

## 검증 기록

(구현 후 T045에서 적는다)
