#!/usr/bin/env bash
# 릴리스 빌드의 단일 진입점. 난독화·심볼 분리·배포 서버 주소·Firebase 값 주입을 한 번에 처리한다.
# 사용법: scripts/build-release.sh          (Play 스토어용 appbundle)
#         scripts/build-release.sh apk      (APK)
# 필요한 파일(저장소에 올리지 않음): env/prod.json, secrets/firebase.json, android/key.properties
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

TARGET="${1:-appbundle}"
case "$TARGET" in
  appbundle|apk) ;;
  *) echo "사용법: $0 [appbundle|apk]" >&2; exit 1 ;;
esac

missing=0
require() {
  if [ ! -f "$1" ]; then
    echo "필요한 파일이 없습니다: $1 ($2)" >&2
    missing=1
  fi
}
require env/prod.json "env/example.json 을 복사해 만드세요"
require secrets/firebase.json "Firebase 연결 값 파일, 저장소에 두지 않습니다"
require android/key.properties "업로드 키 서명 정보, README 의 릴리스 빌드 절을 보세요"
[ "$missing" -eq 0 ] || exit 1

flutter build "$TARGET" --release \
  --obfuscate --split-debug-info=build/debug-info \
  --dart-define-from-file=env/prod.json \
  --dart-define-from-file=secrets/firebase.json

echo "완료. build/debug-info 의 심볼 파일은 크래시 로그 해석에 필요하니 버전별로 보관하세요(저장소에는 올리지 않음)."
