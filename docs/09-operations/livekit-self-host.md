# LiveKit self-host (production voice calls)

In-app calls (DEC-PROD-007) use a LiveKit SFU. Production runs it on one Linux VPS with the kit in
`deploy/livekit/`: LiveKit server, Caddy (layer4) for TLS on 443, embedded TURN, optional Redis.
Local dev keeps using the root `docker-compose.yml` (`livekit-server --dev`), see the end.

## What the kit contains

| File | Purpose |
|---|---|
| `docker-compose.yml` | `livekit` (pinned `livekit/livekit-server:v1.13.11`), `caddy` (`livekit/caddyl4:v2.11.3`), `redis` (profile `redis`). All `network_mode: host`, `restart: unless-stopped`, json-file logs capped at 5 x 50 MB per service, LiveKit healthcheck on `127.0.0.1:7880` |
| `livekit.yaml.template` | API on 7880, ICE/TCP 7881, ICE/UDP 50000-60000, `rtc.use_external_ip: true`, TURN for `TURN_DOMAIN` (TLS on 443 via Caddy, UDP 3478), keys from `key_file` |
| `caddy.yaml.template` | :443 routed by SNI: `LIVEKIT_DOMAIN` → 7880 (wss signalling), `TURN_DOMAIN` → 5349 (TURN/TLS). Let's Encrypt via HTTP challenge on :80 |
| `.env.example` | Domains, ACME email, image tags, optional `LIVEKIT_NODE_IP`, `COMPOSE_PROFILES`. No secrets |
| `gen-keys.sh` | Writes `keys.yaml` (LiveKit key file) and `backend.env.snippet` (`VOICE_PROVIDER`, `LIVEKIT_URL`, `LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET`), both chmod 600. Prints only the key id. Refuses to overwrite without `--force` |
| `render.sh` | Builds `livekit.yaml` and `caddy.yaml` from the templates and `.env`; rejects placeholder domains, identical domains, bad IPs, and a `keys.yaml` that is not chmod 600 |
| `verify.sh` | DNS, local health, public `https://LIVEKIT_DOMAIN/` = `OK`, TURN/TLS certificate, TCP 7881; prints the load-test command |
| `livekit-docker.service` | systemd unit that starts the stack at boot from `/opt/livekit` |
| `.gitignore` | Keeps `.env`, `keys.yaml`, `backend.env.snippet`, rendered configs and `caddy_data/` out of git |

## Requirements

- **VPS**: Linux (Ubuntu 22.04/24.04), public IPv4 directly on the instance or 1:1 NAT, Docker Engine with the compose plugin. Docker Desktop (Mac/Windows) cannot run this kit (host networking).
- **Size**: minimum 2 vCPU, 2 GB RAM, 20 GB disk; plan 4 vCPU / 4-8 GB for more than ~100 concurrent calls. Audio-only 1:1 calls use roughly 50-100 kbit/s per participant each way, so bandwidth is rarely the limit; CPU is. Run the load test below to size.
- **Nothing else on 80/443** of that VPS (Caddy owns them). Put the API/website on another host, or extend `caddy.yaml.template` with more SNI routes.

## DNS

Two A records to the VPS public IPv4 (no proxy/CDN: Cloudflare must be "DNS only", grey cloud):

| Name | Type | Value |
|---|---|---|
| `livekit.<domain>` | A | VPS IP |
| `turn.<domain>` | A | VPS IP |

They must resolve before the first start, otherwise Caddy cannot get certificates.

## Firewall (ufw)

```bash
sudo ufw allow OpenSSH
sudo ufw allow 80/tcp            # ACME HTTP challenge (certificate issue/renewal)
sudo ufw allow 443/tcp           # wss signalling + TURN/TLS (Caddy)
sudo ufw allow 7881/tcp          # WebRTC over TCP
sudo ufw allow 3478/udp          # TURN/UDP (also STUN)
sudo ufw allow 50000:60000/udp   # WebRTC over UDP
sudo ufw enable
sudo ufw status verbose
```

Do not open 7880, 5349 or 6379: they are local only (Caddy and LiveKit talk over localhost). With
`network_mode: host` Docker does not add its own iptables rules, so ufw applies as written. Also open
the same ports in the cloud provider's security group if it has one.

## Install

```bash
# 1. Docker
curl -fsSL https://get.docker.com | sudo sh

# 2. Kit (copy deploy/livekit from the repo)
sudo mkdir -p /opt/livekit && sudo chown "$USER" /opt/livekit
scp -r deploy/livekit/. <user>@<vps>:/opt/livekit/        # run from the repo on your machine
cd /opt/livekit

# 3. Config
cp .env.example .env && chmod 600 .env
nano .env                       # LIVEKIT_DOMAIN, TURN_DOMAIN, ACME_EMAIL
./gen-keys.sh                   # keys.yaml + backend.env.snippet, secret is not printed
./render.sh                     # livekit.yaml + caddy.yaml

# 4. Start (boot-persistent)
sudo cp livekit-docker.service /etc/systemd/system/
sudo systemctl daemon-reload && sudo systemctl enable --now livekit-docker
docker compose ps
docker compose logs caddy | grep -i "certificate obtained"

# 5. Check
./verify.sh
```

