# LiveKit production kit

Self-hosted LiveKit (voice calls) for one Linux VPS: LiveKit + Caddy (TLS/TURN on 443) + optional Redis.

```bash
cp .env.example .env && chmod 600 .env   # set LIVEKIT_DOMAIN, TURN_DOMAIN, ACME_EMAIL
./gen-keys.sh                            # keys.yaml + backend.env.snippet (chmod 600, secret not printed)
./render.sh                              # livekit.yaml + caddy.yaml
docker compose up -d && ./verify.sh
```

Full runbook (DNS, ufw, VPS size, backend env, verification, logs, upgrades):
`docs/09-operations/livekit-self-host.md`.
