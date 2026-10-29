# Research: 교사 답변 작성·점검·전송 화면 (F4 교사)

**Spec**: [spec.md](./spec.md) · **Date**: 2026-10-27

## R1. API 계약 기준 — 앱 사본 api-v0.6

- **Decision**: 앱 사본 `docs/api/openapi.yaml`(api-v0.6, 0.6.0, 커밋 `1d1d388`)을 기준으로 한다. 쓰는 경로: `GET /api/v1/teacher/inquiries/{id}`(상세: `answers`·`followUps` 추가), `GET …/{id}/refinement`, `POST …/{id}/answer-reviews`, `POST …/{id}/answers`. `POST …/{id}/close`는 쓰지 않는다(spec FR-017).
- **Rationale**: Contract-first(constitution). spec 작성 때 기준이던 백엔드 로컬 0.5.0과 F4 부분은 같고, 태그가 있는 0.6.0이 앱 사본에 들어왔다.
- **Alternatives**: 백엔드 로컬 파일 직접 참조 — 사본이 생겨 불필요.

## R2. 기능 위치 — 새 기능 `lib/features/reply/` + `inquiry` 확장

- **Decision**: 답변 작성·점검·전송(F4-2a~F4-2h)과 스레드(F4-3)는 새 기능 `lib/features/reply/`(domain·data·presentation)에 둔다. 문의 상세 응답에 붙는 재문의·답변 목록(`TeacherInquiryDetail.followUps`·`answers`)은 상세를 해석하는 `inquiry` 기능에서 확장한다. `reply` presentation은 `inquiry`의 상세·번역본 Repository를 읽는다(기존에도 `inquiry → parent/domain` 같은 기능 간 참조가 있다).
- **Rationale**: 사용자가 `lib/features/reply/`에서 개발하기로 했다. 답변은 전송·점검이라는 별도 동작(쓰기)이 있고, 상세 조회(읽기)는 F2·F3가 이미 `inquiry`에 갖고 있어 두 곳에 중복하지 않는다.
- **Alternatives**: (a) 모두 `inquiry/presentation/teacher/`에 추가(F3 방식) — `inquiry`가 계속 커지고 사용자 작업 범위와 다름. (b) `reply`가 상세 조회까지 따로 구현 — JSON 해석·mock이 둘로 갈라짐.

## R3. 목록에서 누를 때 "답변한 문의는 스레드로" — 여는 경로 하나 추가

