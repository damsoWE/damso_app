---

description: "배포된 서버로 실연동 전환 작업 목록"
---

# Tasks: 배포된 서버로 실연동 전환

**Input**: `specs/005-real-server-integration/` 설계 문서 (plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md)

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/run-config.md, contracts/api-usage.md, quickstart.md

**Tests**: 새 기능 테스트는 만들지 않는다. 실서버 확인은 quickstart 수동 E2E + `verification.md` 기록이다(research R9). 앱 쪽 계약 불일치를 고칠 때만 그 응답 모양으로 가짜 `HttpClientAdapter` 회귀 테스트를 더한다.

**Organization**: User Story별로 묶는다. Phase 순서는 spec 우선순위(US1·US2 P1 → US3·US4·US5 P2 → US6 P3). 단, 모든 Story가 쓰는 계정·학급 데이터는 관리자 흐름으로 만들어야 하므로 Phase 2에서 먼저 만든다.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: 다른 파일이고 미완료 작업에 의존하지 않아 병렬 가능
- **[Story]**: 해당 User Story (US1~US6)
- 모든 경로는 레포 루트 기준. 시나리오 ID(`Q1-1` 등)는 `quickstart.md`

## 공통 규칙 (모든 작업에 적용)

- **실행**: 배포 서버는 `flutter run --dart-define-from-file=env/prod.json`. 기기 A = 관리자→교사, 기기 B = 학부모(quickstart "준비").
- **기록**: 시나리오를 실행할 때마다 `specs/005-real-server-integration/verification.md`의 해당 행을 `통과`/`실패`/`차단됨`으로 바꾸고 비고를 적는다(data-model §2). 이메일·비밀번호·토큰·초대 코드 값·문의 본문·실명은 적지 않는다. 역할 이름만 쓴다.
- **불일치 처리(research R10)**: 서버 응답이 앱 기대와 다르면 `verification.md`에 `M-<번호>`로 적고 원인을 정한다.
  - 원인이 **앱**이면 해당 `*_repository_impl.dart`(또는 `inquiry_json.dart`)를 `docs/api/openapi.yaml`(api-v0.6)에 맞게 고치고, 같은 응답 모양으로 그 기능의 `test/features/<기능>/` 가짜 어댑터 테스트를 더한다. 파일 머리 주석의 `api-v0.3` 표기도 그때 `api-v0.6`으로 바꾼다(R12).
  - 원인이 **서버**면 앱에서 우회하지 않는다. 사용자에게 백엔드 이슈 초안을 보여 주고 승인받은 뒤 `damsoWE/damso_server`에 올리고, 기록에 이슈 링크를 남긴다.
  - **계약에 없는 동작**(예: 인증 메일 미발송)이면 백엔드 확인 전까지 `차단됨`.
- **바꾸지 않는 것**: 화면·ViewModel·mock 구현·Repository provider·`lib/core/config/env.dart`·`.gitignore`·`docs/api/openapi.yaml` 직접 편집. 불일치 수정이 이들을 건드려야 하면 먼저 사용자에게 알린다.
- **민감정보**: 디버깅용 `print`·`debugPrint`·로그 추가 금지(원칙 VI). 응답 확인이 필요하면 모양(키·타입)만 본다.
- **테스트 데이터**: 가상의 이름·문장만 쓴다.

---

## Phase 1: Setup

**Purpose**: 기록 파일과 계약 사본 준비.

- [X] T001 `specs/005-real-server-integration/verification.md`를 만든다. 머리에 날짜·서버 주소(`https://damso.jibang.site`)·계약 태그(`api-v0.6`)·앱 커밋 해시를 적고, "시나리오 결과" 표에 quickstart의 28개 ID(Q2-1~Q2-4, Q1-1~Q1-8, Q3-1~Q3-5, Q4-1~Q4-4, Q5-1~Q5-4, Q6-1~Q6-3)를 `미실행`으로 미리 넣는다. 열은 data-model §2 "시나리오 결과 한 줄"(ID·역할·결과·비고). "계약 불일치" 표는 열(ID·화면·경로·기대(계약)·실제·원인·처리)만 두고 비운다.
- [X] T002 서버·계약 상태를 확인해 `verification.md` 머리에 적는다: `curl -s https://damso.jibang.site/actuator/health` → `{"status":"UP"}`, `gh api repos/damsoWE/damso_server/compare/api-v0.6...main --jq .ahead_by` → `0`. 0이 아니면 멈추고 사용자에게 알린다(새 태그 필요, research R1).
- [X] T003 `/fetch-api api-v0.6`으로 `docs/api/openapi.yaml`을 갱신한다. `git diff --stat docs/api/openapi.yaml`로 확인하고, 변경이 research R2 표(F4 경로·`parent/notification-settings`·`followUps`·`answers`·`threatFlagged`·`threadThreatFlagged`·ErrorCode 2개 추가)를 벗어나면 멈추고 사용자에게 알린다.
- [X] T004 `flutter analyze`와 `flutter test`를 실행해 사본 갱신 뒤 기준선이 통과하는지 확인한다. 실패하면 출력 그대로 보고한다.

