#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/.." && pwd)/lib/common.sh"

CUSTOMER_TOKEN="${CUSTOMER_TOKEN:-$(cat "${REPORT_DIR}/${RUN_ID}.customer.token" 2>/dev/null || true)}"
DRIVER_TOKEN="${DRIVER_TOKEN:-$(cat "${REPORT_DIR}/${RUN_ID}.driver.token" 2>/dev/null || true)}"
[[ -n "${CUSTOMER_TOKEN}" ]] || CUSTOMER_TOKEN="$(mint_token phone "${CUSTOMER_PHONE:-+84902000001}")"
[[ -n "${DRIVER_TOKEN}" ]] || DRIVER_TOKEN="$(mint_token phone "${DRIVER_PHONE:-+84903000001}")"

echo "== Rides (A–E) =="
# A
api_curl_json GET "/v1/rides" --level A --token "${CUSTOMER_TOKEN}" --note "history default" --expect 200
api_curl_json GET "/v1/rides/open" --level A --token "${DRIVER_TOKEN}" --note "open default (presence)" --expect 200
# B
api_curl_json GET "/v1/rides?page=1&limit=20" --level B --token "${CUSTOMER_TOKEN}" --note "page" --expect 200
api_curl_json GET "/v1/rides/open?lat=10.7769&lng=106.7009" --level B --token "${DRIVER_TOKEN}" --note "open+geo" --expect 200
# C
api_curl_json GET "/v1/rides?page=1&limit=50" --level C --token "${CUSTOMER_TOKEN}" --note "wider page" --expect 200
# D — create negotiate (idempotent)
IDEM="perf-ride-${RUN_ID}"
CREATE_BODY=$(cat <<EOF
{"pickup":{"lat":10.7769,"lng":106.7009,"label":"Perf pickup"},"dropoff":{"lat":10.782,"lng":106.71,"label":"Perf drop"},"offeredFareVnd":35000}
EOF
)
api_curl_json POST "/v1/rides" --level D --token "${CUSTOMER_TOKEN}" \
  --data "${CREATE_BODY}" --note "create ride (may 409 if open exists)" || true
# Force with unique key via header is required — use curl directly for Idempotency-Key
tmp="$(mktemp)"
start="$(python3 -c 'import time; print(int(time.time()*1000))')"
http="$(curl -sS -o "${tmp}" -w '%{http_code}' -X POST "${BASE_URL}/v1/rides" \
  -H "Authorization: Bearer ${CUSTOMER_TOKEN}" \
  -H "Content-Type: application/json" \
  -H "Idempotency-Key: ${IDEM}" \
  --data "${CREATE_BODY}" || true)"
end="$(python3 -c 'import time; print(int(time.time()*1000))')"
ms=$((end - start))
bytes="$(wc -c <"${tmp}" | tr -d ' ')"
printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "D" "POST" "/v1/rides" "${http}" "${ms}" "${bytes}" "create+idem" >>"${REPORT_FILE}"
printf '[D] POST /v1/rides → %s (%sms)\n' "${http}" "${ms}"
RIDE_ID="$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print((d.get("data") or {}).get("id",""))' "${tmp}" || true)"
rm -f "${tmp}"

if [[ -n "${RIDE_ID}" ]]; then
  api_curl_json GET "/v1/rides/${RIDE_ID}" --level D --token "${CUSTOMER_TOKEN}" --note "get ride" --expect 200
  api_curl_json GET "/v1/rides/${RIDE_ID}/messages" --level D --token "${CUSTOMER_TOKEN}" --note "chat list" --expect 200
  if [[ "${SKIP_VOICE}" != "1" ]]; then
    api_curl_json POST "/v1/rides/${RIDE_ID}/voice-session" --level D --token "${CUSTOMER_TOKEN}" --note "voice" || true
  else
    echo "(skip) voice-session"
  fi
fi

# E
api_curl_json GET "/v1/rides?page=100&limit=50" --level E --token "${CUSTOMER_TOKEN}" --note "deep page" --expect 200
api_curl_json GET "/v1/rides" --level E --note "no token" --expect 401 || true
api_curl_json GET "/v1/rides/00000000-0000-4000-8000-000000000000" --level E --token "${CUSTOMER_TOKEN}" --note "missing id" --expect 404 || true
