# spec-kit 개발 가이드 (프론트엔드)

> 팀 공유 문서. 처음 합류한 팀원은 "개발 흐름"부터 읽는다.
> 스킬 정의: `.claude/skills/speckit-*/SKILL.md` · 산출물: `specs/NNN-기능명/`
> 백엔드 가이드(`damso/docs/speckit-guide.md`)를 프론트 기준으로 옮긴 문서다. 백엔드와 **다른 점**은 "프론트가 백엔드와 다른 점"에 모아 두었다.

## 처음 보는 사람을 위한 용어

| 용어 | 뜻 |
|---|---|
| constitution | 이 프로젝트의 **절대 규칙**. 기획서·spec보다 우선한다. `.specify/memory/constitution.md` |
| spec | 화면·기능이 **무엇을, 왜** 하는지. 기술 이야기는 없다. `spec.md` |
| plan | 그 화면을 **어떻게** 만들지. Flutter 구조·상태 관리·API 연동이 여기서 정해진다. `plan.md` |
| contract | 프론트와 백엔드가 주고받는 API 약속. **원본은 백엔드**, 프론트는 사본(`docs/api/openapi.yaml`)을 읽기만 한다 |
| tasks | plan을 실제 작업 단위로 쪼갠 체크리스트. `tasks.md` |
| mock | 서버 없이 앱을 돌리기 위한 가짜 Repository. `lib/mock/`, 실행은 `lib/main_mock.dart` |
| PR | Pull Request. 내 브랜치의 변경을 main에 합쳐 달라고 요청하고 리뷰받는 것 |

---

## 개발 흐름 — 화면(기능) 하나를 처음부터 끝까지

> 기능 하나(F1, F2 …)마다 아래 순서를 한 바퀴 돈다. **한 기능은 한 사람이 끝까지** 맡는다.
> 앱의 기능 번호(F1~F5)는 백엔드 `docs/features.md`와 같다.

### 0. 시작 전 — 이슈 만들고 브랜치 연결

> 규칙 원본: `CLAUDE.md`의 "Git Workflow". **main에 직접 푸시하지 않는다.** (프로젝트 초기 구축 단계의 설정·문서 커밋만 예외)

1. GitHub에서 이슈를 만든다 — New issue → **"기능 요청"** 템플릿, 제목 `[Feat] F1 로그인·회원가입 화면`
2. 이슈와 연결된 브랜치를 만든다 (기능은 `features/…`, 수정은 `fix/…`):

```bash
git switch main
git pull
gh issue develop <이슈 번호> --name features/f1-auth-signup --base main --checkout
```

이슈 화면의 "Development"에 브랜치가 보이면 연결된 것이다.

### 1. 무엇을 만들지 확인

세 가지를 같이 본다.

| 볼 것 | 어디 | 얻는 것 |
|---|---|---|
| 기능 정의 | 백엔드 레포 `docs/features.md`의 해당 섹션 | 왜, 사용자 시나리오, 결정된 규칙 |
| 디자인 | Figma 해당 **프레임 링크**(node-id 포함) | 화면 모양 |
| 화면 이동·상태 | `docs/ia.md`, `docs/소개딩_IA.pdf` | 어디로 이동하고 어떤 상태가 있는지 |

- constitution의 원칙 I~VIII와 "프론트엔드에서의 적용" 표도 한 번 훑는다.
- **대응하는 백엔드 spec이 있는지** 확인한다. 아직 없으면 mock으로 시작한다(아래 7단계).

### 2. spec 작성 — `/speckit-specify`

