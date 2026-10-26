# 화면 경로·접근 계약 (F2)

F1의 [routes.md](../../001-foundation-auth-signup/contracts/routes.md)를 바탕으로 학부모·교사 경로를 **하단 탭 셸**로 바꾼다([research R2](../research.md#r2-하단-탭--statefulshellrouteindexedstack)). 슈퍼 관리자·공개 경로는 그대로다. 접근 제어는 지금처럼 `resolveRedirect` 한 곳에서만 한다.

표시: 🗂 = 탭 Navigator에 쌓임(탭 바 보임) · ⬆ = 루트 Navigator에 띄움(탭 바 가림)

## PARENT — 탭 셸 `/parent`

| 탭 | 경로 | 화면 ID | 비고 |
|---|---|---|---|
| 홈 | `/parent` | F2-1 / F2-1b | 문의 영역 추가(선택한 자녀의 최근 3건) |
| | `/parent/children/select` 🗂 | F2-1a | 기존 |
| 문의 | `/parent/inquiries` | F2-4 | 신규. 카드 펼치기로 타임라인 |
| 마이페이지 | `/parent/me` | F2-7 | 기존 |
| | `/parent/children` 🗂 · `/parent/children/add` 🗂 | F1-4 · F1-5 | 기존(마이페이지 탭 아래로 이동) |
| — | `/parent/inquiries/new` ⬆ | F2-2 | 신규. 대상 자녀는 홈 선택값 |
| — | `/parent/inquiries/submitted` ⬆ | F2-5 / F2-5a / F2-3 계열 | 신규. 결과는 `extra`(`SubmitOutcome`)로만 전달, 작성 화면을 **교체**(`go`) |
| — | `/parent/inquiries/:inquiryId/urgent` ⬆ | F2-3 계열 | 신규. 긴급 카드에서 안내 다시 보기(상세 응답으로 구성) |

- `/parent/inquiries/submitted`에 `extra` 없이 들어오면(앱 재시작·딥링크) `/parent/inquiries`로 보낸다.
- `/parent/children/select`는 홈 탭 안, `/parent/children`·`/add`는 마이페이지 탭 안이다(F2-7에서 "연결된 자녀"로 진입). 기존 경로 문자열은 바꾸지 않는다.

## TEACHER — 탭 셸 `/teacher`

| 탭 | 경로 | 화면 ID | 비고 |
|---|---|---|---|
| 홈 | `/teacher` | F3-4 | 긴급 카드·최근 문의 추가 |
| 문의 | `/teacher/inquiries` | F3-1 | 신규. 페이지 나눠 불러오기 |
| 마이페이지 | `/teacher/me` | F3-7 | "응답 가능 시간·알림" 메뉴 추가 |
| | `/teacher/profile` 🗂 · `/teacher/links` 🗂 | F3-9 · F3-10 | 기존(마이페이지 탭 아래) |
| — | `/teacher/inquiries/:inquiryId/urgent` ⬆ | F3-5 | 신규. 원문 1회 열람(research R8) |
| — | `/teacher/inquiries/:inquiryId/pending` ⬆ | — | 신규. 일반 문의 "준비 중" 안내(F3에서 F3-2/F3-3로 바뀜) |
| — | `/teacher/settings/notifications` ⬆ | F3-8 | 신규 |

## 공통

| 경로 | 비고 |
|---|---|
| `/inquiries` | **삭제**(FR-032). 이전 북마크·딥링크는 redirect가 역할 문의 탭(`/parent/inquiries`·`/teacher/inquiries`, 관리자는 `/admin`)으로 보낸다 |

## redirect 규칙 변경

F1 규칙 1~5를 그대로 두고 아래만 더한다.

- **4-a. 알림으로 연 경로**: redirect 는 바꾸지 않는다. 교사로 로그인하면 평소처럼 교사 홈(탭 셸)으로 가고, 셸이 뜬 뒤 `PendingNavigation`의 경로를 탭 화면 **위에** 띄운다(뒤로 가면 탭 화면). 교사가 아니거나 가입 직후면 비우기만 한다(data-model §5, 코드 리뷰 반영).
- **4-b. 옛 경로**: `/inquiries`(와 하위) → 역할 문의 탭.
- 탭 셸의 경로도 접두사(`/parent`, `/teacher`)로 역할을 가른다. 다른 역할의 경로면 자기 역할 홈으로(F1 규칙 그대로).

URL에 담는 식별자는 UUID뿐이다(문의 ID). 본문·학생 이름·안내 결과는 URL에 넣지 않고 `extra`로만 넘긴다.
