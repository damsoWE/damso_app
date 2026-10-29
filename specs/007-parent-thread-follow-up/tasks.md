# Tasks: 학부모 문의 스레드·이어서 묻기·답변 알림 (F4 학부모)

**Input**: `specs/007-parent-thread-follow-up/` 의 spec.md · plan.md · research.md · data-model.md · contracts/ · quickstart.md

**Tests**: plan.md Testing에 따라 JSON 해석·ViewModel·라우터·알림 데이터 단위 테스트를 둔다. 화면 흐름은 배포 서버 E2E(quickstart)로 확인한다. mock 시나리오 테스트는 만들지 않는다(research R9).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: 다른 파일이고 앞선 미완료 작업에 기대지 않아 동시에 할 수 있음
- **[Story]**: User Story Phase 작업만 붙인다(US1~US4)

## 공통 규칙 (모든 작업에 적용)

- **선행 조건(research R2)**: PR #25(이슈 #23)가 main에 머지된 뒤 이 브랜치를 `git rebase main`으로 올리고 시작한다. 머지 전에는 T001만 한다.
- 위젯 → ViewModel(Riverpod `Notifier`/`AsyncNotifier`, `autoDispose`) → Repository 인터페이스. 위젯은 Repository를 직접 부르지 않는다. `domain`은 Flutter·dio를 import하지 않는다.
- data 계층은 모든 dio 호출을 `mapDioErrors`로 감싼다. 화면 오류는 `userMessageOf(e)` / `AppException.message`만.
- **mock 시나리오를 만들지 않는다**(R9). 인터페이스가 넓어진 기존 mock 클래스는 호출 시 `AppException(message: '이 실행에서는 지원하지 않습니다.')`를 던지는 최소 구현만 둔다. 새 저장소 provider는 실서버 구현만 고른다.
- 재문의·답변 본문, 알림 데이터, 기기 토큰을 `print`·`debugPrint`·로그·저장소에 남기지 않는다(원칙 VI, FR-021). 본문은 일반 `Text`로만 그린다.
- URL에는 문의 UUID만. 학생 이름 등은 `extra`로. 새 경로는 모두 `/parent/` 아래.
- 색·글자·간격은 `AppColors`·`AppTextStyles`·`AppSpacing`·`AppRadius`, 시각은 `lib/features/inquiry/presentation/format.dart`의 `formatDateTime`.
- 파일 맨 위 주석에 화면 ID와 Figma 노드(예: `/// F4-1 문의 상세(스레드) (Figma 216-5241)`).

---

## Phase 1: Setup

- [ ] T001 이 브랜치가 PR #25 머지 뒤 main 위에 있는지 확인: `git log --oneline main..HEAD`가 비었거나 이 기능 커밋만이고, `lib/features/notification/presentation/device_registrar.dart`에 `deleteToken()`, `lib/app/router.dart`에 `_hasValidIds`가 있어야 한다. 없으면 `git fetch origin && git rebase origin/main`. git이 무시하는 `env/prod.json`·`secrets/firebase.json`을 원래 저장소(`C:\Users\HAMA\LeeHyunWoo\damso_front`)에서 복사.

---

## Phase 2: Foundational (모델·저장소·알림 데이터 — 모든 Story의 선행 조건)

### Tests for Foundational

