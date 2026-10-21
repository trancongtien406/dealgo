#!/usr/bin/env bash
# Dev launch: API + Mapbox tiles from backend/.env (MAPBOX_ACCESS_TOKEN).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
MOBILE="$ROOT/mobile"
ENV_FILE="${BACKEND_ENV:-$ROOT/backend/.env}"
API_BASE_URL="${API_BASE_URL:-http://localhost:3011}"
DEVICE="${1:-}"

MAPS_API_KEY=""
if [[ -f "$ENV_FILE" ]]; then
  MAPS_API_KEY="$(
    python3 - <<PY
from pathlib import Path
p = Path("$ENV_FILE")
for line in p.read_text().splitlines():
    if line.startswith("MAPBOX_ACCESS_TOKEN="):
        print(line.split("=", 1)[1].strip().strip('"').strip("'"), end="")
        break
PY
  )"
fi

ARGS=(
  run
  --dart-define="API_BASE_URL=$API_BASE_URL"
)
if [[ -n "$MAPS_API_KEY" ]]; then
  ARGS+=(
    --dart-define="MAPS_API_KEY=$MAPS_API_KEY"
    --dart-define="MAP_ATTRIBUTION=© Mapbox © OpenStreetMap"
  )
fi
if [[ -n "$DEVICE" ]]; then
  ARGS+=(-d "$DEVICE")
fi

cd "$MOBILE"
exec flutter "${ARGS[@]}"
