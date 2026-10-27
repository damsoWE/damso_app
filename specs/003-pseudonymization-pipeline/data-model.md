# Data Model: 가명화·정제 파이프라인 화면 (F3)

**Feature**: [spec.md](./spec.md) · **Plan**: [plan.md](./plan.md)

앱 쪽 모델만 적는다. 서버 스키마는 `docs/api/openapi.yaml`(api-v0.4)을 따른다. 모두 `lib/features/inquiry/domain/`에 두며 Flutter·dio를 참조하지 않는다.

## 기존 모델 변경

### `TeacherInquiryDetail` (models.dart)

| 필드 | 타입 | 변경 | 출처 |
|---|---|---|---|
| `summary` | `TeacherInquirySummary` | 그대로(`refinementStatus` 포함) | 상세 응답 |
| `timeline` | `List<StageEvent>` | 그대로 | `timeline` |
| `retryAvailable` | `bool` | **추가** | `retryAvailable` (NEEDS_ORIGINAL이고 교사 재시도를 아직 안 쓴 경우 true) |

`InquiryJson.teacherDetail`이 `retryAvailable`을 읽는다. 긴급 상세(F3-5)는 이 값을 쓰지 않는다.

### `RefinementStatus`

그대로(`pending`·`refined`·`needsOriginal`, 모르는 값은 `FormatException`). 일반 문의 상세 화면을 고르는 기준이다.

## 새 모델

### `EmotionLevel`

| 값 | 서버 | 표시(고정 문구) |
|---|---|---|
| `low` | `LOW` | 낮음 |
| `medium` | `MEDIUM` | 보통 |
| `high` | `HIGH` | 높음 |

`fromServer(Object?)` → 모르는 값·null이면 `null`(research R8).

### `EmotionLabel`

| 값 | 서버 | 표시 |
|---|---|---|
| `anxiety` | `ANXIETY` | 불안 |
| `dissatisfaction` | `DISSATISFACTION` | 불만 |
| `anger` | `ANGER` | 분노 |
| `worry` | `WORRY` | 걱정 |
| `frustration` | `FRUSTRATION` | 답답함 |
| `sadness` | `SADNESS` | 슬픔 |

`fromServer` → 모르는 값이면 `null`. 목록 해석은 null 제거 → 중복 제거 → 앞에서 2개.

### `InquiryRefinement` (번역본)

| 필드 | 타입 | 규칙 |
|---|---|---|
| `inquiryId` | `String` | UUID |
| `title` | `String` | 1~30자(서버 보장) |
| `facts` | `String` | 사실관계, 1자 이상 |
| `requests` | `String` | 요청사항. 빈 문자열이면 화면은 `NoticeText.noRequests` |
| `emotionLevel` | `EmotionLevel?` | null이면 정서강도 줄만 숨김. 라벨도 없으면 정서 카드 전체 숨김 |
| `emotionLabels` | `List<EmotionLabel>` | 0~2개 |
| `refinedAt` | `DateTime` | 정리 시각 |

화면이 열려 있는 동안 ViewModel 메모리에만 있다. 저장·로그 금지(원칙 III·VI).

## 화면 상태 (presentation)

### `GeneralDetail` — `GeneralDetailViewModel`(AsyncNotifier, family by inquiryId, autoDispose)

```text
sealed GeneralDetail
├── Refined(detail, refinement)                 → F3-2
├── NeedsOriginal(detail)                       → F3-3 (detail.retryAvailable 로 버튼 여부)
└── Refining(detail, afterRetry: bool)          → afterRetry ? F3-3a : 정리 중
```

ViewModel 보조 상태(화면이 읽음): `isRetrying`(다시 정리하기 요청 중), `isRechecking`(다시 확인 중). 다시 확인 중에는 이전 `GeneralDetail`을 그대로 보인다.

### 상태 전이

```text
build / recheck:
  detail = repo.detail(id)
  switch detail.refinementStatus
    REFINED        → refinement = repo.refinement(id)
                       409 REFINEMENT_NOT_READY → detail 다시 1회 → 다시 switch (REFINED 면 오류)
                     → Refined; 목록 refresh()
    NEEDS_ORIGINAL → NeedsOriginal
    PENDING        → Refining(afterRetry: 이번 화면에서 재시도를 받아들였으면 true)
    null(긴급)     → 오류 아님: 화면이 긴급 상세(/urgent)로 replace

retry (NeedsOriginal + retryAvailable, isRetrying=false 일 때만):
  202 PENDING                 → Refining(afterRetry: true)
  202 REFINED/NEEDS_ORIGINAL  → recheck
  409 REFINEMENT_RETRY_UNAVAILABLE → 메시지 + recheck
  그 밖 오류                   → 메시지, 상태 그대로
```

### `ContentView` — `ContentViewModel`(AsyncNotifier, family, autoDispose)

| 필드 | 설명 |
|---|---|
| `detail` | 제목·학생·접수 시각 |
| `content` | 원문. 화면당 1회 받은 값(다시 시도에서도 재사용) |

원문을 받은 뒤 목록 `refresh()`(원문 확인 필요 문의는 첫 열람에 "교사 확인").

## 고정 문구 (`NoticeText` 추가)

| 상수 | 문구 | 쓰는 곳 |
|---|---|---|
| `refinedBadge` | 자동 정리 | F3-2 배지 |
| `translationLabel` | 번역본 | F3-2 제목 위 표시(배지 옆) |
| `factsLabel` / `requestsLabel` | 사실관계 / 요청사항 | F3-2 카드 제목 |
| `noRequests` | 요청사항이 없어요. | 요청사항 빈 값 |
| `emotionLabel` | 정서강도 | F3-2 정서 카드 제목 |
| `contentViewWillLog` | 원문을 열면 열람한 사람과 시각이 기록돼요. | 원문 보기 버튼 근처(F3-2·F3-3·정리 중·F3-3a) |
| `contentViewedLogged` | 원문을 열었어요. 열람한 사람과 시각이 기록돼요. 원문은 수정되거나 삭제되지 않아요. | F3-6 |
| `needsOriginalBadge` | 원문 확인 필요 | F3-3 배지 |
| `needsOriginalHeading` | 원문을 확인해 주세요 | F3-3 제목 |
| `refinementFailed` | 자동 정리에 실패했습니다. 원문을 확인해 주세요 | F3-3 안내(팀 결정 문구) |
| `retryButton` | 다시 정리하기 · 1회 남음 | F3-3 버튼 |
| `retryLimitReached` | 다시 정리하기는 한 번만 할 수 있어요. | 재시도 사용한 F3-3 |
| `retryingBadge` / `retryingHeading` | 다시 정리 중 / 내용을 다시 정리하고 있어요 | F3-3a |
| `refiningBadge` / `refiningHeading` | 정리 중 / 내용을 정리하고 있어요 | 정리 중 |
| `refiningGuide` | 정리가 끝나면 다시 확인을 눌러 주세요. 필요하면 원문을 먼저 확인할 수 있어요. | 정리 중·F3-3a 안내 |
| `retryRemainingNone` | 남은 재요청 0회 · 다시 정리하지 못해도 원문으로 확인하고 답변할 수 있어요. | F3-3a 카드 |
| `recheckButton` | 다시 확인 | 정리 중·F3-3a |

문구 최종본은 구현 때 Figma와 한 번 더 맞춘다. 기존 `contentViewLogged`(F3-5)는 그대로 둔다. `pendingDetail`은 삭제(research R9).
