# Research: 가명화·정제 파이프라인 화면 (F3)

**Feature**: [spec.md](./spec.md) · **Plan**: [plan.md](./plan.md) · **Date**: 2026-10-27

Technical Context에 미해결(NEEDS CLARIFICATION) 항목은 없다. 아래는 설계 중 정한 것들이다.

## R1. API 계약 기준 — 앱 사본 `api-v0.4` 그대로

- **Decision**: 앱 사본 `docs/api/openapi.yaml`(`info.version: 0.4.0`, 태그 `api-v0.4`)을 그대로 기준으로 삼는다. F3에 필요한 것이 모두 들어 있다: `TeacherInquiryDetail.refinementStatus`·`retryAvailable`, `GET /teacher/inquiries/{id}/refinement`(`InquiryRefinement`), `POST /teacher/inquiries/{id}/refinement/retry`(202 `RefinementRetryAccepted`), `GET /teacher/inquiries/{id}/content`, 오류 코드 `REFINEMENT_NOT_READY`·`REFINEMENT_RETRY_UNAVAILABLE`.
- **Rationale**: 백엔드 원격 태그 중 최신이 `api-v0.4`이고, 백엔드 `features.md` 상태 표에서 F3가 "구현 완료"다. F2 때와 달리 태그 전 원본을 볼 필요가 없다.
- **Alternatives**: 백엔드 `main`의 원본을 직접 보기 — 태그가 있으므로 필요 없다. 새 태그가 공지되면 `/fetch-api`로 받고 [contracts/api-usage.md](./contracts/api-usage.md)와 비교한다.

## R2. 일반 문의 상세 화면 하나에 상태 넷 — `GeneralDetailPage`

- **Decision**: 일반 문의는 경로 하나(`/teacher/inquiries/:inquiryId/general`)와 ViewModel 하나로 연다. ViewModel이 서버 상세(`refinementStatus`·`retryAvailable`)를 보고 상태를 고른다.

  | 서버 상태 | 화면 상태 | Figma |
  |---|---|---|
  | `REFINED` | 정리본(번역본 함께 불러옴) | F3-2 `216-5607` |
  | `NEEDS_ORIGINAL` + `retryAvailable` | 원문 확인 필요(다시 정리하기 버튼) | F3-3 `216-5627` |
  | `NEEDS_ORIGINAL` + 재시도 사용함 | 원문 확인 필요(버튼 없음, 한도 안내) | F3-3 변형 |
  | `PENDING` (이 화면에서 방금 다시 정리하기를 받아들임) | 다시 정리하는 중 | F3-3a `216-5640` |
  | `PENDING` (그 밖) | 정리 중 | Figma 없음 → F3-3a 배치에 문구만 바꿈 |

- **Rationale**: IA 상태 표가 "F3-3 → 다시 정리하기 → F3-3a"를 같은 화면의 상태로 묶어도 된다고 한다. 상태 사이 이동(다시 확인·다시 정리하기)이 같은 화면 안에서 일어나므로, 화면을 바꿔 끼우면 뒤로 가기 기록이 꼬인다. 목록은 상태를 보고 경로를 고를 필요 없이 일반 문의면 같은 경로로 보낸다. 상태는 상세를 열 때 서버에서 다시 읽는다(spec FR-003).
- **"다시 정리하는 중"과 "정리 중"의 구분**: API는 재시도 뒤 `PENDING`과 처음 `PENDING`을 구분해 주지 않는다(둘 다 `retryAvailable: false`). 그래서 ViewModel이 **이 화면에서** 재시도를 받아들인 경우에만 "다시 정리하는 중"을 보이고, 화면을 나갔다 다시 열면 "정리 중"으로 보인다. 두 화면의 버튼(원문 보기·다시 확인·문의 목록으로)이 같아 교사가 할 수 있는 일은 같다.
- **Alternatives**: 상태별 경로 4개 — 목록이 상태에 따라 경로를 골라야 하고, 다시 확인 뒤 `context.replace`가 필요하다. 재시도 사실을 기기에 저장해 구분 — 저장할 가치가 작고 F2의 "기기에 저장하지 않음" 방향과 어긋난다.