- [ ] T002 [P] `test/features/inquiry/inquiry_repository_impl_test.dart`에 그룹 "학부모 F4 상세" 추가(기존 가짜 `HttpClientAdapter`): (a) `detail`이 `content`, `followUps`(`inquiryId·content·urgent·stage·submittedAt·notices·hotlines`), `answers`(`answerId·content·sentAt`, `reviewed`는 무시)를 해석, (b) `thread`가 시각 오름차순으로 RootItem·AnswerItem·FollowUpItem을 섞어 만듦(같은 시각이면 서버 배열 순서), (c) 둘 다 `[]`이면 `thread`는 RootItem 하나, (d) 필드 누락이면 `AppException`(fallbackMessage).
- [ ] T003 [P] 같은 파일에 그룹 "재문의 제출": `submitFollowUp(inquiryId: 'r1', content: '본문', idempotencyKey: 'k1')` → `POST /api/v1/parent/inquiries/r1/follow-ups`, 헤더 `Idempotency-Key: k1`, body `{"content":"본문"}`, 201 `{inquiryId, threadRootId, urgent, submittedAt, notices, hotlines}` 해석. 409 `NO_HOMEROOM_TEACHER`·`CONFLICT`·`THREAD_CLOSED` → `AppException.code` 그대로, 429 + `Retry-After: 30` → `retryAfter` 30초, 400 `fieldErrors[{field:"content"}]` → `fieldErrors['content']`.
- [ ] T004 [P] `test/core/push_data_test.dart`에 케이스 추가: `{'kind':'ANSWER','inquiryId':<uuid>}` → `PushKind.answer`, `role == 학부모`, `route == '/parent/inquiries/<uuid>/thread'`; `inquiryId`가 UUID가 아니면 `route == '/parent/inquiries'`; 기존 URGENT·GENERAL은 `role == 교사`·경로 그대로; 모르는 kind는 `role` 없음.

### Implementation for Foundational

- [ ] T005 `lib/features/inquiry/domain/models.dart` 수정(data-model §1~§4): `class ParentFollowUp { inquiryId, content, urgent, InquiryStage stage, DateTime submittedAt, List<Notice> notices, List<Hotline> hotlines; SubmitOutcome get outcome }`, `class ParentAnswer { answerId, content, DateTime sentAt }`, `sealed class ThreadItem` + `RootItem(content, submittedAt, urgent, stage)`·`AnswerItem(content, sentAt)`·`FollowUpItem(content, submittedAt, urgent, stage, hotlines)`, `class FollowUpSubmitted { inquiryId, threadRootId, urgent, DateTime submittedAt, notices, hotlines; SubmitOutcome get outcome }`. `ParentInquiryDetail`에 `required this.content`·`required this.followUps`·`required this.answers` 추가, 파생 `List<ThreadItem> get thread`(data-model §3 순서 규칙). 이 생성자를 쓰는 기존 코드(mock 저장소 등)는 `content: ''`·`const []`로 맞춘다.
- [ ] T006 `lib/features/inquiry/data/inquiry_json.dart` 수정: `parentDetail`이 `content`·`followUps`·`answers`를 읽게 하고(`static ParentFollowUp parentFollowUp(Map)`, `static ParentAnswer parentAnswer(Map)` 추가), 71행 주석 "content·followUps 와 답변 본문은 읽지 않는다"를 지운다. `static FollowUpSubmitted followUpSubmitted(Map)` 추가. 단계·안내 코드 해석은 기존 함수 재사용.
- [ ] T007 `lib/features/inquiry/domain/parent_inquiry_repository.dart`에 `Future<FollowUpSubmitted> submitFollowUp({required String inquiryId, required String content, required String idempotencyKey});` 추가(주석: `inquiryId`는 스레드 루트, 같은 키 재전송은 처음 결과, research R4).
- [ ] T008 `lib/features/inquiry/data/parent_inquiry_repository_impl.dart`에 `submitFollowUp` 구현(contracts/api-usage.md, `Options(headers: {'Idempotency-Key': idempotencyKey})`, `mapDioErrors`).
- [ ] T009 `lib/features/inquiry/data/mock_parent_inquiry_repository.dart`에 `submitFollowUp` 최소 구현: `throw const AppException(message: '이 실행에서는 지원하지 않습니다.')`(주석: mock 시나리오 없음, research R9). 상세 생성 코드는 T005에 맞춰 `content`·빈 목록으로.
- [ ] T010 `lib/core/push/push_messaging.dart` 수정(data-model §8): `PushKind.answer`('ANSWER') 추가, `enum PushTarget { teacher, parent }`와 `PushTarget? get target`(긴급·재알림·일반·묶음 → teacher, answer → parent, unknown → null), `route`를 `answer`면 `inquiryId != null ? '/parent/inquiries/$id/thread' : '/parent/inquiries'`로. 기존 교사 경로는 그대로.

