---

description: "F5 감사 로그·이력 보존 (앱) 작업 목록"
---

# Tasks: F5 감사 로그·이력 보존 — 처리 단계 타임라인 · 관리자 문의 현황

**Input**: `specs/006-audit-history-status/` (plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md)

**대응 백엔드 spec**: `damsoWE/damso_server` `specs/006-audit-log-history` (api-v0.10)

**Tests**: 포함한다. plan.md Testing·research R8이 Repository·ViewModel·위젯·라우터 테스트를 정했다.

**Organization**: 사용자 스토리별로 묶는다. US1(관리자 문의 현황)이 MVP다. US2·US3는 기존 동작을 테스트로 고정하는 일이 대부분이다.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: 동시에 할 수 있음(다른 파일, 끝나지 않은 작업에 의존하지 않음)
- **[Story]**: US1 · US2 · US3
- **(사용자 승인 필요)**: CLAUDE.md "큰 영향 결정은 먼저 확인"에 따라 시작 전에 사용자에게 묻는다

---

## Phase 1: Setup (계약·디자인 기준 맞추기)

**Purpose**: 계약(api-v0.10)과 Figma를 백엔드 결정에 맞춘다. 코드보다 먼저 한다(Contract-first, research R1·R2).

- [X] T001 `/fetch-api api-v0.10`을 실행해 `docs/api/openapi.yaml`을 0.8.0 → 0.10 사본으로 갱신하고 변경 요약을 사용자에게 보고한다. 사본은 직접 고치지 않는다. 요약에서 research R1 표(`GET /api/v1/admin/inquiry-status` 추가, `/content` 감사 기록 실패 500 `INTERNAL_ERROR`, `/refinement` 감사 대상, `CONFLICT` 추가, `page` 최대 10000, 415)와 다른 점이 있으면 구현 전에 멈추고 알린다
- [X] T002 (사용자 승인 필요) Figma ADM-4(`node-id=224-1387`)를 research R2 "앱 결정" 열대로 고친다: "이번 주" → "전체", 요약 4칸 "전체 문의 · 답변 대기 · 교사 확인 · 답변 완료", 학급 카드 1줄 "3학년 2반 · 담임 연결됨/담임 미연결", 2줄 "문의 N · 답변 대기 a · 교사 확인 b · 답변 완료 c", 미연결 카드도 같은 건수 줄, 🔔 제거, 상단 안내 문구 그대로. 사용자가 Figma 수정을 미루면 이 작업을 건너뛰고 코드는 R2 결정대로 만든다

---

## Phase 2: Foundational (모든 스토리 전에)

**Purpose**: 현황 모델·Repository 계약. US1이 바로 쓰고, mock 계정 작업(US1)의 전제다.

**⚠️ CRITICAL**: T001이 끝나야 시작한다(계약 근거).

- [X] T003 `lib/features/admin/domain/models.dart`에 `ClassroomInquiryStatus`를 더한다: `classroomId : String (UUID)`, `waiting : int ≥ 0`(답변 대기, 교사 확인 전), `confirmed : int ≥ 0`(교사 확인, 답변 전), `answered : int ≥ 0`(답변 완료, 답변 1건 이상), getter `total` = `waiting + confirmed + answered`. Flutter·dio import 없음
- [X] T004 `lib/features/admin/domain/admin_repository.dart`의 `AdminRepository`에 `Future<List<ClassroomInquiryStatus>> inquiryStatus();`를 더한다(서버 순서 = 학년·반 순을 그대로 돌려준다는 주석 한 줄)
- [X] T005 [P] `lib/features/admin/data/admin_repository_impl.dart`에 `inquiryStatus()`를 구현한다: `GET /api/v1/admin/inquiry-status` → 응답 `{ items: [ClassroomInquiryStatus] }`의 `items`를 순서 그대로 변환. 네 필드 모두 필수이고 "없거나 음수·정수가 아니면 `FormatException` → 일반 오류 안내(F2 규칙과 같다)". `DioException`은 기존 메서드와 같은 방식으로 `lib/core` 오류 타입으로 바꾼다(403 `FORBIDDEN` → 서버 `message`)
- [X] T006 [P] `lib/features/admin/data/mock_admin_repository.dart`에 `inquiryStatus()`를 구현한다: mock 학급(관리자 홈과 같은 학급들)마다 다른 건수, 그중 1개 학급은 세 건수 0, mock에서 새로 추가한 학급은 0. 슈퍼 관리자가 아닌 토큰이면 403 `FORBIDDEN`(서버와 같은 문구). 기존 mock 메서드의 지연·권한 확인 방식을 따른다
- [X] T007 [P] `test/features/admin/admin_repository_impl_test.dart`(새로)에 `inquiryStatus` 해석 테스트: 정상 응답 → 순서·건수 그대로, 필드 누락·음수 → 일반 오류, 403 → 서버 `message`. 기존 admin 테스트(`test/features/admin/invite_issue_test.dart`)의 가짜 dio 방식을 따른다
- [X] T008 [P] `test/features/admin/mock_admin_repository_test.dart`(새로)에 mock `inquiryStatus` 테스트: 학급마다 건수가 있고 0건 학급이 있음, 학급을 추가하면 그 학급이 0으로 나옴, 비관리자 403

