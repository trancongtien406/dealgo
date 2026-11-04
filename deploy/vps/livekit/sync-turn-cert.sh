#!/usr/bin/env bash
# Copies the turn-dealgo certificate that the shared vms Caddy obtains/renews (HTTP-01) into
# livekit/tls and restarts dealgo-livekit only when it changed (LiveKit reads it at startup).
# Cron (root): 17 4 * * * /opt/dealgo/livekit/sync-turn-cert.sh >> /var/log/dealgo-turn-cert.log 2>&1
set -euo pipefail
DOMAIN=turn-dealgo.laptrinhapp.com
SRC=/var/lib/docker/volumes/vms_caddy_data/_data/caddy/certificates/acme-v02.api.letsencrypt.org-directory/$DOMAIN
DST=/opt/dealgo/livekit/tls
umask 077
mkdir -p "$DST"
[ -s "$SRC/$DOMAIN.crt" ] && [ -s "$SRC/$DOMAIN.key" ] || { echo "$(date -Is) no cert in $SRC"; exit 1; }
if cmp -s "$SRC/$DOMAIN.crt" "$DST/turn.crt" && cmp -s "$SRC/$DOMAIN.key" "$DST/turn.key"; then
  exit 0
fi
install -m 600 "$SRC/$DOMAIN.crt" "$DST/turn.crt"
install -m 600 "$SRC/$DOMAIN.key" "$DST/turn.key"
echo "$(date -Is) certificate updated: $(openssl x509 -in "$DST/turn.crt" -noout -enddate)"
if [ "${1:-}" != "--no-restart" ] && docker ps --format '{{.Names}}' | grep -qx dealgo-livekit; then
  docker restart dealgo-livekit >/dev/null && echo "$(date -Is) dealgo-livekit restarted"
fi
