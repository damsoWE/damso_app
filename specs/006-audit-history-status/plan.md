# Implementation Plan: F5 감사 로그·이력 보존 — 처리 단계 타임라인 · 관리자 문의 현황

**Branch**: `features/f5-audit-history` (이슈 #19) | **Date**: 2026-10-29 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/006-audit-history-status/spec.md` · 대응 백엔드 spec `damsoWE/damso_server` `specs/006-audit-log-history` (api-v0.10)

## Summary

감사 기록은 서버가 모두 남긴다. 앱은 (1) 슈퍼 관리자 탭 셸과 ADM-4 "문의 현황" 화면(학급별 답변 대기·교사 확인·답변 완료 건수, 내용·사람 정보 없음), (2) 학부모·교사 타임라인이 처리 단계만 보이는지 확인, (3) 원문 열람이 기록 실패(500)로 거부될 때 원문 없이 서버 문구만 보이는지 확인을 맡는다. 계약은 api-v0.10의 `GET /admin/inquiry-status` 하나가 새로 생긴다. Figma ADM-4는 백엔드 결정(긴급·기간 없음)에 맞춰 고친 뒤 구현한다(research R2).

## Technical Context

**Language/Version**: Dart 3 / Flutter 3.38.3

**Primary Dependencies**: flutter_riverpod 3 (Notifier/AsyncNotifier), go_router (StatefulShellRoute), dio — 새 패키지 없음

**Storage**: 없음(현황·원문은 화면이 열려 있는 동안 메모리에만)

**Testing**: flutter_test (ViewModel·Repository 단위, 위젯·라우터)

**Target Platform**: Android · iOS

**Project Type**: mobile-app (MVVM + Repository, feature-first)

**Performance Goals**: 현황 탭을 누른 뒤 3초 안에 표시(SC-001). 현황·학급 목록 요청은 동시에 시작

**Constraints**: 현황 화면에 사람 정보·제목·본문·긴급 없음(원칙 VII). 서버 `message`만 표시(원칙 VI). 사본 openapi는 `/fetch-api`로만 갱신

**Scale/Scope**: 새 화면 1개(ADM-4) + 관리자 탭 셸 + Repository 메서드 1개 + 엔드포인트 1개. mock 데모 계정 1개·데모 문의 1개

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| 원칙 | 판정 | 근거 |
|---|---|---|
| I. 연락처 미수집 | ✅ | 현황에 이메일·연락처 없음, 새 입력란 없음 |
| II. 가명화 게이트웨이 | ✅ 해당 없음 | 앱은 외부 LLM 호출 없음 |
| III. 원문 보존·열람 감사 | ✅ | 감사 기록은 서버가 남김. 수정·삭제·내보내기 UI 없음(FR-009). 원문은 서버 API로만, 기록 실패 시 원문 없음(US3) |
| IV. 긴급 우선 | ✅ | 긴급 표시·알림 변경 없음. 관리자 현황에 긴급 건수를 두지 않는 것은 서버 결정(소규모 학급 학생 추정 방지) |
| V. 제안만 | ✅ 해당 없음 | 답변 흐름 변경 없음. 상단 안내는 SystemNotice(시스템 발신) |
| VI. 민감정보 비노출 | ✅ | 로그 출력 없음. 오류는 서버 `message`만 |
| VII. 식별자·권한 | ✅ | 관리자 탭은 `/admin` redirect 그대로. 관리자는 메타데이터만(문의 목록·상세로 가는 이동 없음). 최종 판단은 서버(403) |
| VIII. 안전한 기본값 | ✅ | 시크릿 없음. mock 계정은 mock 전용 |
| 아키텍처 | ✅ | `AdminRepository`에 메서드 추가(인터페이스·실서버·mock), ViewModel은 인터페이스만 의존, DioException → AppException |
| mock 케이스 | ✅ | 정상·0건·403·401 갱신·원문 기록 실패(R7) |
| Contract-first | ✅ | `/fetch-api api-v0.10` 먼저(R1) |

재확인(Phase 1 뒤): 위반 없음. Complexity Tracking 비움.

## Project Structure

### Documentation (this feature)

```text
specs/006-audit-history-status/
├── plan.md
├── research.md            # R1 api-v0.10 · R2 Figma 차이 · R3 탭 셸 · R4 이름 합치기 · R5 상태 · R6 원문 실패 · R7 mock · R8 테스트
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── api-usage.md
│   └── routes.md
├── checklists/requirements.md
└── tasks.md               # /speckit-tasks
```

### Source Code (repository root)

```text
docs/api/openapi.yaml                                    # /fetch-api api-v0.10 (직접 수정 금지)
lib/app/router.dart                                      # 관리자 StatefulShellRoute, /admin/inquiries, 탭 위 경로를 셸 밖으로
lib/app/shells/admin_shell.dart                          # 새로: 홈 · 문의 · 마이페이지 탭
lib/features/admin/
├── domain/models.dart                                   # ClassroomInquiryStatus 추가
├── domain/admin_repository.dart                         # inquiryStatus() 추가
├── data/admin_repository_impl.dart                      # GET /admin/inquiry-status 해석
├── data/mock_admin_repository.dart                      # 학급별 건수(0 포함), 비관리자 403, refresh-admin 갱신 지연
└── presentation/
    ├── inquiry_status_page.dart                         # 새로: ADM-4
    ├── inquiry_status_view_model.dart                   # 새로: 현황 + 학급 목록 합치기
    └── admin_home_page.dart                             # AppBar 마이페이지 아이콘 제거(탭으로 대체)
lib/features/auth/data/mock_auth_repository.dart         # refresh-admin@ 계정 (R7, 사용자 승인 필요)
lib/features/me/data/mock_me_repository.dart             # refresh-admin 내 정보 (R7, 사용자 승인 필요)
lib/features/inquiry/data/mock_inquiry_store.dart        # 원문 기록 실패 데모 문의 (R6)
test/features/admin/                                     # repository·view model·위젯
test/core/router_redirect_test.dart                      # /admin/inquiries
test/features/mock_scenarios_test.dart                   # F5 시연
docs/ia.md                                               # ADM-4 표기·탭 반영
```

**Structure Decision**: 기존 feature-first 구조 그대로. 새 기능 폴더를 만들지 않고 `admin` 기능에 현황을 더한다(같은 역할·같은 Repository). 셸은 교사·학부모 셸과 같은 `lib/app/shells/`.

## 구현 순서

1. `/fetch-api api-v0.10` → 사본 갱신, 변경 요약(R1)
2. Figma ADM-4를 research R2대로 고침(사용자 확인 뒤)
3. 도메인·Repository(실서버·mock)·테스트
4. ViewModel·테스트
5. 관리자 탭 셸·라우터·현황 화면·위젯 테스트
6. mock 데모(refresh-admin, 원문 기록 실패 문의)·시연 테스트
7. 타임라인·원문 실패 확인 테스트(US2·US3)
8. `docs/ia.md`, `flutter analyze`·`flutter test`

## Complexity Tracking

없음.
