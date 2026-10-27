# Implementation Plan: 가명화·정제 파이프라인 화면 (F3)

**Branch**: `features/f3-pseudonymization-pipeline` (이슈 #10) | **Date**: 2026-10-27 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/003-pseudonymization-pipeline/spec.md`

**대응 백엔드 spec**: `damsoWE/damso_server` `specs/003-pseudonymization-pipeline` · **API 계약**: 앱 사본 `docs/api/openapi.yaml` `api-v0.4`(F3 경로 포함, [research R1](./research.md#r1-api-계약-기준--앱-사본-api-v04-그대로))

## Summary

교사가 일반 문의를 누르면 F2의 "준비 중" 대신 서버 정리 상태에 맞는 화면을 연다. 정리 완료는 번역본(사실관계·요청사항·정서강도·감정 라벨, F3-2), 정리 실패는 실패 안내·원문 보기·다시 정리하기 1회(F3-3 → F3-3a), 정리 중은 안내와 "다시 확인"을 보여 준다. 원문 보기(F3-6)는 화면당 1회 열람하고 열람 기록 안내를 보인다. 학부모 화면은 F2 타임라인 그대로다.

접근 방식: F2의 `inquiry` 기능을 확장한다. `TeacherInquiryRepository`에 `refinement`·`retryRefinement` 두 메서드를 더하고(실서버·mock), 일반 문의는 경로 하나 + `GeneralDetailViewModel` 하나가 상태 넷을 고른다(R2). 원문은 별도 경로 `ContentPage`(R6). 새 패키지·플랫폼 설정 변경은 없다.

## Technical Context

**Language/Version**: Dart ^3.10.1 (Flutter 3.38.3 stable)

**Primary Dependencies**: 기존 flutter_riverpod ^3.0.3 · go_router ^17.5.0 · dio ^5.11.1. **추가 없음**

**Storage**: 추가 로컬 저장 없음. 번역본·원문은 ViewModel 메모리에만(원칙 III·VI)

**Testing**: flutter_test (ViewModel 단위·위젯·라우터), 가짜 `HttpClientAdapter`(F2와 같음)

**Target Platform**: Android · iOS (F2와 같음)

**Project Type**: mobile-app (Flutter, 백엔드는 별도 레포)

**Performance Goals**: 목록에서 누른 뒤 번역본 표시 3초 이내(SC-001, 상세 + 번역본 요청 2번)

**Constraints**: 일정 간격 자동 조회 금지(Clarifications 2026-10-27) · 원문 열람은 화면당 1회 · 정리 실패·정리 중 상태에서 정리 결과 표시 금지 · 안내 문구는 앱 상수만 · WebView/HTML 렌더 금지 · 학부모 이름 표시 금지

**Scale/Scope**: 새 화면 2개(일반 문의 상세 = 상태 4개, 원문 열람) · 삭제 1개(준비 중) · Repository 메서드 2개 추가 · 엔드포인트 2개 새로 사용(+ `content`를 일반 문의에도) · 기존 파일 수정 약 8개

## Constitution Check

*GATE: Phase 0 전 확인, Phase 1 설계 후 재확인.*

| 원칙·요건 | 이 계획에서 | 결과 |
|---|---|---|
| I. 연락처 미수집 | 입력 없음. Figma의 "○○ 학부모" 표시는 학생 이름으로 바꾼다(R7). 위젯 테스트로 `@`·학부모 이름 검사 | ✅ |
| II. 가명화 게이트웨이 | 가명화·외부 AI는 서버. 앱은 외부 AI를 부르지 않는다 | ✅ (해당 없음) |
| III. 원문 보존·열람 감사 | 원문은 `/content`로만, F3-6 화면당 1회(R6). 기기 저장·캐시 없음. 열람 전(버튼 근처)·열람 후(F3-6) 기록 안내. 수정·삭제 UI 없음 | ✅ |
| IV. 긴급 우선·일반 fail-closed | 화면은 `refinementStatus`가 `REFINED`일 때만 번역본을 불러온다. `NEEDS_ORIGINAL`·`PENDING`에서는 정리 결과를 보여 주지 않는다(R2·R3). 긴급은 F3 화면에 들어오지 않고 `/urgent`로 | ✅ |
| V. 제안만·시스템 안내 | 화면 안내는 `NoticeText` 상수(data-model). 번역본은 교사에게만 보이는 정리 결과이고 학부모에게 발신하지 않는다 | ✅ |
| VI. 민감정보 비노출 | 번역본·원문 `print`·로그·분석 이벤트 금지. 오류는 서버 `message`만 | ✅ |
| VII. 식별자·권한 | 경로에는 문의 UUID만. 접근 제어는 `resolveRedirect` 한 곳(`/teacher/` 규칙). 남의 문의는 서버 거부 안내 | ✅ |
| VIII. 안전한 기본값 | 새 설정·시크릿 없음 | ✅ |
| 렌더링 | 번역본·원문은 일반 `Text`만 | ✅ |
| 아키텍처 | 위젯 → ViewModel → `TeacherInquiryRepository` 인터페이스. domain에 Flutter·dio 없음. 구현 선택은 기존 provider 한 곳 | ✅ |
| mock 케이스 | 정리 중 → 완료, 원문 확인 필요(재시도 가능·사용함), 재시도 성공·실패, 409 두 종류, 403, 401 갱신(R10) | ✅ |
| Contract-first | 앱 사본 수정 없음 | ✅ |
| 큰 영향 결정 확인(CLAUDE.md) | 새 패키지·권한·외부 시스템 없음. **파일 삭제**(준비 중 화면 2개)는 구현 때 승인(R9) | ⏳ 구현 단계에서 승인 |

**재확인(Phase 1 후)**: data-model·contracts·quickstart 작성 후 새 위반 없음. Complexity Tracking 없음.

## Project Structure

### Documentation (this feature)

```text
specs/003-pseudonymization-pipeline/
├── plan.md
├── research.md                          # R1~R11
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── api-usage.md                     # Repository ↔ 엔드포인트 ↔ 오류 분기
│   └── routes.md                        # /general · /content, /pending 삭제
├── checklists/requirements.md
└── tasks.md                             # /speckit-tasks
```

### Source Code (repository root)

```text
lib/
├── app/router.dart                      # 수정: /pending → /general, /content 추가
├── core/error/error_codes.dart          # 수정: REFINEMENT_NOT_READY, REFINEMENT_RETRY_UNAVAILABLE
└── features/inquiry/
    ├── domain/
    │   ├── models.dart                  # 수정: TeacherInquiryDetail.retryAvailable, EmotionLevel·EmotionLabel·InquiryRefinement
    │   ├── notice_text.dart             # 수정: F3 고정 문구·정서 이름 추가, pendingDetail 삭제
    │   └── teacher_inquiry_repository.dart   # 수정: refinement(), retryRefinement()
    ├── data/
    │   ├── inquiry_json.dart            # 수정: retryAvailable, refinement 해석(모르는 값 버림)
    │   ├── teacher_inquiry_repository_impl.dart  # 수정: 두 엔드포인트
    │   ├── mock_teacher_inquiry_repository.dart  # 수정: 두 메서드
    │   └── mock_inquiry_store.dart      # 수정: 번역본·재시도 상태·데모 문의 4건 추가·서버 단계 규칙(R10)
    └── presentation/teacher/
        ├── general_detail_page.dart     # 신규: 상태별 본문(F3-2 / F3-3 / F3-3a / 정리 중), RefreshIndicator
        ├── general_detail_view_model.dart   # 신규: 상태 고르기·recheck·retry
        ├── refinement_view.dart         # 신규: 번역본 카드(사실관계·요청사항·정서강도) — F4 재사용 가능
        ├── content_page.dart            # 신규: F3-6
        ├── content_view_model.dart      # 신규: 원문 화면당 1회
        ├── teacher_inquiry_tile.dart    # 수정: pathOf 일반 → /general
        ├── pending_detail_page.dart     # 삭제(승인 후)
        └── pending_detail_view_model.dart   # 삭제(승인 후)

test/
├── core/router_redirect_test.dart       # 수정: /pending → /general, /content
├── features/inquiry/
│   ├── general_detail_view_model_test.dart   # 신규
│   ├── content_view_model_test.dart          # 신규
│   ├── general_detail_flow_test.dart         # 신규(위젯)
│   └── inquiry_repository_impl_test.dart     # 수정: refinement·retry 경로·해석·오류 코드
└── features/mock_scenarios_test.dart    # 수정: F3 데모(R10)
```

**Structure Decision**: 정리 결과는 같은 문의 데이터를 교사가 보는 것이라 새 기능을 만들지 않고 `inquiry`의 `presentation/teacher/`에 더한다. 번역본 카드(`refinement_view.dart`)는 F4 답변 작성 화면이 문의 요약으로 다시 쓸 수 있게 화면과 나눈다. 원문 열람은 F3-5(긴급)와 F3-6(일반) 모두 `TeacherInquiryRepository.content`를 쓰지만, 화면 구성이 달라 F3-6을 따로 만든다.

## Phase 0: Research

[research.md](./research.md) — R1 API 기준(api-v0.4) · R2 상세 화면 하나에 상태 넷 · R3 번역본·409 · R4 다시 정리하기 · R5 다시 확인 · R6 원문 열람 1회 · R7 Figma와 다른 곳 · R8 정서 값 해석 · R9 준비 중 정리 · R10 mock · R11 테스트. 미해결 항목 없음.

## Phase 1: Design & Contracts

- [data-model.md](./data-model.md) — 모델 변경·신규, 화면 상태와 전이, 고정 문구 표
- [contracts/api-usage.md](./contracts/api-usage.md) — Repository 메서드 ↔ 엔드포인트 ↔ 오류 분기
- [contracts/routes.md](./contracts/routes.md) — 새 경로 2개, 삭제 1개, 이동 방식
- [quickstart.md](./quickstart.md) — mock 데모 문의표, 검증 시나리오 20개 + 실서버 4개

## 구현 순서 (tasks 입력용)

1. **domain·data**: 모델·오류 코드·JSON 해석·Repository 두 메서드(실서버·mock). 해석·경로 테스트 먼저.
2. **mock 저장소**: 번역본·재시도 상태·데모 문의·서버 단계 규칙(R10). mock 시나리오 테스트.
3. **일반 문의 상세**: ViewModel(상태 고르기·409·recheck·retry) 테스트 → 화면(F3-2 → F3-3 → F3-3a·정리 중).
4. **원문 열람**: ViewModel(1회) 테스트 → 화면(F3-6).
5. **라우터·목록 연결**: `/general`·`/content`, `pathOf` 변경, redirect 테스트.
6. **정리**: 준비 중 화면 삭제(승인 후), `pendingDetail` 문구 삭제, 위젯 흐름 테스트, `flutter analyze`·`flutter test`, quickstart 1~20 에뮬레이터 확인, 21~24 실서버 확인.

## Complexity Tracking

없음.

## 리스크

| 리스크 | 대응 |
|---|---|
| Figma F3-2의 "빠른 회신 권장"(회신 우선도)을 API가 주지 않음 | 그 자리에 정서강도·감정 라벨을 보인다(R7). PR에 디자인 확인 요청 항목으로 남긴다 |
| F3-3 안내 문구가 Figma와 팀 결정 문구가 다름 | 팀 결정(features.md·API 설명) 문구를 쓴다(R7). 디자인 쪽 문구 정리는 PR에서 요청 |
| 재시도 뒤 화면을 나갔다 오면 "다시 정리하는 중"이 "정리 중"으로 보임(API가 구분하지 않음) | 할 수 있는 동작이 같아 영향이 작다(R2). 필요하면 백엔드에 상세 응답 필드 추가를 요청 |
| 원격 `features/f4-teacher-answer`(F4)와 같은 화면을 건드림 | F4는 F3-2·F3-3·F3-6에 답변 작성 버튼을 더한다. 하단 버튼 영역과 `refinement_view.dart`를 나눠 두고, F3를 먼저 머지하도록 팀에 공유 |
| 원문 열람이 다시 그리기로 여러 번 기록됨 | ViewModel이 화면당 1회만 호출, 테스트로 고정(R6) |
