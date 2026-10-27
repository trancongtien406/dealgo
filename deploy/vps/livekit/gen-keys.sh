#!/usr/bin/env bash
# Creates the LiveKit API key pair. Never prints the secret.
#   keys.yaml           -> mounted into LiveKit (key_file), chmod 600
#   backend.env.snippet -> LIVEKIT_URL / LIVEKIT_API_KEY / LIVEKIT_API_SECRET for backend/.env.production, chmod 600
# Refuses to overwrite existing keys unless --force (rotating keys breaks calls until the backend is updated).
set -euo pipefail
cd "$(dirname "$0")"
umask 077

force=false
[[ "${1:-}" == "--force" ]] && force=true
if [[ -e keys.yaml && $force != true ]]; then
  echo "keys.yaml already exists. Use --force to rotate (then update the backend env and restart both)." >&2
  exit 1
fi
command -v openssl >/dev/null || { echo "openssl is required" >&2; exit 1; }

domain=""
if [[ -f .env ]]; then
  domain="$(grep -E '^LIVEKIT_DOMAIN=' .env | tail -n1 | cut -d= -f2- | tr -d '"' | tr -d "'")"
fi
[[ -n "$domain" ]] || domain="livekit.example.com"

api_key="API$(openssl rand -hex 8)"
api_secret="$(openssl rand -base64 48 | tr -d '\n/+=' | cut -c1-48)"

tmp="$(mktemp keys.yaml.XXXXXX)"
printf '%s: %s\n' "$api_key" "$api_secret" > "$tmp"
chmod 600 "$tmp"
mv -f "$tmp" keys.yaml

tmp="$(mktemp backend.env.snippet.XXXXXX)"
{
  echo "# Paste into backend/.env.production (or the secret manager), then delete this file."
  echo "VOICE_PROVIDER=livekit"
  echo "LIVEKIT_URL=wss://${domain}"
  echo "LIVEKIT_API_KEY=${api_key}"
  echo "LIVEKIT_API_SECRET=${api_secret}"
} > "$tmp"
chmod 600 "$tmp"
mv -f "$tmp" backend.env.snippet
unset api_secret

echo "Wrote keys.yaml and backend.env.snippet (both chmod 600). API key id: ${api_key}. The secret was not printed."