## R3. 번역본 불러오기와 `REFINEMENT_NOT_READY`(409)

- **Decision**: 상세가 `REFINED`일 때만 `refinement`를 부른다. 409 `REFINEMENT_NOT_READY`가 오면(목록과 상세 사이에 상태가 바뀐 경쟁) 상세를 한 번 다시 읽어 그 상태로 화면을 고르고, 서버 `message`를 스낵바로 보인다. 다시 읽어도 `REFINED`인데 또 409면 오류 상태(다시 시도)로 둔다 — 무한 반복 방지.
- **Rationale**: 번역본 열람은 감사 기록 대상이 아니라 여러 번 불러도 되지만(API 설명), 첫 열람이 "교사 확인" 단계를 만든다. `REFINED`가 아닌 문의에 미리 부르지 않아도 된다.
- **번역본을 불러온 뒤 목록 새로 고침**: 첫 열람으로 단계가 바뀔 수 있으므로, 긴급 상세(F2 R8)와 같이 번역본을 받은 뒤 `teacherInquiriesViewModelProvider.notifier.refresh()`를 부른다(spec FR-009). 교사 홈은 같은 목록 상태를 본다.

## R4. 다시 정리하기 — 버튼 잠금과 결과 반영

- **Decision**: `retry()`는 진행 중 플래그로 연타를 막는다. 결과별:
  - 202 → 상태를 "다시 정리하는 중"으로. 응답의 `refinementStatus`가 `REFINED`·`NEEDS_ORIGINAL`이면(이미 끝난 경우) 상세를 다시 읽어 그 상태로.
  - 409 `REFINEMENT_RETRY_UNAVAILABLE` → 서버 `message` 스낵바 + 상세 다시 읽기(버튼이 사라진다).
  - 네트워크 오류·그 밖 → 서버 `message`(또는 일반 안내) 스낵바, 상태 그대로(버튼 다시 누를 수 있음, spec US2-7).
- **Rationale**: 재시도 1회 한도와 동시 요청 판단은 서버가 한다(원칙: 앱은 판정 규칙을 갖지 않음). 앱은 버튼을 한 번만 눌리게 하고 서버의 최신 상태를 따른다.
- **Alternatives**: 재시도 후 자동 조회 — Clarifications(2026-10-27) A로 하지 않는다.

## R5. 다시 확인 — 버튼 + 당겨서 새로 고침

- **Decision**: 정리 중·다시 정리하는 중 상태에 "다시 확인" 버튼을 두고, 화면 전체를 `RefreshIndicator`로 감싼다. 둘 다 `recheck()`를 부르며, 다시 읽는 동안 보던 화면을 유지한다(`AsyncValue`의 이전 값 유지, F2 목록과 같은 방식). 바뀐 상태가 `REFINED`면 번역본까지 불러온다. 일정 간격 조회는 없다.
- **Rationale**: spec FR-012(Clarifications 2026-10-27 A). Figma F3-3a에는 다시 확인 버튼이 없어, 원문 보기 아래에 같은 외곽선 버튼 모양으로 더한다.

## R6. 원문 열람(F3-6) — 별도 경로, 화면당 1회

- **Decision**: `/teacher/inquiries/:inquiryId/content` 경로에 `ContentPage` + `ContentViewModel`. 화면 인스턴스당 `content()`를 한 번만 부르고(긴급 상세 R8과 같은 규칙), 원문은 ViewModel 메모리에만 둔다. 상세를 함께 불러 제목·학생·접수 시각을 보인다(상세 실패 때 "다시 시도"는 원문을 다시 부르지 않는다). 원문을 받은 뒤 목록을 새로 고친다(원문 확인 필요 문의는 첫 열람에 "교사 확인"이 된다). "문의 상세로"는 `pop` — 원문 화면은 언제나 상세에서 열린다. 상세로 돌아오면 상세 ViewModel이 상태를 다시 읽는다(`recheck`).
- **Rationale**: spec FR-015~018. 원문 열람마다 감사 기록이 남으므로, 다시 그리기·재빌드로 열람이 여러 번 기록되지 않게 한다. 반대로 화면을 새로 열면 새 열람이므로 이전 원문을 재사용하지 않는다(FR-016).
- **Alternatives**: 상세 화면 안에서 펼치기 — Figma가 별도 화면(F3-6)이고, 펼침 상태가 다시 그리기로 반복 호출될 위험이 있다.

