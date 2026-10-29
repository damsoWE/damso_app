# IA — 화면 트리·화면 상태

> 기준 디자인: Figma `디자인_semi_final` 페이지의 `담소 v3 · 컬러` 섹션 ([페이지 링크](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=106-4993))
> 원본 IA: `docs/소개딩_IA.pdf` (비공개). 기획서와 달라진 결정은 백엔드 레포 `docs/decisions.md`를 따른다.
> 화면 ID(C-0, F2-1 …)는 Figma 프레임 이름 앞부분과 같다. spec에는 아래 표의 **프레임 링크**를 붙인다.

## 탭 구조 (로그인 후)

로그인하면 서버가 내려준 역할(`PARENT` · `TEACHER` · `SUPER_ADMIN`)에 따라 앱이 홈을 고른다. 화면을 고르는 것은 앱이고, 권한 검사는 서버가 API마다 다시 한다.

| 역할 | 홈 탭 | 문의 탭 | 마이페이지 탭 | 🔔 알림 |
|---|---|---|---|---|
| 학부모 | F2-1 학부모 홈 | F2-4 나의 문의 목록 | F2-7 마이페이지 | F2-6 알림 목록 |
| 교사 | F3-4 교사 홈 | F3-1 문의 목록 | F3-7 마이페이지 | F3-11 알림 목록 |
| 학교 관리자 | ADM-1a 관리자 홈 | ADM-4 문의 현황 | ADM-7 마이페이지 | ADM-8 코드 발행 요청 |

## 프로토타입 흐름

Figma 프로토타입 탭에서 아래 흐름을 골라 재생하면 화면 이동을 눌러 볼 수 있다.

| 흐름 | 시작 화면 |
|---|---|
| ① 시작 · 초대코드 가입 | [285:6781](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=285-6781) |
| ② 학부모 · 문의·진행 상태 | [216:5162](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=216-5162) |
| ②-1 학부모 · 긴급 전달 | [216:5319](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=216-5319) |
| ③ 교사 · 문의 확인·답변 | [216:5567](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=216-5567) |
| ③-0 교사 · 가입 (코드 확인 후) | [225:1553](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=225-1553) |
| ④ 학교 관리자 · 명단·코드 | [216:5699](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=216-5699) |
| ⑤ 비밀번호 재설정 | [216:5029](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=216-5029) |

## 화면 트리

### 01 · 시작·가입·계정 ([섹션](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=216-5013))

| ID | 화면 | 주요 이동 |
|---|---|---|
| [C-0](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=285-6781) | 시작 | 로그인 → C-1 · 초대코드로 가입하기 → F1-1 |
| [C-1](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=224-1169) | 로그인 | 로그인 → 역할별 홈 · 비밀번호 재설정 → C-3 · 가입하기 → F1-1 |
| [C-1a](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=225-1512) | 로그인 잠금 (5회 실패, 10분) | 비밀번호 재설정 → C-3 · 가입하기 → F1-1 |
| [F1-1](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=216-5050) | 초대코드 입력 | 코드 확인 → F1-3 (교사 코드면 F1-3a) |
| [F1-2](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=216-5060) | 코드 오류 · 재입력 가능 | 다시 확인 → F1-3 |
| [F1-2b](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=216-5069) | 코드 입력 잠금 | 잠시 후 다시 확인 → F1-1 |
| [F1-3](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=216-5101) | 계정 만들기 · 학부모 | 동의하고 계정 만들기 → C-2 |
| [F1-3a](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=225-1553) | 계정 만들기 · 교사 (이름 입력 포함) | 동의하고 계정 만들기 → C-2 |
| [C-2](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=224-1185) | 이메일 인증 (6자리 코드) | 인증하고 가입 완료 → C-6 |
| [C-6](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=216-5082) | 담소 이용 안내 | 확인했어요 → 역할별 홈 |
| [C-3](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=216-5029) | 비밀번호 재설정 · 이메일 입력 | 재설정 코드 받기 → C-3b |
| [C-3b](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=216-5039) | 재설정 코드 입력 | 코드 확인 → C-4 |
| [C-3c](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=216-5143) | 코드 만료·횟수 초과 | 코드 다시 받기 → C-3b · 로그인으로 → C-0 |
| [C-4](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=216-5115) | 새 비밀번호 설정 | 비밀번호 변경 → C-5 |
| [C-5](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=216-5128) | 비밀번호 변경 완료 | 로그인하기 → C-0 |
| [C-7](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=225-1591) | 이용약관 · 개인정보 처리방침 | 확인 → 뒤로 |
| [C-9](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=225-1658) | 계정 정보 | 확인 → 뒤로 |
| [C-8](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=225-1623) | 회원 탈퇴 확인 | 취소 → 뒤로 · 탈퇴하기 → C-0 |

