# 경로 계약 (F4 교사)

F2·F3 라우터(`lib/app/router.dart`, 탭 셸)를 그대로 쓰고 교사 경로 4개를 더한다. 모두 **루트 Navigator**(탭 위)에 쌓인다. 접근 제어는 `resolveRedirect` 한 곳의 `/teacher/` 규칙 그대로(교사만).

| 경로 | 화면 | 변경 | 비고 |
|---|---|---|---|
| `/teacher/inquiries/:inquiryId` | 문의 열기(로딩만) | **신규** | 상세를 읽고 `/thread`·`/urgent`·`/general` 중 하나로 `replace`(research R3) |
| `/teacher/inquiries/:inquiryId/answer` | F4-2a~F4-2h 답변 작성 | **신규** | `extra: AnswerTarget` 필수. 없으면(앱 재시작·딥링크) `/teacher/inquiries/:inquiryId`로 redirect |
| `/teacher/inquiries/:inquiryId/thread` | F4-3 스레드 | **신규** | |
| `/teacher/inquiries/:inquiryId/follow-ups/:followUpId` | 재문의 상세(F3-2 구성) | **신규** | `extra: FollowUpArgs` 필수. 없으면 `/teacher/inquiries/:inquiryId/thread`로 redirect(research R13) |
| `/teacher/inquiries/:inquiryId/urgent` · `/general` · `/content` | F3-5 · F3-2/3/3a · F3-6 | 그대로 | 하단에 "답변 작성" 버튼만 추가 |

`:inquiryId`는 언제나 스레드 루트 ID다(재문의 원문 열람 `/content`만 재문의 ID). URL에는 UUID만 넣는다.

## 이동

| 출발 | 동작 | 도착 | 방식 |
|---|---|---|---|
| F3-1 목록 · F3-4 홈 | 문의 누름 | `/teacher/inquiries/:id` | `push` (`TeacherInquiryTile.pathOf` 변경) |
| 문의 열기 | 답변 1건 이상 | `/thread` | `replace` |
| 문의 열기 | 답변 없음 · 긴급 | `/urgent` | `replace` |
| 문의 열기 | 답변 없음 · 일반 | `/general` | `replace` |
| F3-2·F3-3·F3-5·F3-6 | 답변 작성 | `/answer` (extra) | `push` |
| `/thread` | 최초 문의 카드 "원문 보기" | `/teacher/inquiries/:rootId/content` (extra: 루트 머리 정보) | `push`, 돌아오면 스레드 다시 읽기 |
| `/thread` | 재문의 카드 | `/follow-ups/:followUpId` (extra: `FollowUpArgs`) | `push`, 돌아오면 스레드 다시 읽기 |
| 재문의 상세 | 원문 보기 | `/teacher/inquiries/:followUpId/content` (extra: 제목 "… - 재문의") | `push` |
| 재문의 상세 · 재문의 원문 | 답변 작성 | `/teacher/inquiries/:rootId/answer` (extra: `AnswerTarget(fromThread: true, requests: 재문의 것)`) | `push` |
| `/answer` | 전송 성공(`fromThread`) | 스레드 | 스레드까지 `pop`, 스레드 다시 읽기(research R14) |
| `/answer` | 전송 성공(그 밖) | `/thread` | `replace`(뒤로 가면 진입했던 화면) |
| `/answer` | 뒤로(본문 있음) | 확인 후 이전 화면 | `pop` |
| `/thread` | 문의 목록으로 | F3-1 | `go('/teacher/inquiries')` |

## 알림

F2 그대로: 긴급 알림 → `/urgent`, 일반·묶음 알림 → F3-1. 바꾸지 않는다.

## redirect 테스트

`router_redirect_test.dart`에 새 경로 4개를 추가해 학부모·슈퍼 관리자가 각자 홈으로 가는지 확인한다.
