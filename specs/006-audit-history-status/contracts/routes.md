# 화면 경로: F5

관리자 탭 셸을 새로 만든다(research R3). 경로 문자열은 기존 그대로이고 `/admin/inquiries`만 새로 생긴다.

| 경로 | 화면 | 위치 |
|---|---|---|
| `/admin` | ADM-1a 관리자 홈 | 탭 "홈" |
| `/admin/inquiries` (새로) | ADM-4 문의 현황 | 탭 "문의" |
| `/admin/me` | ADM-7 마이페이지 | 탭 "마이페이지" |
| `/admin/classrooms/new` | ADM-1c 학급 추가 | 탭 위(셸 밖) |
| `/admin/classrooms/:classroomId` (+ `students/new`, `invite-codes`) | ADM-1 학급 상세 | 탭 위(셸 밖) |
| `/admin/invite/confirm`, `/admin/invite/issued` | ADM-6 · ADM-3 | 탭 위(셸 밖) |

이동

| 출발 | 동작 | 도착 | 방식 |
|---|---|---|---|
| ADM-4 | 학급 카드 누름 | `/admin/classrooms/:classroomId` | `push` |
| 관리자 홈 | (AppBar 마이페이지 아이콘) | — | 탭으로 대체, 아이콘 제거 |

redirect: 바꾸지 않는다. `/admin/inquiries`는 `/admin` 접두어라 슈퍼 관리자만 열리고, 다른 역할은 자기 홈으로 간다. 감사 기록 화면 경로는 없다(spec FR-009).