- 백엔드 features.md 섹션에서 **화면에 보이는 것만** 추린다(아래 [specify 입력 만드는 법](#specify-입력-만드는-법) 참고).
- `specs/001-기능명/spec.md`가 생긴다. **AI가 쓴 걸 그대로 믿지 말고 끝까지 읽는다.**
- spec 맨 위에 두 가지를 직접 적는다.
  - `대응 백엔드 spec: damso_server/specs/NNN-…` (번호는 레포마다 따로 매겨져서 꼭 적어야 한다)
  - `Figma: <프레임 링크>` + 디자인 기준 날짜

### 3. 모호한 곳 정리 — `/speckit-clarify`

- AI가 최대 5개 질문을 한다. 답하면 spec에 반영된다.
- 프론트에서 자주 나오는 질문: 빈 목록·로딩·오류 때 무엇을 보여 줄지, 뒤로 가기 동작, 입력 검증 문구.
- 모르는 질문은 혼자 정하지 말고 팀에 묻는다. 기획서·IA와 달라지면 백엔드 레포 `docs/decisions.md`에 한 줄 추가한다.

### 4. 설계 — `/speckit-plan`

- 여기서 처음으로 기술 스택을 말한다.
  ```
  /speckit-plan Flutter 3.38 / Dart 3.10, Android·iOS. flutter_riverpod 3.x,
  go_router, dio(Interceptor 단일 지점), flutter_secure_storage.
  lib/features/<기능>/{data,domain,presentation} 구조, Repository 인터페이스 +
  provider override로 mock 교체. API는 docs/api/openapi.yaml 을 따른다.
  ```
- 프론트 plan은 **API 계약을 새로 만들지 않는다.** 필요한 API가 `docs/api/openapi.yaml`에 없으면 만들지 말고 백엔드에 요청한다(5단계).
- plan이 constitution 위반 여부를 스스로 점검한다(Constitution Check). 위반이 나오면 무시하지 말고 팀에 공유한다.

### 5. API 약속 확인 — 받아서 읽기 (중요)

백엔드가 `api-vX.Y` 공지를 보내면 프론트에서 받는다.

```
/fetch-api api-v0.2
```

안 되면: `scripts/fetch-openapi.sh api-v0.2` (두 레포 모두 비공개라 처음 한 번 `gh auth login` 필요)

받은 뒤 확인한다.

- [ ] 이 화면에 필요한 요청·응답이 모두 명세에 있나 (없으면 백엔드에 요청 — **프론트가 임의로 필드를 가정하지 않는다**)
- [ ] ID가 UUID 문자열로 정의돼 있나 (앱 모델에서 `int`로 받지 않는다)
- [ ] 403/404/401 응답이 정의돼 있나 (mock과 화면 처리에 쓴다)
- [ ] 에러 응답 형식(`code`, `message`, `fieldErrors`)을 앱이 그대로 쓸 수 있나
- [ ] 연락처(전화번호·주소) 필드가 없나 (있으면 백엔드에 알린다)

**API를 바꿀 땐 항상 백엔드 openapi.yaml 먼저 → 공지 → 코드** 순서다. 앱의 `docs/api/openapi.yaml`은 직접 고치지 않는다.

### 6. 작업 목록 — `/speckit-tasks` → `/speckit-analyze`

- `tasks`가 `tasks.md`를 만든다.
- `analyze`는 spec·plan·tasks가 서로 맞는지 **읽기만** 하고 리포트를 준다. 지적이 나오면 해당 파일을 고치고 다시 돌린다.

### 7. 구현 — `/speckit-implement`

- tasks.md 순서대로 코드를 만들고 완료 항목을 체크한다.
- **순서 권장**: domain(모델·Repository 인터페이스) → mock → 화면 → data(실서버 구현). 서버가 없어도 화면을 끝까지 만들 수 있다.
- 화면은 `domain` 인터페이스에만 의존한다. `data`를 직접 import 하지 않는다(constitution 아키텍처).
- mock에는 정상 응답만 넣지 않는다: 401(토큰 만료→갱신), 403(남의 문의), 정제 진행 중→완료, "원문 확인 필요", 긴급 문의.
- 디자인 값(색·글꼴·간격)은 화면마다 하드코딩하지 않고 테마 한 곳에 모은다.
- AI가 만든 코드도 **내가 설명할 수 있을 때까지** 읽는다. 대회 발표·진단 때 질문받는다.

### 8. 확인

```bash
flutter analyze
flutter test
flutter run -t lib/main_mock.dart                          # mock (서버 없이)
flutter run --dart-define-from-file=env/dev.json           # 실서버 (백엔드가 떠 있을 때)
```

- 실패를 숨기거나 테스트를 지워서 통과시키지 않는다.
- 아래를 손으로 확인한다: 로딩·빈 목록·에러 상태가 보이나, 뒤로 가기가 자연스러운가, 로그에 본문이 찍히지 않나(`print`·`debugPrint` 검색).
- `/speckit-converge`로 spec 대비 빠진 작업이 없는지 확인한다. 빠진 게 있으면 tasks.md에 추가되니 다시 implement.
- 에뮬레이터는 메모리를 많이 쓴다. 확인이 끝나면 끈다.

### 9. 문서 갱신

- `docs/ia.md`: 화면 트리·상태가 바뀌었으면 반영한다.
- 백엔드 `docs/features.md` 상태 표는 백엔드 담당이 관리한다. 프론트 진행 상황은 이슈·PR로 공유한다.

### 10. 올리기

```bash
git add .
git commit -m "Feat : F1 로그인·회원가입 화면 구현"   # 커밋 전에 Gitleaks가 자동 검사한다
git push -u origin features/f1-auth-signup
```

- 커밋 메시지는 `타입 : 내용` (콜론 앞뒤 공백). 타입은 `Feat`(기능), `Fix`(수정), `Docs`(문서), `Chore`(설정·빌드·템플릿). AI 기여자 표시는 넣지 않는다.
- GitHub에서 PR을 만든다 → 제목 `[Feat] …`, 본문에 `Closes #<이슈 번호>` → 리뷰 → CI(Gitleaks) 통과 → main에 merge.
- Gitleaks가 커밋을 막으면 키·토큰이 들어간 것이다. **그 값을 지운다.** 앱에는 시크릿을 넣지 않는다(`env/*.json`에도). 이미 push했다면 팀에 바로 알리고 키를 교체한다.

---

## 프론트가 백엔드와 다른 점

| 항목 | 백엔드 | 프론트 |
|---|---|---|
| API 명세 | 원본을 만들고 태그(`api-vX.Y`)를 찍는다 | 사본을 받아 읽기만 한다 (`/fetch-api`) |
| `/api-release` | 사용 | **사용하지 않음** |
| plan의 `contracts/` | 사람이 리뷰하고 openapi.yaml에 합친다 | 만들지 않는다 |
| 기능 정의 원본 | `docs/features.md` | 백엔드 features.md + Figma 프레임 + `docs/ia.md` |
| 서버 없을 때 | — | mock Repository로 개발 |
| 테스트 확인 | `./gradlew test` | `flutter analyze` · `flutter test` |
| 보안 점검 문서 | `docs/security-checklist.md` | constitution의 "프론트엔드에서의 적용" 표 |

---

## specify 입력 만드는 법

백엔드 features.md는 서버 기준으로 쓰여 있다. 프론트 spec은 **사용자가 화면에서 보고 하는 것**만 남긴다.

1. 백엔드 features.md에서 맡은 기능 섹션을 복사한다.
2. 서버 내부 규칙(암호화 저장 방식, 감사 로그 기록 등)과 **기술 이름**(Spring, Redis, JWT, Flutter, Riverpod …)을 지운다. 화면에 영향이 있는 규칙("10분 잠금", "원문 확인 필요 상태에서는 정리본 숨김")은 남긴다.
3. 아래를 직접 덧붙인다.
   - Figma 프레임 링크(node-id 포함)
   - 화면 상태 요구: 로딩 / 빈 목록 / 오류 / 권한 없음
   - 대응 백엔드 spec 경로
4. 붙여 넣는다.
   ```
   /speckit-specify (정리한 F1 내용)
   ```

### Figma 프레임 링크 만드는 법

- Figma에서 프레임 선택 → 우클릭 → `Copy link to selection` → `?node-id=…`가 포함된 링크가 복사된다.
- Figma 파일 링크는 `CLAUDE.md`에, **프레임 링크는 각 spec**에 둔다.
- Figma MCP가 연결돼 있으면 프레임 링크로 디자인(구조·색·간격)을 읽어 구현에 쓸 수 있다.

---

## 스킬 한눈에 보기

```
constitution (레포당 1회)
      │
specify → clarify → plan → tasks → analyze → implement → converge
  무엇/왜    모호점     어떻게    작업목록   교차점검     구현       빠진 것 확인
                        │
                    checklist (선택)
```

| 스킬 | 언제 | 입력 | 산출물 |
|---|---|---|---|
| `/speckit-constitution` | 레포당 1회, 원칙 바꿀 때(팀 합의 후, **백엔드와 같은 시점에**) | 원칙 목록 | `.specify/memory/constitution.md` |
| `/speckit-specify` | 새 기능 시작 | 정리한 features 섹션 + Figma 링크 | `specs/NNN-기능명/spec.md`, `checklists/requirements.md` |
| `/speckit-clarify` | spec에 모호한 곳이 있을 때 | 없음 (질문에 답) | spec.md에 결정 반영 (최대 5문항) |
| `/speckit-plan` | spec 확정 후 | 기술 스택 | `plan.md`, `research.md`, `data-model.md`, `quickstart.md` |
| `/speckit-tasks` | plan 확정 후 | 없음 | `tasks.md` |
| `/speckit-analyze` | tasks 후, 구현 전 | 없음 | 점검 리포트 (파일 수정 없음) |
| `/speckit-implement` | analyze 이상 없을 때 | 없음 | 코드 + tasks.md 체크 |
| `/speckit-converge` | 구현 후 | 없음 | 빠진 작업을 tasks.md에 추가 |
| `/speckit-checklist` | plan 이후 (선택) | 주제 (예: "보안") | 요구사항 품질 체크리스트 |
| `/fetch-api <태그>` | 백엔드 명세 공지를 받았을 때 | 태그 | `docs/api/openapi.yaml` 갱신 + 바뀐 점 요약 |
| `/speckit-taskstoissues` | — | — | **deprecated**, 쓰지 않음 |

## 막히면

- AI 결과가 이상하면 그대로 진행하지 말고 팀에 공유한다.
- "이거 constitution에 맞아?"가 헷갈리면 해당 원칙 번호와 "프론트엔드에서의 적용" 표를 같이 본다.
- 명령이 안 먹으면 Claude Code를 이 레포 루트에서 열었는지 확인한다(`.claude/skills/`가 보여야 한다).
- **`flutter`를 찾을 수 없다고 나오면**: Flutter SDK의 `bin` 폴더(예: `C:\Users\<사용자>\flutter\bin`)를 PATH에 추가하고 터미널을 다시 연다.
- **Android 에뮬레이터에서 로컬 서버에 접속이 안 되면**: 에뮬레이터에서 호스트 PC는 `localhost`가 아니라 `10.0.2.2`다. `env/dev.json`의 `API_BASE_URL`을 확인한다. `env/dev.json`은 커밋되지 않으므로 `env/example.json`을 복사해 만든다.
- **앱이 `API_BASE_URL 이 설정되지 않았습니다`로 바로 종료되면**: `--dart-define-from-file=env/dev.json` 없이 실행한 것이다. mock이면 `-t lib/main_mock.dart`로 실행한다.
- **`flutter pub get`에서 riverpod 버전 충돌이 나면**: 현재 Dart 3.10에서는 `flutter_riverpod` 3.0.x, `riverpod_annotation`·`riverpod_generator` 3.0.x 대를 쓴다(4.x는 Dart 3.12 필요). Flutter SDK를 올리기 전엔 버전을 올리지 않는다. riverpod 3에서 `Override` 타입은 `package:flutter_riverpod/misc.dart`에서 가져온다.
- **Windows에서 `UnicodeEncodeError: 'cp949' codec can't encode …`가 나며 스킬이 멈추면**: spec-kit 스크립트가 한글·이모지를 Windows 콘솔 인코딩(cp949)으로 출력하다 실패한 것이다. 명령 앞에 `PYTHONIOENCODING=utf-8`을 붙여 다시 실행한다. 매번 붙이기 번거로우면 Windows 환경변수에 `PYTHONIOENCODING=utf-8`을 등록한다.
- **Gradle 첫 빌드가 5분 넘게 걸리면**: 정상이다(의존성 최초 다운로드). 두 번째부터는 10초 안팎이다.