## R7. Figma와 spec이 다른 곳

| Figma | spec·원칙 | 결정 |
|---|---|---|
| 상세·원문 화면에 "김하늘 학부모" 표시 | FR-019 학부모 이름 표시 금지(원칙 I·F2 FR-023) | F2 화면과 같이 `학생 이름 · 접수 시각`으로 바꾼다 |
| F3-2에 "빠른 회신 권장" 카드(회신 우선도) | API에 회신 우선도 값이 없음. spec은 정서강도·감정 라벨 표시 | 그 자리(같은 따뜻한 배경 카드)에 **정서강도 · 감정 라벨**을 보인다. 회신 우선도는 만들지 않는다(리스크 표에 디자인 확인 요청) |
| F3-3 안내 "내용을 자동으로 정리하지 못했어요. 원문을 확인하고 답변할 수 있어요." | 팀 결정·API 설명의 고정 문구 "자동 정리에 실패했습니다. 원문을 확인해 주세요" | 팀 결정 문구를 안내 상자에 쓴다(features.md "결정됨"). 큰 제목은 Figma "원문을 확인해 주세요" |
| 답변 작성 버튼(F3-2·F3-3·F3-6) | FR-023 F4 범위 | 두지 않는다. 하단 버튼 영역을 F4가 더할 수 있게 비워 둔다 |
| F3-3a에 다시 확인 버튼 없음 | FR-012 | 원문 보기 아래에 외곽선 버튼으로 더한다 |
| 정리 중(첫 정리) 화면 없음 | US4 | F3-3a 배치, 배지 "정리 중"·제목 "내용을 정리하고 있어요" |

## R8. 정서강도·감정 라벨 해석 — 모르는 값은 버린다

- **Decision**: `EmotionLevel.fromServer`·`EmotionLabel.fromServer`는 모르는 값이면 `null`을 돌려준다(예외 아님). 라벨 목록은 `null`을 빼고, 중복을 빼고, 2개까지만 쓴다. 정서강도가 `null`이면 **정서강도 줄만** 숨기고, 아는 라벨이 있으면 정서 카드에 라벨은 보인다. 정서강도도 라벨도 없으면 카드 전체를 숨긴다(spec FR-005a, analyze T2 — 라벨을 버리면 정보 손실). 표시 문구는 `NoticeText`의 고정 문구.
- **Rationale**: spec FR-005a. 기존 `RefinementStatus.fromServer`는 모르는 값에 `FormatException`을 던지는데(상태를 모르면 화면을 고를 수 없음), 정서강도는 보조 표시라 없어도 번역본의 핵심(사실관계·요청사항)은 보여야 한다.

## R9. 기존 "준비 중" 자리 정리

- **Decision**: `pending_detail_page.dart`·`pending_detail_view_model.dart`와 `NoticeText.pendingDetail`을 삭제하고, 경로 `/teacher/inquiries/:id/pending`을 `/general`로 바꾼다. `TeacherInquiryTile.pathOf`가 일반 문의를 `/general`로 보낸다. 라우터 테스트의 `/pending` 경로도 바꾼다.
- **Rationale**: spec FR-002. 앱 밖에서 `/pending`으로 들어오는 경로(알림 등)는 없다 — 일반 알림은 목록(F3-1)으로 간다.
- **승인**: 파일 삭제는 CLAUDE.md에 따라 구현 단계(`/speckit-implement`)에서 사용자 승인을 받고 한다.

## R10. mock — 문의별 시나리오

