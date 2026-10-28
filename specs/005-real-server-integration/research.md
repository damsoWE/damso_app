# Research: 배포된 서버로 실연동 전환

**Date**: 2026-10-28 · **Spec**: [spec.md](./spec.md) · **Plan**: [plan.md](./plan.md)

## R1. 배포 서버의 API 계약 = `api-v0.6`

- **Decision**: 앱 사본을 `/fetch-api api-v0.6`으로 갱신한다. 손으로 고치지 않는다.
- **Rationale**: 백엔드 `deploy.yml`은 `main` push 때 배포한다. 2026-10-28 기준 `api-v0.6...main` 비교 결과 `ahead_by = 0`이라 배포본이 곧 `api-v0.6`이다. 배포 서버의 `/v3/api-docs`·Swagger는 401이라 직접 볼 수 없다.
- **Alternatives**: `api-v0.4` 유지 — 배포 서버와 사본이 어긋난 채 검증하게 되어 FR-003 위반. 배포 서버 문서 화면 열람 — 인증이 걸려 있어 불가.
- **갱신(2026-10-28 12:19 KST)**: 구현 중 백엔드가 `api-v0.7`로 재배포됐다(`api-v0.7...main` ahead_by = 0). 사본을 `/fetch-api api-v0.7`로 다시 받았다 → R13.
- **확인 방법(구현 시)**: 작업 시작 시점에 `gh api repos/damsoWE/damso_server/compare/api-v0.6...main --jq .ahead_by`를 다시 확인한다. 0이 아니면 새 태그를 백엔드에 요청한다.

## R2. v0.4 → v0.6 변경이 기존 화면에 주는 영향 = 없음(추가만)

`diff --strip-trailing-cr` 결과(352줄 변경)를 기존 화면 기준으로 나눴다.

| 변경 | 종류 | 기존 화면 영향 | 처리 |
|---|---|---|---|
| F4 경로 4개(`follow-ups`, `answer-reviews`, `answers`, `close`) | 추가 | 없음(앱이 부르지 않음) | 범위 밖(F4 별도 이슈) |
| `/api/v1/parent/notification-settings` | 추가 | 없음 | 범위 밖 |
| `ParentInquiryDetail.followUps`·`answers` | 필드 추가(required) | 파서는 모르는 키를 무시 | 무시. F4에서 사용 |
| `TeacherInquiryDetail.threatFlagged`·`followUps`·`answers` | 필드 추가 | 위와 같음 | 무시 |
| `TeacherInquirySummary.threatFlagged`·`threadThreatFlagged` | 필드 추가 | 위와 같음 | 무시. 위협·폭언 표시 UI는 새 화면 요소라 별도 이슈(spec "새 화면을 만들지 않는다") |
| `ErrorCode`에 `THREAD_CLOSED`·`INQUIRY_NOT_READY_TO_CLOSE` | 값 추가 | 기존 경로는 응답하지 않음 | `ErrorCodes` 상수 추가 안 함(F4에서) |
| enum(`InquiryStage`·`RefinementStatus`·`Role` 등) | 변경 없음 | — | — |

- **Decision**: 사본만 갱신하고 모델·파서 코드는 바꾸지 않는다. 실제 응답이 계약과 다른 부분은 E2E(R9)에서 찾는다.
- **Rationale**: 파서(`inquiry_json.dart` 등)는 필요한 키만 읽고, `mapDioErrors`가 `TypeError`·`FormatException`을 일반 안내로 바꾼다. 추가 필드는 깨지지 않는다.

## R3. 실행 설정 — `env/prod.json`, 저장소 규칙은 그대로

- **Decision**:
  - 배포 서버용 파일 이름은 `env/prod.json`(`API_BASE_URL=https://damso.jibang.site`, `USE_MOCK=false`).
  - `env/example.json`의 기본값을 배포 서버 주소로 바꾼다. `cp env/example.json env/prod.json`만으로 실행된다.
  - `env/dev.json`(로컬 서버 `10.0.2.2:8080`)과 `USE_MOCK=true` 실행은 그대로 둔다(FR-002).
  - `.gitignore`(`env/*.json`, `!env/example.json`)는 바꾸지 않는다.
  - README 실행 방법에 세 가지 실행(배포·로컬·mock)을 적는다.
