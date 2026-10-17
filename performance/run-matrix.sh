#!/usr/bin/env bash
# Run full A–E curl performance matrix against a live Nest API.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/common.sh
source "${ROOT}/lib/common.sh"

write_summary_header

echo "DealGo performance matrix RUN_ID=${RUN_ID} BASE_URL=${BASE_URL}"
fail=0
for script in \
  "${ROOT}/matrices/00-health.sh" \
  "${ROOT}/matrices/01-auth.sh" \
  "${ROOT}/matrices/02-food-stores.sh" \
  "${ROOT}/matrices/03-rides.sh" \
  "${ROOT}/matrices/04-food-orders.sh" \
  "${ROOT}/matrices/05-ops.sh"
do
  echo
  echo ">>> $(basename "${script}")"
  if ! bash "${script}"; then
    fail=1
  fi
done

python3 - "${REPORT_FILE}" >>"${SUMMARY_FILE}" <<'PY'
from collections import defaultdict
from pathlib import Path
import sys
rows=[]
for line in Path(sys.argv[1]).read_text().splitlines()[1:]:
    if not line.strip():
        continue
    parts=line.split("\t")
    if len(parts)<7: continue
    level, method, path, http, ms = parts[1], parts[2], parts[3], parts[4], int(parts[5])
    rows.append((level, method, path, http, ms))

by_level=defaultdict(list)
for level, method, path, http, ms in rows:
    by_level[level].append(ms)

print("## Latency by level (ms)")
print()
print("| Level | n | p50 | p95 | max |")
print("|:---|---:|---:|---:|---:|")
for level in sorted(by_level):
    xs=sorted(by_level[level])
    n=len(xs)
    p50=xs[n//2]
    p95=xs[max(0, int(n*0.95)-1)]
    print(f"| {level} | {n} | {p50} | {p95} | {xs[-1]} |")

slow=sorted(rows, key=lambda r: -r[4])[:15]
print()
print("## Slowest calls")
print()
print("| ms | level | method | path | http |")
print("|---:|:---|:---|:---|---:|")
for level, method, path, http, ms in slow:
    print(f"| {ms} | {level} | {method} | `{path}` | {http} |")

non2xx=[r for r in rows if not r[3].startswith("2") and r[3] not in {"401","404"}]
print()
print(f"## Non-2xx (excluding expected 401/404): {len(non2xx)}")
for level, method, path, http, ms in non2xx[:30]:
    print(f"- [{level}] {method} `{path}` → {http} ({ms}ms)")
PY

echo
echo "Wrote ${SUMMARY_FILE}"
echo "TSV ${REPORT_FILE}"
exit "${fail}"