**Checkpoint**: `inquiryStatus()`가 실서버·mock 모두에서 동작하고 테스트가 통과한다

---

## Phase 3: User Story 1 - 슈퍼 관리자가 학급별 문의 처리 현황을 건수로만 본다 (Priority: P1) 🎯 MVP

**Goal**: 관리자 하단 탭(홈 · 문의 · 마이페이지)과 ADM-4 문의 현황 화면. 학급별 세 건수만, 사람 정보·제목·본문·긴급 없음.

**Independent Test**: mock `admin@damso.test`로 문의 탭을 열어 학급마다 세 건수가 mock 값과 같고, 화면 글자에 제목·본문·이름·`@`·"긴급"·"이번 주"가 없고, 0건 학급이 0으로 보이며, 학급을 누르면 ADM-1이 열리는지 확인한다(quickstart 1~8).

### Tests for User Story 1

- [X] T009 [P] [US1] `test/features/admin/inquiry_status_view_model_test.dart`(새로): 가짜 `AdminRepository`로 (a) `inquiryStatus()`와 `listClassrooms()`가 동시에 시작됨(둘 다 끝나기 전에 둘 다 호출됨), (b) `classroomId`로 학급 이름 "N학년 M반"·`homeroomAssigned` 합침, (c) 학급 목록에 없는 `classroomId` → `label` null, (d) 학급 목록만 실패 → 모든 행 `label`·`homeroomAssigned` null이고 상태는 데이터, (e) 현황 실패 → `AsyncError`, (f) `totals`가 학급별 값의 합, (g) `allZero`는 행이 있고 합계 0일 때만 true, 행 0개면 false, (h) 행 순서 = 현황 순서
- [X] T010 [P] [US1] `test/features/admin/inquiry_status_page_test.dart`(새로): (a) 상단 안내 "관리자는 문의 건수와 처리 상태만 볼 수 있어요. 문의 내용과 답변은 볼 수 없어요.", 요약 "전체" 4칸 "전체 문의 / 답변 대기 / 교사 확인 / 답변 완료", "학급별" 카드와 `문의 {n} · 답변 대기 {a} · 교사 확인 {b} · 답변 완료 {c}` 문구, (b) 화면 전체 글자에 `@`·학생 이름·"긴급"·"이번 주" 없음, (c) 모두 0 → "아직 접수된 문의가 없어요." 보임, (d) 학급 0개 → "등록된 학급이 없습니다. 학급을 추가해 주세요.", (e) 이름 모르는 학급 → "학급", 담임 표시 없음, (f) 세 자리 이상 건수가 잘리지 않음, (g) 오류 → 서버 `message`와 다시 시도 버튼만, (h) 학급 카드 누름 → `/admin/classrooms/:classroomId` push
- [X] T011 [P] [US1] `test/core/router_redirect_test.dart`에 `/admin/inquiries` 경우를 더한다: 슈퍼 관리자는 열림, 교사·학부모는 자기 홈으로 redirect, 비로그인은 로그인 화면

### Implementation for User Story 1

