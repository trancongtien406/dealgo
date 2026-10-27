#!/usr/bin/env bash
# Post-deploy checks. Run on the VPS (local checks) and/or from a laptop (public checks).
#   ./verify.sh            # everything that applies where it runs
# Never prints keys. Exit code 1 if any check fails.
set -uo pipefail
cd "$(dirname "$0")"
get() { grep -E "^$1=" .env 2>/dev/null | tail -n1 | cut -d= -f2- | tr -d '"' | tr -d "'"; }
LIVEKIT_DOMAIN="${LIVEKIT_DOMAIN:-$(get LIVEKIT_DOMAIN)}"
TURN_DOMAIN="${TURN_DOMAIN:-$(get TURN_DOMAIN)}"
fail=0
ok()  { echo "OK   $*"; }
bad() { echo "FAIL $*"; fail=1; }

# 1. DNS: both names resolve to the same address (this VPS).
lk_ip="$(getent hosts "$LIVEKIT_DOMAIN" 2>/dev/null | awk '{print $1; exit}')"
[[ -n "$lk_ip" ]] || lk_ip="$(dig +short "$LIVEKIT_DOMAIN" 2>/dev/null | tail -n1)"
turn_ip="$(getent hosts "$TURN_DOMAIN" 2>/dev/null | awk '{print $1; exit}')"
[[ -n "$turn_ip" ]] || turn_ip="$(dig +short "$TURN_DOMAIN" 2>/dev/null | tail -n1)"
if [[ -n "$lk_ip" && "$lk_ip" == "$turn_ip" ]]; then ok "DNS $LIVEKIT_DOMAIN and $TURN_DOMAIN -> $lk_ip"; else bad "DNS livekit='$lk_ip' turn='$turn_ip' (both must be the VPS IP)"; fi

# 2. Local health (only on the VPS).
if curl -fsS -m 3 http://127.0.0.1:7880/ >/dev/null 2>&1; then
  ok "LiveKit answers on 127.0.0.1:7880"
  if command -v docker >/dev/null; then
    st="$(docker inspect -f '{{.State.Health.Status}}' livekit-livekit-1 2>/dev/null || true)"
    [[ -z "$st" || "$st" == healthy ]] && ok "container health: ${st:-n/a}" || bad "container health: $st"
  fi
else
  echo "SKIP local health (not on the VPS or LiveKit down)"
fi

# 3. Public signalling over TLS (valid certificate, LiveKit answers "OK").
body="$(curl -fsS -m 10 "https://${LIVEKIT_DOMAIN}/" 2>/dev/null || true)"
[[ "$body" == OK* ]] && ok "https://${LIVEKIT_DOMAIN}/ -> OK (TLS valid)" || bad "https://${LIVEKIT_DOMAIN}/ did not answer OK (check Caddy logs, DNS, port 443)"

# 4. TURN/TLS certificate on 443 for the TURN name.
if command -v openssl >/dev/null; then
  if echo | openssl s_client -connect "${TURN_DOMAIN}:443" -servername "$TURN_DOMAIN" -verify_return_error </dev/null >/dev/null 2>&1; then
    ok "TURN/TLS ${TURN_DOMAIN}:443 certificate verifies"
  else
    bad "TURN/TLS ${TURN_DOMAIN}:443 handshake/certificate failed"
  fi
fi

# 5. WebRTC over TCP port reachable.
if (exec 3<>"/dev/tcp/${LIVEKIT_DOMAIN}/7881") 2>/dev/null; then ok "TCP ${LIVEKIT_DOMAIN}:7881 open"; else bad "TCP 7881 not reachable (firewall?)"; fi

echo
echo "UDP 3478 and 50000-60000 cannot be probed with curl. Prove media with a real join:"
echo "  lk load-test --url wss://${LIVEKIT_DOMAIN} --api-key <key> --api-secret <secret> --room verify --audio-publishers 2 --subscribers 2 --duration 30s"
echo "  (lk = LiveKit CLI; read the key from keys.yaml without echoing it, see the runbook)"
exit $fail
