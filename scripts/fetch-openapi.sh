#!/usr/bin/env bash
# 백엔드 레포의 지정 태그 openapi.yaml 을 docs/api/openapi.yaml 로 내려받는다.
# 사용법: scripts/fetch-openapi.sh api-v0.1
# 백엔드 레포가 비공개라 gh(로그인 필요: gh auth login)로 받는다. 공개 레포면 curl로도 받는다.
set -euo pipefail

TAG="${1:?사용법: $0 <태그 예: api-v0.1>}"
REPO="${DAMSO_BACKEND_REPO:-damsoWE/damso_server}"
OUT="$(dirname "$0")/../docs/api/openapi.yaml"
TMP="${OUT}.download"
trap 'rm -f "$TMP"' EXIT

# 실패해도 기존 파일이 지워지지 않도록 임시 파일에 먼저 받는다
if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  gh api "repos/${REPO}/contents/docs/api/openapi.yaml?ref=${TAG}" \
    -H "Accept: application/vnd.github.raw" > "$TMP"
else
  curl -fsSL "https://raw.githubusercontent.com/${REPO}/${TAG}/docs/api/openapi.yaml" -o "$TMP"
fi

mv "$TMP" "$OUT"
echo "saved: $OUT (${REPO}@${TAG})"
