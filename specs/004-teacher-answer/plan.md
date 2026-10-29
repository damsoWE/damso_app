# Implementation Plan: 교사 답변 작성·점검·전송 화면 (F4 교사)

**Branch**: `features/f4-teacher-answer` (이슈 #9) | **Date**: 2026-10-27 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/004-teacher-answer/spec.md`

**대응 백엔드 spec**: `damsoWE/damso_server` `specs/004-answer-review-send` · **API 계약**: 앱 사본 `docs/api/openapi.yaml` `api-v0.6`([research R1](./research.md#r1-api-계약-기준--앱-사본-api-v06))

## Summary

교사가 문의 상세(F3-2·F3-3·F3-5·F3-6)에서 "답변 작성"을 눌러 답변을 쓰고(F4-2a), 반드시 한 번 점검한 뒤(F4-2b), 결과 화면(제안 있음 F4-2c·적용 후 F4-2c-1·제안 없음 F4-2e·실패 F4-2f·수정 F4-2d)에서 직접 전송한다(F4-2g, 실패 F4-2h). 전송하면 스레드(F4-3)로 가고, 이미 답한 문의는 목록에서 바로 스레드로 열린다. 재문의는 답변 카드 아래 카드로 붙고, 누르면 재문의 상세(F3-2 구성, 제목 "… - 재문의")가 열려 원문 보기(F3-6) 또는 답변 작성(F4-2a~)을 고른다. 닫기(F4-3a)는 없다.

접근 방식: 새 기능 `lib/features/reply/`(AnswerRepository: 점검·전송, 작성·스레드 화면)를 만들고, `inquiry` 기능은 상세 응답의 `answers`·`followUps` 해석과 진입 버튼·"문의 열기" 경로만 확장한다(R2·R3). 새 패키지·플랫폼 설정 변경 없음.

## Technical Context

**Language/Version**: Dart ^3.10.1 (Flutter 3.38.3 stable)

**Primary Dependencies**: 기존 flutter_riverpod ^3.0.3 · go_router ^17.5.0 · dio ^5.11.1. **추가 없음**

**Storage**: 추가 로컬 저장 없음. 작성 중 본문·점검 결과는 ViewModel 메모리(`autoDispose`)에만(원칙 III·VI)

**Testing**: flutter_test (ViewModel 단위·위젯 흐름·라우터 redirect), 가짜 `HttpClientAdapter`(F2·F3와 같음)

**Target Platform**: Android · iOS

**Project Type**: mobile-app (Flutter, 백엔드는 별도 레포)

**Performance Goals**: 화면 조작 4단계 안에 전송(SC-001). 스레드는 상세·번역본·프로필을 병렬로 불러온다

**Constraints**: 입력 직후 전송 버튼 없음(Clarifications Q1) · 제안 카드 제목은 "제안 N"(Q2) · 점검 결과 자동 반영·자동 전송 금지 · 전송 한 번만(멱등키 없음, 자동 재전송 금지) · 스레드·작성 화면에서 원문을 부르지 않음 · 닫기 기능 없음 · WebView/HTML 렌더 금지 · 학부모 이름·연락처 표시 금지

**Scale/Scope**: 새 화면 4개(문의 열기·답변 작성(상태 7개)·스레드·재문의 상세) · 새 기능 1개(`reply`) · 기존 화면 4개에 버튼 추가 · 엔드포인트 2개 새로 사용 · 기존 파일 수정 약 12개

## Constitution Check

*GATE: Phase 0 전 확인, Phase 1 설계 후 재확인.*

| 원칙·요건 | 이 계획에서 | 결과 |
|---|---|---|
| I. 연락처 미수집 | 입력은 답변 본문뿐. "학부모" 표시는 학생 이름 + "학부모". 위젯 테스트로 `@`·학부모 이름 검사 | ✅ |
| II. 가명화 게이트웨이 | 점검의 가명화·외부 AI는 서버. 앱은 외부 AI를 부르지 않는다 | ✅ (해당 없음) |
| III. 원문 보존·열람 감사 | 보낸 답변 수정·삭제 UI 없음. 스레드·작성 화면은 원문을 부르지 않는다(열람 기록 불필요하게 남기지 않음, R3·R5). 본문 기기 저장 없음 | ✅ |
| IV. 긴급 우선·일반 fail-closed | 요청사항은 번역본(`REFINED`)이 있을 때만. "원문 확인 필요"·정리 중에는 정리 결과를 보이지 않는다(FR-015a) | ✅ |
| V. 제안만 한다 | 제안은 카드마다 "바꾸기"를 눌러야만 반영, "되돌리기" 가능, 자동 전송 없음, 점검 실패해도 전송 가능. 안내 문구는 `answer_text.dart` 상수. "직접 전송"은 점검·안전 보증으로 표시하지 않는다 | ✅ |
| VI. 민감정보 비노출 | 답변 본문·점검 결과 `print`·로그·분석 이벤트 금지(테스트로 검색). 오류는 서버 `message`만 | ✅ |
| VII. 식별자·권한 | URL에는 문의 UUID만, 이름·제목·요청사항은 `extra`. 새 경로도 `resolveRedirect`의 `/teacher/` 규칙. 남의 문의는 서버 거부 안내 | ✅ |
| VIII. 안전한 기본값 | 새 설정·시크릿 없음 | ✅ |
| 렌더링 | 본문·점검 결과는 일반 `Text`만 | ✅ |
| 아키텍처 | 위젯 → ViewModel → Repository 인터페이스(`AnswerRepository`·`TeacherInquiryRepository`·`TeacherRepository`). domain에 Flutter·dio 없음. 구현 선택은 provider 한 곳(`answer_repository_provider.dart`) | ✅ |
| mock 케이스 | 점검 제안 있음·없음·실패, 전송 성공·실패, 답변한 문의·재문의, 403, 401 갱신(R11) | ✅ |
| Contract-first | 앱 사본 수정 없음(api-v0.6 커밋됨) | ✅ |
| Figma·백엔드와 다른 결정 | 닫기 없음·점검 필수·제안 번호 제목 → 백엔드 `docs/decisions.md` 기록과 팀 공유 필요(spec Assumptions) | ⏳ 팀 공유 |
| 수정 허락 범위 | 사용자가 허락한 범위는 `lib/features/reply/`. 아래 "reply 밖 수정 파일"은 구현 전에 허락이 필요 | ⏳ 구현 전 승인 |

**재확인(Phase 1 후)**: data-model·contracts·quickstart 작성 후 새 위반 없음. Complexity Tracking 없음.

## Project Structure

### Documentation (this feature)

```text
specs/004-teacher-answer/
├── plan.md
├── research.md                 # R1~R12
├── data-model.md               # 모델·상태 기계·고정 문구
├── quickstart.md               # mock 시나리오 25개 + 실서버 4개
├── contracts/
│   ├── api-usage.md            # Repository ↔ 엔드포인트 ↔ 오류 분기
│   └── routes.md               # 새 경로 3개, 이동 방식
├── checklists/requirements.md
└── tasks.md                    # /speckit-tasks
```

### Source Code (repository root)

```text
lib/features/reply/                              # 신규 기능 (사용자 허락 범위)
├── domain/
│   ├── models.dart                              # Highlight, AnswerReview, AnswerSent, AnswerTarget
│   ├── answer_repository.dart                   # review(), send()
│   └── answer_text.dart                         # 고정 문구(data-model §5)
├── data/
│   ├── answer_repository_impl.dart              # dio, mapDioErrors
│   ├── mock_answer_repository.dart              # MockInquiryStore 공유(R11)
│   └── answer_repository_provider.dart          # USE_MOCK 전환
└── presentation/
    ├── answer_compose_page.dart                 # F4-2a~F4-2h
    ├── answer_compose_view_model.dart           # 상태 기계(R6), 바꾸기·되돌리기(R7), 전송 1회(R8)
    ├── suggestion_card.dart                     # "제안 N" 카드
    ├── thread_page.dart                         # F4-3
    ├── thread_view_model.dart                   # 상세+번역본+프로필 병렬, 카드 정렬(R5)
    ├── follow_up_detail_page.dart               # 재문의 상세(F3-2 구성, R13)
    └── follow_up_detail_view_model.dart         # 재문의 번역본(409 → 정리 안 됨), 긴급 분기

# reply 밖 수정 (구현 전 사용자 승인 필요)
lib/app/router.dart                              # 경로 4개 추가
docs/ia.md                                       # F4-3a 미사용, 재문의 상세, 이동 갱신(T046)
lib/core/error/error_codes.dart                  # THREAD_CLOSED
lib/features/inquiry/
├── domain/models.dart                           # TeacherInquiryDetail.followUps·answers, TeacherFollowUp, SentAnswer
├── data/inquiry_json.dart                       # followUps·answers 해석
├── data/mock_inquiry_store.dart                 # 답변·재문의 데모(R11)
└── presentation/teacher/
    ├── open_inquiry_page.dart                   # 신규: 문의 열기(R3)
    ├── teacher_inquiry_tile.dart                # pathOf → /teacher/inquiries/:id
    ├── general_detail_page.dart                 # F3-2·F3-3 "답변 작성"
    ├── urgent_detail_page.dart                  # F3-5 "답변 작성"
    └── content_page.dart                        # F3-6 "답변 작성"(재문의에서 오면 요청사항은 재문의 것)

test/
├── core/router_redirect_test.dart               # 수정: 새 경로 3개
├── helpers/test_app.dart                        # 수정: answerRepository mock override
├── features/inquiry/inquiry_repository_impl_test.dart   # 수정: followUps·answers 해석
├── features/inquiry/open_inquiry_test.dart      # 신규
├── features/reply/answer_repository_impl_test.dart      # 신규
├── features/reply/answer_compose_view_model_test.dart   # 신규
├── features/reply/thread_view_model_test.dart   # 신규
├── features/reply/follow_up_detail_view_model_test.dart # 신규
├── features/reply/answer_flow_test.dart         # 신규(위젯)
└── features/mock_scenarios_test.dart            # 수정: F4 데모
```

**Structure Decision**: 쓰기 동작(점검·전송)과 F4 화면은 새 기능 `reply`에 둔다. 상세 조회·해석·mock 저장소는 이미 `inquiry`에 있으므로 거기서 확장하고 `reply`가 읽는다(R2). 기능 간 참조는 presentation·mock 수준이며 기존에도 있는 패턴이다(`inquiry → parent/domain`).

## Phase 0: Research

[research.md](./research.md) — R1 API 기준(api-v0.6) · R2 기능 위치 · R3 문의 열기 경로(백엔드 답변 여부 필드가 오면 생략) · R4 답변은 루트로 · R5 스레드 내용 · R6 작성 상태 기계 · R7 바꾸기·되돌리기 · R8 전송 1회·오류 · R9 화면 떠날 때 · R10 진입 버튼 · R11 mock · R12 테스트 · R13 재문의 상세 · R14 작성 ViewModel 키·전송 뒤 이동 · R15 세션 만료 안내. 미해결 항목 없음(백엔드 확인 항목은 리스크 표).

## Phase 1: Design & Contracts

- [data-model.md](./data-model.md) — 모델 변경·신규, 작성 상태 기계, 스레드 카드, 고정 문구표
- [contracts/api-usage.md](./contracts/api-usage.md) — 메서드 ↔ 엔드포인트 ↔ 오류 분기
- [contracts/routes.md](./contracts/routes.md) — 새 경로 3개, 이동 방식
- [quickstart.md](./quickstart.md) — mock 시나리오 25개 + 실서버 4개

## 구현 순서 (tasks 입력용)

1. **domain·data(reply)**: 모델·고정 문구·`AnswerRepository`·실서버 구현·provider. 경로·본문·해석·오류 테스트 먼저.
2. **inquiry 확장**: `TeacherInquiryDetail.followUps·answers`, JSON 해석, `THREAD_CLOSED` 상수. 해석 테스트.
3. **mock**: `MockInquiryStore` 답변·재문의 데모, `MockAnswerRepository`. mock 시나리오 테스트.
4. **작성 화면**: ViewModel(상태 전이·바꾸기·되돌리기·결과 무효·전송 1회·오류) 테스트 → 화면(F4-2a → 2b → 2c/2c-1 → 2e → 2f → 2d → 2g → 2h).
5. **스레드·재문의 상세**: 스레드 ViewModel(병렬 로드·정렬·409·프로필 실패·답하지 않은 재문의) 테스트 → 화면(F4-3). 재문의 상세 ViewModel(정리됨·409·긴급) 테스트 → 화면(F3-2 구성) → 원문 보기·답변 작성 연결.
6. **연결**: 문의 열기 경로·`pathOf`, F3 화면 4곳 "답변 작성", 라우터 3경로, redirect 테스트.
7. **마무리**: 위젯 흐름 테스트, `flutter analyze`·`flutter test`, quickstart 1~25 에뮬레이터, 26~29 실서버.

## Complexity Tracking

없음.

## 리스크

| 리스크 | 대응 |
|---|---|
| 실서버 점검이 아직 임시 상태(항상 `available=false`)일 수 있음(계약 설명) | 실서버는 F4-2f만 보일 수 있다. 제안 화면은 mock으로 검증. 백엔드에 연동 여부 확인 |
| 목록에 답변 여부가 없어 문의 열기 때 상세를 한 번 더 읽음 | 화면 하나 더(로딩만). 백엔드에 목록 답변 여부 필드 요청함(PR #19 논의). 태그로 나오면 문의 열기 화면 생략(R3) |
| `TeacherFollowUpView`("원문은 긴급만")와 `/content`("일반·긴급") 설명이 다름 | 앱은 `/content` 기준으로 재문의 원문 보기를 둔다. 거부되면 서버 안내 문구. 백엔드에 설명 정리 요청(R13) |
| 재문의 상세(`GET …/{followUpId}`) 동작이 계약에 없음 | 재문의 상세는 상세 API 없이 스레드가 넘긴 값 + 번역본 API만 쓴다(R13) |
| 전송 API에 멱등키가 없어 응답 전 끊기면 중복 전송 가능 | 자동 재전송 없음, F4-2h에 "보내졌을 수 있어요" 안내(R8). 백엔드에 멱등키 검토 요청 후보 |
| 재문의 ID로 전송 시 서버 동작이 계약에 없음 | 앱은 항상 루트 ID로 보낸다(R4). 백엔드에 확인 |
| 스레드에서 재문의 번역본을 열면 그 재문의가 "교사 확인"이 됨 | 교사가 요청사항을 보는 것이 곧 확인이므로 의도와 맞다(R5) |
| 제안 카드 제목·닫기 없음·점검 필수가 Figma·백엔드와 다름 | spec Assumptions, 백엔드 `docs/decisions.md` 기록·팀 공유 |
| `reply` 밖 기존 파일 약 12개 수정 | 구현 전에 목록 승인(Constitution Check) |