- [X] T012 [US1] `lib/features/admin/presentation/inquiry_status_view_model.dart`(새로): `AsyncNotifier<InquiryStatusState>`. `InquiryStatusState { rows: List<InquiryStatusRow>, totals: InquiryStatusTotals, allZero getter (rows 가 있고 totals.total == 0) }`, `InquiryStatusRow { status: ClassroomInquiryStatus, label: String? ("3학년 2반", 모르면 null), homeroomAssigned: bool? (모르면 null) }`, `InquiryStatusTotals { total, waiting, confirmed, answered }`. `build()`에서 `inquiryStatus()`와 `listClassrooms()`를 함께 시작(`Future.wait` 아님 — 학급 목록 실패는 잡아서 null 처리, 현황 실패만 그대로 던짐). `AdminRepository` 인터페이스(provider)에만 의존하고 dio·구현 클래스를 참조하지 않는다. `refresh()`로 다시 불러온다 (T009 통과)
- [X] T013 [US1] `lib/features/admin/presentation/inquiry_status_page.dart`(새로): ADM-4. 기존 `AsyncView`(로딩·오류+다시 시도·빈 상태)와 `SystemNotice`를 쓰고 `RefreshIndicator`로 당겨서 새로 고침. 문구는 data-model.md §3 표 그대로(title "문의 현황", metadataOnlyNotice, summaryTitle "전체", 네 칸 이름, byClassTitle "학급별", unknownClass "학급", "담임 연결됨 / 담임 미연결", rowCounts, allZeroNotice, noClassrooms) — 기존 admin 문구 관례(`AdminText` 또는 화면 상수)를 따른다. 학급 카드 누름 → `context.push('/admin/classrooms/$classroomId')`. 문의 목록·상세로 가는 이동, 긴급·기간 문구, 🔔 없음. 색·글자는 `lib/core/theme/app_theme.dart` 토큰 (T010 통과)
- [X] T014 [US1] `lib/app/shells/admin_shell.dart`(새로): `TabShell`을 쓰는 관리자 탭 셸 — 홈(`/admin`) · 문의(`/admin/inquiries`) · 마이페이지(`/admin/me`), 탭 이름·아이콘은 Figma TabBar(홈·문의·마이페이지). 문의 탭에 들어오면 `inquiryStatusViewModelProvider`를 다시 불러온다(FR-007, `teacher_shell.dart`의 `onTabEntered` 방식)
- [X] T015 [US1] `lib/app/router.dart`: 관리자 경로를 `StatefulShellRoute.indexedStack(builder: AdminShell)`로 바꾸고 브랜치 3개(`/admin` 홈, `/admin/inquiries` 새로, `/admin/me`)를 둔다. `/admin/classrooms/new`, `/admin/classrooms/:classroomId`(+ `students/new`, `invite-codes`), `/admin/invite/confirm`, `/admin/invite/issued`는 교사 셸처럼 셸 밖 GoRoute로 옮기고 경로 문자열은 그대로 둔다. redirect 함수는 바꾸지 않는다 (T011 통과)
- [X] T016 [US1] `lib/features/admin/presentation/admin_home_page.dart`: AppBar의 마이페이지 아이콘을 뺀다(탭으로 대체, contracts/routes.md). 관련 기존 테스트가 이 아이콘을 누르면 마이페이지 탭 이동으로 고친다
- [X] T017 [US1] (사용자 승인 필요) 관리자 401 갱신 데모 계정 `refresh-admin@damso.test`를 더한다 — `lib/features/auth/data/mock_auth_repository.dart`(로그인 계정, 비밀번호 `damso1234`, 역할 슈퍼 관리자)와 `lib/features/me/data/mock_me_repository.dart`(내 정보). F4 `refresh-teacher@` 방식 그대로, `lib/features/admin/data/mock_admin_repository.dart`에서 이 계정의 **첫** `inquiryStatus()`만 토큰 만료 → 갱신 → 재시도 성공을 흉내 낸다(R7)
- [X] T018 [US1] `test/features/mock_scenarios_test.dart`에 F5 관리자 시연을 더한다: `admin@damso.test` 로그인 → 탭 3개 → 문의 탭 현황 표시(0건 학급 포함) → 홈에서 학급 추가 → 문의 탭에서 새 학급 0, `refresh-admin@damso.test` → 문의 탭이 오류 없이 현황(T017을 건너뛰었으면 이 경우는 빼고 tasks에 표시)

