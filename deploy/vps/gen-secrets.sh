#!/usr/bin/env bash
# Generates the DealGo production env files on the VPS. Never prints a secret.
#   env/postgres.env  env/backend.env  env/website.env   (chmod 600, root)
#   .env              compose build args (public NEXT_PUBLIC_* values only)
#   env/ops-admin.txt       first super-admin login (chmod 600)
# Inputs (optional, chmod 600): env/thirdparty.env with owner-provided provider keys
#   (MAPBOX_ACCESS_TOKEN, MAPBOX_DIRECTIONS_TOKEN, NEXT_PUBLIC_MAPBOX_TOKEN, ESMS_*, SMTP_*,
#   SENTRY_BACKEND_DSN, SENTRY_WEB_DSN, SENTRY_AUTH_TOKEN, ...).
#   build-secrets/sentry-auth-token: web source-map upload token (Docker build secret; empty = off)
# LiveKit keys are read from livekit/keys.yaml (made by livekit/gen-keys.sh).
# Refuses to overwrite existing env files unless --force (rotating JWT/chat keys logs everyone out
# and makes old chat messages unreadable unless CHAT_ENCRYPTION_PREVIOUS_KEYS is set).
set -euo pipefail
cd "$(dirname "$0")"
umask 077
mkdir -p env secrets build-secrets

[[ -e env/backend.env && "${1:-}" != "--force" ]] && { echo "env/backend.env exists; use --force to regenerate" >&2; exit 1; }
[[ -f livekit/keys.yaml ]] || { echo "Run livekit/gen-keys.sh first" >&2; exit 1; }

API_DOMAIN="${API_DOMAIN:-api-dealgo.laptrinhapp.com}"
WEB_DOMAIN="${WEB_DOMAIN:-dealgo.laptrinhapp.com}"
LIVEKIT_DOMAIN="${LIVEKIT_DOMAIN:-livekit-dealgo.laptrinhapp.com}"
OPS_EMAIL="${OPS_EMAIL:-ops@dealgo.laptrinhapp.com}"

rand() { openssl rand -base64 "$1" | tr -d '\n/+=' | cut -c1-"$2"; }
pg_pass="$(rand 48 40)"
jwt="$(openssl rand -base64 64 | tr -d '\n')"
chat_key="$(openssl rand -base64 32 | tr -d '\n')"
secrets_key="$(openssl rand -base64 32 | tr -d '\n')"
ops_pass="$(rand 24 20)"
lk_key="$(cut -d: -f1 livekit/keys.yaml | head -n1)"
lk_secret="$(cut -d: -f2- livekit/keys.yaml | head -n1 | tr -d ' ')"

cat > env/postgres.env <<EOT
POSTGRES_USER=dealgo
POSTGRES_DB=dealgo
POSTGRES_PASSWORD=${pg_pass}
EOT

third() { [[ -f env/thirdparty.env ]] && grep -E "^$1=" env/thirdparty.env | tail -n1 | cut -d= -f2- || true; }

cat > env/backend.env <<EOT
NODE_ENV=production
DEPLOY_ENV=production
PORT=3001
LOG_FORMAT=json
# vms Caddy -> Cloudflare -> client: two trusted hops in X-Forwarded-For.
TRUST_PROXY=2
SWAGGER_ENABLED=false
DATABASE_URL=postgresql://dealgo:${pg_pass}@dealgo-postgres:5432/dealgo?schema=public
DATABASE_POOL_MAX=10
REDIS_URL=redis://dealgo-redis:6379
JWT_ACCESS_SECRET=${jwt}
CHAT_ENCRYPTION_KEY=${chat_key}
CHAT_ENCRYPTION_KEY_VERSION=1
SECRETS_ENCRYPTION_KEY=${secrets_key}
CORS_ALLOWED_ORIGINS=https://${WEB_DOMAIN}
PUBLIC_WEB_BASE_URL=https://${WEB_DOMAIN}
WEBAUTHN_RP_ID=${WEB_DOMAIN}
WEBAUTHN_RP_NAME=DealGo
WEBAUTHN_ORIGIN=https://${WEB_DOMAIN}
APP_LINKS_IOS_APP_IDS=6J3522877H.com.nguyenngoctien.dealgo
APP_LINKS_ANDROID_PACKAGE=com.nguyenngoctien.dealgo
APP_LINKS_ANDROID_CERT_SHA256=

