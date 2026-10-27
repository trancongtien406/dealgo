#!/usr/bin/env bash
# Renders livekit.yaml and caddy.yaml from the templates and .env. Safe to re-run; holds no secrets.
set -euo pipefail
cd "$(dirname "$0")"
[[ -f .env ]] || { echo "Missing .env (cp .env.example .env and fill it in)" >&2; exit 1; }

get() { grep -E "^$1=" .env | tail -n1 | cut -d= -f2- | tr -d '"' | tr -d "'" || true; }
LIVEKIT_DOMAIN="$(get LIVEKIT_DOMAIN)"
TURN_DOMAIN="$(get TURN_DOMAIN)"
ACME_EMAIL="$(get ACME_EMAIL)"
LIVEKIT_NODE_IP="$(get LIVEKIT_NODE_IP)"
COMPOSE_PROFILES="$(get COMPOSE_PROFILES)"

host_re='^[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?)+$'
for v in LIVEKIT_DOMAIN TURN_DOMAIN; do
  [[ "${!v}" =~ $host_re ]] || { echo "$v must be a hostname, got '${!v}'" >&2; exit 1; }
done
[[ "$LIVEKIT_DOMAIN" != "$TURN_DOMAIN" ]] || { echo "LIVEKIT_DOMAIN and TURN_DOMAIN must differ (SNI routing)" >&2; exit 1; }
[[ "$ACME_EMAIL" == *@*.* ]] || { echo "ACME_EMAIL must be an email address" >&2; exit 1; }
if [[ "$LIVEKIT_DOMAIN" == *example.com* || "$TURN_DOMAIN" == *example.com* ]] && [[ "${ALLOW_EXAMPLE:-}" != 1 ]]; then
  echo "Domains are still example.com placeholders. Edit .env." >&2; exit 1
fi

use_external_ip=true
node_ip_line=""
if [[ -n "$LIVEKIT_NODE_IP" ]]; then
  [[ "$LIVEKIT_NODE_IP" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]] || { echo "LIVEKIT_NODE_IP must be an IPv4 address" >&2; exit 1; }
  use_external_ip=false
  node_ip_line="  node_ip: ${LIVEKIT_NODE_IP}"
fi
redis_block=""
if [[ ",${COMPOSE_PROFILES}," == *",redis,"* ]]; then
  redis_block=$'redis:\n  address: 127.0.0.1:6379'
fi

render() {
  local src="$1" dst="$2"
  local out
  out="$(cat "$src")"
  out="${out//__LIVEKIT_DOMAIN__/$LIVEKIT_DOMAIN}"
  out="${out//__TURN_DOMAIN__/$TURN_DOMAIN}"
  out="${out//__ACME_EMAIL__/$ACME_EMAIL}"
  out="${out//__USE_EXTERNAL_IP__/$use_external_ip}"
  out="${out//__NODE_IP_LINE__/$node_ip_line}"
  out="${out//__REDIS_BLOCK__/$redis_block}"
  if grep -v '^#' <<<"$out" | grep -q '__[A-Z_]*__' ; then
    echo "Unfilled placeholder in $src" >&2; exit 1
  fi
  printf '%s\n' "$out" | sed '/^$/d' > "$dst"
}
render livekit.yaml.template livekit.yaml
render caddy.yaml.template caddy.yaml
mkdir -p caddy_data

[[ -f keys.yaml ]] || echo "Note: keys.yaml is missing, run ./gen-keys.sh before docker compose up." >&2
if [[ -f keys.yaml ]]; then
  perm="$(stat -c '%a' keys.yaml 2>/dev/null || stat -f '%Lp' keys.yaml)"
  [[ "$perm" == 600 || "$perm" == 400 ]] || { echo "keys.yaml must be chmod 600 (LiveKit refuses others-readable key files)" >&2; exit 1; }
fi
echo "Rendered livekit.yaml and caddy.yaml for ${LIVEKIT_DOMAIN} / ${TURN_DOMAIN}."
