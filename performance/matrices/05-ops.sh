#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/.." && pwd)/lib/common.sh"

OPS_TOKEN="${OPS_TOKEN:-$(cat "${REPORT_DIR}/${RUN_ID}.ops.token" 2>/dev/null || ops_login)}"

echo "== Ops admin (A–E) =="
api_curl_json GET "/v1/ops/overview" --level A --token "${OPS_TOKEN}" --note "overview" --expect 200
api_curl_json GET "/v1/ops/monitor/snapshot" --level A --token "${OPS_TOKEN}" --note "monitor" --expect 200
api_curl_json GET "/v1/ops/exceptions" --level A --token "${OPS_TOKEN}" --note "exceptions" --expect 200
api_curl_json GET "/v1/ops/rides?page=1&limit=20" --level B --token "${OPS_TOKEN}" --note "rides page" --expect 200
api_curl_json GET "/v1/ops/food-orders?page=1&limit=20" --level B --token "${OPS_TOKEN}" --note "food page" --expect 200
api_curl_json GET "/v1/ops/customers?page=1&limit=20" --level B --token "${OPS_TOKEN}" --note "customers" --expect 200
api_curl_json GET "/v1/ops/drivers?page=1&limit=20" --level B --token "${OPS_TOKEN}" --note "drivers" --expect 200
api_curl_json GET "/v1/ops/stores?page=1&limit=20" --level B --token "${OPS_TOKEN}" --note "stores" --expect 200
api_curl_json GET "/v1/ops/settlements?page=1&limit=20" --level C --token "${OPS_TOKEN}" --note "settlements" --expect 200
api_curl_json GET "/v1/ops/transactions?page=1&limit=20" --level C --token "${OPS_TOKEN}" --note "transactions" --expect 200
api_curl_json GET "/v1/ops/disputes?page=1&limit=20" --level C --token "${OPS_TOKEN}" --note "disputes" --expect 200
api_curl_json GET "/v1/ops/platform-settings" --level C --token "${OPS_TOKEN}" --note "settings" --expect 200
api_curl_json GET "/v1/ops/faqs" --level C --token "${OPS_TOKEN}" --note "faqs" --expect 200
api_curl_json GET "/v1/ops/auth-methods" --level C --token "${OPS_TOKEN}" --note "auth methods" --expect 200
api_curl_json GET "/v1/ops/notifications?page=1&limit=20" --level D --token "${OPS_TOKEN}" --note "campaigns" --expect 200
api_curl_json GET "/v1/ops/notifications/cms" --level D --token "${OPS_TOKEN}" --note "cms" --expect 200
api_curl_json GET "/v1/ops/audit-logs?page=1&limit=20" --level D --token "${OPS_TOKEN}" --note "audit" --expect 200
api_curl_json GET "/v1/ops/partner-applications?page=1&limit=20" --level D --token "${OPS_TOKEN}" --note "KYC queue" --expect 200
api_curl_json GET "/v1/ops/catalog/moderation?page=1&limit=20" --level D --token "${OPS_TOKEN}" --note "catalog mod" --expect 200

# E
api_curl_json GET "/v1/ops/rides?page=100&limit=50" --level E --token "${OPS_TOKEN}" --note "deep rides" --expect 200
api_curl_json GET "/v1/ops/customers?q=randomxyz123" --level E --token "${OPS_TOKEN}" --note "empty search" --expect 200
api_curl_json GET "/v1/ops/overview" --level E --note "no token" --expect 401 || true
