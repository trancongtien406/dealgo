# VPS deploy (single host, shared with other services)

DealGo production runs on one VPS (`103.116.38.245`, Ubuntu 24.04) that **also hosts other live
services** (hancity.vn, other *.trancongtien.com sites). Everything DealGo lives in `/opt/dealgo` as
the Docker Compose project `dealgo`. Never stop, restart or edit other projects' containers.

## Layout

| Path on VPS | What |
|---|---|
| `/opt/dealgo/docker-compose.yml` | Stack definition (from `deploy/vps/docker-compose.yml`) |
| `/opt/dealgo/src/{backend,website}` | Build contexts (copy of the repo, no `node_modules`/`.env`) |
| `/opt/dealgo/env/` (700) | `backend.env`, `postgres.env`, `website.env`, `thirdparty.env`, `ops-admin.txt` — all 600 |
| `/opt/dealgo/.env` (600) | Build args for the web image (`NEXT_PUBLIC_*`) |
| `/opt/dealgo/secrets/` (700, uid 1000) | `fcm-service-account.json`, `AuthKey_<id>.p8`; mounted read-only at `/run/dealgo` |
| `/opt/dealgo/livekit/` | `livekit.yaml`, `keys.yaml` (600), `gen-keys.sh` |
| `/opt/dealgo/Caddyfile.dealgo` | Site blocks appended to the shared Caddy (see below) |
| `/opt/dealgo/gen-secrets.sh` | First-time secret generation (refuses to overwrite without `--force`) |

## Services

| Container | Image / target | Network | Host port | Limit |
|---|---|---|---|---|
| `dealgo-postgres` | postgres:16-alpine, volume `dealgo_postgres` | dealgo_internal | none | 1g |
| `dealgo-redis` | redis:7-alpine (AOF, noeviction), volume `dealgo_redis` | dealgo_internal | none | 384m |
| `dealgo-api` | backend `api` target, :3001, volume `dealgo_objects` | internal + vms_edge | none | 1g |
| `dealgo-worker` | backend `worker` target | dealgo_internal | none | 768m |
| `dealgo-web` | website (Next standalone), :3000 | internal + vms_edge | none | 768m |
| `dealgo-livekit` | livekit/livekit-server:v1.13.11, host network | host | 7880 (127.0.0.1 + 172.19.0.1 only), 7881/tcp, 3478/udp, TURN/TLS 5349/tcp, 50000-60000/udp, TURN relay 30000-40000/udp | 1g |
| `dealgo-photon` | Photon 1.3.0 (komoot, OSM), Vietnam-only index, :2322, volume `dealgo_photon` | dealgo_internal | none | 1536m, 2 CPU, `-Xmx1g` |
| `dealgo-photon-import` | same image (profile `photon-import`, one-shot index build) | dealgo_internal | none | 1536m, 2 CPU |
| `dealgo-migrate` | backend `migrate` target (profile `migrate`, one-shot) | dealgo_internal | none | — |

Containers are named `dealgo-*` because they share the `vms_edge` network with other projects; short
aliases such as `web` or `api` would collide there.

## Public entry (shared Caddy)

`:80/:443` belong to the `vms-caddy-1` container (project in `/opt/vms_service/deploy`). Its
Caddyfile is a **single-file bind mount**, so edit it in place (append / `cat >`), never `sed -i` or
`mv` (that changes the inode and the container keeps the old file).

| Host | Upstream |
|---|---|
| `dealgo.trancongtien.com` | `dealgo-web:3000` |
| `api-dealgo.trancongtien.com` | `dealgo-api:3001` (REST + Socket.IO, no read timeout, 25 MB body) |
| `livekit-dealgo.trancongtien.com` | `172.19.0.1:7880` (LiveKit signalling via the vms_edge gateway) |

Change procedure:

```bash
cd /opt/vms_service/deploy
cp -p Caddyfile Caddyfile.bak.$(date +%Y%m%d%H%M%S)
# edit the DealGo blocks in place (keep the inode), then:
docker exec vms-caddy-1 caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
docker exec vms-caddy-1 caddy reload   --config /etc/caddy/Caddyfile --adapter caddyfile
```

If validation fails, restore with `cat Caddyfile.bak.<ts> > Caddyfile` (in place) and validate again.
Certificates are issued by that Caddy via HTTP-01 (`import http01_only`).

## DNS (Cloudflare)

| Record | Value | Proxy |
|---|---|---|
| `dealgo` | A 103.116.38.245 | proxied OK (SSL mode Full/Full strict) |
| `api-dealgo` | A 103.116.38.245 | proxied OK (WebSockets on) |
| `livekit-dealgo` | A 103.116.38.245 | proxied OK for wss signalling; DNS-only also works |
| `turn-dealgo` | A 103.116.38.245 | **DNS only** (TURN is UDP; Cloudflare cannot proxy it) |

Media never goes through Cloudflare: LiveKit advertises the node IP `103.116.38.245` directly.

## LiveKit / TURN

