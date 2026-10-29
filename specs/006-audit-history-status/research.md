# Research: F5 감사 로그·이력 보존 (앱)

**Spec**: [spec.md](spec.md) · **대응 백엔드 spec**: `damsoWE/damso_server` `specs/006-audit-log-history`

## R1. API 명세 api-v0.10 받아 오기

- **Decision**: 구현 첫 작업으로 `/fetch-api api-v0.10`을 실행해 앱 사본(`docs/api/openapi.yaml`, 지금 0.8.0)을 갱신한다. 사본을 직접 고치지 않는다(constitution Contract-first).
- **v0.8 → v0.10 변경(이 기능과의 관계)**:
  | 변경 | 앱 영향 |
  |---|---|
  | `GET /api/v1/admin/inquiry-status` 추가(슈퍼 관리자 전용, 학급별 `waiting`·`confirmed`·`answered`) | **이 기능의 본체**(R2~R5) |
  | 원문 열람(`/content`)은 감사 기록 저장 실패 시 500 `INTERNAL_ERROR`, 원문 없음 | US3. 기존 오류 처리로 충분한지 확인(R6) |
  | 번역본 열람(`/refinement`)이 감사 대상이 됨. 기록 실패해도 200. 첫 열람 확인 전이 실패 시 500 | 앱 동작 변화 없음(오류는 기존처럼 서버 문구) |
  | 재시도·점검 요청·종료 감사 기록(실패해도 정상 처리) | 앱 동작 변화 없음 |
  | 답변 전송·종료에 `CONFLICT`(다른 요청이 같은 문의 처리 중, 3초) 추가 | F4 범위(PR #18). 이 브랜치에는 답변 화면이 없어 여기서 다루지 않는다 |
  | 목록 `page` 최대 10000 | 앱 영향 없음 |
  | JSON만 받음(415) | 앱은 JSON만 보낸다 |
- **확인**: v0.9·v0.10 어디에도 목록 `lastFollowUpAt`(백엔드 #28)은 아직 없다.
- **Alternatives**: 사본을 그대로 두고 화면만 만든다 → 계약 근거 없이 구현하게 되어 원칙 위반.

## R2. Figma ADM-4와 백엔드 결정의 차이

Figma ADM-4(`224-1387`)는 F5 백엔드 결정보다 먼저 그려졌다. 백엔드 spec 006 Clarifications·FR-014/015가 금지한 항목이 있다.

| Figma ADM-4 | 백엔드 결정 | 앱 결정 |
|---|---|---|
| "이번 주" 기간 묶음 | 기간 필터 없음 | **"전체"**로 표시(기간 문구 없음) |
| 요약 카드 "전체 문의 · 긴급 · 처리 중 · 답변 완료" | 긴급 건수 금지, 묶음은 waiting·confirmed·answered | 요약 카드 **"전체 문의 · 답변 대기 · 교사 확인 · 답변 완료"**(4칸 유지, 긴급 칸 → 답변 대기, 처리 중 → 교사 확인) |
| 학급 카드 "3학년 2반 · 이○○" / "문의 5 · 처리 중 2 · 긴급 1" | 교사 정보·긴급 없음 | 1줄 **"3학년 2반 · 담임 연결됨/담임 미연결"**(학급 목록의 `homeroomAssigned`), 2줄 **"문의 N · 답변 대기 a · 교사 확인 b · 답변 완료 c"** |
| "담임 미연결" 카드 2줄 "교사 코드 발행 · 20시간 남음" | 현황 API에 코드 정보 없음 | 미연결 학급도 같은 건수 줄. 누르면 학급 상세(ADM-1)로 가서 교사 코드를 발행한다(ADM-2 화면은 학급 상세 안에 이미 있음) |
| 상단 안내 "관리자는 문의 건수와 처리 상태만 볼 수 있어요. 문의 내용과 답변은 볼 수 없어요." | 같음 | **그대로**(SystemNotice) |
| 🔔(ADM-8 코드 발행 요청) | 이 기능 밖 | 두지 않는다 |

- **Decision**: 위 "앱 결정" 열대로 만든다. **Figma 원본도 같은 내용으로 고친다**(F4 때처럼 Figma 먼저 → 코드). Figma 수정은 사용자 확인 뒤 구현 첫 단계에서 한다.
- **요약 카드 합계**: "전체 문의"와 세 묶음 합계는 학급별 서버 값을 더한 것이다. 묶음을 다시 나누거나 단계로 다시 계산하지 않는다 — spec FR-002 "다시 계산하지 않는다"의 뜻(서버 분류 그대로)을 지킨다.
- **Alternatives**: Figma 그대로 긴급·기간 표시 → 백엔드가 값을 주지 않고, 소규모 학급에서 학생 추정 위험(백엔드 Clarifications).

## R3. 관리자 하단 탭

- **Decision**: 관리자도 교사·학부모처럼 `StatefulShellRoute.indexedStack` 탭 셸을 만든다. 탭: **홈**(`/admin`, ADM-1a) · **문의**(`/admin/inquiries`, ADM-4) · **마이페이지**(`/admin/me`, ADM-7). 탭 이름·아이콘은 Figma TabBar(홈·문의·마이페이지)를 따른다.
  - 탭 위에 띄우는 화면(`/admin/classrooms/new`, `/admin/classrooms/:id` 과 그 하위, `/admin/invite/confirm`, `/admin/invite/issued`)은 교사 셸처럼 셸 밖 GoRoute로 옮긴다(경로 문자열은 그대로).
  - 관리자 홈 AppBar의 "마이페이지" 아이콘은 탭으로 대체되므로 뺀다.
- **Rationale**: `docs/ia.md` 하단 탭 표와 Figma가 탭 구조다. 경로 문자열을 바꾸지 않아 redirect 규칙(`/admin` 접두어)·기존 테스트가 그대로 맞는다.
- **Alternatives**: 홈에서 push로 현황 화면 열기 → Figma·IA와 다르고, 나중에 탭으로 옮길 때 다시 바꿔야 한다.

## R4. 현황 + 학급 이름 합치기

- **Decision**: `AdminRepository`에 `inquiryStatus()`를 더한다(같은 admin 기능, 새 Repository를 만들지 않음). `InquiryStatusViewModel`(`AsyncNotifier`)이 `inquiryStatus()`와 `listClassrooms()`를 **함께** 요청한다.
  - 현황이 실패하면 화면 전체 오류(서버 `message` + 다시 시도).
  - 학급 목록만 실패하면 건수는 보이고 학급 이름은 "학급", 담임 표시는 숨긴다(spec Edge Case).
  - 순서는 서버 현황 순서(학년·반 순, API 설명).
  - 학급 목록에 없는 `classroomId`는 이름 "학급".
- **Rationale**: 현황 API는 학급 이름을 주지 않는다. 학급 목록은 관리자 홈이 이미 쓰는 API라 새 계약이 없다.
- **Alternatives**: 관리자 홈 ViewModel 상태를 재사용 → 탭 간 결합. 이름 없이 ID만 → 식별 불가.

## R5. 상태 화면

- **Decision**: 기존 `AsyncView`(로딩·오류+다시 시도·빈 상태)를 쓴다.
  - 학급이 0개: "등록된 학급이 없습니다. 학급을 추가해 주세요."(관리자 홈과 같은 문구)
  - 학급은 있고 모두 0건: 목록을 그대로 보이고 요약 위에 "아직 접수된 문의가 없어요." 안내(SystemNotice)
  - 403: AsyncView 오류에 서버 문구(다른 오류와 같은 경로)
  - 당겨서 새로 고침·탭 재진입 시 다시 불러오기(`ref.invalidate`/`RefreshIndicator`)
- **Rationale**: 기존 패턴 재사용, 서버 `message`만 보이는 규칙(원칙 VI)이 이미 들어 있다.

## R6. 원문 열람 기록 실패(US3)

- **Decision**: 코드 변경 없이 동작을 확인하고 테스트로 고정한다.
  - F3-6(`ContentViewModel`): 원문 요청이 실패하면 `AsyncView` 오류(서버 문구 + 다시 시도). 성공 전에는 원문이 없으므로 "이전 원문이 남는" 경우가 없다.
  - F3-5(`UrgentDetailViewModel`): 원문을 먼저 부르므로 실패하면 **화면 전체가 오류**(서버 문구 + 다시 시도)다. spec US3-2의 "긴급 안내 문구는 그대로 보인다"는 바꾸지 않고 현재 동작(화면 전체 오류)으로 spec을 맞춘다 — 긴급 안내만 따로 띄우려면 상세·원문 요청 분리가 필요해 F3 화면 구조를 바꾸게 되고, 원문이 없는 긴급 상세는 쓸모가 적다.
- **mock**: 원문 기록 실패 데모 문의 1건을 더한다. 첫 원문 요청은 500 `INTERNAL_ERROR`("요청을 처리하지 못했습니다. 잠시 후 다시 시도해 주세요."), 다시 시도하면 성공.

## R7. mock

| 경우 | 재현 |
|---|---|
| 현황 정상 | mock 학급(관리자 홈과 같은 학급들)마다 다른 건수, 1개 학급은 0 |
| 모든 학급 0 | 새로 만든 학급만 있는 상태 — mock에서 학급을 추가하면 그 학급은 0. "모두 0"은 ViewModel 테스트(가짜 Repository)로 확인 |
| 403 | 슈퍼 관리자가 아닌 토큰으로 `inquiryStatus()` → 403 `FORBIDDEN`(Repository 테스트). 화면은 redirect가 막으므로 UI 데모는 없다 |
| 401 갱신 | **관리자 갱신 데모 계정 `refresh-admin@damso.test` 추가**(F4의 `refresh-teacher@`와 같은 방식, 첫 현황 조회만 갱신 지연을 흉내) — F1 mock(`mock_auth_repository.dart`·`mock_me_repository.dart`)을 고친다. **사용자 승인 필요** |
| 원문 열람 기록 실패 | R6 데모 문의 |

## R8. 테스트

- `AdminRepositoryImpl.inquiryStatus` 해석(정상·필드 누락 → 일반 오류·403 message) — 기존 `admin_repository_impl_test` 패턴.
- `InquiryStatusViewModel`: 두 요청 동시 시작, 학급 이름 합치기, 학급 목록 실패 시 "학급", 모두 0 안내 여부, 현황 실패 → 오류.
- 위젯: 탭 3개, 현황 화면 글자에 `@`·학생 이름·"긴급"·"이번 주" 없음, 학급 누르면 학급 상세.
- 라우터: `/admin/inquiries`가 관리자에게만 열림(redirect 테스트에 추가).
- 타임라인(US2): 기존 `stage_timeline_test`로 처리 단계만 그리는지 확인, 감사 화면 경로 없음은 라우터 경로 목록으로 확인.
