# Contract: 실행 설정

앱을 어떤 대상에 연결해 실행하는지에 대한 약속. 화면 코드는 이 설정을 모른다(FR-001).

| 실행 | 명령 | 파일 | 저장소 |
|---|---|---|---|
| 배포 서버 | `flutter run --dart-define-from-file=env/prod.json` | `env/prod.json` | git 제외(`env/*.json`) |
| 로컬 서버 | `flutter run --dart-define-from-file=env/dev.json` | `env/dev.json` | git 제외 |
| mock | `flutter run --dart-define=USE_MOCK=true` | 없음 | — |
| 배포 서버 release 확인 | `flutter build apk --release --obfuscate --split-debug-info=build/debug-info --dart-define-from-file=env/prod.json` 후 설치(`adb install -r build/app/outputs/flutter-apk/app-release.apk`) | `env/prod.json` | — (INTERNET 권한 필요, research R4) |

## `env/example.json` (커밋 대상, 변경)

```json
{
  "API_BASE_URL": "https://damso.jibang.site",
  "USE_MOCK": false
}
```

처음 받은 사람은 `cp env/example.json env/prod.json` 한 번으로 배포 서버 실행이 된다.

## 보장

- 같은 커밋으로 세 실행이 모두 된다(FR-001·FR-002).
- 배포 서버 실행에서 요청은 모두 `https://damso.jibang.site`로 간다(US6-2). 주소는 `dioProvider`의 `baseUrl` 한 곳에서만 쓴다.
- Firebase 값이 없으면 알림 없이 동작한다(FR-014).