---

## Phase 2: Foundational (모든 Story의 전제)

**Purpose**: 배포 서버로 실행할 수 있는 설정과, 모든 시나리오가 쓰는 계정·학급 데이터.

**⚠️ CRITICAL**: T009~T011이 끝나야 Phase 3 이후 시나리오를 실행할 수 있다.

- [X] T005 [P] `env/example.json`의 `API_BASE_URL`을 `"https://damso.jibang.site"`로 바꾼다(`USE_MOCK`은 `false` 유지). 내용은 `contracts/run-config.md` "`env/example.json`" 블록과 같아야 한다.
- [X] T006 [P] `README.md` 실행 방법(현재 20~23행 부근)을 세 가지 실행으로 고친다: 배포 서버 `cp env/example.json env/prod.json` → `flutter run --dart-define-from-file=env/prod.json`, 로컬 서버 `env/dev.json`(`http://10.0.2.2:8080`, Android 에뮬레이터), mock `--dart-define=USE_MOCK=true`. 기존 "시크릿을 넣지 않음" 문장은 유지한다.
- [X] T007 `cp env/example.json env/prod.json`로 로컬 실행 파일을 만들고 `git status --short`에 `env/prod.json`이 나타나지 않는지(무시되는지) 확인한다.
- [X] T008 Android `INTERNET` 권한 추가를 **사용자에게 승인받는다**(research R4: `src/main` 매니페스트에 없어 release 빌드가 서버에 연결하지 못함). 승인되면 `android/app/src/main/AndroidManifest.xml`의 `<manifest>` 바로 아래에 `<uses-permission android:name="android.permission.INTERNET"/>`을 추가한다. 거절되면 Q6-3을 `차단됨(권한 미승인)`으로 기록한다.
- [X] T009 사용자에게 슈퍼 관리자 계정(서버 환경변수로 만든 것, research R8)과 기기 2대 준비를 요청한다. 계정은 대화·파일에 남기지 않고 사용자가 앱에 직접 입력한다. 두 기기에서 `flutter run --dart-define-from-file=env/prod.json`으로 시작 화면이 뜨는지 확인한다.
- [X] T010 Q2-1 실행(기기 A, 관리자): 학급 1개 생성 → 학생 **3명** 등록(두 번째는 Q3-5의 두 번째 학부모용, 세 번째는 Q2-3 재발급 확인용) → 교사 초대 코드 발급 → 학생별 학부모 초대 코드 발급. 학급 상세에 학생 3명이 보이는지 확인하고 기록한다.
- [X] T011 Q2-2(기기 A, 교사 코드로 교사 가입·이메일 인증)와 Q2-4(기기 B, 첫 번째 학생의 학부모 코드로 학부모 가입)를 실행하고 기록한다. 인증 메일이 오지 않으면 `차단됨` + 불일치 `M-` 기록(계약에 없는 동작) 후 사용자에게 알린다.

**Checkpoint**: 관리자·교사·학부모 계정과 같은 학급 연결이 준비됨.

---

## Phase 3: User Story 1 - 가입·로그인·로그인 유지 (Priority: P1) 🎯 MVP

**Goal**: 배포 서버 계정으로 로그인하고, 재시작·토큰 만료에도 로그인이 유지되며, 로그아웃·세션 끊김에서 로그인 화면으로 간다.

**Independent Test**: 역할별 계정으로 로그인 → 앱 재시작 → 홈이 바로 보임, 로그아웃 → 로그인 화면(spec US1).