**Checkpoint**: mock으로 quickstart 1~8이 모두 기대대로 동작한다. 이 시점에서 MVP 시연 가능

---

## Phase 4: User Story 2 - 학부모·교사는 문의 상세에서 처리 단계만 본다 (Priority: P2)

**Goal**: 타임라인에 감사 항목이 섞이지 않고, 앱 어디에도 감사 기록 화면이 없음을 테스트로 고정한다. 코드 변경은 원칙적으로 없다(data-model §4).

**Independent Test**: 원문 열람·재시도·점검 요청이 있었던 mock 문의를 학부모·교사 상세로 열어 타임라인이 처리 단계·시각만이고, 라우터 경로 목록에 감사 화면 경로가 없는지 확인한다(quickstart 10·11).

### Tests for User Story 2

- [X] T019 [P] [US2] `test/features/inquiry/stage_timeline_test.dart`에 더한다: (a) 원문 열람·재시도·점검 요청을 거친 mock 문의의 학부모 상세·교사 상세 타임라인이 같은 처리 단계 목록(접수·긴급 전달·정리 완료·교사 확인)과 시각만 그림, (b) "열람"·"재시도"·"점검" 글자 없음, (c) 모르는 단계 값 → 화면이 깨지지 않고 일반 오류 안내(F2 규칙, 기존 테스트가 있으면 그대로 두고 확인만)
- [X] T020 [P] [US2] `test/core/router_redirect_test.dart`에 감사 화면 경로 없음 테스트: 라우터에 등록된 모든 경로 문자열에 `audit`·`history`·`export`가 없음(FR-009, SC-004)

### Implementation for User Story 2

- [X] T021 [US2] T019·T020이 실패하면 원인을 사용자에게 보고하고, 승인을 받은 뒤에만 `lib/features/inquiry/` 타임라인 코드를 고친다(기존 동작이 맞으면 코드 변경 없음)

**Checkpoint**: US1·US2 모두 독립적으로 동작하고 테스트 통과

---

## Phase 5: User Story 3 - 원문 열람이 기록 실패로 거부되면 원문 없이 안내만 본다 (Priority: P3)

**Goal**: v0.10 원문 열람 감사 기록 실패(500 `INTERNAL_ERROR`) 때 F3-6·F3-5가 원문 없이 서버 문구와 다시 시도만 보이고, 다시 시도하면 원문이 보이는지 고정한다(research R6).

**Independent Test**: mock 원문 기록 실패 데모 문의로 원문 보기(F3-6)·긴급 상세(F3-5)가 원문 없이 서버 문구 + 다시 시도만 보이고, 다시 시도하면 원문이 보이는지 확인한다(quickstart 9).

### Implementation for User Story 3

- [X] T022 [US3] `lib/features/inquiry/data/mock_inquiry_store.dart`에 원문 기록 실패 데모 문의 1건(긴급 아님, 교사 `teacher@damso.test` 학급)을 더하고, `lib/features/inquiry/data/mock_teacher_inquiry_repository.dart`의 `content()`가 그 문의의 **첫** 요청만 500 `INTERNAL_ERROR` "요청을 처리하지 못했습니다. 잠시 후 다시 시도해 주세요."로 실패, 다시 시도하면 성공하게 한다. 긴급 상세 확인용으로 같은 실패를 재현할 긴급 데모 문의가 필요하면 같은 방식으로 1건 더한다

### Tests for User Story 3

- [X] T023 [P] [US3] `test/features/inquiry/content_view_model_test.dart`에 더한다: 원문 요청 500 → `AsyncError`이고 원문 없음, 화면에는 서버 `message`와 다시 시도만, 다시 시도 → 원문 표시. 이전에 받은 원문이 오류 화면에 남지 않음(FR-010)
- [X] T024 [P] [US3] `test/features/inquiry/urgent_detail_test.dart`에 더한다: 원문 요청 500 → 화면 전체가 서버 `message` + 다시 시도(원문 글자 없음), 다시 시도 → 긴급 상세 정상(spec US3-2, research R6)
- [X] T025 [US3] `test/features/mock_scenarios_test.dart`에 시연을 더한다: `teacher@damso.test` → 원문 기록 실패 데모 문의 → 원문 보기 → 서버 문구 + 다시 시도 → 다시 시도 → 원문