MAPS_PROVIDER=mapbox
MAPBOX_ACCESS_TOKEN=$(third MAPBOX_ACCESS_TOKEN)
ROUTING_PROVIDER=mapbox
MAPBOX_DIRECTIONS_TOKEN=$(third MAPBOX_DIRECTIONS_TOKEN)
PLACES_OSM_SEARCH_URL=$(third PLACES_OSM_SEARCH_URL)
GOOGLE_MAPS_API_KEY=$(third GOOGLE_MAPS_API_KEY)

# No SMS/email provider keys yet: those login methods stay off (provider none).
SMS_PROVIDER=$(third SMS_PROVIDER)
ESMS_API_KEY=$(third ESMS_API_KEY)
ESMS_SECRET_KEY=$(third ESMS_SECRET_KEY)
ESMS_BRANDNAME=$(third ESMS_BRANDNAME)
EMAIL_PROVIDER=$(third EMAIL_PROVIDER)
SMTP_URL=$(third SMTP_URL)
EMAIL_FROM=$(third EMAIL_FROM)

PUSH_PROVIDER=fcm
FCM_SERVICE_ACCOUNT_PATH=$( [[ -f secrets/fcm-service-account.json ]] && echo /run/dealgo/fcm-service-account.json )

APNS_KEY_ID=TL36K38ZKR
APNS_TEAM_ID=6J3522877H
APNS_KEY_PATH=$( [[ -f secrets/AuthKey_TL36K38ZKR.p8 ]] && echo /run/dealgo/AuthKey_TL36K38ZKR.p8 )
APNS_BUNDLE_ID=com.nguyenngoctien.dealgo
APNS_ENV=production

PAYMENT_PROVIDER=cash-only

SENTRY_DSN=$(third SENTRY_BACKEND_DSN)
SENTRY_ENVIRONMENT=production
SENTRY_TRACES_SAMPLE_RATE=0.1
# Set per deploy (docs/09-operations/vps-deploy.md); a placeholder keeps the key in the file.
SENTRY_RELEASE=initial

VOICE_PROVIDER=livekit
LIVEKIT_URL=wss://${LIVEKIT_DOMAIN}
LIVEKIT_API_KEY=${lk_key}
LIVEKIT_API_SECRET=${lk_secret}

OBJECT_STORAGE_PROVIDER=local
OBJECT_STORAGE_LOCAL_DIR=/app/var/object-storage

OPS_BOOTSTRAP_EMAIL=${OPS_EMAIL}
OPS_BOOTSTRAP_PASSWORD=${ops_pass}
EOT
# Drop empty assignments so the app sees "unset" rather than "".
sed -i -E '/^[A-Z0-9_]+=$/d' env/backend.env

cat > env/website.env <<EOT
NODE_ENV=production
DEALGO_API_BASE_URL=http://dealgo-api:3001
NEXT_PUBLIC_APP_ENV=production
SENTRY_DSN=$(third SENTRY_WEB_DSN)
EOT

cat > .env <<EOT
NEXT_PUBLIC_API_BASE_URL=https://${API_DOMAIN}
NEXT_PUBLIC_MAPBOX_TOKEN=$(third NEXT_PUBLIC_MAPBOX_TOKEN)
NEXT_PUBLIC_SENTRY_DSN=$(third SENTRY_WEB_DSN)
NEXT_PUBLIC_SENTRY_ENVIRONMENT=production
NEXT_PUBLIC_SENTRY_TRACES_SAMPLE_RATE=0.1
NEXT_PUBLIC_SENTRY_RELEASE=initial
EOT
third SENTRY_AUTH_TOKEN > build-secrets/sentry-auth-token

printf 'URL: https://%s/login\nEmail: %s\nPassword: %s\n' "$WEB_DOMAIN" "$OPS_EMAIL" "$ops_pass" > env/ops-admin.txt
chmod 600 env/*.env .env env/ops-admin.txt
unset pg_pass jwt chat_key secrets_key ops_pass lk_secret
echo "Wrote env/postgres.env env/backend.env env/website.env .env env/ops-admin.txt (chmod 600). No secret printed."
