# Data Model: 교사 답변 작성·점검·전송 화면 (F4 교사)

**Spec**: [spec.md](./spec.md) · **Research**: [research.md](./research.md)

모든 모델은 화면이 열려 있는 동안 메모리에만 둔다. 기기 저장·로그 출력 없음(원칙 III·VI). ID는 UUID 문자열.

## 1. `inquiry` 기능 변경 (`lib/features/inquiry/domain/models.dart`)

### TeacherInquiryDetail (수정)

| 필드 | 타입 | 변경 | 출처(API) |
|---|---|---|---|
| summary | TeacherInquirySummary | 그대로 | — |
| timeline | List<StageEvent> | 그대로 | `timeline` |
| retryAvailable | bool | 그대로 | `retryAvailable` |
| **followUps** | List<TeacherFollowUp> | 신규 | `followUps` (시간순) |
| **answers** | List<SentAnswer> | 신규 | `answers` (시간순) |

- 파생: `hasAnswers => answers.isNotEmpty`(문의 열기 R3). (`isClosed`는 api-v0.8에서 종료가 생기지 않아 두지 않는다, FR-019 삭제.)
- `threatFlagged`(spec 005)는 이번에 읽지 않는다.

### TeacherFollowUp (신규) — `TeacherFollowUpView`

| 필드 | 타입 | 규칙 |
|---|---|---|
| inquiryId | String | 재문의 자신의 ID |
| urgent | bool | 긴급 재문의 |
| title | String | 서버 제목 |
| stage | InquiryStage | 모르는 값은 `FormatException`(F2 규칙) |
| submittedAt | DateTime | 정렬·답변 여부 판단 |

본문은 없다(교사 API 규칙).

### SentAnswer (신규) — `AnswerView`

| 필드 | 타입 | 규칙 |
|---|---|---|
| answerId | String | |
| content | String | 교사 자신이 쓴 본문. 일반 `Text`로만 표시 |
| reviewed | bool | 점검을 요청했는지. 화면에 "안전 확인됨"으로 쓰지 않음(spec FR-014·FR-015b) |
| sentAt | DateTime | |

### ErrorCodes (수정, `lib/core/error/error_codes.dart`)

- `threadClosed = 'THREAD_CLOSED'` 추가. (`INQUIRY_NOT_READY_TO_CLOSE`는 종료 API를 쓰지 않아 추가하지 않는다.)

## 2. `reply` 기능 (`lib/features/reply/domain/`)

### Highlight — 서버 `Highlight`

| 필드 | 타입 | 화면 |
|---|---|---|
| excerpt | String | 바꾸기 대상(본문에서 찾을 문장) |
| reason | String | 카드 제목 아래 이유 |
| suggestion | String | "고쳐 쓴 문장" 상자 |

### AnswerReview — 서버 `AnswerReviewResult`

| 필드 | 타입 | 규칙 |
|---|---|---|
| available | bool | false면 F4-2f. highlights는 무시 |
| highlights | List<Highlight> | 비면 F4-2e |

### AnswerSent — 서버 `AnswerSent`

`answerId`, `inquiryId`, `sentAt`.

### AnswerTarget (화면 간 전달값, 라우터 `extra`)

| 필드 | 타입 | 규칙 |
|---|---|---|
| inquiryId | String | **스레드 루트 ID**(R4). 점검·전송 경로에 쓴다 |
| studentName | String | "<학생 이름> 학부모에게" |
| title | String | 문의 제목 |
| requests | String? | 정리된 요청사항(재문의에서 왔으면 그 재문의 것). 번역본이 없으면 null → 요청사항 상자 숨김 |
| fromThread | bool | 스레드(재문의 상세 경유)에서 왔는지. 전송 성공 시 true면 스레드까지 `pop`, false면 `/thread`로 `replace`(research R14) |

URL에는 `inquiryId`만 들어간다. 이름·제목·요청사항은 `extra`로만 넘긴다(F2 규칙). 작성 ViewModel의 family 키는 `inquiryId` 문자열이고 `AnswerTarget`은 `init`으로 넘긴다(R14).

### FollowUpArgs (스레드 → 재문의 상세, 라우터 `extra`)

| 필드 | 타입 | 규칙 |
|---|---|---|
| rootId | String | 스레드 루트 ID(답변 전송 대상) |
| studentName | String | 머리 줄 |
| rootTitle | String | 제목 "`{rootTitle} - 재문의`" |
| followUp | TeacherFollowUp | 재문의 항목(ID·긴급·접수 시각) |

### AnswerRepository (인터페이스)