### 02 · 학부모 — 자녀와 진행 상태 ([섹션](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=216-5159))

| ID | 화면 | 주요 이동 |
|---|---|---|
| [F2-1](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=216-5162) | 학부모 홈 | 자녀 카드 → F2-1a · 문의 카드 → F4-1 · 문의 작성 → F2-2 · 🔔 → F2-6 |
| [F2-1b](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=216-5199) | 학부모 홈 · 문의 없음 (빈 상태) | 자녀 카드 → F2-1a · 문의 작성 → F2-2 |
| [F2-1a](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=216-5183) | 자녀 선택 | 선택한 자녀 확인 → 홈 · 자녀 추가 연결 → F1-5 |
| [F2-2](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=216-5213) | 문의 작성 | 문의 보내기 → F2-5 (긴급 판정이면 F2-3 계열) |
| [F2-5](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=216-5227) | 문의 접수 | 보낸 문의 보기 → F2-4 |
| [F2-5a](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=216-5258) | 전달 준비 지연 | 문의 목록으로 → F2-4 |
| [F2-3](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=216-5319) | 긴급 전달 · 그 밖의 안전 (번호 없음) | 보낸 문의 보기 → F2-4 |
| [F2-3c](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=216-5332) | 긴급 전달 · 자해 (109) | 보낸 문의 보기 → F2-4 |
| [F2-3d](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=216-5346) | 긴급 전달 · 학대 (112) | 보낸 문의 보기 → F2-4 |
| [F2-3b](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=216-5360) | 긴급 전달 · 기본 안내 (분류 실패·지연, 112·109) | 보낸 문의 보기 → F2-4 |
| [F2-4](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=216-5272) | 나의 문의 목록 | 카드 펼치기/접기 · 카드 → F4-1 / F4-1b / F2-3 · 새 문의 작성 → F2-2 |
| [F4-1](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=216-5241) | 문의 상세 (스레드) | 이어서 묻기 → F4-1a · 문의 목록 → F2-4 |
| [F4-1a](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=225-1722) | 이어서 묻기 | 보내기 → F2-5 |
| [F4-1b](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=225-1752) | 종료된 문의 (교사가 닫음) | 새 문의 작성 → F2-2 · 문의 목록 → F2-4 |
| [F2-6](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=216-5289) | 알림 목록 | 알림 → F4-1 / F2-4 · 안내 → F2-8 |
| [F2-7](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=224-1228) | 마이페이지 | 연결된 자녀 → F1-4 · 비밀번호 변경 → C-3 · 알림 설정 → F2-8 · 약관 → C-7 · 로그아웃 → C-0 · 회원 탈퇴 → C-8 |
| [F2-8](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=216-5303) | 알림 설정 | 뒤로 |
| [F1-4](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=224-1210) | 연결된 자녀 | 초대코드로 자녀 추가 → F1-5 |
| [F1-5](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=225-1692) | 자녀 추가 · 초대코드 입력 | 코드 확인 → F1-4 |

### 03 · 교사 — 답변 작성·점검·전송 ([섹션](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=216-5378))