## Backend

Move the three LiveKit lines from `backend.env.snippet` into the backend's production env (secret
manager or `backend/.env.production`), then delete the snippet on the VPS:

```
VOICE_PROVIDER=livekit
LIVEKIT_URL=wss://livekit.<domain>
LIVEKIT_API_KEY=<from snippet>
LIVEKIT_API_SECRET=<from snippet>
```

Read it without printing it to a shared terminal, e.g. copy the file with `scp` straight into the secret
store. `backend/src/platform/config/env.ts` refuses to boot in production when `LIVEKIT_URL` is not
`wss://` or the secret is shorter than 32 characters. Then enable `VOICE_CALLS_ENABLED` in Admin › Settings.

## Mobile

- Release builds join LiveKit only over `wss://` (`assertLiveKitUrlAllowed` in
  `mobile/lib/features/voice/data/media/livekit_url_policy.dart`); the URL comes from the backend's call
  session, so nothing is baked into the app.
- Android: cleartext is enabled only in the `debug` and `profile` manifests; the release manifest has
  none (targetSdk 36, so cleartext is off by default).
- iOS: `Info.plist` only has `NSAllowsLocalNetworking` (local hostnames, never public cleartext). Flutter's
  `dart:io` sockets, which LiveKit signalling and the API client use, are not subject to ATS anyway;
  the release rule is enforced in Dart.

## Verify media end to end

`verify.sh` cannot test UDP. Prove that two participants exchange audio through the public server with the
LiveKit CLI (`lk`, https://github.com/livekit/livekit-cli), from a machine outside the VPS:

```bash
# key and secret from keys.yaml (format "<key>: <secret>"), without echoing them
LK_KEY=$(ssh <vps> "cut -d: -f1 /opt/livekit/keys.yaml")
LK_SECRET=$(ssh <vps> "cut -d' ' -f2 /opt/livekit/keys.yaml")
lk load-test --url wss://livekit.<domain> --api-key "$LK_KEY" --api-secret "$LK_SECRET" \
  --room verify --audio-publishers 2 --subscribers 2 --duration 30s
unset LK_SECRET
```

Expect every subscriber to receive tracks and packet loss near 0 %. Then make a real call between two
phones on different networks (one on mobile data) from a driver/customer trip. If a phone on a strict
network connects but has no audio, check that 443/tcp reaches TURN (`openssl s_client -connect turn.<domain>:443 -servername turn.<domain>`).

## Operations

- **Status**: `docker compose ps` (LiveKit shows `healthy`), `curl -s http://127.0.0.1:7880/` → `OK`.
- **Logs**: `docker compose logs -f livekit` / `caddy`. Rotated by Docker (5 x 50 MB per service).
- **Restart**: `sudo systemctl restart livekit-docker`. Containers also restart on crash and after reboot. Use systemctl, not `docker compose down`, so systemd's state stays right.
- **Config change**: edit `.env` → `./render.sh` → `sudo systemctl restart livekit-docker`.
- **Key rotation**: `./gen-keys.sh --force`, update the backend env, restart LiveKit and the backend together (calls in progress drop).
- **Certificates**: Caddy renews automatically; keep port 80 open and `caddy_data/` on disk.
- **Wrong public IP in ICE** (calls connect but no audio on a NAT'd cloud): set `LIVEKIT_NODE_IP=<public IPv4>` in `.env`, re-render, restart.
- **Redis**: only needed for Egress/Ingress or a second node. Set `COMPOSE_PROFILES=redis` in `.env`, re-render (adds the `redis:` block), restart. Redis listens on 127.0.0.1 only.

## Upgrade

1. Read the release notes: https://github.com/livekit/livekit/releases
2. Change `LIVEKIT_IMAGE` in `.env` (and the tag in `docker-compose.yml`/root dev compose to keep them in step).
3. `docker compose pull livekit && sudo systemctl restart livekit-docker` (in-progress calls drop, so do it at a quiet hour).
4. `./verify.sh`, then one test call. Roll back by restoring the previous tag and repeating step 3.

Caddy: same steps with `CADDY_IMAGE` (`livekit/caddyl4` tags).

## Local dev (unchanged)

Root `docker-compose.yml` runs the same server version with `--dev` (keys `devkey`/`secret`) on 7880/7881/7882-udp.
Start it with `LIVEKIT_NODE_IP=<LAN IP of the dev machine> docker compose up -d livekit` and set
`LIVEKIT_URL=ws://<same LAN IP>:7880` in `backend/.env`; without the node IP LiveKit advertises the
container address (172.x) and phones get no audio.
