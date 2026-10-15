#!/usr/bin/env bash
# 백엔드 레포의 지정 태그 openapi.yaml 을 docs/api/openapi.yaml 로 내려받는다.
# 사용법: scripts/fetch-openapi.sh api-v0.1
set -euo pipefail

TAG="${1:?사용법: $0 <태그 예: api-v0.1>}"
REPO="${DAMSO_BACKEND_REPO:-damsoWE/damso}"
OUT="$(dirname "$0")/../docs/api/openapi.yaml"

curl -fsSL "https://raw.githubusercontent.com/${REPO}/${TAG}/docs/api/openapi.yaml" -o "$OUT"
echo "saved: $OUT (${REPO}@${TAG})"
