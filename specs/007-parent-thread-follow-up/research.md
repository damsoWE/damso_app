# Research: 학부모 문의 스레드·이어서 묻기·답변 알림

## R1. API 계약 기준 — 앱 사본 api-v0.11

- **Decision**: 앱 사본 `docs/api/openapi.yaml` `api-v0.11`(2026-10-29 확인, 백엔드 최신 태그와 같음)을 따른다.
- **Rationale**: 필요한 경로가 모두 있다 — `GET /api/v1/parent/inquiries/{inquiryId}`(followUps·answers 포함), `POST /api/v1/parent/inquiries/{inquiryId}/follow-ups`(Idempotency-Key), `GET`·`PUT /api/v1/parent/notification-settings`, `PUT /api/v1/me/devices`, `DELETE /api/v1/me/devices/current`.
- **Alternatives considered**: 없음. 새 태그가 나오면 `/fetch-api`로 다시 받는다.

## R2. 선행 작업 — PR #25(보안 수정) 위에서 구현

- **Decision**: 이 브랜치는 main(`d32c8d5`)에서 땄다. 구현(`/speckit-implement`) 전에 PR #25가 머지되면 `git rebase main`으로 올린다. 머지 전이면 구현을 미룬다.
- **Rationale**: 이 기능이 기대는 동작이 PR #25에 있다 — 로그아웃·탈퇴 때 기기 알림 토큰 폐기(FR-017), 배너 대기열 비우기(FR-019), 라우터의 경로 UUID 검사(R7), 로그아웃 때 알림 대기 경로 비우기. 같은 파일(`device_registrar.dart`, `push_listener.dart`, `router.dart`)을 양쪽에서 고치면 충돌한다.
- **Alternatives considered**: `fix/security-review`를 이 브랜치에 병합 — PR 두 개가 같은 변경을 담게 돼 리뷰가 꼬인다.

## R3. 스레드 데이터 — 학부모 상세 응답 하나로

- **Decision**: 스레드는 `GET /parent/inquiries/{id}` 한 번으로 그린다. `ParentInquiryDetail`에 `content`(처음 문의 원문), `followUps`(재문의), `answers`(답변)를 더하고, 화면용 `ThreadItem` 목록(처음 문의·답변·재문의를 시각순 병합)을 모델에서 만든다.
- **Rationale**: 계약상 학부모 상세에 스레드 전부가 시간순으로 들어 있다. 지금 해석기는 이 필드를 일부러 읽지 않는다(`inquiry_json.dart:71` "학부모 F4 화면의 몫").
- **Alternatives considered**: 별도 스레드 엔드포인트 — 계약에 없다.

## R4. 재문의 제출과 멱등키

- **Decision**: `ParentInquiryRepository.submitFollowUp({inquiryId, content, idempotencyKey})` → `FollowUpSubmitted`(inquiryId·threadRootId·urgent·submittedAt·notices·hotlines). 키 규칙은 처음 문의 작성(`compose_view_model.dart`)과 같다 — 같은(앞뒤 공백 뺀) 내용으로 다시 보내면 같은 키, 내용이 바뀌거나 성공하면 새 키.
- **Rationale**: FR-010(응답 유실 뒤 재시도해도 1건). 계약이 409 `CONFLICT`(같은 키·다른 내용, 또는 3초 안에 차례가 오지 않음 → 잠시 뒤 같은 키로 재시도)를 정의한다.
- **Alternatives considered**: 매 시도 새 키 — 중복 저장.

## R5. 접수·긴급 안내 화면 재사용

- **Decision**: 재문의 결과도 기존 `SubmitOutcome`(일반 접수·긴급 안내 종류·번호)으로 바꿔 기존 접수 화면(F2-5·F2-3 계열)을 그대로 쓴다. `SubmittedArgs`에 `threadRootId`(선택)를 더해, 있으면 "보낸 문의 보기"가 그 스레드로 가고 없으면 지금처럼 목록으로 간다.
- **Rationale**: 계약상 `FollowUpSubmitted`는 처음 문의 접수 결과와 같은 모양이다. 화면을 새로 만들 필요가 없다.
- **Alternatives considered**: 재문의 전용 접수 화면 — Figma·IA에 없다(F4-1a → F2-5).