| ID | 화면 | 주요 이동 |
|---|---|---|
| [F4-2a](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=216-5381) | 답변 작성 · 처음 | 입력 → F4-2a-2 |
| [F4-2a-2](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=216-5548) | 답변 작성 · 입력 완료 | 답변 점검 → F4-2b |
| [F4-2b](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=216-5397) | 답변 점검 중 (로딩) | 완료 시 → F4-2c (제안 없으면 F4-2e, 실패면 F4-2f) |
| [F4-2c](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=216-5411) | 점검 결과 · 고쳐 쓴 문장 제안 | 바꾸기 → F4-2c-1 · 답변 수정 → F4-2d · 직접 전송 → F4-2g |
| [F4-2c-1](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=216-5439) | 제안 적용 후 · 전송 전 확인 | 되돌리기 → F4-2c · 답변 수정 → F4-2d · 직접 전송 → F4-2g |
| [F4-2d](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=216-5467) | 답변 수정 · 재점검 | 다시 점검 → F4-2b · 직접 전송 → F4-2g |
| [F4-2e](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=216-5481) | 점검 완료 · 제안 없음 | 답변 수정 → F4-2d · 직접 전송 → F4-2g |
| [F4-2f](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=216-5493) | 점검 실패 · 작성 내용 보존 | 다시 점검 → F4-2b · 직접 확인 후 전송 → F4-2g |
| [F4-2g](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=216-5505) | 답변 전송 중 (로딩) | 완료 시 → F4-3 (실패면 F4-2h) |
| [F4-2h](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=216-5520) | 전송 실패 · 다시 보내기 | 다시 보내기 → F4-2g · 답변 수정 → F4-2d |
| [F4-3](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=315-1789) | 답변 전송 완료 · 스레드 | 최초 문의 카드 원문 보기 → F3-6 · 문의 목록으로 → F3-1 |
| [F4-3 · 재문의](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=315-1822) | 재문의가 있는 스레드 | 재문의 카드 → F4-3b · 문의 목록으로 → F3-1 |
| [F4-3b](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=323-1843) | 재문의 상세 (F3-2 배치, "… - 재문의") | 원문 보기 → F3-6 (재문의) · 답변 작성 → F4-2a (전송 뒤 스레드로) |
| [F3-6 · 재문의](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=323-1863) | 재문의 원문 열람 | 문의 상세로 → F4-3b · 답변 작성 → F4-2a |
| F4-3a | 답변 완료로 닫음 — **쓰지 않음** (spec 004 FR-017, Figma에서 삭제). 앱에는 닫기 기능이 없다 | — |

### 04 · 교사 — 문의 확인·연결 관리 ([섹션](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=216-5564))

| ID | 화면 | 주요 이동 |
|---|---|---|
| [F3-4](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=216-5567) | 교사 홈 | 긴급 카드 → F3-5 · 문의 카드 → F3-2 / F3-3 (답변한 문의 → F4-3) · 문의 목록 보기 → F3-1 · 🔔 → F3-11 |
| [F3-11](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=225-1833) | 알림 목록 (교사) | 알림 → F3-5 / F3-2 |
| [F3-1](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=216-5587) | 문의 목록 · 답변 대기 | [답변 대기 \| 답변 완료] 전환 → F3-1b · 긴급 → F3-5 · 일반 → F3-2 · 원문 확인 필요 → F3-3 |
| [F3-1b](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=352-1856) | 문의 목록 · 답변 완료 (답변이 1건 이상 있는 문의, 재문의가 와도 여기 남음 — spec 004 FR-031) | 답변한 문의 → F4-3 · 답변 대기 → F3-1 |
| [F3-5](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=224-1245) | 긴급 문의 상세 (원문 그대로) | 답변 작성 → F4-2a |
| [F3-2](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=216-5607) | 문의 상세 (정리본) | 원문 보기 → F3-6 · 답변 작성 → F4-2a |
| [F3-3](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=216-5627) | 원문 확인 필요 (정리 실패) | 원문 보기 → F3-6 · 다시 정리하기(1회) → F3-3a · 답변 작성 → F4-2a |
| [F3-3a](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=216-5640) | 다시 정리하는 중 | 원문 보기 → F3-6 · 문의 목록으로 → F3-1 |
| [F3-6](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=216-5653) | 원문 열람 (열람 기록) | 문의 상세로 → F3-2 · 답변 작성 → F4-2a |
| [F3-7](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=224-1263) | 마이페이지 (교사) | 공개 프로필 → F3-9 · 연결 현황 → F3-10 · 비밀번호 변경 → C-3 · 응답 가능 시간·알림 → F3-8 · 약관 → C-7 · 로그아웃 → C-0 · 회원 탈퇴 → C-8 |
| [F3-9](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=224-1317) | 공개 프로필 편집 | 저장 → 뒤로 |
| [F3-10](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=216-5666) | 학부모 연결 현황 | 관리자에게 재발행 요청 → F3-10a |
| [F3-10a](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=216-5683) | 재발행 요청 완료 | 연결 현황으로 → F3-10 |
| [F3-8](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=224-1287) | 응답 가능 시간·알림 설정 | 저장 → 뒤로 |

### 05 · 학교 관리자 — 명단·코드 관리 ([섹션](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=216-5696))

