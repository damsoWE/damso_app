# Implementation Plan: 배포된 서버로 실연동 전환

**Branch**: `features/real-server-integration` (이슈 #13) | **Date**: 2026-10-28 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/005-real-server-integration/spec.md`

**대응 백엔드 spec**: `damsoWE/damso_server` `specs/001-auth-signup`, `specs/002-inquiry-intake-urgent`, `specs/003-pseudonymization-pipeline` · **API 계약**: `api-v0.4` → `api-v0.6`으로 갱신([research R1](./research.md#r1-배포-서버의-api-계약--api-v06)), 구현 중 백엔드 재배포로 `api-v0.7`([research R13](./research.md#r13-api-v07-재배포-대응))

## Summary

이미 만든 F1~F3 화면을 배포 서버(`https://damso.jibang.site`)에 연결해 끝까지 동작하는지 확인하고, 어긋난 곳을 고친다.

접근 방식: **코드 변경은 최소로 하고 검증이 중심이다.** 배포 서버는 `api-v0.6`이고, v0.4 → v0.6 변경은 F4 경로와 응답 필드 추가뿐이라 기존 파서·모델은 그대로 둔다(R2). 바꾸는 것은 네 가지다. 구현 중 `api-v0.7` 재배포로 목록 답변 여부(`hasAnswer`) 반영이 더해졌다(R13).
1. 계약 사본 갱신
2. 실행 설정(`env/example.json`·README)
3. Android main 매니페스트의 INTERNET 권한 — 승인 필요(R4)
4. E2E에서 발견한 불일치 수정

검증은 quickstart 시나리오를 두 기기로 수동 실행하고 `verification.md`에 남긴다(R9). 네트워크 오류 처리·푸시 없는 실행은 이미 구현되어 있어 확인만 한다(R5·R7).

## Technical Context

**Language/Version**: Dart ^3.10.1 (Flutter 3.38.3 stable)

**Primary Dependencies**: 기존 flutter_riverpod ^3.0.3 · go_router ^17.5.0 · dio ^5.11.1. **추가 없음**

**Storage**: 변경 없음

**Testing**: flutter_test(mock·가짜 `HttpClientAdapter`). 실서버 확인은 수동 E2E + `verification.md`(R9)

**Target Platform**: Android · iOS. E2E는 Android 에뮬레이터 2대(또는 에뮬레이터 + 실기기)

**Project Type**: mobile-app (Flutter, 백엔드는 별도 레포)

**Performance Goals**: 학부모 제출 후 교사 새로 고침 1회 안에 표시(SC-002) · 네트워크 끊김 시 15초 안에 안내(SC-004)

**Constraints**: mock 실행 유지(FR-002) · 계약 사본 직접 수정 금지 · 서버 쪽 불일치를 앱에서 우회 금지(FR-008, R10) · 계정·본문을 저장소·기록에 남기지 않음 · F4·위협 표시·푸시 실연동은 범위 밖

**Scale/Scope**: 검증 대상 API 경로 30개([contracts/api-usage.md](./contracts/api-usage.md)) · quickstart 시나리오 28개 · 확정 변경 파일 4개(`docs/api/openapi.yaml`, `env/example.json`, `README.md`, `android/app/src/main/AndroidManifest.xml`) + 새 기록 1개(`verification.md`) + 불일치 수정(개수 미정)

## Constitution Check

*GATE: Phase 0 전 확인, Phase 1 설계 후 재확인.*

| 원칙·요건 | 이 계획에서 | 결과 |
|---|---|---|
| I. 연락처 미수집 | 화면·입력 변경 없음. 검증 기록에 이메일 등 쓰지 않음(data-model §2) | ✅ |
| II. 가명화 게이트웨이 | 앱은 외부 AI를 부르지 않음 | ✅ (해당 없음) |
| III. 원문 보존·열람 감사 | 원문 열람은 기존 `/content` 경로 그대로. 기기 저장 없음 | ✅ |
| IV. 긴급 우선 | 긴급 표시 경로 변경 없음. 모르는 상태 값은 표시하지 않고 오류 안내(R6) | ✅ |
| V. 제안만 한다 | 답변 관련 경로(F4) 사용 안 함 | ✅ |
| VI. 민감정보 비노출 | 로깅 추가 없음. 검증 기록에 본문·실명·토큰·코드 값 금지. 오류는 서버 `message`만 | ✅ |
| VII. 식별자·권한 | 남의 문의 접근 거부를 실서버로 확인(Q3-5). 앱 쪽 권한 로직 변경 없음 | ✅ |
| VIII. 안전한 기본값 | `env/example.json`·`env/prod.json`에는 공개 서버 주소만. 관리자 계정은 저장소 밖(R8) | ✅ |
| 토큰 보관·갱신 단일 지점 | 인터셉터 그대로, 실서버로 갱신 확인(Q1-3) | ✅ |
| 아키텍처 | 구현 선택은 기존 provider + `USE_MOCK` 그대로. 화면 코드 변경 없음 | ✅ |
| mock 케이스 | 지우지 않음. `flutter test` 회귀 0건(SC-006) | ✅ |
| Contract-first | 사본은 `/fetch-api`로만 갱신(`api-v0.6` → `api-v0.7`) | ✅ |
| 릴리스 빌드 | release 실행 확인(Q6-3). 난독화 빌드 배포는 범위 밖 | ✅ |
| 큰 영향 결정 확인(CLAUDE.md) | **새 권한**: Android `INTERNET`을 main 매니페스트에 추가(R4) | ⏳ 구현 단계에서 승인 |

**재확인(Phase 1 후)**: data-model·contracts·quickstart 작성 후 새 위반 없음. Complexity Tracking 없음.

## Project Structure

### Documentation (this feature)

```text
specs/005-real-server-integration/
├── plan.md
├── research.md                          # R1~R12
├── data-model.md                        # 실행 환경 · 검증 기록 모양
├── quickstart.md                        # Q1~Q6 시나리오 28개
├── contracts/
│   ├── run-config.md                    # 배포·로컬·mock 실행 약속
│   └── api-usage.md                     # 경로 30개 ↔ 시나리오 ID
├── verification.md                      # 구현 단계에서 작성(FR-013)
├── checklists/requirements.md
└── tasks.md                             # /speckit-tasks
```

### Source Code (repository root)

```text
docs/api/openapi.yaml                    # 갱신: /fetch-api api-v0.6 → api-v0.7(R13)
env/example.json                         # 수정: API_BASE_URL → https://damso.jibang.site
README.md                                # 수정: 배포·로컬·mock 실행 방법
android/app/src/main/AndroidManifest.xml # 수정(승인 후): INTERNET 권한
lib/features/*/data/*_impl.dart          # E2E에서 앱 쪽 불일치가 나오면 해당 파일만
test/features/**                         # 불일치 수정마다 가짜 어댑터 회귀 테스트
```

바꾸지 않는 것: `lib/core/config/env.dart`, `lib/core/network/*`, `lib/core/error/*`, 각 Repository provider, 화면·ViewModel, mock 구현, `.gitignore`.

**Structure Decision**: 기존 feature-first 구조 그대로. 새 디렉터리·클래스 없음.

## 진행 순서 (tasks 입력)

1. **준비**: R1 재확인 → `/fetch-api api-v0.6` → `flutter analyze`·`flutter test` 통과 확인
2. **설정**: `env/example.json`·README 수정 → INTERNET 권한 승인 요청 후 추가
3. **E2E**: quickstart Q2 → Q1 → Q3 → Q4 → Q5 → Q6 순서(데이터 생성 순서)
4. **불일치 처리**: 발견할 때마다 R10 규칙(앱 수정 + 회귀 테스트 / 백엔드 이슈)
5. **마무리**: `verification.md` 정리 → `flutter analyze`·`flutter test` → PR(`Closes #13`)

## Complexity Tracking

없음.