## R6. 목록 카드 → 스레드 (Clarification A)

- **Decision**: `InquiryCard`의 펼치기/접기를 없앤다. 카드 탭 규칙: 처음 문의가 긴급이고 `hasAnswer == false`면 기존 긴급 안내(`/parent/inquiries/:id/urgent`), 그 밖에는 스레드(`/parent/inquiries/:id/thread`). 홈 문의 영역도 같은 규칙.
- **Rationale**: spec Clarifications 2026-10-29. 펼친 영역의 처리 단계는 스레드가 보여 준다.
- **Alternatives considered**: B·C안 — 사용자가 A를 골랐다.

## R7. 알림 종류·경로 — 역할별

- **Decision**: `PushKind.answer`('ANSWER')를 더한다. `PushData`가 이동 경로와 **그 경로의 역할**을 함께 알려 준다 — 긴급·재알림·일반·묶음은 교사, 답변은 학부모(`/parent/inquiries/{id}/thread`). 알림 리스너는 로그인 역할과 알림 역할이 같을 때만 배너·이동을 한다. 로그인 전이면 대기 경로로 두고, 로그인한 역할이 그 경로의 역할과 다르면 버린다. 문의 ID는 지금처럼 UUID일 때만 쓴다.
- **Rationale**: FR-018·FR-020. 백엔드 답변 알림의 `data.inquiryId`는 스레드 루트 ID다(`NotifyAnswerUseCase` 주석, 2026-10-29 확인).
- **Alternatives considered**: 역할 판단을 경로 문자열 접두어로만 — 동작은 같지만 의도가 코드에 드러나지 않는다.

## R8. 학부모 기기 등록·권한 요청

- **Decision**: `DeviceRegistrar`의 대상 역할을 교사에서 교사·학부모로 넓힌다(관리자는 제외). 권한 요청은 학부모 홈(F2-1) 첫 진입 때 `requestPermissionIfNeeded()` — 교사 홈과 같은 규칙. 등록·해제 API는 같은 `/me/devices`.
- **Rationale**: FR-015·FR-016. 기기 등록은 로그인 세션에 묶이고 역할과 무관하다(계약).
- **Alternatives considered**: 학부모 전용 등록기 — 같은 규칙을 두 번 구현하게 된다.

## R9. mock 없이 실서버 연동

- **Decision**: 새 화면용 mock 시나리오를 만들지 않는다. 인터페이스에 메서드가 늘어난 기존 mock 클래스(`MockParentInquiryRepository`)에는 호출되면 "이 실행에서는 지원하지 않습니다" `AppException`을 던지는 최소 구현만 둔다. 새 저장소(`ParentNotificationRepository`)의 provider는 실서버 구현만 고른다(mock 분기 없음). 화면 흐름은 배포 서버에서 E2E로 확인하고, 자동 테스트는 JSON 해석·ViewModel·라우터 단위로 둔다(테스트 전용 가짜 저장소는 앱 코드의 mock이 아니다).
- **Rationale**: 사용자 결정 2026-10-29. plan Complexity Tracking에 예외로 기록.
- **Alternatives considered**: mock 시나리오 작성 — 사용자가 원하지 않음.

## R10. 알림 설정 화면(F2-8)

- **Decision**: `notification` 기능에 `ParentNotificationRepository`(get/save, `answerNotifyEnabled`)와 `ParentSettingsViewModel`·`ParentSettingsPage`를 더한다. 저장은 낙관적 반영 없이 서버 성공 뒤 확정, 실패 시 원래 값 + 서버 안내(FR-023). 기기 알림 권한 안내는 교사 설정 화면이 쓰는 `pushPermissionProvider`를 재사용. 진입: 학부모 마이페이지 "알림 설정" → `/parent/settings/notifications`.
- **Rationale**: 교사 설정(F3-8)과 같은 기능 폴더·같은 권한 안내를 쓰면 일관된다. 학부모 설정은 값 하나라 저장 버튼 없이 토글이 바로 저장한다.
- **Alternatives considered**: 기존 `NotificationRepository`에 메서드 추가 — 교사·학부모 설정이 한 인터페이스에 섞이고, 기존 mock이 또 넓어진다.
