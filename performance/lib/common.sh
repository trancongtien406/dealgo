#!/usr/bin/env bash
# Shared helpers for DealGo performance A–E curl matrices.
set -euo pipefail

PERF_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "${PERF_ROOT}/.." && pwd)"
BACKEND_ROOT="${REPO_ROOT}/backend"
REPORT_DIR="${PERF_ROOT}/reports"
mkdir -p "${REPORT_DIR}"

BASE_URL="${BASE_URL:-http://127.0.0.1:3001}"
RUN_ID="${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
REPORT_FILE="${REPORT_FILE:-${REPORT_DIR}/${RUN_ID}.tsv}"
SUMMARY_FILE="${SUMMARY_FILE:-${REPORT_DIR}/${RUN_ID}.summary.md}"

# Skip domains (user request)
SKIP_SMS="${SKIP_SMS:-1}"
SKIP_PSP="${SKIP_PSP:-1}"
SKIP_VOICE="${SKIP_VOICE:-1}"

export BASE_URL RUN_ID REPORT_DIR REPORT_FILE SUMMARY_FILE SKIP_SMS SKIP_PSP SKIP_VOICE
export PERF_ROOT REPO_ROOT BACKEND_ROOT

if [[ ! -f "${REPORT_FILE}" ]]; then
  printf 'ts\tlevel\tmethod\tpath\thttp\tms\tbody_bytes\tnote\n' >"${REPORT_FILE}"
fi

api_curl_json() {
  local method="$1"
  local path="$2"
  shift 2
  local level="A"
  local token=""
  local data=""
  local note=""
  local expect=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --level) level="$2"; shift 2 ;;
      --token) token="$2"; shift 2 ;;
      --data) data="$2"; shift 2 ;;
      --note) note="$2"; shift 2 ;;
      --expect) expect="$2"; shift 2 ;;
      *) echo "unknown arg: $1" >&2; return 2 ;;
    esac
  done

  local url="${BASE_URL}${path}"
  local tmp
  tmp="$(mktemp)"
  local headers=(-H "Accept: application/json" -H "Content-Type: application/json")
  if [[ -n "${token}" ]]; then
    headers+=(-H "Authorization: Bearer ${token}")
  fi

  local start end ms http code
  start="$(python3 -c 'import time; print(int(time.time()*1000))')"
  if [[ -n "${data}" ]]; then
    http="$(curl -sS -o "${tmp}" -w '%{http_code}' -X "${method}" "${headers[@]}" --data "${data}" "${url}" || true)"
  else
    http="$(curl -sS -o "${tmp}" -w '%{http_code}' -X "${method}" "${headers[@]}" "${url}" || true)"
  fi
  end="$(python3 -c 'import time; print(int(time.time()*1000))')"
  ms=$((end - start))
  local bytes
  bytes="$(wc -c <"${tmp}" | tr -d ' ')"

  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${level}" "${method}" "${path}" "${http}" "${ms}" "${bytes}" "${note}" \
    >>"${REPORT_FILE}"

  local ok=1
  if [[ -n "${expect}" ]]; then
    if [[ "${http}" != "${expect}" ]]; then
      ok=0
    fi
  fi

  local preview
  preview="$(python3 -c '
import json,sys
p=sys.argv[1]
raw=open(p,"rb").read()
text=raw.decode("utf-8","replace")
try:
  print(json.dumps(json.loads(text), ensure_ascii=False)[:240])
except Exception:
  print(text[:240].replace("\n"," "))
' "${tmp}")"

  printf '[%s] %s %s → %s (%sms, %sb) %s\n' "${level}" "${method}" "${path}" "${http}" "${ms}" "${bytes}" "${note}"
  if [[ "${ok}" -ne 1 ]]; then
    printf '  EXPECT %s GOT %s | %s\n' "${expect}" "${http}" "${preview}" >&2
    rm -f "${tmp}"
    return 1
  fi
  rm -f "${tmp}"
  return 0
}

mint_token() {
  local kind="$1"
  local value="$2"
  local channel="${3:-customer}"
  (
    cd "${BACKEND_ROOT}"
    if [[ "${kind}" == "phone" ]]; then
      npx tsx scripts/mint-dev-session.ts --phone "${value}" --channel "${channel}"
    else
      npx tsx scripts/mint-dev-session.ts --email "${value}" --channel "${channel}"
    fi
  ) | python3 -c 'import json,sys; print(json.load(sys.stdin)["accessToken"])'
}

ops_login() {
  local email="${OPS_EMAIL:-ops@localhost}"
  local password="${OPS_PASSWORD:-change-me-dev-only}"
  curl -sS -X POST "${BASE_URL}/v1/ops/sessions" \
    -H 'Content-Type: application/json' \
    -d "{\"email\":\"${email}\",\"password\":\"${password}\"}" \
    | python3 -c 'import json,sys; print(json.load(sys.stdin)["data"]["accessToken"])'
}

write_summary_header() {
  cat >"${SUMMARY_FILE}" <<EOF
# DealGo performance matrix ${RUN_ID}

- Base URL: \`${BASE_URL}\`
- Report TSV: \`${REPORT_FILE}\`
- Skips: SMS=${SKIP_SMS} PSP=${SKIP_PSP} VOICE=${SKIP_VOICE}

## Param matrix levels

| Level | Purpose |
|:---|:---|
| A Minimal | Hot path / defaults |
| B Single filter | One criterion |
| C Combo | Typical app combo |
| D Full stack | All accepted filters |
| E Edge | Deep page / empty / no token |

EOF
}
