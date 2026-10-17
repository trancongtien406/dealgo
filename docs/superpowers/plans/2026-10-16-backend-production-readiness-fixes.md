# Backend Production Readiness Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Resolve all 5 production-readiness findings in DealGo Backend (outbox provider wiring, atomic outbox claim locking, CI integration test paths, domain decouple from Ops via AuditModule, and worker composition cleanup).

**Architecture:** 
- Add `lockedAt` column and index to `OutboxMessage`, implementing atomic batch claim via `FOR UPDATE SKIP LOCKED` CTE in `PrismaOutboxRepository` and memory lease in `MemoryOutboxRepository`.
- Wire `RideModule`, `FoodModule`, and `RealtimeModule` into `OutboxModule` and enforce strict fail-fast validation in `OutboxRelayService` so unhandled events are never marked processed.
- Decouple domain modules (`service-area`, `support`) from `OpsModule` by establishing `AuditModule` in `platform/audit`.
- Fix CI test file paths in `.github/workflows/backend.yml` to reflect new test layout.
- Eliminate duplicate module imports in `StandaloneWorkerModule`.

**Tech Stack:** NestJS 12, Prisma 7, PostgreSQL, TypeScript, Vitest.

---

## Tasks

### Task 1: Atomic Outbox Claim & Lock (Finding 2)
**Files:**
- Modify: `backend/prisma/schema.prisma`
- Create: `backend/prisma/migrations/20261016150000_outbox_claim_lock/migration.sql`
- Modify: `backend/src/modules/communication/outbox/outbox.repository.ts`
- Modify: `backend/src/modules/communication/outbox/outbox-prisma.repository.ts`

- [ ] Add `lockedAt DateTime?` and index `@@index([processedAt, lockedAt])` to `model OutboxMessage` in `schema.prisma`.
- [ ] Create SQL migration `backend/prisma/migrations/20261016150000_outbox_claim_lock/migration.sql`.
- [ ] Regenerate Prisma client (`npm run prisma:generate`).
- [ ] Update `OutboxRepository` interface to add `claimPending(limit: number, now?: Date, lockTtlMs?: number)` and `releaseLock(id: string)`.
- [ ] Implement lease-based `claimPending` and `releaseLock` in `MemoryOutboxRepository`.
- [ ] Implement atomic `claimPending` with `FOR UPDATE SKIP LOCKED` and `releaseLock` in `PrismaOutboxRepository`.
- [ ] Verify with unit tests in `outbox-claim.spec.ts`.

### Task 2: Outbox Module Wiring & Fail-Fast Notification Delivery (Finding 1)
**Files:**
- Modify: `backend/src/modules/communication/outbox/outbox.module.ts`
- Modify: `backend/src/modules/communication/outbox/outbox-relay.service.ts`
- Modify: `backend/src/modules/communication/outbox/outbox-relay.service.spec.ts`

- [ ] Import `RideModule`, `FoodModule`, and `RealtimeModule` into `OutboxModule`.
- [ ] Update `OutboxRelayService.relayOnce()` to use `this.outbox.claimPending(limit, now)` instead of `listPending`.
- [ ] In `OutboxRelayService`, throw an error if a notable push or snapshot event requires a service (`rides`, `food`, `fanout`, `push`, `prisma`) that is not available, ensuring it logs failure and releases the lock instead of marking processed.
- [ ] On relay error in loop, call `this.outbox.releaseLock(row.id)` so retry happens immediately without waiting for lock expiration.
- [ ] Update `outbox-relay.service.spec.ts` to test `claimPending` and fail-fast behavior.

### Task 3: Decouple Domain Modules from Operations via AuditModule (Finding 4)
**Files:**
- Create: `backend/src/platform/audit/audit-logs.service.ts`
- Create: `backend/src/platform/audit/audit.module.ts`
- Create: `backend/src/platform/audit/index.ts`
- Modify: `backend/src/platform/index.ts`
- Modify: `backend/src/modules/operations/ops-audit-logs.service.ts`
- Modify: `backend/src/modules/operations/ops.module.ts`
- Modify: `backend/src/modules/service-area/service-area.module.ts`
- Modify: `backend/src/modules/service-area/service-regions.service.ts`
- Modify: `backend/src/modules/support/support.module.ts`
- Modify: `backend/src/modules/support/ops-disputes.service.ts`
- Modify: `backend/src/app.module.ts`

- [ ] Create `AuditLogsService` and `AuditModule` in `src/platform/audit/`.
- [ ] Re-export `AuditModule` and `AuditLogsService` in `src/platform/index.ts`.
- [ ] In `src/modules/operations/ops-audit-logs.service.ts`, re-export or alias from `src/platform/audit/`.
- [ ] In `src/modules/operations/ops.module.ts`, import `AuditModule`.
- [ ] In `src/modules/service-area/service-area.module.ts`, replace `OpsModule` with `AuditModule`.
- [ ] In `src/modules/service-area/service-regions.service.ts`, inject `AuditLogsService` from `platform/audit`.
- [ ] In `src/modules/support/support.module.ts`, replace `OpsModule` with `AuditModule`.
- [ ] In `src/modules/support/ops-disputes.service.ts`, inject `AuditLogsService` from `platform/audit`.
- [ ] In `src/app.module.ts`, add `AuditModule`.

### Task 4: Fix CI Integration Test Paths (Finding 3)
**Files:**
- Modify: `.github/workflows/backend.yml`

- [ ] Update integration test arguments to point to valid test files:
  - `test/concurrency/driver-assignment.race.spec.ts`
  - `test/concurrency/food-claim.race.spec.ts`
  - `test/concurrency/payment-webhook.race.spec.ts`
  - `src/modules/communication/outbox/outbox-relay.service.spec.ts`
  - `src/integrations/push/push-sender.spec.ts`
  - `src/modules/operations/ops-exceptions.classify.spec.ts`

### Task 5: Clean Up Worker Composition (Finding 5)
**Files:**
- Modify: `backend/src/workers/worker-main.ts`

- [ ] Remove duplicate `PrismaModule`, `RideModule`, `OutboxModule` imports from `StandaloneWorkerModule`.

### Task 6: Verification & Quality Gates
- [ ] Run `npm run lint` in `backend`.
- [ ] Run `npm run build` in `backend`.
- [ ] Run `npm test` in `backend`.
- [ ] Verify all test suites pass.
