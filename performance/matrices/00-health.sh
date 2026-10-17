#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "$0")/.." && pwd)/lib/common.sh"

echo "== Health =="
api_curl_json GET "/" --level A --note "root" --expect 200
api_curl_json GET "/health" --level A --note "health" --expect 200
api_curl_json GET "/health/live" --level A --note "liveness" --expect 200
api_curl_json GET "/health/ready" --level B --note "readiness+deps" --expect 200
api_curl_json GET "/health/ready?probe=deep" --level E --note "unknown probe tolerated" || true