- [X] T012 [US1] Q1-1·Q1-2 실행(기기 B 학부모, 기기 A 교사 각각): 로그아웃 → 로그인 → 앱 완전 종료 → 재실행 시 로그인 화면 없이 홈. 기록한다.
- [X] T013 [US1] Q1-3 실행: 접근 토큰 만료 시간이 지난 뒤 목록 새로 고침 → 로그인 화면 없이 목록. 만료 시간이 길어 기다릴 수 없으면 `차단됨(만료 시간 미도래)`으로 적고 비고에 `test/core/auth_interceptor_test.dart`로 갈음한다고 남긴다.
- [X] T014 [US1] Q1-4(틀린 비밀번호 → 서버 문구만), Q1-6(로그아웃 → 로그인 화면), Q1-7(비밀번호 재설정 메일 코드 → 새 비밀번호로 로그인)을 실행하고 기록한다.
- [X] T015 [US1] Q1-5 실행: 기기 A에서 교사로 로그인한 상태에서, 같은 교사 계정으로 다른 실행(두 번째 에뮬레이터 또는 같은 기기 재설치)에서 로그아웃 → 기기 A에서 조작 시 로그인 화면으로 이동. 서버가 다른 기기 로그아웃으로 기존 갱신 토큰을 폐기하지 않는 설계면 `해당 없음`으로 적고 이유를 남긴다.
- [X] T016 [US1] Phase 3에서 기록된 원인=앱 불일치를 공통 규칙대로 고친다: `lib/features/auth/data/auth_repository_impl.dart`, `lib/features/me/data/me_repository_impl.dart`, (토큰 갱신 문제면) `lib/core/network/auth_interceptor.dart` — 회귀 테스트는 `test/features/auth/`, `test/features/me/`, `test/core/auth_interceptor_test.dart`. 불일치가 없으면 "없음"으로 기록하고 완료.

**Checkpoint**: US1 수용 시나리오 1~5 확인 완료.

---

## Phase 4: User Story 2 - 학부모 문의가 교사에게 도착 (Priority: P1)

**Goal**: 학부모가 보낸 일반·긴급 문의가 같은 학급 교사 목록에 맞는 표시로 보이고, 학부모는 처리 단계를 본다.

**Independent Test**: 학부모가 일반 1건·긴급 1건 제출 → 교사 목록에 두 건이 맞게 표시(spec US2).

- [X] T017 [US2] Q3-1 실행: 기기 B 일반 문의 제출 → 기기 A 교사 목록 새로 고침 1회 안에 보이는지(SC-002). 기록한다.
- [X] T018 [US2] Q3-2 실행: 기기 B에서 긴급 표현이 든 문의 제출(가상 문장) → 기기 A 목록 긴급 표시 → 상세에서 원문(`/content`) 표시. 기록한다.
- [X] T019 [US2] Q3-3(학부모 문의 상세의 단계·안내)과 Q3-4(1분 안에 일반 문의 2건 → 서버 제한 문구)를 실행하고 기록한다.
- [X] T020 [US2] Q3-5 실행: 두 번째 학생의 학부모 코드로 두 번째 학부모 계정을 만들고, 그 계정으로 Q3-1 문의 상세 접근 시 거부되는지 확인한다. 앱에 다른 사람 문의로 가는 경로가 없으면 사용자에게 `curl`로 확인할지 묻는다(토큰은 셸 변수로만, 출력·기록 금지). 거부 화면 표시는 기존 403 mock 테스트로 갈음한다고 비고에 남긴다.
- [X] T021 [US2] Phase 4에서 기록된 원인=앱 불일치를 고친다: `lib/features/inquiry/data/parent_inquiry_repository_impl.dart`, `lib/features/inquiry/data/teacher_inquiry_repository_impl.dart`, `lib/features/inquiry/data/inquiry_json.dart` — 회귀 테스트는 `test/features/inquiry/`. 없으면 "없음" 기록.

**Checkpoint**: US1 + US2 = MVP. 학부모 → 교사 전달이 실서버로 동작.

---

## Phase 5: User Story 3 - 교사가 정리 결과를 본다 (Priority: P2)

**Goal**: 정리 완료·정리 중·원문 확인 필요 상태가 실서버 상태 변화대로 보이고, 다시 정리하기·원문 열람이 된다.

**Independent Test**: 정리 끝난 문의 1건, 정리 중 문의 1건을 열어 각 화면 확인, "다시 확인"으로 정리 중 → 완료(spec US3).