| 메서드 | 반환 | 엔드포인트 |
|---|---|---|
| `review(inquiryId, content)` | Future<AnswerReview> | `POST /api/v1/teacher/inquiries/{id}/answer-reviews` |
| `send(inquiryId, content, {required reviewed})` | Future<AnswerSent> | `POST /api/v1/teacher/inquiries/{id}/answers` |

## 3. 작성 화면 상태 (`AnswerComposeViewModel`, research R6)

```
Editing(text)
  └ 답변 점검 ─→ Reviewing ─┬→ Reviewed(highlights, applied)   F4-2c / F4-2c-1 / F4-2e
                            └→ ReviewFailed                    F4-2f
Reviewed / ReviewFailed
  ├ 바꾸기·되돌리기 ─→ Reviewed(applied 갱신)                    F4-2c ↔ F4-2c-1
  ├ 답변 수정(본문 변경) ─→ EditedAfterReview                    F4-2d
  ├ 다시 점검 ─→ Reviewing
  └ 직접 전송 ─→ Sending                                        F4-2g
EditedAfterReview ─┬ 다시 점검 ─→ Reviewing
                   └ 수정한 답변 직접 전송 ─→ Sending
Sending ─┬→ 성공: 스레드로 replace
         └→ SendFailed(message, canResend)                     F4-2h
SendFailed ─┬ 다시 보내기 ─→ Sending   (canResend=false면 숨김: THREAD_CLOSED)
            └ 답변 수정 ─→ EditedAfterReview
```

공통 값: `text`(현재 본문), `reviewRequested`(전송 때 `reviewed`), `message`(한 번 보여 줄 안내).
`applied`: 카드 번호 → (원래 문장, 바꾼 문장). 본문이 바뀌면 비운다.

## 4. 스레드 (`ThreadViewModel`, research R5)

```
ThreadState
  title, studentName, teacherName(String?)
  entries: List<ThreadEntry>  // 시간순
ThreadEntry =
  | ParentCard(inquiryId, isFollowUp, urgent, requests?, submittedAt, unanswered, TeacherFollowUp? followUp)
  | AnswerCard(content, sentAt)
```

- 정렬: 루트 문의 → 답변·재문의를 시간순으로 섞음.
- `unanswered`: 재문의이고 마지막 답변보다 늦게 접수됨(R4) → "재문의 받음 · 눌러서 확인" 표시.
- 최초 문의 카드: 요청사항(있을 때) + "원문 보기" 버튼(→ 루트 F3-6). 재문의 카드: 요청사항(있을 때), 카드 전체를 눌러 재문의 상세(§6). 원문은 이 화면에서 부르지 않는다(spec FR-015a).
- 하단 버튼: "문의 목록으로" 하나(spec FR-017).

## 6. 재문의 상세 (`FollowUpDetailViewModel`, research R13)

```
FollowUpDetail =
  | Refined(refinement)        // 번역본 있음 → RefinementView
  | NotRefined                 // 409 REFINEMENT_NOT_READY → "아직 정리되지 않았어요"
  | Urgent                     // followUp.urgent → 긴급 안내(번역본 요청 안 함)
```

- 공통: 제목 `"{rootTitle} - 재문의"`, 머리 줄 `"{studentName} 학부모 · {M/d HH:mm} 접수"`, 원문 열람 기록 안내, 하단 "원문 보기"·"답변 작성".
- 원문은 "원문 보기"를 누를 때만 F3-6에서 연다(재문의 ID, 제목 그대로).

## 5. 고정 문구 (`lib/features/reply/domain/answer_text.dart`, Figma 2026-10-27)