- **Decision**: 새 경로 `/teacher/inquiries/:inquiryId`(문의 열기)를 둔다. 상세를 한 번 읽어 `answers`가 1건 이상이면 스레드(`/thread`), 아니면 긴급은 `/urgent`, 일반은 `/general`로 `replace`한다. `TeacherInquiryTile.pathOf`는 이 경로를 가리킨다.
- **Rationale**: 목록 항목(`TeacherInquirySummary`)에 답변 여부가 없고, 답변을 보내도 단계는 `TEACHER_CONFIRMED`에 머문다(`ANSWERED`는 종료 때만). 긴급 상세(F3-5)는 열자마자 원문을 불러와 열람 기록을 남기므로, 거기서 다시 돌려보내면 불필요한 열람 기록이 생긴다. 판단을 앞에서 한 번 하면 F3 화면을 바꾸지 않는다.
- **Alternatives**: (a) F3 상세 ViewModel이 상세를 읽고 스레드로 보냄 — 긴급은 원문 열람이 먼저 일어남. (b) 백엔드에 목록 항목 `answered` 필드 요청 — 지금 계약에 없음, 리스크 표에 남김.
- **비용**: 열기 때 상세 1회 + 이동한 화면에서 상세 1회. 교사 화면 응답 기준(SC)에는 영향이 작다.
- **백엔드 필드가 생기면**: 목록 항목에 답변 여부(예: `answered`)를 백엔드에 요청했다(2026-10-27, damso_server PR #19 논의). 태그로 나오면 문의 열기 화면(T038)·테스트(T032)를 없애고 `TeacherInquiryTile.pathOf`가 `answered`·`urgent`로 바로 고른다.

## R4. 답변은 스레드 루트로 보낸다

- **Decision**: 점검·전송은 언제나 **최초 문의(스레드 루트) ID**로 보낸다. 재문의 카드에서 들어와도 경로 ID는 루트이고, 화면 머리의 요청사항만 그 재문의 것을 보인다.
- **Rationale**: 백엔드 data-model: `answer.thread_root_id = 루트 inquiry.id`, 소유권·종료 검사도 루트 기준. 재문의 ID로 보냈을 때의 동작은 계약에 적혀 있지 않다.
- **"답하지 않은 재문의"**: 마지막 답변 `sentAt`보다 늦게 접수된(`submittedAt`) 재문의. 이런 카드에 "재문의 받음 · 눌러서 확인" 표시를 붙인다. 모든 재문의 카드는 눌러서 재문의 상세(R13)로 간다(spec FR-002c).
- **확인 필요**: 재문의 ID로 전송했을 때의 서버 동작은 백엔드에 확인을 남긴다(앱은 쓰지 않으므로 막지 않는다).

## R5. 스레드 내용 — 상세 + 번역본(요청사항) + 교사 표시 이름

- **Decision**: 스레드 ViewModel은 병렬로 (1) 루트 상세, (2) 루트 번역본(`refinementStatus == REFINED`일 때만), (3) 재문의마다 번역본(긴급이 아니면 요청, `409 REFINEMENT_NOT_READY`는 "요청사항 없음"으로), (4) 교사 공개 프로필 표시 이름(`teacher` 기능 `TeacherRepository.getProfile`, 실패하면 "선생님"만)을 불러온다. 원문은 부르지 않는다(spec FR-015a).
- **Rationale**: Figma F4-3 카드는 학부모 카드에 요청사항, 답변 카드에 "<표시 이름> 선생님"을 보인다. 재문의 항목(`TeacherFollowUpView`)에는 정리 상태가 없어 번역본 요청 결과로 판단한다.
- **부수 효과**: 번역본 첫 열람은 그 문의를 "교사 확인"으로 바꾼다(백엔드 F3 FR-025). 교사가 스레드에서 요청사항을 보는 것이 곧 확인이므로 의도와 맞다. 원문 열람 기록은 남지 않는다.
- **Alternatives**: 제목만 표시 — Figma와 다름(Clarifications).

## R6. 작성 화면 상태 기계

- **Decision**: `AnswerComposeViewModel` 하나가 F4-2a~F4-2h를 상태로 고른다.

| 상태 | 화면 | 들어오는 조건 |
|---|---|---|
| `Editing` | F4-2a(빈칸) / F4-2a-2(입력) | 처음 |
| `Reviewing` | F4-2b | "답변 점검" |
| `Reviewed(highlights, applied)` | F4-2c / F4-2c-1 / F4-2e | `available=true` |
| `ReviewFailed` | F4-2f | `available=false` 또는 점검 요청 오류 |
| `EditedAfterReview` | F4-2d | 점검 뒤 "답변 수정"으로 본문을 고침 |
| `Sending` | F4-2g | "직접 전송"류 버튼 |
| `SendFailed` | F4-2h | 전송 오류(종료·권한 오류는 안내 후 같은 화면) |

- 입력 직후(`Editing`)에는 전송 버튼이 없다(Clarifications Q1). `reviewed` 값은 "이 화면에서 점검을 요청한 적이 있는지"로 보낸다(서버 의미 그대로).
- 점검 결과는 그 결과를 받은 본문에만 유효하다. 본문을 고치면 `EditedAfterReview`로 가고 이전 결과는 보이지 않는다(spec FR-007).
- 점검 요청 중에 본문은 잠긴다(Figma F4-2b "작성한 내용은 그대로 유지돼요"). 그래서 "점검 중 수정" 경합이 생기지 않는다.

## R7. 바꾸기·되돌리기

- **Decision**: "바꾸기"는 현재 본문에서 `excerpt`가 처음 나오는 곳 하나를 `suggestion`으로 바꾸고, 되돌릴 수 있게 (바꾼 위치·원래 문장)을 기억한다. `excerpt`가 본문에 없으면 그 카드의 "바꾸기"를 비활성화한다. 카드 제목은 "제안 N", 적용한 카드는 "제안 N · 바꿈"·"바꾼 문장"·"되돌리기"(Figma F4-2c-1, Clarifications Q2). 상단 배지는 "확인할 제안 N개" / "제안 N개 적용함".
- **Rationale**: 교사의 명시적 동작으로만 바뀐다(원칙 V). 서버 값의 따옴표(`“…”`)는 화면에서만 붙인다.
- **Alternatives**: 모든 제안 일괄 적용 버튼 — Figma에 없고 원칙 V 취지에 어긋남.

## R8. 전송 한 번만 · 오류 분기

- **Decision**: 전송 중에는 버튼을 막고, ViewModel이 `ref.keepAlive()`로 화면을 떠나도 응답 처리를 마친다(F1·F2 방식). 오류 분기:

| 응답 | 화면 |
|---|---|
| 201 | 스레드(`/thread`)로 `replace` |
| 409 `THREAD_CLOSED` | 서버 `message` 안내, 작성 내용 유지, 다시 보내기 숨김 |
| 403·404 | 서버 `message`(존재 여부를 드러내지 않음), 작성 내용 유지 |
| 400 `INVALID_INPUT` | `fieldErrors['content']` 또는 `message`를 입력칸 아래에 |
| 네트워크 오류·시간 초과 | F4-2h. "스레드에서 보내졌는지 먼저 확인" 안내를 함께(전송 API에 멱등키가 없어 응답 전에 끊기면 이미 저장됐을 수 있다) |

- **Rationale**: 전송 API는 멱등키를 받지 않는다(계약). 자동 재전송은 하지 않는다.

## R9. 화면을 떠날 때

- **Decision**: 본문이 비어 있지 않으면 뒤로 가기 때 확인을 받는다(F2 `discardConfirm` 문구 재사용 가능). 본문·점검 결과는 ViewModel 메모리에만 두고 `autoDispose`로 지운다(spec FR-003·FR-007, 원칙 III·VI). 갱신 거부로 로그인 화면에 가면 작성 내용은 사라진다(spec Edge Case).

## R10. 진입 버튼 — F3 화면 4곳에 "답변 작성"

- **Decision**: F3-2(정리본)·F3-3(원문 확인 필요)·F3-6(원문 열람)·F3-5(긴급 상세)·재문의 상세(R13) 하단에 "답변 작성" 버튼을 더한다. 재문의에서 들어온 원문 열람(F3-6)도 같은 버튼을 두고, 이때 `AnswerTarget.requests`는 그 재문의의 요청사항이다. F3-3a·정리 중에는 두지 않는다. 상세 단계가 `ANSWERED`(서버 기준 종료)면 두지 않는다. 버튼은 `/teacher/inquiries/:id/answer`로 `push`하며 `extra`로 머리 정보(학생 이름·제목·요청사항)를 넘긴다.
- **Rationale**: F3 spec FR-023, F2 spec(F3-5 답변 작성은 F4). F3 화면은 이 목적으로 하단 버튼 줄을 비워 두었다.

## R11. mock

- **Decision**: 기존 `MockInquiryStore`에 답변 목록·재문의 목록을 더하고(종료 여부는 api-v0.8에 따라 2026-10-28 제거), `reply`의 `MockAnswerRepository`가 같은 저장소를 쓴다(학부모·교사 mock이 저장소를 공유하는 F2 방식). 데모:

| 데모 | 재현 |
|---|---|
| 답변 본문에 "큰 문제는 아니" 포함 | 점검 결과 제안 2개(F4-2c, Figma 예시) |
| "점검실패" 포함 | `available=false`(F4-2f) |
| 그 밖의 본문 | 제안 없음(F4-2e) |
| "전송실패" 포함 | 네트워크 오류(F4-2h) |
| 답변 + 답하지 않은 재문의가 있는 데모 문의 | 목록에서 스레드로, 재문의 카드 → F4-2a |
| 기존 403 데모 카드·`noclass` 계정 | 권한 없음 |
| 기존 갱신 데모 계정 | 401 → 갱신 → 재시도 |

- **Rationale**: spec FR-027. 실서버 점검은 현재 항상 `available=false`일 수 있어(계약 설명) 제안 화면은 mock으로만 확인된다.

## R13. 재문의 상세 — F3-2 구성, 재문의 ID로 조회

- **Decision**: 새 경로 `/teacher/inquiries/:inquiryId/follow-ups/:followUpId`에 `FollowUpDetailPage`(reply 기능)를 둔다. 화면 구성은 F3-2(Figma "F4-3b 재문의 상세", node 323-1843): 제목 "<문의 제목> - 재문의", 머리 줄 "<학생 이름> 학부모 · <접수 시각> 접수", 정리된 경우 F3의 `RefinementView`(사실관계·요청사항·정서강도) 재사용, 원문 열람 기록 안내, 하단 "원문 보기"(Secondary)·"답변 작성"(Primary).
  - 데이터: 재문의 자신의 ID로 `refinement(followUpId)`를 부른다. 409 `REFINEMENT_NOT_READY`면 정리 결과 없이 "아직 정리되지 않았어요" 안내(정리 중과 원문 확인 필요를 구분할 정보가 재문의 항목에 없다). 긴급 재문의(`urgent`)는 번역본을 부르지 않고 F3-5의 긴급 안내 문구를 보인다. 원문은 부르지 않는다.
  - 학생 이름·문의 제목·재문의 항목은 스레드가 `extra`(`FollowUpArgs { rootId, studentName, rootTitle, TeacherFollowUp followUp }`)로 넘긴다. 없으면(앱 재시작·딥링크) 스레드로 redirect.
  - "원문 보기" → `/teacher/inquiries/:followUpId/content`, `extra`로 제목 "<문의 제목> - 재문의"와 머리 줄 정보를 넘긴다(F3-6 `ContentPage`의 `summary`). F3-6의 "답변 작성"은 `AnswerTarget(inquiryId: rootId, …, requests: 재문의 요청사항)`.
  - "답변 작성" → `/teacher/inquiries/:rootId/answer`, `AnswerTarget(inquiryId: rootId, studentName, title: rootTitle, requests: 재문의 요청사항, fromThread: true)`.
- **Rationale**: 사용자 결정(2026-10-27). 교사가 재문의 내용을 정리본·원문으로 확인한 뒤 답하게 한다.
- **Alternatives**: 스레드 카드에서 바로 F4-2a — 재문의 내용을 보기 전에 답하게 되어 기각. F3 `GeneralDetailPage`를 재문의 ID로 그대로 열기 — 재문의 상세 조회(`GET …/{followUpId}`) 동작이 계약에 없고 제목·머리 줄 형식이 달라 기각.
- **확인 필요(백엔드)**: 일반 재문의의 `/content` 열람 허용 여부(`TeacherFollowUpView` 설명과 `/content` 설명이 다름). 거부되면 서버 안내 문구를 보인다.

## R14. 작성 화면 ViewModel 키와 전송 뒤 이동 (analyze U1·I1)

- **Decision**: `AnswerComposeViewModel`의 family 키는 **`String`(스레드 루트 ID)**이다. 머리 정보(`AnswerTarget`)는 화면이 처음 한 번 `init(target)`으로 넘긴다. `AnswerTarget`에 `fromThread`(bool)를 둔다. 전송 성공 시 `fromThread`면 `pop`(스택 위의 화면들을 스레드까지 되돌리고 스레드가 다시 읽음), 아니면 `/thread`로 `replace`.
- **Rationale**: 객체 키는 같은지 비교 규칙이 없으면 다시 그릴 때마다 새 ViewModel이 생겨 작성 중 본문이 사라진다. 스레드에서 들어왔는데 `replace`하면 스레드가 두 겹이 된다.
- **구현 메모**: 스레드 → 재문의 상세 → (원문) → 작성 순으로 쌓이므로, 성공 시 `context.go`가 아니라 `Navigator.popUntil`(스레드 경로) 또는 스레드로 돌아갈 때까지 pop. 탭 셸 위 루트 Navigator라 경로 이름으로 판별한다.

## R15. 세션 만료 때 작성 내용 손실 안내 (analyze G1)

- **Decision**: 작성 화면이 `sessionControllerProvider`를 듣다가 `SignedOut(sessionExpired: true)`가 되고 본문이 비어 있지 않으면, 이동 전에 스낵바 "로그인이 만료되어 작성 중인 답변이 저장되지 않았어요."를 띄운다(루트 `ScaffoldMessenger`). 본문은 저장하지 않는다(원칙 III·VI).

## R12. 테스트

- **Decision**: (1) Repository 실서버 구현 — 가짜 `HttpClientAdapter`로 경로·본문(`content`·`reviewed`)·응답 해석·오류 코드(F2·F3와 같은 방식). (2) `inquiry_json` — `answers`·`followUps` 해석. (3) `AnswerComposeViewModel` — 상태 전이 전부, 바꾸기·되돌리기, 수정 후 결과 무효, 전송 한 번, 오류 분기. (4) 스레드 ViewModel — 카드 순서, 번역본 409 처리, 프로필 실패 대체, 답하지 않은 재문의 판정. (5) 문의 열기 — 답변 유무·긴급별 이동. (6) 라우터 redirect — 새 경로 3개 교사 전용. (7) 위젯 흐름 — 입력 → 점검 → 바꾸기 → 직접 전송 → 스레드, "문의 목록으로"만 있음, 로그·`print` 없음. (8) 재문의 상세 — 정리됨·정리 안 됨(409)·긴급, 원문 보기 → F3-6 제목 "… - 재문의", 답변 작성 → F4-2a → 전송 뒤 스레드로 pop(스레드 한 겹), `content` 호출은 원문 보기를 누를 때만.