| ID | 화면 | 주요 이동 |
|---|---|---|
| [ADM-1a](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=216-5699) | 관리자 홈 · 학교 전체 명단 현황 | 학년·학급별 명단 → ADM-1b · 학생 명단 등록 → ADM-5 · 교직원 명단 → ADM-9 · 🔔 → ADM-8 |
| [ADM-1b](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=216-5716) | 학급별 등록 현황 | 학급 → ADM-1 · 학급 추가 → ADM-1c · 학생 명단 등록 → ADM-5 |
| [ADM-1c](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=225-1862) | 학급 추가 | 학급 추가 → ADM-1b |
| [ADM-1](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=224-1343) | 학급 상세 · 학생 명단 | 학생 등록 → ADM-5 · 코드 만료 학생 → ADM-6 · 학부모 코드 발행 → ADM-3 |
| [ADM-5](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=216-5736) | 학생 등록 | 등록 → ADM-5a |
| [ADM-5a](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=216-5748) | 학생 등록 완료 | 보호자 초대코드 발행 → ADM-3 · 학급 명단으로 → ADM-1b |
| [ADM-3](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=216-5828) | 학부모 코드 발행 완료 (1회 표시) | 목록으로 → ADM-8 |
| [ADM-8](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=216-5779) | 코드 발행 요청 목록 | 요청 확인 → ADM-6 |
| [ADM-6](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=216-5761) | 코드 재발행 확인 | 새 코드 발행 → ADM-3 · 취소 → 뒤로 |
| [ADM-4](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=224-1387) | 문의 현황 (건수·상태만) | 학급 → ADM-1 · 담임 미연결 학급 → ADM-2 |
| [ADM-2](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=224-1374) | 교사 초대코드 발행 | 교사 코드 발행 → ADM-3t |
| [ADM-3t](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=227-1743) | 교사 코드 발행 완료 (1회 표시) | 문의 현황으로 → ADM-4 |
| [ADM-9](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=216-5803) | 교직원 명단 | 교직원 등록 → ADM-9a |
| [ADM-9a](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=216-5818) | 교직원 등록 | 등록하기 → ADM-9 |
| [ADM-7](https://www.figma.com/design/LAQp2ZzMBavuZjjtH1bXFH/%EB%8B%B4%EC%86%8C-%EB%94%94%EC%9E%90%EC%9D%B8?node-id=216-5790) | 마이페이지 (관리자) | 계정 정보 → C-9 · 비밀번호 재설정 → C-3 · 담소 이용 안내 → C-6 · 로그아웃 → C-0 |

총 77개 화면. 화살표 아이콘(뒤로)은 모든 하위 화면에서 이전 화면으로 돌아간다.

## 화면별 상태

한 기능 안에서 상태별로 따로 그려 둔 화면이다. 구현할 때 같은 화면의 상태로 묶어도 된다.

| 상태 | 화면 |
|---|---|
| 로딩 (버튼 `Type=Loading`) | F4-2b 답변 점검 중 · F4-2g 답변 전송 중 · F3-3a 다시 정리하는 중 |
| 빈 목록 | F2-1b 학부모 홈 · 문의 없음 |
| 입력 오류 | C-1 로그인 오류(2/5회) · F1-2 코드 오류 |
| 잠금 (5회 실패 → 10분) | C-1a 로그인 잠금 · F1-2b 코드 입력 잠금 · C-3c 재설정 코드 만료·횟수 초과 |
| 처리 지연 | F2-5a 전달 준비 지연 |
| 긴급 표시 | F2-3 · F2-3b · F2-3c · F2-3d (학부모) · F3-5 (교사) |
| 원문 확인 필요 | F3-3 → 다시 정리하기 1회 → F3-3a |
| 실패 후 재시도 | F4-2f 점검 실패 · F4-2h 전송 실패 |
| 종료된 문의 | F4-1b (학부모) · 교사 F4-3a는 쓰지 않음 (spec 004 FR-017) |
| 1회만 보이는 값 | ADM-3 · ADM-3t 초대코드 발행 완료 |

## 아직 정해지지 않은 것

- C-7 약관·C-8 회원 탈퇴 문구는 임시 문안이다. 탈퇴 시 계정 정보 처리는 백엔드 `docs/features.md` F1 미정 항목.
- ~~교사가 대화를 닫는 행동의 이름("답변 완료")과 답변을 보낸 상태의 태그("답변 완료")가 겹친다.~~ → 해결: 앱에 닫기 기능을 두지 않는다(spec 004 FR-017). "답변 완료"는 답변을 보냈다는 표시로만 쓴다.
- 답변한 문의에 재문의가 오면 답변 대기로 돌려보내는 동작은 서버 목록에 재문의 시각이 생긴 뒤 켠다(백엔드 damsoWE/damso_server#28, spec 004 FR-031).
- 로그인 응답에 역할 필드를 별도로 넣을지는 백엔드 F1 plan에서 정한다.