| 키 | 문구 | 화면 |
|---|---|---|
| composeTitle | 답변 작성 | F4-2a·2a-2 앱바 |
| recipient | `{학생 이름} 학부모에게` | F4-2a |
| requestsLabel | 요청사항 | F4-2a·2d |
| answerLabel / writtenLabel | 답변 / 작성한 답변 | 입력칸 제목 |
| placeholder | 학부모에게 보낼 답변을 작성해 주세요. | F4-2a |
| notSentHint | 작성한 답변은 직접 전송하기 전까지 전달되지 않아요. | F4-2a·2a-2 |
| reviewButton | 답변 점검 | F4-2a·2a-2 |
| reviewingTitle | 답변 점검 | F4-2b 앱바 |
| reviewingGuide | 표현과 요청사항에 빠진 부분이 있는지 확인해요. | F4-2b |
| reviewingNotice | 답변을 점검하고 있어요. 작성한 내용은 그대로 유지돼요. | F4-2b |
| reviewingButton | 점검 중… | F4-2b |
| resultTitle | 점검 결과 | F4-2c·2c-1·2e |
| suggestionCount | `확인할 제안 {n}개` | F4-2c |
| appliedCount | `제안 {n}개 적용함` | F4-2c-1 |
| suggestionTitle | `제안 {n}` / `제안 {n} · 바꿈` | 카드 |
| rewrittenLabel / appliedLabel | 고쳐 쓴 문장 / 바꾼 문장 | 카드 |
| applyButton / undoButton | 바꾸기 / 되돌리기 | 카드 |
| resultHint | 바꿔도 바로 전송되지 않아요. 전송은 선생님이 직접 해요. | F4-2c |
| appliedHint | 바뀐 답변을 한 번 더 확인하고 직접 전송해 주세요. | F4-2c-1 |
| noSuggestionBadge | 점검 완료 | F4-2e |
| noSuggestion | 추가로 제안할 내용이 없어요. 보내기 전에 한 번 더 확인해 주세요. | F4-2e |
| reviewFailed | 지금은 답변을 점검할 수 없어요. 작성한 내용은 그대로 남아 있어요. | F4-2f |
| reviewFailedGuide | 다시 점검하거나, 내용을 직접 확인한 후 전송할 수 있어요. | F4-2f |
| editTitle | 답변 수정 | F4-2d |
| editedLabel | 직접 수정한 답변 | F4-2d |
| editedNotice | 답변이 수정됐어요. 바뀐 내용을 다시 점검할 수 있어요. | F4-2d |
| editButton / recheckButton | 답변 수정 / 다시 점검 | 여러 화면 |
| sendButton | 직접 전송 | F4-2c·2c-1·2e |
| sendEditedButton | 수정한 답변 직접 전송 | F4-2d |
| sendAfterCheckButton | 직접 확인 후 전송 | F4-2f |
| sendingTitle | 답변 전송 | F4-2g·2h 앱바 |
| sendingHeading / sendingGuide | 답변을 보내고 있어요 / 전송이 끝날 때까지 잠시 기다려 주세요. | F4-2g |
| recipientLabel | 받는 분 · `{학생 이름} 학부모 · {제목}` | F4-2g |
| sendOnceNotice | 버튼을 다시 누르지 않아도 돼요. 답변은 한 번만 보내져요. | F4-2g |
| sendingButton | 전송 중… | F4-2g |
| sendFailedHeading / sendFailedGuide | 답변을 보내지 못했어요 / 작성한 답변은 그대로 남아 있어요. | F4-2h |
| unsentLabel | 보내지 못한 답변 | F4-2h |
| sendFailedHint | 연결 상태를 확인하고 다시 보내 주세요. | F4-2h |
| resendButton | 다시 보내기 | F4-2h |
| maybeSentHint | 보내졌을 수 있어요. 스레드에서 먼저 확인해 주세요. | F4-2h(응답 없음, R8) — 앱 추가 문구 |
| parentCardTitle | `{학생 이름} 학부모 · 요청사항` / `… · 재문의` | F4-3 |
| answerCardTitle | `{표시 이름} 선생님 · 직접 전송` (이름 없으면 `선생님 · 직접 전송`) | F4-3 |
| sentAt | `{M/d HH:mm} · 전송 완료` | F4-3 |
| followUpHint | `{M/d HH:mm} · 재문의 받음 · 눌러서 확인` | F4-3(답하지 않은 재문의) |
| viewOriginalButton | 원문 보기 | F4-3 최초 문의 카드, 재문의 상세 |
| followUpTitle | `{문의 제목} - 재문의` | 재문의 상세·재문의 원문 열람 제목 |
| followUpHeader | `{학생 이름} 학부모 · {M/d HH:mm} 접수` | 재문의 상세 머리 줄 |
| followUpNotRefined | 아직 정리되지 않았어요. 원문 보기로 내용을 확인할 수 있어요. | 재문의 상세(정리 안 됨) — 앱 추가 문구 |
| discardConfirm | 작성한 내용이 사라집니다. 나갈까요? | 작성 화면 뒤로 가기(F2 문구와 같음) |
| sessionExpiredDraftLost | 로그인이 만료되어 작성 중인 답변이 저장되지 않았어요. | 세션 만료(R15) — 앱 추가 문구 |
| sentNotice | 답변을 보냈어요. 문의와 답변은 기록으로 보관돼요. | F4-3 |
| answeredTag | 답변 완료 | F4-3 태그 |
| toListButton | 문의 목록으로 | F4-3 |
| writeAnswerButton | 답변 작성 | F3-2·F3-3·F3-5·F3-6 하단 |