- [X] T022 [US3] Q4-1·Q4-2 실행: 기기 A에서 Q3-1 문의 상세 → 정리 중이면 "다시 확인"·당겨서 새로 고침 → 번역본(사실관계·요청사항·정서강도)으로 바뀌는지. 정리 완료까지 걸린 대략 시간을 비고에 적는다.
- [X] T023 [US3] Q4-4 실행: 일반 문의 원문 열람 → 원문과 열람 기록 안내. 기록한다.
- [X] T024 [US3] Q4-3 실행: 목록에 "원문 확인 필요" 문의가 있으면 다시 정리하기 → 두 번째 시도 시 서버 문구·버튼 없음. 정리 실패를 일부러 만들 방법이 없으면 `차단됨`으로 적고 `test/features/mock_scenarios_test.dart`(원문 확인 필요·재시도) 통과로 갈음한다고 남긴다.
- [X] T025 [US3] Phase 5에서 기록된 원인=앱 불일치를 고친다: `lib/features/inquiry/data/teacher_inquiry_repository_impl.dart`, `lib/features/inquiry/data/inquiry_json.dart` — 회귀 테스트 `test/features/inquiry/`. 없으면 "없음" 기록.

**Checkpoint**: F3 화면 실서버 확인 완료.

---

## Phase 6: User Story 4 - 관리자 운영 (Priority: P2)

**Goal**: 학급·학생·초대 코드 운영이 실서버에서 되고, 재발급한 코드의 이전 값은 거부된다.

**Independent Test**: 학급 생성 → 학생 등록 → 코드 발급 → 그 코드로 가입 성공(spec US4). Q2-1·Q2-2·Q2-4는 Phase 2에서 이미 실행.

- [X] T026 [US4] Q2-3 실행: 기기 A 관리자로 세 번째 학생(아직 아무도 가입하지 않은 코드)의 학부모 코드 재발급 → 로그아웃 → 이전 코드로 가입 시도 시 서버 거부 문구. 기록한다.
- [X] T027 [US4] `contracts/api-usage.md` "관리자" 표의 나머지 화면을 확인한다: 학급 목록·학급 상세 학생 목록 재조회, 초대 코드 목록(`GET /api/v1/admin/invite-codes`)의 상태 표시(`UNUSED`·`USED`·`REVOKED` 등). 결과를 Q2-1 비고에 덧붙인다.
- [X] T028 [US4] Phase 2·6에서 기록된 원인=앱 불일치를 고친다: `lib/features/admin/data/admin_repository_impl.dart`, `lib/features/parent/data/parent_repository_impl.dart`, `lib/features/teacher/data/teacher_repository_impl.dart` — 회귀 테스트 `test/features/admin/`, `test/features/parent/`, `test/features/teacher/`. 없으면 "없음" 기록.

**Checkpoint**: 관리자 흐름 실서버 확인 완료.

---

## Phase 7: User Story 5 - 네트워크·서버 오류 (Priority: P2)

**Goal**: 연결 끊김·서버 거부에서 안내와 다시 시도가 보이고, 내부 오류 내용이 보이지 않는다.

**Independent Test**: 비행기 모드에서 목록 열기 → 안내 + 다시 시도, 연결 복구 후 회복(spec US5).

- [X] T029 [US5] Q5-1·Q5-2 실행: 기기 B 비행기 모드 → 학부모 홈·문의 목록, 기기 A 비행기 모드 → 교사 목록 → 15초 안에 연결 안내 + 다시 시도(SC-004) → 해제 후 다시 시도로 회복. 15초를 넘긴 화면은 화면 이름과 걸린 시간을 기록한다.
- [X] T030 [US5] Q5-3 실행: 이미 가입된 이메일로 가입 시도 등 서버가 거부할 값 → 입력란 아래 또는 화면에 서버 문구. 기록한다.
- [X] T031 [US5] Q5-4: 지금까지 본 모든 오류 화면 문구를 점검해 예외 내용·내부 코드·영문 클래스명이 섞인 것이 0건인지 기록한다(SC-005).
- [X] T032 [US5] T029~T031에서 무한 로딩·빈 화면·내부 문구 노출이 나온 화면이 있으면 사용자에게 알리고 승인받은 뒤 해당 화면의 ViewModel(`lib/features/<기능>/presentation/`)만 고친다(공통 규칙상 화면 변경은 사전 알림 대상). 회귀 테스트는 그 기능의 `test/features/<기능>/`. 없으면 "없음" 기록.

**Checkpoint**: 오류 상태 실서버 확인 완료.

---

## Phase 8: User Story 6 - 실행 설정 전환 (Priority: P3)

**Goal**: 같은 코드로 배포 서버·mock·release 실행이 모두 된다.

