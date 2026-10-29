# Data Model: F5 감사 로그·이력 보존 (앱)

모두 화면이 열려 있는 동안 메모리에만 둔다. 기기에 저장하지 않는다.

## 1. 도메인 모델 (`lib/features/admin/domain/models.dart`에 추가)

```
ClassroomInquiryStatus            // 서버 ClassroomInquiryStatus 그대로
  classroomId : String (UUID)
  waiting     : int ≥ 0           // 답변 대기(교사 확인 전)
  confirmed   : int ≥ 0           // 교사 확인(답변 전)
  answered    : int ≥ 0           // 답변 완료(답변 1건 이상)
  total       : int  (getter)     // waiting + confirmed + answered
```

- 해석 규칙(data 계층): 네 필드 모두 필수. 없거나 음수·정수가 아니면 `FormatException` → 일반 오류 안내(F2 규칙과 같다).
- 응답 `items`는 서버 순서(학년·반 순)를 그대로 둔다.

## 2. 화면 상태 (`InquiryStatusViewModel`, presentation)

```
InquiryStatusState
  rows      : List<InquiryStatusRow>     // 서버 현황 순서
  totals    : InquiryStatusTotals        // 학급별 값을 더한 것(R2)
  allZero   : bool (getter)              // rows 가 있고 totals.total == 0

InquiryStatusRow
  status        : ClassroomInquiryStatus
  label         : String?                // "3학년 2반". 학급 목록에 없거나 목록 실패면 null → "학급"
  homeroomAssigned : bool?               // 학급 목록에서. 모르면 null → 담임 표시 숨김

InquiryStatusTotals
  total, waiting, confirmed, answered : int
```

- 현황 실패 → `AsyncError`(화면 전체 오류). 학급 목록 실패 → `label`·`homeroomAssigned` 모두 null, 화면은 열림(R4).
- `rows`가 비면(학급 0개) 빈 상태 문구.

## 3. 화면 문구 (`AdminText` 또는 화면 상수)

| 키 | 문구 |
|---|---|
| title | 문의 현황 |
| metadataOnlyNotice | 관리자는 문의 건수와 처리 상태만 볼 수 있어요. 문의 내용과 답변은 볼 수 없어요. |
| summaryTitle | 전체 |
| total / waiting / confirmed / answered | 전체 문의 / 답변 대기 / 교사 확인 / 답변 완료 |
| byClassTitle | 학급별 |
| unknownClass | 학급 |
| homeroom(assigned) | 담임 연결됨 / 담임 미연결 |
| rowCounts | `문의 {n} · 답변 대기 {a} · 교사 확인 {b} · 답변 완료 {c}` |
| allZeroNotice | 아직 접수된 문의가 없어요. |
| noClassrooms | 등록된 학급이 없습니다. 학급을 추가해 주세요. |

## 4. 처리 단계 타임라인

F2 `StageEvent`·`StageTimeline` 그대로. 바뀌는 것 없음(spec FR-008). 서버 `timeline`에는 처리 단계만 온다(백엔드 spec 006 FR-012).
