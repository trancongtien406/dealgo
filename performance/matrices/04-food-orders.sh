#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/.." && pwd)/lib/common.sh"

# Prefer a customer unlikely to already hold an open order slot.
PLACE_CUSTOMER_PHONE="${PLACE_CUSTOMER_PHONE:-+84902000007}"
CUSTOMER_TOKEN="${CUSTOMER_TOKEN:-$(cat "${REPORT_DIR}/${RUN_ID}.customer.token" 2>/dev/null || mint_token phone "${CUSTOMER_PHONE:-+84902000001}")}"
PLACE_TOKEN="$(mint_token phone "${PLACE_CUSTOMER_PHONE}")"
DRIVER_TOKEN="${DRIVER_TOKEN:-$(cat "${REPORT_DIR}/${RUN_ID}.driver.token" 2>/dev/null || mint_token phone "${DRIVER_PHONE:-+84903000001}")}"
MERCHANT_TOKEN="$(mint_token phone "${MERCHANT_PHONE:-+84904000001}")"

echo "== Food orders (A–E) =="
api_curl_json GET "/v1/food/orders" --level A --token "${CUSTOMER_TOKEN}" --note "history" --expect 200
api_curl_json GET "/v1/food/orders/ready" --level A --token "${DRIVER_TOKEN}" --note "ready default" --expect 200
api_curl_json GET "/v1/food/orders/ready?lat=10.7769&lng=106.7009" --level B --token "${DRIVER_TOKEN}" --note "ready+geo" --expect 200
api_curl_json GET "/v1/food/orders/queue" --level B --token "${MERCHANT_TOKEN}" --note "merchant queue" --expect 200
api_curl_json GET "/v1/food/merchant/catalog" --level C --token "${MERCHANT_TOKEN}" --note "catalog" --expect 200
api_curl_json GET "/v1/food/orders?page=1&limit=20" --level C --token "${CUSTOMER_TOKEN}" --note "paged history" --expect 200
api_curl_json GET "/v1/food/orders?page=100&limit=50" --level E --token "${CUSTOMER_TOKEN}" --note "deep page" --expect 200
api_curl_json GET "/v1/food/orders" --level E --note "no token" --expect 401 || true

# Place order against first store (D)
STORES_JSON="$(mktemp)"
curl -sS "${BASE_URL}/v1/food/stores?search=B%C3%BAn&limit=5" -H "Authorization: Bearer ${PLACE_TOKEN}" >"${STORES_JSON}"
STORE_ID="$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); items=(d.get("data") or {}).get("items") or []; print(items[0]["id"] if items else "")' "${STORES_JSON}")"
rm -f "${STORES_JSON}"
if [[ -n "${STORE_ID}" ]]; then
  DETAIL="$(mktemp)"
  curl -sS "${BASE_URL}/v1/food/stores/${STORE_ID}" -H "Authorization: Bearer ${PLACE_TOKEN}" >"${DETAIL}"
  ITEM_ID="$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); items=(d.get("data") or {}).get("items") or []; print(items[0]["id"] if items else "")' "${DETAIL}")"
  rm -f "${DETAIL}"
  if [[ -n "${ITEM_ID}" ]]; then
    BODY=$(cat <<EOF
{"storeId":"${STORE_ID}","deliveryFareVnd":15000,"dropoff":{"lat":10.78,"lng":106.70,"label":"Perf home"},"items":[{"itemId":"${ITEM_ID}","quantity":1}]}
EOF
)
    tmp="$(mktemp)"
    start="$(python3 -c 'import time; print(int(time.time()*1000))')"
    http="$(curl -sS -o "${tmp}" -w '%{http_code}' -X POST "${BASE_URL}/v1/food/orders" \
      -H "Authorization: Bearer ${PLACE_TOKEN}" \
      -H "Content-Type: application/json" \
      -H "Idempotency-Key: perf-food-${RUN_ID}" \
      --data "${BODY}" || true)"
    end="$(python3 -c 'import time; print(int(time.time()*1000))')"
    ms=$((end - start))
    bytes="$(wc -c <"${tmp}" | tr -d ' ')"
    note="place+idem"
    if [[ "${http}" != "200" && "${http}" != "201" ]]; then
      note="place status=${http} $(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(d.get("message","")[:80])' "${tmp}" 2>/dev/null || true)"
    fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "D" "POST" "/v1/food/orders" "${http}" "${ms}" "${bytes}" "${note}" >>"${REPORT_FILE}"
    printf '[D] POST /v1/food/orders → %s (%sms) %s\n' "${http}" "${ms}" "${note}"
    rm -f "${tmp}"
  fi
fi

if [[ "${SKIP_PSP}" == "1" ]]; then
  echo "(skip) MoMo/VNPay webhooks"
fi