- Signalling: `wss://livekit-dealgo.trancongtien.com` (through the shared Caddy).
- Media: UDP 50000-60000 on the node IP; ICE-TCP fallback on 7881.
- Embedded TURN: UDP 3478 and TURN/TLS on **TCP 5349** (`turn-dealgo.trancongtien.com`), relay ports
  30000-40000/udp. TURN/TLS is not on 443 because the shared Caddy owns 443. Clients on networks that
  block UDP use TURN/TLS 5349 or ICE-TCP 7881.
- TURN/TLS certificate: the shared Caddy has a `turn-dealgo.trancongtien.com` site block that only
  obtains and renews the Let's Encrypt certificate (HTTP-01; it answers 404). `livekit/sync-turn-cert.sh`
  copies it to `livekit/tls/turn.{crt,key}` (600, mounted read-only at `/etc/livekit-tls`) and restarts
  `dealgo-livekit` only when the file changed. Root cron runs it daily at 04:17
  (log `/var/log/dealgo-turn-cert.log`). Run it by hand after the first deploy with `--no-restart`,
  then start LiveKit.
- API keys: `livekit/keys.yaml` (generated by `gen-keys.sh`); the same key/secret are in
  `env/backend.env` (`LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET`). Rotate both together.
- Host firewall: there is no ufw/nft policy on this VPS (INPUT ACCEPT). If a provider firewall exists,
  it must allow 7881/tcp, 5349/tcp, 3478/udp, 30000-40000/udp and 50000-60000/udp.

## Production configuration notes

- `NODE_ENV=production`; the API refuses to start without: non-dev `JWT_ACCESS_SECRET`,
  `CHAT_ENCRYPTION_KEY`, FCM credentials (`PUSH_PROVIDER=fcm`), Mapbox maps + directions tokens, and
  LiveKit wss + secret ≥ 32 chars.
- Payments: `PAYMENT_PROVIDER=cash-only`.
- SMS and email providers are not configured, so the `PHONE_SMS` and `EMAIL_LOGIN_IDENTIFIER` sign-in
  methods are **disabled** in `auth_method_policies` (only `PASSKEY` is on). The API refuses to start
  while a method is enabled without its provider. After adding provider keys to `env/backend.env`,
  re-enable them in Admin → Phương thức đăng nhập (or the SQL below) and recreate the API.
- `PLACES_OSM_SEARCH_URL=http://dealgo-photon:2322` (self-hosted Photon, see below). Mapbox stays the
  primary provider; Photon adds the OSM street/alley data Mapbox lacks in VN (e.g. Nguyễn Hoàng, Đà Nẵng).
  Unset it and recreate `dealgo-api` to fall back to Mapbox-only; Photon failures already degrade to [].
- `GOOGLE_MAPS_API_KEY` is blank, so Admin → Cài đặt → Bản đồ shows Google as not configured and every
  map capability uses Mapbox. To enable it: put the key in `env/thirdparty.env` and `env/backend.env`, recreate
  `dealgo-api` and `dealgo-worker`, then pick Google per capability in Admin (cost/ToS: `05-architecture/places-search.md`).
- Object storage is local (`OBJECT_STORAGE_PROVIDER=local`, volume `dealgo_objects`, owned by uid 1000).
- `TRUST_PROXY=2` (Cloudflare → Caddy → API).
- First super-admin comes from `OPS_BOOTSTRAP_EMAIL` / `OPS_BOOTSTRAP_PASSWORD`
  (credentials in `env/ops-admin.txt`). Change the password after the first login.
- Demo seed is never run here (`SEED_ALLOW_PRODUCTION` is unset).

Break-glass toggle of sign-in methods without the TS CLI (the runtime images have no `tsx`):

```bash
docker exec -i dealgo-postgres sh -c 'psql -U $POSTGRES_USER -d $POSTGRES_DB' <<'SQL'
UPDATE auth_method_policies SET enabled = true, "updatedAt" = now() WHERE method = 'PHONE_SMS';
SQL
```

## First install

```bash
cd /opt/dealgo
livekit/gen-keys.sh && rm -f livekit/backend.env.snippet
./gen-secrets.sh                      # writes env/*.env, .env, env/ops-admin.txt (600, never printed)
docker compose --profile migrate build
docker compose up -d dealgo-postgres dealgo-redis dealgo-livekit
docker volume create dealgo_objects
docker run --rm -v dealgo_objects:/d alpine chown -R 1000:1000 /d
docker compose --profile migrate run --rm dealgo-migrate
docker compose up -d
# then append Caddyfile.dealgo to the shared Caddyfile (procedure above)
```

## Redeploy (new code)

```bash
# from a workstation: ship the source without node_modules/.env/secrets
tar czf - --exclude=node_modules --exclude=dist --exclude=.next --exclude='.env*' backend website \
  | ssh root@103.116.38.245 'cd /opt/dealgo/src && tar xzf -'
ssh root@103.116.38.245 '
  cd /opt/dealgo &&
  docker compose --profile migrate build &&
  docker compose --profile migrate run --rm dealgo-migrate &&
  docker compose up -d dealgo-api dealgo-worker dealgo-web'
```

`NEXT_PUBLIC_*` values are baked at build time from `/opt/dealgo/.env`; rebuild `dealgo-web` after
changing them.

