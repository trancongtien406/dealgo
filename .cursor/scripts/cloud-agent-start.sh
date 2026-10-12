#!/usr/bin/env bash
set -euo pipefail

wait_for() {
  local url="$1"
  local expect="${2:-}"
  local i
  for i in $(seq 1 120); do
    if [[ -n "$expect" ]]; then
      if curl -sf "$url" | grep -q "$expect"; then
        return 0
      fi
    elif curl -sf -o /dev/null "$url"; then
      return 0
    fi
    sleep 1
  done
  echo "Timed out waiting for ${url}" >&2
  return 1
}

if ! tmux has-session -t dealgo-api 2>/dev/null; then
  tmux new-session -d -s dealgo-api -c /workspace/backend -- bash -lc 'export PORT=3001; exec npm run start:dev'
fi

if ! tmux has-session -t dealgo-admin 2>/dev/null; then
  tmux new-session -d -s dealgo-admin -c /workspace/website -- bash -lc 'exec npm run dev -- --port 3000'
fi

wait_for http://127.0.0.1:3001/ "DealGo API"
wait_for http://127.0.0.1:3000/
echo "DealGo API http://127.0.0.1:3001 and Admin Web http://127.0.0.1:3000 are ready"