- **Rationale**: 서버 주소는 공개 값이라 example에 둬도 원칙 VIII에 맞는다. ignore 규칙을 바꾸면 개인 설정 파일이 커밋될 위험이 생긴다.
- **Alternatives**: `.gitignore`에 `!env/prod.json` 예외 추가 — 팀 규칙 변경이라 이득에 비해 영향이 크다.

## R4. Android main 매니페스트에 INTERNET 권한이 없다 ⚠️

- **발견**: `android/app/src/debug/`·`profile/` 매니페스트에만 `android.permission.INTERNET`이 있고 `src/main/`에는 없다. debug 실행은 되지만 **release 빌드(`flutter run --release`, `flutter build apk`)는 서버에 연결하지 못한다.**
- **Decision**: `android/app/src/main/AndroidManifest.xml`에 `INTERNET` 권한을 추가한다. **새 권한이므로 구현 단계에서 사용자 승인을 받는다**(CLAUDE.md "Confirm before … new permissions").
- **Rationale**: 실서버 앱의 필수 권한이고, release 빌드 확인(난독화 옵션 포함)은 CLAUDE.md 규칙이다. iOS는 https라 ATS 설정 변경이 필요 없다.
- **Alternatives**: debug로만 확인 — 배포 전에 release에서 같은 문제가 다시 나온다.

## R5. 네트워크 실패·시간 초과 = 기존 처리로 충분, 코드 변경 없음

- **현재**: `dioProvider` connectTimeout 10초·receiveTimeout 20초. `AppException.fromDio`가 응답 없는 오류를 `networkMessage`로, 응답 있는 오류를 서버 `message`(없으면 고정 안내)로 바꾼다. `ProviderScope(retry: null)` + 화면의 다시 시도 버튼(F1 FR-041).
- **Decision**: 코드는 바꾸지 않고 quickstart의 비행기 모드 시나리오로 검증한다. 어긋나는 화면이 나오면 그 화면만 고친다.
- **SC-004(15초)와의 관계**: 연결 자체가 안 되면 OS가 즉시 실패시키거나 connectTimeout 10초 안에 끝난다. 서버가 연결 후 응답을 안 주는 경우는 최대 20초다. 이건 "네트워크 끊김"이 아니라 서버 지연이라 SC-004 대상이 아니다. receiveTimeout은 바꾸지 않는다(정리 결과 등 서버 처리가 긴 요청 보호).

## R6. 모르는 enum 값 = 오류 안내 + 다시 시도

- **현재**: `InquiryStage.fromServer` 등은 모르는 값이면 `FormatException` → `mapDioErrors`가 고정 안내로 바꾼다. 화면은 오류 상태(다시 시도)로 간다. 앱은 종료되지 않는다.
- **Decision**: 그대로 둔다. spec Edge Case "알 수 없는 상태로 표시"는 "화면이 깨지지 않는다"가 요지이고, 오류 안내로 충족한다. v0.6에서 enum이 바뀌지 않아(R2) 실제로 발생할 경로도 없다.
- **Alternatives**: `unknown` 값 추가 — 모든 화면에 새 분기가 필요하고, 원칙 IV(검증되지 않은 상태 표시 금지)와 부딪칠 수 있다.

## R7. 푸시 알림 없이 실서버 실행 = 이미 안전 (FR-014)

- **현재**: `initPushMessaging`은 `Env.hasFirebase`가 false면 초기화하지 않고, `pushMessagingProvider`는 `NoopPushMessaging`을 쓴다. `DeviceRegistrar`는 `isAvailable == false`면 등록하지 않으며 실패를 화면에 보이지 않는다.
- **Decision**: 코드 변경 없음. quickstart에서 `secrets/firebase.json` 없이 교사 로그인 → 교사 홈·알림 설정 화면에 오류가 없는지 확인한다.

## R8. 테스트 계정 확보

