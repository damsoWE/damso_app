# 화면 경로·접근 계약 (go_router)

화면 ID는 `docs/ia.md`·Figma 프레임 이름과 같다. 접근 제어는 `GoRouter.redirect` 한 곳에서만 한다([research R7](../research.md#r7-화면-접근-제어라우터-가드)).

## 공개 (signedOut)

| 경로 | 화면 ID | 비고 |
|---|---|---|
| `/splash` | — | checking·unreachable 상태 전용 |
| `/` | C-0 시작 | |
| `/login` | C-1 / C-1a | 대기는 같은 화면의 상태 |
| `/signup` | F1-1 / F1-2 / F1-2b | 초대 코드 입력·오류·잠금 |
| `/signup/account` | F1-3 / F1-3a | 역할에 따라 문구 차이, 역할 모르면 중립 문구 |
| `/signup/verify` | C-2 | |
| `/password-reset` | C-3 | 로그인 상태에서도 접근 가능(마이페이지 "비밀번호 변경") |
| `/password-reset/code` | C-3b / C-3c | |
| `/password-reset/new` | C-4 | |
| `/password-reset/done` | C-5 | |
| `/terms` | C-7 | 로그인 상태에서도 접근 가능 |

## 로그인 후 공통

| 경로 | 화면 ID |
|---|---|
| `/welcome` | C-6 담소 이용 안내 (가입 직후 1회, 관리자 마이페이지에서도 열람) |
| `/me/account` | C-9 계정 정보 (이름 수정) |
| `/me/withdraw` | C-8 회원 탈퇴 (SUPER_ADMIN 접근 불가) |

## PARENT

| 경로 | 화면 ID | 비고 |
|---|---|---|
| `/parent` | F2-1 / F2-1b 학부모 홈 | 문의 영역은 F2. 이 작업에서는 자녀·담임 카드만 |
| `/parent/children/select` | F2-1a 자녀 선택 | |
| `/parent/me` | F2-7 마이페이지 | 알림 설정 메뉴는 F2에서 |
| `/parent/children` | F1-4 연결된 자녀 | |
| `/parent/children/add` | F1-5 자녀 추가 | |

## TEACHER

| 경로 | 화면 ID | 비고 |
|---|---|---|
| `/teacher` | F3-4 교사 홈 | 이 작업에서는 진입 화면만(문의는 F2) |
| `/teacher/me` | F3-7 마이페이지 | 응답 가능 시간 메뉴는 F2에서 |
| `/teacher/profile` | F3-9 공개 프로필 편집 | |
| `/teacher/links` | F3-10 학부모 연결 현황 | "재발행 요청" 버튼 없음(API 없음, 오프라인 요청 안내 문구만) |

## SUPER_ADMIN

| 경로 | 화면 ID |
|---|---|
| `/admin` | ADM-1a 관리자 홈 / ADM-1b 학급별 현황 (학급 목록) |
| `/admin/classrooms/new` | ADM-1c 학급 추가 |
| `/admin/classrooms/:classroomId` | ADM-1 학급 상세·학생 명단 (+ 교사 코드 발행 진입 ADM-2) |
| `/admin/classrooms/:classroomId/students/new` | ADM-5 / ADM-5a 학생 등록 |
| `/admin/classrooms/:classroomId/invite-codes` | 발행 현황 |
| `/admin/invite/confirm` | ADM-6 재발행 확인 |
| `/admin/invite/issued` | ADM-3 / ADM-3t 발행 완료(1회 표시, `extra`로만 전달) |
| `/admin/me` | ADM-7 마이페이지 |

이 작업에서 만들지 않는 관리자 화면: ADM-4 문의 현황, ADM-8 코드 발행 요청 목록, ADM-9/9a 교직원 명단.

## redirect 규칙

1. `checking`·`unreachable` → `/splash`.
2. `signedOut` → 공개 경로가 아니면 `/`.
3. `signedIn(justSignedUp)` → `/welcome`이 아니면 `/welcome`.
4. `signedIn(role)` →
   - 공개 전용 경로(`/`, `/login`, `/signup*`, `/splash`)면 역할 홈(`/parent`·`/teacher`·`/admin`).
   - 다른 역할의 경로(`/parent/**` 등)면 자기 역할 홈.
   - SUPER_ADMIN이 `/me/withdraw`면 `/admin/me`.
5. 그 외는 그대로.

URL에 담는 식별자는 UUID뿐이다(학급 ID). 학생 이름·코드 원문은 URL에 넣지 않는다.
