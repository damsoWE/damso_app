# API 사용: F5 (api-v0.10)

원본: 백엔드 `docs/api/openapi.yaml` 태그 `api-v0.10`. 앱 사본은 `/fetch-api api-v0.10`으로 받는다(research R1).

| Repository 메서드 | 요청 | 성공 | 오류 |
|---|---|---|---|
| `AdminRepository.inquiryStatus()` (새로) | `GET /api/v1/admin/inquiry-status` | 200 `InquiryStatusSummary { items: [ClassroomInquiryStatus] }` → `List<ClassroomInquiryStatus>` | 401 → 인터셉터 갱신 · 403 `FORBIDDEN` → 서버 `message` · 네트워크 → 고정 안내 · 형식 오류 → 일반 안내 |
| `AdminRepository.listClassrooms()` (그대로) | `GET /api/v1/admin/classrooms` | 학급 이름·담임 연결 여부 | 실패해도 현황 화면은 열림(R4) |
| `TeacherInquiryRepository.content()` (그대로) | `GET /api/v1/teacher/inquiries/{id}/content` | 원문 | **v0.10**: 감사 기록 실패 → 500 `INTERNAL_ERROR`, 원문 없음 → 서버 `message` + 다시 시도(R6) |
| `TeacherInquiryRepository.refinement()` (그대로) | `GET .../refinement` | 번역본 | v0.10: 기록 실패해도 200. 첫 열람 확인 전이 실패 시 500 → 서버 `message` |

- 응답에 학생·학부모·교사 정보, 제목·본문이 없다(서버 보장). 앱도 현황 화면에 어떤 사람 정보도 더하지 않는다(학급 이름·담임 연결 여부만, 학급 목록에서).
- 현황 조회는 서버 감사 기록을 남기지 않는다. 앱도 따로 기록을 보내지 않는다.
