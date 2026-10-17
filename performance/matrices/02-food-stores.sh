#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/.." && pwd)/lib/common.sh"

CUSTOMER_TOKEN="${CUSTOMER_TOKEN:-$(cat "${REPORT_DIR}/${RUN_ID}.customer.token" 2>/dev/null || mint_token phone "${CUSTOMER_PHONE:-+84902000001}")}"

echo "== Food stores browse (A–E) =="
# A Minimal
api_curl_json GET "/v1/food/stores" --level A --token "${CUSTOMER_TOKEN}" --note "default page" --expect 200
# B Single
api_curl_json GET "/v1/food/stores?category=cafe" --level B --token "${CUSTOMER_TOKEN}" --note "category" --expect 200
api_curl_json GET "/v1/food/stores?search=Perf" --level B --token "${CUSTOMER_TOKEN}" --note "search" --expect 200
# C Combo
api_curl_json GET "/v1/food/stores?category=cafe&lat=10.7769&lng=106.7009" --level C --token "${CUSTOMER_TOKEN}" --note "category+geo" --expect 200
# D Full
api_curl_json GET "/v1/food/stores?category=cafe&lat=10.7769&lng=106.7009&sort_by=distance&search=a&page=1&limit=20" \
  --level D --token "${CUSTOMER_TOKEN}" --note "full filters" --expect 200
# E Edge
api_curl_json GET "/v1/food/stores?page=100&limit=50" --level E --token "${CUSTOMER_TOKEN}" --note "deep page" --expect 200
api_curl_json GET "/v1/food/stores?search=randomxyz123doesnotexist" --level E --token "${CUSTOMER_TOKEN}" --note "empty result" --expect 200
api_curl_json GET "/v1/food/stores" --level E --note "no token" --expect 401 || true