- 슈퍼 관리자: 서버가 환경변수 `DAMSO_SUPER_ADMIN_EMAIL`·`DAMSO_SUPER_ADMIN_PASSWORD`로 기동 때 1회 만든다(백엔드 `SuperAdminBootstrap`). 앱에는 생성 경로가 없다. 배포 담당자에게서 저장소 밖 경로로 받는다.
- 교사·학부모: 관리자가 앱에서 학급·학생을 만들고 초대 코드를 발급해 앱으로 가입한다(US4 → US1). 이 과정 자체가 검증 시나리오다.
- 가입 이메일 인증: 배포 서버가 실제 메일을 보내야 한다. 메일이 오지 않으면 백엔드 이슈로 올리고 그 시나리오는 "차단됨"으로 기록한다.
- **금지**: 계정 정보를 저장소·이슈·PR·검증 기록에 쓰지 않는다. 검증 기록에는 역할만 적는다.

## R9. 검증 방식 — 수동 E2E + 기록, 자동 테스트는 mock 유지

- **Decision**:
  - 실서버 검증은 에뮬레이터(또는 실기기)에서 quickstart 시나리오를 수동으로 실행하고 `verification.md`에 기능별 결과를 남긴다(FR-013).
  - `flutter test`는 지금처럼 mock·가짜 HttpClientAdapter로만 돈다. 실서버를 부르는 자동 테스트는 만들지 않는다.
  - 계약 불일치를 고칠 때는 그 응답 모양을 가짜 어댑터 테스트에 추가해 회귀를 막는다.
- **Rationale**: 실서버 자동 테스트는 배포 서버에 데이터를 계속 쌓고, 네트워크 때문에 CI가 흔들린다. 1회성 확인 + 기록이 이 기능 목적(실연동 확인)에 맞다.
- **Alternatives**: `integration_test` + 실서버 — 계정·데이터 정리 방법이 없어 보류.

## R10. 계약 불일치 처리 규칙 (FR-008)

| 원인 | 처리 |
|---|---|
| 앱이 계약을 잘못 따름(경로·필드 이름·타입) | 앱 수정 + 가짜 어댑터 테스트 추가 |
| 서버가 자기 계약(`api-v0.6`)과 다르게 응답 | 백엔드 레포에 이슈. 앱에서 우회 코드 금지. 검증 기록에 "백엔드 이슈 #N"으로 남김 |
| 계약에 없는 동작(예: 메일 미발송) | 백엔드에 확인 요청. 결과 나올 때까지 "차단됨" |

## R11. 배포 서버 오류 형식 확인

- `GET /api/v1/me`(인증 없이) → `401`, `{"code":"UNAUTHORIZED","message":"인증이 필요합니다."}`. `ErrorResponse` 형식이 계약과 같아 `AppException.fromDio`가 그대로 읽는다.
- `GET /actuator/health` → `200 {"status":"UP"}`.

## R12. 코드 주석의 계약 버전 표기

- `*_repository_impl.dart` 머리 주석에 `api-v0.3`이 남아 있다. 기능과 무관한 수정이라 이 기능에서는 바꾸지 않는다. 해당 파일을 불일치 때문에 고치게 되면 그때 함께 `api-v0.7`로 바꾼다.

## R13. api-v0.7 재배포 대응

구현 중(2026-10-28 12:19 KST) 백엔드가 `api-v0.7`로 재배포됐다. R2와 달리 기존 화면의 의미를 바꾸는 변경이 있다.

| 변경 | 영향 | 처리 |
|---|---|---|
| 목록 항목(`ParentInquirySummary`·`TeacherInquirySummary`)에 필수 `hasAnswer`·`lastAnsweredAt` | 파서는 무시해도 깨지지 않음 | 모델·파서에 반영(PR #14와 같은 커밋). 상세에는 두 필드가 없어 `answers`로 같은 값을 만든다 |
| 서버가 `ANSWERED` 단계를 만들지 않음(앱이 `/close`를 부르지 않음). 답변 여부는 `hasAnswer`로 판단 | `stage`만 보는 화면은 답변이 와도 "답변 완료"를 표시하지 못함 | 화면 표시 단계는 `displayStage`(`hasAnswer`면 답변 완료), 진행 표시의 "답변 완료" 칸은 `lastAnsweredAt`으로 채운다 |
| `POST /teacher/inquiries/{id}/close` deprecated(운영 404) | 앱에서 부르지 않음 | 변경 없음 |

- 이 변경 전에 실행한 E2E 시나리오는 v0.6 서버, 이후는 v0.7 서버 기준이다(`verification.md` 머리). 두 버전 모두 추가 필드뿐이라 기존 시나리오 결과는 유효하다.
