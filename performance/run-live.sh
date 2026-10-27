#!/usr/bin/env bash
# Live curl timing against a running Nest API (no docs — prints real HTTP codes + seconds).
set -euo pipefail
export PATH="/usr/bin:/bin:/opt/homebrew/bin:${HOME}/.nvm/versions/node/v24.18.0/bin:${PATH}"

ROOT="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/common.sh
source "${ROOT}/lib/common.sh"

BASE_URL="${BASE_URL:-http://127.0.0.1:3001}"
export BASE_URL RUN_ID

echo "=============================================="
echo " LIVE PERF  $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo " BASE_URL=$BASE_URL"
echo "=============================================="

time_get() {
  local label="$1"
  local path="$2"
  local token="${3:-}"
  local headers=(-H 'Accept: application/json')
  if [[ -n "${token}" ]]; then
    headers+=(-H "Authorization: Bearer ${token}")
  fi
  local out
  out="$(curl -sS -o /tmp/dealgo_live_body.json -w '%{http_code} %{time_total}' "${headers[@]}" "${BASE_URL}${path}")"
  local code="${out%% *}"
  local sec="${out##* }"
  printf '%-8s  %-55s  http=%-3s  %7.3fs\n' "${label}" "${path}" "${code}" "${sec}"
}

echo
echo "--- public ---"
time_get A "/health"
time_get A "/health/ready"

echo
echo "--- auth mint ---"
CUSTOMER_TOKEN="$(mint_token phone "${CUSTOMER_PHONE:-+84902000001}" customer)"
DRIVER_TOKEN="$(mint_token phone "${DRIVER_PHONE:-+84903000001}" customer)"
OPS_TOKEN="$(ops_login)"
echo "tokens ok (customer/driver/ops)"

echo
echo "--- customer / driver ---"
time_get A "/v1/me" "${CUSTOMER_TOKEN}"
time_get A "/v1/food/stores" "${CUSTOMER_TOKEN}"
time_get B "/v1/food/stores?category=cafe" "${CUSTOMER_TOKEN}"
time_get C "/v1/food/stores?category=cafe&lat=10.7769&lng=106.7009" "${CUSTOMER_TOKEN}"
time_get D "/v1/food/stores?category=cafe&lat=10.7769&lng=106.7009&sort_by=distance&search=a&page=1&limit=20" "${CUSTOMER_TOKEN}"
time_get E "/v1/food/stores?page=100&limit=50" "${CUSTOMER_TOKEN}"
time_get A "/v1/rides" "${CUSTOMER_TOKEN}"
time_get A "/v1/rides/open" "${DRIVER_TOKEN}"
time_get B "/v1/rides/open?lat=10.7769&lng=106.7009" "${DRIVER_TOKEN}"
time_get A "/v1/food/orders/ready" "${DRIVER_TOKEN}"

echo
echo "--- ops (hot / slow paths) ---"
time_get A "/v1/ops/overview" "${OPS_TOKEN}"
time_get A "/v1/ops/monitor/snapshot" "${OPS_TOKEN}"
time_get A "/v1/ops/exceptions?page=1&limit=10" "${OPS_TOKEN}"
time_get A "/v1/ops/exceptions?page=1&limit=10" "${OPS_TOKEN}"
time_get B "/v1/ops/rides?page=1&limit=20" "${OPS_TOKEN}"
time_get B "/v1/ops/food-orders?page=1&limit=20" "${OPS_TOKEN}"
time_get B "/v1/ops/customers?page=1&limit=20" "${OPS_TOKEN}"
time_get E "/v1/ops/rides?page=100&limit=50" "${OPS_TOKEN}"
time_get E "/v1/ops/overview" ""

echo
echo "=============================================="
echo " LIVE PERF DONE"
echo "=============================================="
