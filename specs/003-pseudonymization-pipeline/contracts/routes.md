# 경로 계약 (F3)

F2의 라우터(`lib/app/router.dart`, 탭 셸)를 그대로 쓰고 교사 문의 상세 경로만 바꾼다. 상세 화면들은 F2의 긴급 상세처럼 **루트 Navigator**(탭 위)에 쌓인다.

| 경로 | 화면 | 변경 | 접근 |
|---|---|---|---|
| `/teacher/inquiries/:inquiryId/urgent` | F3-5 긴급 문의 상세 | 그대로 | 교사 |
| ~~`/teacher/inquiries/:inquiryId/pending`~~ | ~~준비 중~~ | **삭제**([research R9](../research.md#r9-기존-준비-중-자리-정리)) | — |
| `/teacher/inquiries/:inquiryId/general` | 일반 문의 상세: F3-2 / F3-3 / F3-3a / 정리 중 | **신규** | 교사 |
| `/teacher/inquiries/:inquiryId/content` | F3-6 원문 열람 | **신규** | 교사 |

## 이동

| 출발 | 동작 | 도착 | 방식 |
|---|---|---|---|
| F3-1 목록 · F3-4 홈 | 일반 문의 누름 | `/general` | `push` (`TeacherInquiryTile.pathOf`) |
| F3-1 · F3-4 | 긴급 문의 누름 | `/urgent` | `push` (그대로) |
| `/general` | 원문 보기 | `/content` | `push` |
| `/content` | 문의 상세로 · 뒤로 | `/general` | `pop` → 상세가 상태 다시 읽기 |
| `/general`(F3-3a·정리 중) | 문의 목록으로 | F3-1 | `go('/teacher/inquiries')` |
| `/general` | 상세가 긴급 문의로 확인됨(경쟁·잘못된 주소) | `/urgent` | `replace` |

## redirect

`resolveRedirect` 한 곳에서 `/teacher/` 경로는 교사만 들어온다(F2 규칙 그대로). 새 경로 2개도 이 규칙에 들어가며 `router_redirect_test.dart`에서 학부모·슈퍼 관리자가 각 역할 홈으로 가는지 확인한다.

## 알림

일반 문의 알림을 누르면 F2처럼 문의 목록(F3-1)으로 간다(묶음 알림일 수 있음). 바꾸지 않는다.
