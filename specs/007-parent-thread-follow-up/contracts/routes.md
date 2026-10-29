# 경로: 학부모 스레드·이어서 묻기·알림 설정

모든 새 경로는 `/parent/` 아래라 `resolveRedirect`의 역할 규칙(학부모만)과 경로 ID UUID 검사(PR #25)를 그대로 받는다. 학생 이름 등 화면 표시값은 URL이 아니라 `extra`로 넘긴다.

| 경로 | 화면 | 셸 | 진입 | extra |
|---|---|---|---|---|
| `/parent/inquiries/:inquiryId/thread` | 스레드 F4-1 | 셸 밖(뒤로 가기) | 목록·홈 카드, 접수 화면 "보낸 문의 보기", 답변 알림 | 없음(상세를 다시 불러옴) |
| `/parent/inquiries/:inquiryId/follow-up` | 이어서 묻기 F4-1a | 셸 밖 | 스레드 "이어서 묻기" | `FollowUpArgs(studentName)` — 없으면 스레드로 redirect |
| `/parent/settings/notifications` | 알림 설정 F2-8 | 셸 밖 | 마이페이지 "알림 설정" | 없음 |

## 이동 규칙

- **목록·홈 카드**(R6): `summary.urgent && !summary.hasAnswer` → `/parent/inquiries/:id/urgent`(기존), 그 밖 → `/parent/inquiries/:id/thread` (`push`).
- **스레드 "이어서 묻기"** → `push('/parent/inquiries/:id/follow-up', extra: FollowUpArgs)`.
- **재문의 접수 성공** → `pushReplacement('/parent/inquiries/submitted', extra: SubmittedArgs(..., threadRootId))`. 접수 화면 "보낸 문의 보기": `threadRootId`가 있으면 `go('/parent/inquiries')` 뒤 `push(스레드)`로 스레드가 목록 위에 오게 하고(뒤로 → 목록), 없으면 지금처럼 `go('/parent/inquiries')`.
- **스레드 "문의 목록으로"** → `go('/parent/inquiries')`.
- **답변 알림**(R7): 학부모로 로그인 상태면 `push('/parent/inquiries/:id/thread')`. 로그인 전이면 대기 경로로 두고, 학부모 셸이 뜬 뒤 그 위에 띄운다(교사 셸과 같은 방식). 다른 역할로 로그인하면 버린다.
- **마이페이지 "알림 설정"** → `push('/parent/settings/notifications')`.
