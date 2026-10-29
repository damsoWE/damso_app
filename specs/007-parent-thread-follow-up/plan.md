# Implementation Plan: 학부모 문의 스레드·이어서 묻기·답변 알림 (F4 학부모)

**Branch**: `features/parent-thread-follow-up` (이슈 #24) | **Date**: 2026-10-29 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/007-parent-thread-follow-up/spec.md`

**대응 백엔드 spec**: `damsoWE/damso_server` `specs/004-answer-review-send` · `specs/002-inquiry-intake-urgent` · **API 계약**: 앱 사본 `docs/api/openapi.yaml` `api-v0.11`([research R1](./research.md#r1-api-계약-기준--앱-사본-api-v011))

## Summary

학부모가 홈·나의 문의 목록의 카드를 누르면 스레드(F4-1)가 열려 처음 문의·교사 답변·재문의를 시간순으로 본다. 스레드의 "이어서 묻기"(F4-1a)로 재문의를 보내면 접수(F2-5) 또는 긴급 안내(F2-3 계열)를 거쳐 스레드로 돌아온다. 학부모 기기도 알림 받을 기기로 등록해 답변 도착 알림(`ANSWER`)을 받고, 누르면 그 스레드로 간다. 마이페이지에서 답변 도착 알림을 켜고 끈다(F2-8).

접근 방식: 기존 `inquiry` 기능의 학부모 쪽(상세 해석·저장소·목록 카드)을 넓히고 화면 2개(스레드·이어서 묻기)를 더한다. 접수 화면은 그대로 쓰고 "보낸 문의 보기" 목적지만 넓힌다. 알림은 `core/push`의 알림 종류·경로 규칙과 `DeviceRegistrar`의 대상 역할을 학부모까지 넓힌다. 알림 설정은 `notification` 기능에 학부모 설정 저장소와 화면을 더한다. **mock 시나리오는 만들지 않고 실서버로 바로 연동한다**(사용자 결정 2026-10-29, R9). 새 패키지·플랫폼 설정 변경 없음.

## Technical Context

**Language/Version**: Dart ^3.10.1 (Flutter 3.38.3 stable)

**Primary Dependencies**: 기존 flutter_riverpod ^3.0.3 · go_router ^17.5.0 · dio ^5.11.1 · firebase_messaging ^16.7.0. **추가 없음**

**Storage**: 추가 로컬 저장 없음. 작성 중 재문의 본문·스레드 내용은 ViewModel 메모리(`autoDispose`)에만. 알림 데이터·토큰 저장 금지(FR-021)

**Testing**: flutter_test — JSON 해석·저장소는 가짜 `HttpClientAdapter`(기존과 같음), ViewModel은 테스트 전용 가짜 저장소, 라우터 redirect 단위 테스트. 화면 흐름은 배포 서버 + 에뮬레이터 E2E([quickstart](./quickstart.md))

**Target Platform**: Android · iOS

**Project Type**: mobile-app (Flutter, 백엔드는 별도 레포)

**Performance Goals**: 목록에서 탭 1번에 답변 확인(SC-001), 스레드에서 3번 조작 안에 재문의 접수(SC-002)

**Constraints**: 재문의 멱등키(같은 내용 재시도 시 같은 키) · 보낸 글 수정·삭제 UI 없음 · 학부모 화면에 정리본·원문 열람 기능 없음 · 알림 이동은 역할에 맞는 종류만 · 알림 내용 저장·로그 금지 · WebView/HTML 렌더 금지

**Scale/Scope**: 새 화면 3개(스레드·이어서 묻기·알림 설정) · 새 경로 3개 · 새 엔드포인트 3개(재문의, 설정 조회·저장) · 기존 화면 수정 약 5개(목록 카드·홈 문의 영역·접수 화면·마이페이지·학부모 셸) · core 수정 3곳(알림 종류·경로, 기기 등록 대상, 알림 리스너)

## Constitution Check

*GATE: Phase 0 전 확인, Phase 1 설계 후 재확인.*

| 원칙·요건 | 이 계획에서 | 결과 |
|---|---|---|
| I. 연락처 미수집 | 입력은 재문의 본문뿐. 답변 작성자는 "담임 선생님"으로만 표시(교사 이름·연락처 없음) | ✅ |
| II. 가명화 게이트웨이 | 재문의 정제·긴급 판정은 서버. 앱은 외부 AI를 부르지 않는다 | ✅ (해당 없음) |
| III. 원문 보존·열람 감사 | 보낸 글 수정·삭제 UI 없음. 학부모는 본인 원문만 보며 교사용 원문 열람 경로를 부르지 않는다 | ✅ |
| IV. 긴급 우선 | 긴급 재문의는 서버 결과대로 긴급 안내(위기 번호)를 즉시 보인다. 긴급 판정을 앱이 하지 않는다 | ✅ |
| V. 제안만 한다 | 학부모 화면에 자동 작성·자동 발송 없음 | ✅ (해당 없음) |
| VI. 민감정보 비노출 | 본문·알림 데이터·토큰 `print`·로그 금지(테스트로 검색). 오류는 서버 `message`만 | ✅ |
| VII. 식별자·권한 | URL에는 문의 UUID만(라우터 UUID 검사, PR #25). 학생 이름 등은 `extra`. 남의 문의는 서버 거부 안내만 | ✅ |
| VIII. 안전한 기본값 | 새 설정·시크릿 없음. 알림 설정 기본값은 서버(켜짐) | ✅ |
| 렌더링 | 본문은 일반 `Text`만 | ✅ |
| 아키텍처 | 위젯 → ViewModel → Repository 인터페이스. 구현 선택은 저장소별 provider 한 곳 | ✅ |
| mock 케이스 (CLAUDE.md) | **새 화면에 mock 시나리오 없음** — 사용자 결정(R9). 기존 mock은 컴파일용 최소 구현만 | ⚠️ Complexity Tracking |
| Contract-first | 앱 사본 수정 없음(api-v0.11) | ✅ |
| 선행 작업 | 로그아웃 시 기기 토큰 폐기·배너 대기열·경로 UUID 검사는 PR #25(이슈 #23). 구현 전에 이 브랜치를 PR #25 머지 후 main으로 rebase(R2) | ⏳ PR #25 머지 대기 |

**재확인(Phase 1 후)**: data-model·contracts·quickstart 작성 후 새 위반 없음. mock 예외 1건만 Complexity Tracking에 둔다.

## Project Structure

### Documentation (this feature)

```text
specs/007-parent-thread-follow-up/
├── plan.md
├── research.md                 # R1~R10
├── data-model.md               # 모델·스레드 항목 순서·상태
├── quickstart.md               # 배포 서버 E2E 시나리오
├── contracts/
│   ├── api-usage.md            # Repository ↔ 엔드포인트 ↔ 오류 분기
│   └── routes.md               # 새 경로 3개, 카드·알림 이동 규칙
├── checklists/requirements.md
└── tasks.md                    # /speckit-tasks
```

### Source Code (repository root)

```text
lib/
├── app/
│   ├── router.dart                         # 새 경로 3개, 학부모 대기 경로 허용
│   ├── push_listener.dart                  # 역할별 알림 처리(학부모 배너·이동·새로고침)
│   └── shells/parent_shell.dart            # 대기 경로 소비
├── core/push/push_messaging.dart           # PushKind.answer, 역할별 경로
├── features/
│   ├── inquiry/
│   │   ├── domain/models.dart              # ParentInquiryDetail 확장, ThreadItem, FollowUpSubmitted
│   │   ├── domain/parent_inquiry_repository.dart  # submitFollowUp
│   │   ├── data/inquiry_json.dart          # parentDetail 확장, followUpSubmitted
│   │   ├── data/parent_inquiry_repository_impl.dart
│   │   ├── data/mock_parent_inquiry_repository.dart  # 컴파일용 최소 구현만
│   │   └── presentation/parent/
│   │       ├── thread_page.dart · thread_view_model.dart        # F4-1 (새)
│   │       ├── follow_up_page.dart · follow_up_view_model.dart  # F4-1a (새)
│   │       ├── inquiry_card.dart · parent_inquiries_page.dart · home_inquiry_section.dart  # 카드 → 스레드
│   │       └── submitted_page.dart          # "보낸 문의 보기" 목적지
│   ├── notification/
│   │   ├── domain/parent_notification_repository.dart  # 새 인터페이스
│   │   ├── data/parent_notification_repository_impl.dart · _provider.dart
│   │   └── presentation/
│   │       ├── device_registrar.dart        # 대상: 교사 + 학부모
│   │       └── parent_settings_page.dart · parent_settings_view_model.dart  # F2-8 (새)
│   └── parent/presentation/
│       ├── parent_home_page.dart            # 알림 권한 요청
│       └── parent_my_page.dart              # "알림 설정" 메뉴
test/
├── features/inquiry/parent_thread_test.dart · follow_up_view_model_test.dart · inquiry_json_test.dart(확장)
├── features/notification/parent_settings_view_model_test.dart · device_registrar_test.dart(확장)
└── core/push_data_test.dart · router_redirect_test.dart(확장)
```

**Structure Decision**: 기존 feature-first 구조를 따른다. 학부모 문의 화면은 `inquiry/presentation/parent/`, 학부모 알림 설정은 교사 설정과 같은 `notification` 기능에 둔다. 새 feature 폴더는 만들지 않는다.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| 새 화면에 mock 시나리오 없음(CLAUDE.md "실서버·mock 구현을 둘 다", "mock은 정상 경로 이상") | 백엔드가 배포 서버에 모두 올라가 있고, 사용자가 남은 작업은 실서버로 바로 연동하기로 결정(2026-10-29). mock 시나리오 작성·유지 비용을 없앤다 | 기존 방식대로 mock을 두면 같은 동작을 두 번 구현해야 하고, 사용자가 명시적으로 원하지 않았다. 기존 mock 클래스는 인터페이스가 넓어진 만큼만 컴파일되게 맞추고(호출 시 안내 오류), 지우지 않는다(기존 테스트가 사용) |
