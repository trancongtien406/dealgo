# DealGo Backend

NestJS 12 modular monolith for DealGo Ride and Food: REST API under `/v1`, Socket.IO realtime, and a separate BullMQ worker process. PostgreSQL via Prisma 7, Redis for cache, queues and the Socket.IO adapter.

## Layout

| Path | Contents |
|---|---|
| `src/modules/*` | Business modules (ride, dispatch, food-order, pricing, promotion, ledger, settlement, identity, operations, support, …) |
| `src/platform/*` | Shared infrastructure: config (`env.ts`, zod), database, cache, queue, security, settings, storage, audit, health, observability |
| `src/workers/` | Worker entry (`worker-main`) and jobs: `ride-expiry`, `outbox-relay`, `upload-orphan-cleanup`, `account-purge`, `worker-heartbeat`, `chat-retention` |
| `prisma/` | `schema.prisma`, migrations, seed scripts |
| `scripts/` | Operational scripts, including `export-openapi.mjs` |

## Run locally

```bash
docker compose -f ../docker-compose.yml up -d   # Postgres :5433, Redis :6379
npm install
npx prisma migrate deploy
npm run seed                 # refuses NODE_ENV=production unless SEED_ALLOW_PRODUCTION=true
npm run start:dev            # API on PORT (default 3001)
npm run start:worker:dev     # worker, in a second terminal
```

Health: `GET /health`, `/health/live`, `/health/ready`, `/health/worker`.

Environment variables and secrets: [`../docs/09-operations/secrets-and-env-catalog.md`](../docs/09-operations/secrets-and-env-catalog.md). Runtime settings editable in Admin: [`../docs/10-ai-execution/open-admin-settings-map.md`](../docs/10-ai-execution/open-admin-settings-map.md).

## Checks

```bash
npm run lint
npm run typecheck
npm run test          # vitest unit tests
npm run test:e2e      # vitest e2e (needs Postgres + Redis)
```

## API contract

- REST: [`../docs/06-data-api/rest-api.openapi.yaml`](../docs/06-data-api/rest-api.openapi.yaml), generated from code with `npm run openapi:export`.
- Realtime: [`../docs/06-data-api/realtime-api-contract.md`](../docs/06-data-api/realtime-api-contract.md).

## Production

`start:prod` runs the API, `start:worker` runs the worker. Production refuses mock providers (SMS, email, push, voice) and requires the secrets listed in the env catalog. Example stack: `../docker-compose.prod.example.yml`.
