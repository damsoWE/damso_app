# API 사용 계약 (F4 교사)

앱 사본 `docs/api/openapi.yaml` **api-v0.6** 기준. 이 문서는 앱이 어떤 경로를 어떻게 부르는지만 적는다. 계약 원본은 백엔드다(앱이 새 API를 만들지 않는다).

## reply 기능 — `AnswerRepository`

| 메서드 | 요청 | 성공 | 오류 → 화면 |
|---|---|---|---|
| `review(inquiryId, content)` | `POST /api/v1/teacher/inquiries/{inquiryId}/answer-reviews` · body `{content}` | 200 `AnswerReviewResult` → `available=false`면 F4-2f, `highlights` 비면 F4-2e, 아니면 F4-2c | 400 `INVALID_INPUT` → 입력칸 아래 안내 · 401 → 인터셉터 갱신 · 403/404 → 서버 `message` · 네트워크 → **F4-2f**(점검 실패와 같게, 전송은 막지 않음) |
| `send(inquiryId, content, reviewed)` | `POST …/{inquiryId}/answers` · body `{content, reviewed}` | 201 `AnswerSent` → 스레드로 `replace` | 400 → 입력칸 아래 안내 · 409 `THREAD_CLOSED` → 서버 `message`, 다시 보내기 숨김 · 403/404 → 서버 `message` · 네트워크 → F4-2h + "보내졌을 수 있어요" 안내 |

- `inquiryId`는 항상 **스레드 루트 ID**(research R4).
- `reviewed` = 이 작성 화면에서 점검을 요청한 적이 있는지.
- 멱등키 없음 → 자동 재전송 금지(research R8).
- 본문·점검 결과는 로그에 남기지 않는다. dio 로깅 인터셉터를 추가하지 않는다(원칙 VI).

## inquiry 기능 — 기존 `TeacherInquiryRepository` (메서드 추가 없음)

| 메서드 | 이번 변경 |
|---|---|
| `detail(inquiryId)` | 응답의 `followUps`·`answers` 해석 추가(`InquiryJson.teacherDetail`) |
| `refinement(inquiryId)` | 그대로. 스레드(루트·재문의 요청사항)와 재문의 상세(재문의 ID, 사실관계·요청사항·정서강도)에서 쓴다. 409 `REFINEMENT_NOT_READY` → 정리 결과 없음 |
| `content(inquiryId)` | 그대로. F3-6에서만 부른다(루트 또는 재문의 ID, "원문 보기"를 누를 때만). 스레드·재문의 상세·작성 화면에서는 부르지 않는다. 일반 재문의 열람 허용 여부는 백엔드 확인 중(research R13) — 거부되면 서버 `message` |

## teacher 기능 — 기존 `TeacherRepository`

| 메서드 | 이번 사용 |
|---|---|
| `getProfile()` | 스레드 답변 카드의 "<표시 이름> 선생님". 실패해도 화면은 열고 "선생님"만 표시 |

## 쓰지 않는 경로

- `POST …/{inquiryId}/close` — spec FR-017(닫기 없음).
- `POST /api/v1/parent/inquiries/{id}/follow-ups`, `GET/PUT /api/v1/parent/notification-settings` — 학부모 화면(범위 밖).