- **Decision**: `MockInquiryStore`에 번역본·재시도 상태를 더한다. 데모 문의(교사 `teacher` 계정, 3학년 2반):

  | ID 끝자리 | 학생 | 처음 상태 | 동작 |
  |---|---|---|---|
  | `…0003` | 김하나 | 정리 중 | **F2 데모 그대로**: 교사 목록 두 번째 조회 때 정리 완료(F2 테스트가 쓴다). F3 시연에는 쓰지 않는다 — 다른 문의를 열 때 목록을 새로 고치면 먼저 바뀌어 버린다 |
  | `…000a` | 김하나 | 정리 중 | **F3 정리 중 데모**: 이 문의 **자기 상세의 두 번째 교사 조회**(다시 확인) 때만 정리 완료. 목록 조회 횟수와 무관(analyze G1). 학부모 계정 `parent`의 문의라 학부모 화면 확인(US5)에도 쓴다 |
  | `…0004` | 박서준 | 원문 확인 필요(재시도 가능) | 다시 정리하기 → 다음 상세 조회에서 **성공**(정리 완료) |
  | `…0006` | 이도윤 | 원문 확인 필요(재시도 가능) | 다시 정리하기 → 다음 상세 조회에서 **실패**(재시도 사용함) |
  | `…0007` | 박서준 | 원문 확인 필요(재시도 사용함) | 버튼 없음 |
  | `…0005` | 김하나 | 정리 완료(교사 확인) | 정서강도 보통 · 걱정 |
  | `…0008` | 이도윤 | 정리 완료(정제) | 정서강도 높음 · 분노·답답함, 첫 열람에 "교사 확인" |
  | `…0009` | 김하나 | 정리 완료(정제) | 요청사항 빈 값 · 라벨 없음 · 정서강도 낮음 |

  학부모가 새로 보낸 일반 문의는 F2처럼 "정리 중"으로 들어오고, 교사 두 번째 목록 조회 때 고정 mock 번역본으로 정리 완료된다. 서버 규칙도 따라 한다: 번역본 첫 열람에 `REFINING` → `TEACHER_CONFIRMED`, 원문 확인 필요 문의의 원문 첫 열람에 `RECEIVED` → `TEACHER_CONFIRMED`, 교사 확인 뒤 재시도 성공은 "정제"를 더하지 않음, `REFINED`가 아닌 문의의 `refinement`는 409, 재시도 불가 문의의 `retry`는 409. 403(담당 학급 없음 `noclass` 계정)·401 갱신은 F1·F2 mock을 그대로 쓴다.
- **Rationale**: spec FR-025, constitution "정제 진행 중 → 완료, 원문 확인 필요" mock 요건. 교사 목록 25건 페이지 데모(`b2…`)는 그대로 두고 번역본만 공통 mock 값으로 준다.

## R11. 테스트

- **Decision**:
  - `general_detail_view_model_test.dart` — 상태 고르기 5가지, 409 NOT_READY 후 다시 읽기(1회만), 재시도 202·409·네트워크 오류, 연타 1회, 다시 확인으로 전이, 번역본 뒤 목록 새로 고침.
  - `content_view_model_test.dart` — 화면당 원문 1회(상세만 다시 시도 시 원문 재호출 없음), 실패 시 원문 없음.
  - `inquiry_json_test.dart`(또는 기존 `inquiry_repository_impl_test.dart`에 추가) — `InquiryRefinement` 해석, 모르는 정서강도·라벨 버리기, `retryAvailable`, 재시도 경로·오류 코드.
  - `general_detail_flow_test.dart`(위젯) — mock으로 목록 → 상세 각 상태 → 원문 → 돌아오기, 학부모 이름·`@` 없음, 답변 작성 버튼 없음.
  - `router_redirect_test.dart` — `/general`·`/content`가 교사 전용.
  - `mock_scenarios_test.dart` — R10 표.
- **Rationale**: F2와 같은 층(ViewModel 단위·위젯·라우터)과 같은 도구(flutter_test, 가짜 `HttpClientAdapter`).