**Checkpoint**: T002~T004 통과, 기존 테스트 통과(`flutter test test/features/inquiry test/core`).

---

## Phase 3: User Story 1 - 스레드에서 교사 답변을 확인한다 (Priority: P1) 🎯 MVP

**Goal**: 홈·목록 카드 → 스레드(F4-1)에서 처음 문의·답변·재문의를 시간순으로 본다.

**Independent Test**: 배포 서버에서 답변 받은 문의를 학부모로 열어 시간순 표시·답변 대기 안내·403 안내를 확인(quickstart #2~#4, #17).

### Tests for User Story 1

- [ ] T011 [P] [US1] `test/features/inquiry/parent_thread_view_model_test.dart` 작성(테스트 전용 가짜 `ParentInquiryRepository`): (a) 로드 성공 → `AsyncData(detail)`, (b) 403 `AppException` → `AsyncError`, 메시지 그대로, (c) `reload()` → `detail` 2회.
- [ ] T012 [P] [US1] `test/core/router_redirect_test.dart`에 케이스: 학부모가 `/parent/inquiries/<uuid>/thread`·`/parent/inquiries/<uuid>/follow-up`·`/parent/settings/notifications` → `null`(그대로), 교사가 같은 경로 → `/teacher`, 학부모가 `/parent/inquiries/abc/thread` → `/parent/inquiries`.

### Implementation for User Story 1

- [ ] T013 [US1] `lib/features/inquiry/presentation/parent/thread_view_model.dart` 생성 — `AsyncNotifier` family(`inquiryId`), `build`에서 `ref.read(parentInquiryRepositoryProvider).detail(inquiryId)`, `reload()`.
- [ ] T014 [US1] `lib/features/inquiry/presentation/parent/thread_page.dart` 생성(F4-1, Figma 216-5241): AppBar 제목 학생 이름(상세의 `summary.studentName`), `thread`를 카드로 — RootItem·FollowUpItem은 "학부모 · 처음 문의"/"학부모 · 이어서 물음" + `formatDateTime` + 본문 + 긴급이면 긴급 배지와 `hotlines` 번호(기존 긴급 안내의 번호 위젯 재사용), AnswerItem은 "담임 선생님" + 시각 + 본문. 답변이 하나도 없으면 끝에 "답변을 기다리고 있어요" + 처음 문의 처리 단계(기존 `StageTimeline` 위젯 재사용). 로딩·오류(서버 안내 + 다시 시도)는 기존 `AsyncView`. 당겨서 새로 고침 → `reload()`. 하단 버튼 "이어서 묻기"(T020 경로로 push) · "문의 목록으로"(`go('/parent/inquiries')`). 수정·삭제 버튼 없음.
- [ ] T015 [US1] `lib/app/router.dart`에 `GoRoute(path: '/parent/inquiries/:inquiryId/thread', builder: (_, s) => ThreadPage(inquiryId: s.pathParameters['inquiryId']!))`를 셸 밖(기존 `/parent/inquiries/:inquiryId/urgent` 옆)에 추가.
- [ ] T016 [US1] `lib/features/inquiry/presentation/parent/inquiry_card.dart` 수정(research R6): 펼치기/접기(`expandable`, `_toggle`, 펼친 타임라인)를 없애고 `onTap` 하나로. `lib/features/inquiry/presentation/parent/parent_inquiries_page.dart`·`home_inquiry_section.dart`의 탭 규칙: `s.urgent && !s.hasAnswer` → 기존 `/parent/inquiries/${id}/urgent`, 그 밖 → `/parent/inquiries/${id}/thread`(`push`). 펼친 카드용 `parentInquiryDetailsProvider`를 더 쓰지 않으면 지우고, `lib/app/shells/parent_shell.dart`의 `ref.invalidate(parentInquiryDetailsProvider)` 줄도 지운다.
- [ ] T017 [US1] 기존 `test/features/inquiry/parent_inquiries_test.dart`에서 펼치기 동작을 기대하는 케이스를 카드 탭 → 스레드 경로 이동으로 고친다(긴급·답변 없음은 긴급 안내 경로).

**Checkpoint**: 배포 서버에서 quickstart #2~#4 확인.

---

## Phase 4: User Story 2 - 같은 문의에서 이어서 묻는다 (Priority: P1)

**Goal**: 스레드 → 이어서 묻기(F4-1a) → 접수(F2-5)/긴급 안내 → 스레드.

**Independent Test**: quickstart #5~#9.

### Tests for User Story 2

- [ ] T018 [P] [US2] `test/features/inquiry/follow_up_view_model_test.dart` 작성(가짜 저장소): (a) 빈 내용·공백만·`inquiryLength > 2000`이면 `canSend false`, (b) `send()`를 await 없이 두 번 → `submitFollowUp` 1회, (c) 네트워크 실패 뒤 같은 내용(앞뒤 공백 차이 포함)으로 재전송 → 같은 `idempotencyKey`, 내용을 바꾸면 새 키, 성공 뒤 새 키, (d) 429 `retryAfter` 동안 `canSend false`, 내용 유지, (e) 409·400 → 서버 메시지, 내용 유지, (f) 성공 → `done`에 `FollowUpSubmitted`.

### Implementation for User Story 2

- [ ] T019 [US2] `lib/features/inquiry/presentation/parent/follow_up_view_model.dart` 생성(data-model §5): 상태 `content·sending·error·retryAfter·done`, 입력 규칙 `inquiryMaxLength`·`inquiryLength`(compose_view_model.dart와 같은 함수), 키 규칙은 `compose_view_model.dart`의 `_key` 방식을 따라 `(inquiryId, trim(content))`가 같으면 재사용. 429는 기존 `CooldownTimer`/`startIfLimited`로 대기. `ref.keepAlive()`로 전송 중 화면이 사라져도 응답 처리 완료.
- [ ] T020 [US2] `lib/features/inquiry/presentation/parent/follow_up_page.dart` 생성(F4-1a, Figma 225-1722): 입력란(글자 수 `n/2000`), "보내기"(`SubmitButton(isLoading: sending)`), 보내는 중 `PopScope(canPop: false)`, 내용이 있으면 떠날 때 처음 문의 작성(`compose_page.dart`)과 같은 확인 대화상자. 성공하면 `pushReplacement('/parent/inquiries/submitted', extra: SubmittedArgs(outcome: done.outcome, studentName: args.studentName, submittedAt: done.submittedAt, threadRootId: done.threadRootId))`. `class FollowUpArgs { final String studentName; }`도 이 파일에 둔다.
- [ ] T021 [US2] `lib/app/router.dart`에 `GoRoute(path: '/parent/inquiries/:inquiryId/follow-up', redirect: (_, s) => s.extra is FollowUpArgs ? null : '/parent/inquiries/${s.pathParameters['inquiryId']}/thread', builder: …FollowUpPage(inquiryId, args))` 추가(셸 밖).
- [ ] T022 [US2] `lib/features/inquiry/presentation/parent/submitted_page.dart` 수정(research R5, contracts/routes.md): `SubmittedArgs`에 `final String? threadRootId;`(선택) 추가. "보낸 문의 보기"는 `threadRootId != null`이면 `context.go('/parent/inquiries')` 다음 `context.push('/parent/inquiries/$threadRootId/thread')`, 아니면 지금처럼 `go('/parent/inquiries')`. 긴급 안내 화면도 같은 버튼 규칙(같은 파일 안 분기).
- [ ] T023 [US2] `thread_page.dart`의 "이어서 묻기" 버튼을 `push('/parent/inquiries/$inquiryId/follow-up', extra: FollowUpArgs(studentName: detail.summary.studentName))`로 연결(T014에서 자리만 둔 경우).

**Checkpoint**: quickstart #5~#9를 배포 서버에서 확인. 교사 계정 스레드에 재문의 카드가 생기는지 함께 본다.

---

## Phase 5: User Story 3 - 답변 도착 알림을 받고 스레드로 간다 (Priority: P2)

**Goal**: 학부모 기기 등록, 답변 알림 → 스레드, 앱 안 배너.

**Independent Test**: quickstart #1, #10~#12, #15~#16.

### Tests for User Story 3

- [ ] T024 [P] [US3] `test/features/notification/device_registrar_test.dart`에 케이스: 학부모 `SignedIn` + 권한 허용 → `registerDevice` 1회, 관리자 → 0회, 학부모 로그아웃 → `unregisterCurrentDevice`·`deleteToken`(PR #25 흐름) 호출.
- [ ] T025 [P] [US3] `test/features/notification/push_navigation_test.dart`에 케이스: 학부모 로그인 중 답변 알림 열기 → `/parent/inquiries/<id>/thread` push, 교사 로그인 중 답변 알림 → 이동 없음, 학부모 로그인 중 긴급 알림 → 이동 없음, 로그아웃 중 답변 알림 → 대기 경로 저장 후 학부모 로그인 → 그 경로, 교사로 로그인 → 버림.

### Implementation for User Story 3

- [ ] T026 [US3] `lib/features/notification/presentation/device_registrar.dart` 수정(research R8): 대상 판정을 `session.role == Role.teacher`에서 `role == Role.teacher || role == Role.parent`로(필드 이름 `_teacher` → `_eligible`, 주석 "학부모는 F4" 갱신). 등록·해제·토큰 폐기 흐름은 그대로.
- [ ] T027 [US3] `lib/features/parent/presentation/parent_home_page.dart`: 교사 홈(`teacher_home_page.dart:21`)과 같이 첫 프레임 뒤 `ref.read(deviceRegistrarProvider).requestPermissionIfNeeded()` 호출(FR-016).
- [ ] T028 [US3] `lib/app/push_listener.dart` 수정(research R7): `_isTeacher` 대신 `PushTarget? _roleTarget`(교사 → teacher, 학부모 → parent, 그 밖 null). `_onForeground`는 `message.data.target == _roleTarget`일 때만 배너(PR #25의 `clearMaterialBanners()` 유지)와 새로고침 — 교사면 기존 교사 목록, 학부모면 `parentInquiriesViewModelProvider`와 그 스레드(`threadViewModelProvider(id)`)를 `invalidate`. `_open`은 같은 조건일 때만 `push(data.route)`, 로그아웃 상태면 대기 경로 저장. 로그인 리스너의 대기 경로 버림 조건을 "로그인 역할이 경로의 역할과 다르거나 가입 직후"로 바꾼다(학부모 경로는 `/parent/`로 시작).
- [ ] T029 [US3] `lib/app/shells/parent_shell.dart`를 `TeacherShell`(`lib/app/shells/teacher_shell.dart:28-34`)처럼 바꿔 첫 프레임 뒤 `pendingNavigationProvider`가 있으면 `push` 후 `clear()`.

**Checkpoint**: 학부모 기기로 quickstart #1, #10~#12, #15~#16 확인(교사 답변은 교사 계정으로).

---

## Phase 6: User Story 4 - 답변 도착 알림을 켜고 끈다 (Priority: P3)

**Goal**: 마이페이지 → 알림 설정(F2-8) 토글.

**Independent Test**: quickstart #13~#14.

### Tests for User Story 4

- [ ] T030 [P] [US4] `test/features/notification/parent_notification_repository_impl_test.dart` 작성(가짜 어댑터): `getSettings` → `GET /api/v1/parent/notification-settings` 해석, `saveSettings(false)` → `PUT` body `{"answerNotifyEnabled":false}`, 400 → `AppException`.
- [ ] T031 [P] [US4] `test/features/notification/parent_settings_view_model_test.dart` 작성(가짜 저장소): 로드 값 표시, 토글 → `saving true` → 성공 응답 값으로 확정, 실패 → 원래 값 + 서버 메시지, `saving` 중 토글 무시.

### Implementation for User Story 4

- [ ] T032 [P] [US4] `lib/features/notification/domain/parent_notification_repository.dart` 생성 — `class ParentNotificationSettings { final bool answerNotifyEnabled; }`(같은 파일 또는 `models.dart`), `abstract class ParentNotificationRepository { Future<ParentNotificationSettings> getSettings(); Future<ParentNotificationSettings> saveSettings(bool answerNotifyEnabled); }`.
- [ ] T033 [US4] `lib/features/notification/data/parent_notification_repository_impl.dart`(dio, `mapDioErrors`)와 `parent_notification_repository_provider.dart`(`Provider<ParentNotificationRepository>((ref) => ParentNotificationRepositoryImpl(ref.watch(dioProvider)))`, 주석: mock 분기 없음 — research R9) 생성.
- [ ] T034 [US4] `lib/features/notification/presentation/parent_settings_view_model.dart` 생성(data-model §7).
- [ ] T035 [US4] `lib/features/notification/presentation/parent_settings_page.dart` 생성(F2-8, Figma 216-5303): "답변 도착 알림" 스위치(저장 중 비활성), 안내 "알림을 꺼도 답변은 문의 목록에서 확인할 수 있어요."(FR-025), 기기 알림이 꺼져 있으면 교사 설정 화면(`settings_page.dart`)과 같은 `SystemNotice`(`pushPermissionProvider` 재사용, FR-024), 로딩·오류는 `AsyncView`.
- [ ] T036 [US4] `lib/app/router.dart`에 `GoRoute(path: '/parent/settings/notifications', builder: (_, _) => const ParentSettingsPage())`(셸 밖), `lib/features/parent/presentation/parent_my_page.dart`에 `MenuTile('알림 설정', onTap: () => context.push('/parent/settings/notifications'))`를 "연결된 자녀" 아래에 추가.

**Checkpoint**: quickstart #13~#14.

---

## Phase 7: Polish & Cross-Cutting

- [ ] T037 [P] `docs/ia.md` 학부모 표 갱신: F2-4 "카드 펼치기/접기" 제거(카드 → F4-1 / F2-3), F4-1·F4-1a·F2-8 경로 메모, 앱 spec 007 참조.
- [ ] T038 [P] `lib/`·`test/`에서 이 기능이 더한 코드에 `print`·`debugPrint`·`log(`가 없는지 검색, 본문이 `Text` 밖(HTML·Markdown)으로 그려지지 않는지 확인.
- [ ] T039 `flutter analyze` · `flutter test` 통과(실패를 숨기지 않는다).
- [ ] T040 배포 서버 E2E: quickstart #1~#17을 에뮬레이터(`Pixel_8`)에서 진행하고 결과를 이 파일 "검증 기록"에 적는다. 운영 DB에 남는 테스트 문의·답변은 본문 앞에 `[E2E]`.

---

## Dependencies & Execution Order

- **Setup(T001)** → **Foundational(T002~T010)** → 각 Story.
- **US1(T011~T017)**: Foundational 뒤. MVP.
- **US2(T018~T023)**: US1의 스레드 화면(T014·T015)이 있어야 진입 버튼을 연결할 수 있다(T023). T018~T022는 US1과 병행 가능.
- **US3(T024~T029)**: Foundational(T010) 뒤. 이동 목적지(스레드, T015)가 있어야 E2E가 된다.
- **US4(T030~T036)**: Foundational과 무관하게 진행 가능(다른 파일). `router.dart`는 US1·US2·US4가 함께 고치므로 순서대로 한다.
- **Polish(T037~T040)**: 모든 Story 뒤.

## Parallel Opportunities

- Foundational 테스트 T002·T003·T004 동시.
- US1 테스트 T011·T012, US2 테스트 T018, US3 테스트 T024·T025, US4 테스트 T030·T031 — 서로 다른 파일이라 동시.
- US4 전체(T030~T035)는 US1~US3과 동시에 진행 가능(T036의 `router.dart`만 순서 조정).

## Implementation Strategy

1. **MVP**: Setup → Foundational → US1. 학부모가 답변을 볼 수 있게 되는 것만으로 소통이 이어진다.
2. **+US2**: 이어서 묻기 — 교사 "닫기"를 뺀 운영 방식을 완성.
3. **+US3**: 답변 알림 — 소통 속도.
4. **+US4**: 알림 끄기 선택지.
5. 각 단계마다 배포 서버에서 quickstart 해당 번호를 확인한다.

## 검증 기록

(구현 뒤 T039·T040 결과를 적는다)