**Independent Test**: mock 설정과 배포 서버 설정으로 각각 실행해 둘 다 로그인 화면까지(spec US6).

- [X] T033 [P] [US6] Q6-1 실행: `flutter run --dart-define=USE_MOCK=true` → 서버 없이 로그인 화면, mock 계정으로 문의 목록까지. 기록한다.
- [X] T034 [US6] Q6-2 실행: `secrets/firebase.json` 없이 배포 서버로 교사 로그인 → 교사 홈·알림 설정 화면에 알림 관련 오류 표시 없음(FR-014, research R7). 기록한다.
- [X] T035 [US6] Q6-3 실행(T008 승인 시): `flutter run --release --dart-define-from-file=env/prod.json` → 로그인 성공. 기록한다.

**Checkpoint**: 모든 Story 확인 완료.

---

## Phase 9: Polish & 마무리

- [X] T036 Q1-8 실행(마지막): 두 번째 학부모 테스트 계정 탈퇴 → 시작 화면, 같은 계정 로그인 불가. 기록한다.
- [X] T037 `verification.md`를 정리한다: 결과 요약(통과·실패·차단됨 개수), `미실행` 행 0개, 모든 `M-` 항목에 처리 값이 있는지, 백엔드 이슈 링크. 금지 정보가 없는지 `grep -nE "@|Bearer|eyJ" specs/005-real-server-integration/verification.md` 결과 0건을 확인한다.
- [X] T038 `flutter analyze`와 `flutter test`를 실행해 통과를 확인한다(SC-006). 실패는 출력 그대로 보고한다.
- [X] T039 `git status --short`로 변경 파일이 plan "Source Code" 목록과 불일치 수정 파일뿐인지, `env/prod.json`이 추적되지 않는지 확인하고 사용자에게 결과(통과·실패·차단 요약, 변경 파일, 백엔드 이슈)를 보고한다. 커밋·PR은 사용자가 요청할 때만 한다(`Feat : …`, PR 본문 `Closes #13`).

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 Setup**: 의존 없음. T001 → T002 → T003 → T004 순서.
- **Phase 2 Foundational**: T004 이후. T005·T006 병렬, T007은 T005 뒤, T008은 독립(승인 대기 가능), T009 → T010 → T011 순서. **T011이 끝나야 Phase 3~8 시나리오 실행 가능.**
- **Phase 3 US1**: Phase 2 뒤.
- **Phase 4 US2**: Phase 2 뒤. US1과 독립이지만 같은 기기를 쓰므로 실제로는 US1 다음에 한다.
- **Phase 5 US3**: T017(Q3-1 문의)이 있어야 한다.
- **Phase 6 US4**: Phase 2 뒤. T026은 T010에서 만든 세 번째 학생 코드를 쓰므로 다른 Story와 독립.
- **Phase 7 US5**: Phase 2 뒤, 언제든.
- **Phase 8 US6**: T033은 언제든(서버 불필요). T035는 T008 뒤.
- **Phase 9**: 모든 Story 뒤. T036은 맨 마지막 시나리오.

### 불일치 수정 작업(T016·T021·T025·T028·T032)

각 Phase의 시나리오가 끝난 뒤 실행한다. 고친 뒤 해당 시나리오를 다시 실행해 기록을 `통과`로 바꾼다.

### Parallel Opportunities

- T005·T006(다른 파일)
- T033(mock 실행)은 서버·다른 기기와 무관해 어느 Phase와도 병렬
- 불일치 수정은 기능별 파일이 달라 T016·T021·T028을 병렬로 할 수 있다(T021·T025는 같은 파일이라 순서대로)

## Parallel Example: Phase 2

```text
T005 env/example.json 수정
T006 README.md 실행 방법 수정
(동시에) T008 INTERNET 권한 승인 요청
```

## Implementation Strategy

### MVP (US1 + US2)

1. Phase 1~2 완료(계약 갱신·설정·테스트 계정)
2. Phase 3(US1) → Phase 4(US2)
3. **멈추고 확인**: 학부모 → 교사 전달이 실서버로 되면 MVP 달성. 이 시점에 중간 보고 가능.

### 이후

US3 → US4 → US5 → US6 → Phase 9. 각 Phase 끝에 `verification.md`가 갱신되어 있어야 한다.

### 시간 추정

- Phase 1~2: 약 30분(메일 인증 대기 포함)
- Phase 3~8 시나리오: 약 1.5~2시간(불일치가 없을 때)
- 불일치 1건 수정 + 회귀 테스트: 건당 20~40분
