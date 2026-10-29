# Data Model: 학부모 문의 스레드·이어서 묻기·답변 알림

모든 모델은 `domain`(Flutter·dio 없음). 서버 필드는 `docs/api/openapi.yaml` api-v0.11.

## 1. ParentInquiryDetail (확장)

| 필드 | 출처 | 비고 |
|---|---|---|
| summary | 기존 | inquiryId·studentName·urgent·stage·submittedAt·hasAnswer(answers로 계산) |
| timeline · notices · hotlines | 기존 | 처음 문의의 단계·안내 |
| **content** | `content` | 처음 문의 원문(본인 글) |
| **followUps** | `followUps[]` → ParentFollowUp | 시간순 |
| **answers** | `answers[]` → ParentAnswer | 시간순 |
| **thread** (계산) | content·followUps·answers | ThreadItem 목록, §3 순서 |

필드가 없거나 형식이 틀리면 기존처럼 형식 오류 → 일반 안내(`mapDioErrors`).

## 2. ParentFollowUp · ParentAnswer (새)

- **ParentFollowUp**: inquiryId(UUID), content, urgent, stage, submittedAt, notices, hotlines. `outcome`(SubmitOutcome)으로 긴급 안내 종류·번호를 얻는다.
- **ParentAnswer**: answerId(UUID), content, sentAt. (`reviewed`는 학부모 화면에 보이지 않으므로 읽지 않는다.)

## 3. ThreadItem (새, 화면용)

```text
sealed ThreadItem
├── RootItem(content, submittedAt, urgent, stage)       # 학부모 · 처음 문의
├── AnswerItem(content, sentAt)                          # 담임 선생님
└── FollowUpItem(content, submittedAt, urgent, stage, hotlines)  # 학부모 · 재문의
```

- 순서: 각 항목의 시각(submittedAt / sentAt) 오름차순. 시각이 같으면 서버 배열 순서(처음 문의 → 재문의/답변 원래 순서) 유지.
- 답변이 하나도 없으면 스레드 끝에 "답변을 기다리고 있어요" 안내(FR-004).

## 4. FollowUpSubmitted (새)

inquiryId, threadRootId, urgent, submittedAt, notices, hotlines → `SubmitOutcome`으로 바꿔 접수 화면에 넘긴다.

## 5. 이어서 묻기 상태 (FollowUpViewModel)

```text
Editing(content) ──보내기──▶ Sending ──성공──▶ Done(FollowUpSubmitted)  → 접수 화면으로 이동
                              │
                              └─실패──▶ Editing(content, error, retryAfter?)
```

- 보내기 가능: 앞뒤 공백 뺀 길이 1~2,000(코드 포인트, 처음 문의와 같은 계산), Sending 아님, 429 대기 중 아님.
- 멱등키: `(threadRootId, trim(content))`가 직전 실패 시도와 같으면 같은 키, 다르면 새 키. Done이면 키 폐기.
- 떠나기 확인: content가 비어 있지 않고 Done이 아니면 확인 대화상자(처음 문의 작성과 같은 문구).

## 6. ThreadViewModel

`AsyncValue<ParentInquiryDetail>`. 다시 시도·당겨서 새로 고침·알림 수신 시 새로고침(FR-019). `autoDispose`.

## 7. ParentNotificationSettings (새)

| 필드 | 비고 |
|---|---|
| answerNotifyEnabled | bool, 서버 기본 true |

ParentSettingsViewModel 상태: `AsyncValue<ParentNotificationSettings>` + `saving: bool` + `error: String?`. 토글 → saving → 서버 응답 값으로 확정 / 실패 시 이전 값 + error.

## 8. PushKind · PushData (확장)

| 서버 kind | PushKind | 역할 | 경로 |
|---|---|---|---|
| URGENT · URGENT_REMINDER | urgent · urgentReminder | 교사 | `/teacher/inquiries/{id}/urgent` (id 없으면 목록) |
| GENERAL · GENERAL_DIGEST | general · generalDigest | 교사 | `/teacher/inquiries` |
| **ANSWER** | **answer** | **학부모** | `/parent/inquiries/{id}/thread` (id 없으면 `/parent/inquiries`) |
| 그 밖 | unknown | 없음 | 이동하지 않음 |

`PushData.role`(교사·학부모·없음)을 더하고, 리스너는 `로그인 역할 == PushData.role`일 때만 배너·이동한다.
