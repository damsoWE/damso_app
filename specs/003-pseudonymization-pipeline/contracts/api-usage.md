# API 사용 계약: 화면 ↔ Repository ↔ 엔드포인트 (F3)

**원본**: 앱 사본 `docs/api/openapi.yaml`(`api-v0.4`, [research R1](../research.md#r1-api-계약-기준--앱-사본-api-v04-그대로)). 이 문서는 앱이 **어떤 엔드포인트를 어디서 쓰는지**만 정한다. 요청·응답 스키마는 원본을 따른다.

모든 경로는 교사 로그인 필요(401은 `AuthInterceptor`가 갱신·재시도). 다른 학급 문의는 서버가 403·404로 거부하고 앱은 서버 `message`만 보인다.

## inquiry(교사) — `TeacherInquiryRepository` (F2에서 확장)

| 메서드 | 엔드포인트 | 성공 | 분기할 오류 | 화면 |
|---|---|---|---|---|
| `list(page, size)` | `GET /api/v1/teacher/inquiries` | 그대로(F2) | — | F3-1, F3-4 |
| `detail(id)` | `GET /api/v1/teacher/inquiries/{id}` | 200 → `TeacherInquiryDetail` + **`retryAvailable`** | 403·404 | 일반 문의 상세(상태 고르기), F3-6 머리 |
| `content(id)` | `GET /api/v1/teacher/inquiries/{id}/content` | 200 → 원문. **열람 기록이 남는다.** 원문 확인 필요 문의는 첫 열람에 `TEACHER_CONFIRMED` | 403·404 | F3-5(긴급), **F3-6(일반)** |
| **`refinement(id)`** (신규) | `GET /api/v1/teacher/inquiries/{id}/refinement` | 200 → `InquiryRefinement`. 첫 열람에 `REFINING` → `TEACHER_CONFIRMED`. 감사 기록 대상 아님 | `REFINEMENT_NOT_READY`(409) · 403·404 | F3-2 |
| **`retryRefinement(id)`** (신규) | `POST /api/v1/teacher/inquiries/{id}/refinement/retry` | 202 → `RefinementStatus`(`RefinementRetryAccepted.refinementStatus`) | `REFINEMENT_RETRY_UNAVAILABLE`(409) · 403·404 | F3-3 → F3-3a |

- `refinement`는 상세가 `REFINED`일 때만 부른다([research R3](../research.md#r3-번역본-불러오기와-refinement_not_ready409)).
- `content`는 원문 열람 화면(F3-6)을 열 때 화면당 1회만 부른다. 일반 문의 상세 화면에서는 부르지 않는다([research R6](../research.md#r6-원문-열람f3-6--별도-경로-화면당-1회)).
- `retryRefinement`는 요청 본문이 없다. 재시도 결과는 알림이 오지 않으므로 `detail`로 확인한다(다시 확인).

## 오류 코드 (`lib/core/error/error_codes.dart` 추가)

| 상수 | 값 | 앱 동작 |
|---|---|---|
| `refinementNotReady` | `REFINEMENT_NOT_READY` | 상세 1회 다시 읽고 그 상태로 화면 고르기 + 서버 `message` |
| `refinementRetryUnavailable` | `REFINEMENT_RETRY_UNAVAILABLE` | 서버 `message` + 상세 다시 읽기(버튼 사라짐) |

## 학부모

새로 쓰는 엔드포인트 없음. `GET /api/v1/parent/inquiries/{id}`의 `timeline`이 `REFINING`·`TEACHER_CONFIRMED`를 담으며, F2 타임라인이 그대로 보인다. 학부모 응답에는 번역본·정서강도가 없다(서버 보장).

## 이번에 쓰지 않는 경로

`/answer-reviews`, `/answers`, `/close` (F4).