**Checkpoint**: 세 스토리 모두 독립적으로 동작

---

## Phase 6: Polish & Cross-Cutting Concerns

- [X] T026 [P] `docs/ia.md`: ADM-4 표기를 R2 결정(요약 4칸·학급 카드 문구·"전체", 긴급·기간 없음)으로 고치고, 관리자 하단 탭(홈 · 문의 · 마이페이지)과 `/admin/inquiries` 경로를 반영한다
- [X] T027 SC-003 점검: `lib/features/admin/presentation/inquiry_status_page.dart`·`inquiry_status_view_model.dart`에서 이메일·이름·제목·본문 필드를 참조하지 않는지, 로그 출력(`print`·`debugPrint`)이 없는지 확인(원칙 VI·VII)
- [X] T028 `flutter analyze`와 `flutter test`를 실행하고 결과(실패 포함)를 그대로 보고한다
- [X] T029 quickstart.md mock 1~11을 순서대로 확인한다(`flutter run --dart-define=USE_MOCK=true --no-enable-impeller`). 배포 서버 12·13은 슈퍼 관리자 계정이 있을 때 사용자가 확인

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: T001 먼저. T002는 사용자 확인에 따라 T001과 따로 진행 가능(코드에는 영향 없음)
- **Foundational (Phase 2)**: T001 뒤. US1을 막는다
- **US1 (Phase 3)**: Phase 2 뒤
- **US2 (Phase 4)**: Phase 2와 관계없음 — T001 뒤 바로 시작 가능(기존 코드 테스트)
- **US3 (Phase 5)**: T001 뒤 바로 시작 가능(기존 코드 + mock)
- **Polish (Phase 6)**: 원하는 스토리가 끝난 뒤

### Within User Story 1

- T009·T010·T011(테스트) 먼저 작성 → 실패 확인
- T012(ViewModel) → T013(화면) → T014(셸) → T015(라우터) → T016(홈 아이콘)
- T017(승인 필요)은 T006 뒤 언제든, T018은 T015·T017 뒤

### 같은 파일을 건드리는 작업(동시에 하지 않음)

- `lib/features/admin/data/mock_admin_repository.dart`: T006 → T017
- `test/core/router_redirect_test.dart`: T011 → T020
- `test/features/mock_scenarios_test.dart`: T018 → T025

---

## Parallel Example

```text
# Phase 2 (T003·T004 뒤)
Task: "T005 inquiryStatus 실서버 구현 in lib/features/admin/data/admin_repository_impl.dart"
Task: "T006 inquiryStatus mock 구현 in lib/features/admin/data/mock_admin_repository.dart"
Task: "T007 Repository 해석 테스트 in test/features/admin/admin_repository_impl_test.dart"
Task: "T008 mock 테스트 in test/features/admin/mock_admin_repository_test.dart"

# US1 테스트
Task: "T009 in test/features/admin/inquiry_status_view_model_test.dart"
Task: "T010 in test/features/admin/inquiry_status_page_test.dart"
Task: "T011 in test/core/router_redirect_test.dart"

# US2·US3 테스트(US1과 동시에 가능)
Task: "T019 in test/features/inquiry/stage_timeline_test.dart"
Task: "T023 in test/features/inquiry/content_view_model_test.dart"
Task: "T024 in test/features/inquiry/urgent_detail_test.dart"
```

---

## Implementation Strategy

### MVP First (User Story 1)

1. T001(`/fetch-api api-v0.10`) → 변경 요약 확인
2. T002 Figma 수정(사용자 확인)
3. Phase 2 → Phase 3
4. **멈추고 확인**: quickstart 1~8

### Incremental Delivery

1. Setup + Foundational → 계약·Repository 준비
2. US1 → 관리자 탭·현황 시연(MVP)
3. US2 → 타임라인·감사 화면 없음 고정
4. US3 → 원문 기록 실패 안내 고정
5. Polish → ia.md, analyze·test, quickstart

---

## Notes

- 사용자 승인이 필요한 작업: T002(Figma 수정), T017(F1 mock 계정 추가), T021(타임라인 코드를 고쳐야 할 때)
- 커밋은 사용자가 요청할 때만, 형식 `Feat : <요약>`
- `docs/api/openapi.yaml`은 `/fetch-api`로만 갱신
