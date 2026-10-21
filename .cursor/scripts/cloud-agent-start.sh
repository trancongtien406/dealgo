#!/usr/bin/env bash
set -euo pipefail

NODE_MAJOR="$(tr -d '[:space:]v' < /workspace/.nvmrc)"
export PATH="/opt/node-v${NODE_MAJOR}/bin:${PATH}"
if ! node -v 2>/dev/null | grep -q "^v${NODE_MAJOR}\."; then
  echo "Node ${NODE_MAJOR}.x required by .nvmrc; re-run .cursor/scripts/cloud-agent-install.sh" >&2
  exit 1
fi

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

# Postgres + Redis: docker-compose.yml (host port 5433) when Docker works, else local services (5432).
if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  docker compose -f /workspace/docker-compose.yml up -d --wait postgres redis
  DATABASE_URL="postgresql://dealgo:dealgo_dev@127.0.0.1:5433/dealgo?schema=public"
else
  sudo service postgresql start
  sudo service redis-server start
  for _ in $(seq 1 30); do
    if sudo -u postgres pg_isready -q; then
      break
    fi
    sleep 1
  done
  if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname = 'dealgo'" | grep -q 1; then
    sudo -u postgres psql -qc "CREATE ROLE dealgo LOGIN CREATEDB PASSWORD 'dealgo_dev'"
  fi
  if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname = 'dealgo'" | grep -q 1; then
    sudo -u postgres psql -qc "CREATE DATABASE dealgo OWNER dealgo"
  fi
  DATABASE_URL="postgresql://dealgo:dealgo_dev@127.0.0.1:5432/dealgo?schema=public"
fi
export DATABASE_URL
export REDIS_URL="redis://127.0.0.1:6379"

# Seed is idempotent (upserts); it provides the ops@localhost account and sample data.
(
  cd /workspace/backend
  npx prisma migrate deploy
  npm run seed >/dev/null
)

api_env="export NODE_ENV=development PORT=3001 DATABASE_URL='${DATABASE_URL}' REDIS_URL='${REDIS_URL}' PATH='${PATH}'"

if ! tmux has-session -t dealgo-api 2>/dev/null; then
  tmux new-session -d -s dealgo-api -c /workspace/backend -- bash -lc "${api_env}; exec npm run start:dev"
fi

if ! tmux has-session -t dealgo-admin 2>/dev/null; then
  tmux new-session -d -s dealgo-admin -c /workspace/website -- bash -lc "export PATH='${PATH}'; exec npm run dev -- --port 3000"
fi

wait_for http://127.0.0.1:3001/ "DealGo API"

# Runs the dist build that `nest start --watch` just produced; tsx (start:worker:dev)
# drops decorator metadata, so Nest DI cannot resolve the worker module under it.
if ! tmux has-session -t dealgo-worker 2>/dev/null; then
  tmux new-session -d -s dealgo-worker -c /workspace/backend -- bash -lc "${api_env}; exec npm run start:worker"
fi
wait_for http://127.0.0.1:3000/
echo "DealGo API http://127.0.0.1:3001, worker (tmux dealgo-worker), Admin Web http://127.0.0.1:3000 ready"
