# Data Model: 배포된 서버로 실연동 전환

이 기능은 **domain 모델을 새로 만들거나 바꾸지 않는다**(research R2). 아래는 실행 설정과 검증 기록의 모양이다.

## 1. 실행 환경 (빌드 시점 값)

`--dart-define-from-file=env/<이름>.json`으로 주입한다. 읽는 곳은 `lib/core/config/env.dart` 한 곳.

| 키 | 타입 | 배포 서버 | 로컬 서버 | mock |
|---|---|---|---|---|
| `API_BASE_URL` | string | `https://damso.jibang.site` | `http://10.0.2.2:8080` | (비워도 됨) |
| `USE_MOCK` | bool | `false` | `false` | `true` |

규칙:
- 공개 값만 둔다. 계정·토큰·키 금지(원칙 VIII, FR-012).
- `USE_MOCK=false`인데 `API_BASE_URL`이 비면 기동을 거부한다(기존 `Env.ensureConfigured`).
- Firebase 값은 `secrets/firebase.json`으로 따로 주입한다(이 기능 범위 밖, R7).

파일별 계약은 [contracts/run-config.md](./contracts/run-config.md).

## 2. 검증 기록 (`verification.md`)

FR-013의 결과물. 구현 단계에서 만든다.

**시나리오 결과 한 줄**

| 필드 | 값 |
|---|---|
| ID | quickstart 시나리오 ID (예: `Q1-3`) |
| 역할 | 관리자 / 교사 / 학부모 (계정 정보는 쓰지 않는다) |
| 결과 | 통과 / 실패 / 차단됨 |
| 비고 | 실패·차단 이유, 관련 불일치 ID |

**계약 불일치 한 건**

| 필드 | 값 |
|---|---|
| ID | `M-<번호>` |
| 화면 | 화면 ID(`docs/ia.md`) 또는 화면 이름 |
| 경로 | `METHOD /api/v1/...` |
| 기대(계약) | `api-v0.6` 기준 |
| 실제 | 서버 응답의 모양(본문 값은 쓰지 않는다 — 원칙 VI) |
| 원인 | 앱 / 서버 / 계약에 없음 (research R10) |
| 처리 | 앱 수정(커밋) / 백엔드 이슈 링크 / 대기 |

상태: `발견` → `앱 수정됨` | `백엔드 이슈` → `해결 확인`.

기록 금지: 문의·답변 본문, 학생·학부모 실명, 이메일, 토큰, 초대 코드 값.
