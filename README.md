# 담소 (DAMSO) — App

> 학부모·교사 간 안전한 소통을 위한 AI 민원 정제 앱의 Flutter 클라이언트

2026 소프트웨어 개발보안 시큐어코딩 경진대회 트랙 A(자유주제) 출품작 · 팀 **아기하마**

🖥️ 백엔드: [damsoWE/damso](https://github.com/damsoWE/damso)

## 보안 설계 (프론트)

- RT는 OS 보안 저장소(`flutter_secure_storage`), AT는 메모리에만 보관
- 토큰 주입·갱신은 dio Interceptor 단일 지점
- WebView·HTML 렌더 패키지를 사용하지 않음
- 앱에 API 키 등 시크릿을 넣지 않음 (`env/`에는 서버 주소만)
- 릴리스 빌드는 `--obfuscate --split-debug-info`

## 실행

```bash
cp env/example.json env/prod.json                       # 최초 1회 (배포 서버 주소가 들어 있음)
flutter pub get
flutter run --dart-define-from-file=env/prod.json       # 배포 서버 (https://damso.jibang.site)
flutter run --dart-define-from-file=env/dev.json        # 로컬 서버 (API_BASE_URL=http://10.0.2.2:8080, Android 에뮬레이터)
flutter run --dart-define=USE_MOCK=true                  # mock Repository (서버 불필요)
flutter analyze && flutter test
```

## 구조

```
lib/
├── app/        루트 위젯, 라우터
├── core/       config(Env), network(dio), storage(토큰), error, theme
└── features/   <기능>/{presentation,domain,data}  (MVVM, mock 구현은 data 안)
```

## 문서

| 문서 | 위치 |
|---|---|
| API 명세 (백엔드 태그 기준 사본) | [`docs/api/openapi.yaml`](docs/api/openapi.yaml) (`scripts/fetch-openapi.sh <태그>`) |
| 화면 트리·상태 | [`docs/ia.md`](docs/ia.md) |

## 개발 방식

- [spec-kit](https://github.com/github/spec-kit) 기반 명세 주도 개발(SDD): 화면 단위 명세는 [`specs/`](specs/)에 있으며, 각 명세에 대응하는 백엔드 명세 경로를 적습니다.
- Claude Code 등 AI 코딩 도구를 활용하며, 사용 사실을 공개합니다.
- 보안 원칙은 constitution에서 관리하고, AI 생성 코드는 PR 리뷰와 CI 보안 검증(Gitleaks 등)을 거쳐 머지합니다.

## License

[Apache License 2.0](LICENSE)
