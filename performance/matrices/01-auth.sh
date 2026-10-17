#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/.." && pwd)/lib/common.sh"

CUSTOMER_PHONE="${CUSTOMER_PHONE:-+84902000001}"
DRIVER_PHONE="${DRIVER_PHONE:-+84903000001}"

echo "== Auth / me =="
CUSTOMER_TOKEN="$(mint_token phone "${CUSTOMER_PHONE}" customer)"
DRIVER_TOKEN="$(mint_token phone "${DRIVER_PHONE}" customer)"
OPS_TOKEN="$(ops_login)"

api_curl_json GET "/v1/me" --level A --token "${CUSTOMER_TOKEN}" --note "me" --expect 200
api_curl_json GET "/v1/me/role-grants" --level A --token "${CUSTOMER_TOKEN}" --note "grants" --expect 200
api_curl_json GET "/v1/me/presence" --level B --token "${DRIVER_TOKEN}" --note "presence get" --expect 200
api_curl_json POST "/v1/me/presence" --level C --token "${DRIVER_TOKEN}" \
  --data '{"online":true,"lat":10.7769,"lng":106.7009}' --note "presence up" --expect 200
api_curl_json POST "/v1/me/push-tokens" --level D --token "${CUSTOMER_TOKEN}" \
  --data '{"token":"perf-fcm-token-'"${RUN_ID}"'","platform":"android"}' --note "register FCM" --expect 200

# E — auth gate
api_curl_json GET "/v1/me" --level E --note "no token" --expect 401 || true

if [[ "${SKIP_SMS}" == "1" ]]; then
  echo "(skip) SMS OTP challenge/verify real send — mock path only"
  api_curl_json POST "/v1/auth/phone/challenges" --level A \
    --data "{\"phone\":\"${CUSTOMER_PHONE}\"}" --note "otp challenge mock" --expect 200
fi

api_curl_json POST "/v1/ops/sessions" --level A \
  --data '{"email":"ops@localhost","password":"change-me-dev-only"}' --note "ops login" --expect 200
api_curl_json POST "/v1/ops/sessions" --level E \
  --data '{"email":"ops@localhost","password":"wrong-password-xx"}' --note "ops bad password" --expect 401 || true

export CUSTOMER_TOKEN DRIVER_TOKEN OPS_TOKEN
printf '%s\n' "${CUSTOMER_TOKEN}" >"${REPORT_DIR}/${RUN_ID}.customer.token"
printf '%s\n' "${DRIVER_TOKEN}" >"${REPORT_DIR}/${RUN_ID}.driver.token"
printf '%s\n' "${OPS_TOKEN}" >"${REPORT_DIR}/${RUN_ID}.ops.token"