## Place search: self-hosted Photon (OSM)

Mapbox alone misses many Vietnamese streets, so the API also queries a private Photon
(`deploy/vps/photon/`: `Dockerfile`, `photon-import.sh`). Data © OpenStreetMap contributors (ODbL).

- Image `dealgo-photon` = `eclipse-temurin:21-jre` + the official `photon-1.3.0.jar`
  (github.com/komoot/photon/releases). Dumps must match the Photon major version (`1.0` dumps for 1.x).
- Data: GraphHopper weekly Vietnam JSON dump
  `https://download1.graphhopper.com/public/asia/vietnam/photon-dump-vietnam-1.0-latest.jsonl.zst`
  (~70 MB; ~460k documents; index ~185 MB; import ~3 min at 2 CPU, nice 19). The import script checks the
  `.md5`, imports with `-country-codes vn -languages vi,en` into a staging dir, then swaps it in.
- Runtime: ~0.4–1 GB RSS, internal network only (no host port), healthcheck = a sample `/api` query.

First install:

```bash
cd /opt/dealgo
docker compose build dealgo-photon
docker volume create dealgo_photon
docker run --rm -v dealgo_photon:/p alpine chown 2322:2322 /p     # image runs as uid 2322
docker compose --profile photon-import run --rm dealgo-photon-import > photon-import.log 2>&1
docker compose up -d --no-deps dealgo-photon
# env/backend.env: PLACES_OSM_SEARCH_URL=http://dealgo-photon:2322
docker compose up -d --no-deps dealgo-api
```

Monthly refresh (OSM changes; GraphHopper republishes weekly). The running server keeps serving the
old index while the import builds the new one; restart Photon to pick it up (~30 s gap during which the
API answers Mapbox-only):

```bash
cd /opt/dealgo
docker compose --profile photon-import run --rm dealgo-photon-import > photon-import.log 2>&1 \
  && docker compose restart dealgo-photon
docker exec dealgo-api node -e "fetch('http://dealgo-photon:2322/api?q=Nguy%E1%BB%85n%20Ho%C3%A0ng&lat=16.0544&lon=108.2022&limit=3').then(r=>r.json()).then(j=>console.log(j.features.length))"
```

Upgrading Photon: bump `PHOTON_VERSION` in `photon/Dockerfile`, rebuild, re-run the import (an index is
tied to its Photon version), restart `dealgo-photon`. Optional cron (1st of month, 03:30):
`30 3 1 * * cd /opt/dealgo && docker compose --profile photon-import run --rm dealgo-photon-import > photon-import.log 2>&1 && docker compose restart dealgo-photon`

## Mobile app against this VPS

Release builds of `mobile/` default to `https://api-dealgo.trancongtien.com` (REST + Socket.IO) and
`APP_LINK_HOST=dealgo.trancongtien.com`; LiveKit's `wss://livekit-dealgo.trancongtien.com` comes from
`LIVEKIT_URL` in `env/backend.env`. Build commands: [`mobile/README.md`](../../mobile/README.md#build-production).

App-link files are served by Nest through the website at `https://dealgo.trancongtien.com/.well-known/…`:
- `apple-app-site-association`: from `APP_LINKS_IOS_APP_IDS` (`6J3522877H.com.trancongtien.dealgo`).
- `assetlinks.json`: returns 404 until `APP_LINKS_ANDROID_CERT_SHA256` is set. Set it from the release keystore
  or the Play App Signing certificate, then recreate `dealgo-api`. There is no release keystore yet.

## Verify

```bash
curl -s https://api-dealgo.trancongtien.com/health/ready    # database/redis up, worker up
curl -s https://api-dealgo.trancongtien.com/health/worker
curl -s 'https://api-dealgo.trancongtien.com/socket.io/?EIO=4&transport=polling'   # 0{"sid":...}
curl -s https://livekit-dealgo.trancongtien.com/            # OK
curl -sI https://dealgo.trancongtien.com/login              # 200
docker compose ps                                           # all healthy
```

Also check the neighbours are unaffected after any Caddy change (status of each other site via
`curl --resolve <host>:443:127.0.0.1`).

## Backups (not automated yet)

```bash
docker exec dealgo-postgres sh -c 'pg_dump -U $POSTGRES_USER -Fc $POSTGRES_DB' > /root/dealgo-$(date +%F).dump
docker run --rm -v dealgo_objects:/d -v /root:/out alpine tar czf /out/dealgo-objects-$(date +%F).tgz -C /d .
```

Keep copies off the VPS. `env/`, `secrets/` and `livekit/keys.yaml` must be backed up separately
(encrypted): losing `CHAT_ENCRYPTION_KEY` makes stored chat unreadable.

## Rollback

- App: re-tag/rebuild the previous source and `docker compose up -d dealgo-api dealgo-worker dealgo-web`.
  Migrations are forward-only; restore from a `pg_dump` if a migration must be undone.
- Edge: restore the latest `Caddyfile.bak.<ts>` in place, validate, reload.
- Full removal: `docker compose down` (keeps volumes) and delete the DealGo blocks from the shared
  Caddyfile. Do not touch other projects.
