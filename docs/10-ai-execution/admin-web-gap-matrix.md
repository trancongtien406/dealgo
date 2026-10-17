---
doc_id: DG-AI-004
title: "DealGo — Admin Web gap matrix vs dealgo-website.mdc"
version: "0.5.5"
status: "ACTIVE"
owner: "Tech Lead"
last_updated: "2026-10-14"
---

# Admin Web gap matrix

> Lint/`tsc` xanh **không** bằng Done với Nest. Done Phase 1 = feature-first + data boundary + Query/URL.

## Verdict (2026-10-14)

**Phase 1 + 1b DONE (architecture mock).** **Phase 2b–2c Nest-backed:** rides / food-orders / partner-applications (KYC + approve/reject) + ledger inspect + **exceptions board** (`/exceptions`, list-only) + **settlements** day buckets (`GET /api/ops/settlements` → Nest) + **auth-methods** (`/settings/auth-methods` → Nest GET/PATCH); session probe TTL (15s). **Login/logout** use `features/session` TanStack mutations (BFF `/api/ops/session`) — no direct `apiFetch`/`fetch` in form/button. **Platform settings** `/settings/platform` + **FAQ OPEN** `/settings/faqs` (Nest DB overrides for TEST_ONLY tunables; FAQ drafts PROPOSED OPEN-001..021). Role-grants Nest only has approve/reject by id (no ops list) — staff UI stays fixture. **Customers board remains fixture** until Nest exposes an ops users/customers list. Drivers / stores / transactions still fixture. Browser sanity NOT_RUN. **CAP-OPS-05 intervene** on ride/food detail DONE; exceptions list-only.

## Phase plan

### Phase 1 / 1b — Ownership + data boundary — DONE

- [x] Feature folders; boards out of god `components/`
- [x] EN codes + mappers; fixtures out of UI
- [x] TanStack Query + nuqs + `lib/api`
- [x] AdminPrivatePage all private routes
- [x] Detail by `code` + SampleNotFound
- [x] typecheck + vitest

### Phase 2 — Auth + Nest contract

1. [x] Verify ops session với Nest (GET `/api/ops/session` + `requireOpsSession` probe `GET /v1/ops/rides?limit=1`; no Nest ops `/me`)
2. [x] BFF Route Handlers: rides, food-orders, partner-applications (+ approve/reject)
3. [x] Swap mock adapters → BFF khi `ADMIN_UI_MOCK` tắt (3 domains)
4. [x] Map Nest status → feature EN → VN labels
5. [x] **Phase 2b:** BFF `…/rides/:id/ledger`, `…/food-orders/:id/ledger` + detail journal panel (live only)
6. [x] **Phase 2b:** KYC detail approve/reject → Nest when `!ADMIN_UI_MOCK` + query invalidation
7. [x] **Phase 2b:** Enrich customer/driver/store labels from Nest ids/metadata (RideView still omits `customerId`)
8. [x] **Phase 2b:** Session probe TTL cache (`OPS_SESSION_PROBE_TTL_MS`, default 15s, clamp 5–30s; success-only)
9. [x] **Phase 2b:** Ops exceptions BFF + live adapter when `!ADMIN_UI_MOCK` (`GET /v1/ops/exceptions`)
10. [x] **Phase 2b:** Exceptions board UI `/exceptions` (nav + filters + entity links; **list-only**, no intervene)
11. [x] **Phase 2c:** Settlements BFF + live lines table when `!ADMIN_UI_MOCK` (`GET /v1/ops/settlements`)
12. [ ] Role-grants staff UI: Nest chỉ `POST …/approve|reject` (không list ops) — giữ fixture
13. [ ] **Customers:** vẫn fixture — Nest **không** có `GET /v1/ops/users|customers` (cũng không có ops GET user-by-id); không invent BFF live swap. Drivers / stores / transactions vẫn fixture.
14. [x] **CAP-OPS-05 intervene (DONE cancel/reassign on detail):** Nest `POST …/rides|food-orders/:id/cancel|reassign` + Admin BFF CSRF + detail reason dialog when `!ADMIN_UI_MOCK`; exceptions board remains list-only
15. [x] **Auth methods (FR-OPS-010):** `/settings` link → `/settings/auth-methods`; BFF GET/PATCH → Nest when `!ADMIN_UI_MOCK`

### Phase 3 — UX reliability

- error/loading/not-found
- Mutation thật thay PreviewButton (KYC approve/reject + ride/food cancel/reassign + **login/logout session mutations** done; other boards pending)
- Hex → CSS variables
- Browser E2E smoke

## Session probe cache (ops)

| Item | Value |
|---|---|
| Where | `website/lib/api/ops-upstream.ts` → `verifyOpsAccessToken` |
| Used by | `requireOpsSession` on every `AdminPrivatePage` |
| TTL | `OPS_SESSION_PROBE_TTL_MS` env, default **15000**, clamped **5000–30000** |
| Scope | In-process Map keyed by truncated token fingerprint; **successful** probes only |
| Why | Nest has no ops `/me`; list probe each navigation is expensive |

## Nest coverage vs Admin boards

| Board / surface | Nest ops API | Admin BFF | Live adapter |
|---|---|---|---|
| Rides list/detail | Yes | Yes | Yes (`!ADMIN_UI_MOCK`) |
| Ride ledger | Yes `GET …/rides/:id/ledger` | Yes | Yes (detail panel) |
| Food orders list/detail | Yes | Yes | Yes |
| Food order ledger | Yes `GET …/food-orders/:id/ledger` | Yes | Yes (detail panel) |
| KYC / partner applications | Yes | Yes + approve/reject | Yes |
| Ops exceptions board | Yes `GET /v1/ops/exceptions` | Yes | Yes (`!ADMIN_UI_MOCK`); UI `/exceptions` DONE; **list-only** (intervene on ride/food detail) |
| Ride / food cancel (CAP-OPS-05) | Yes `POST …/cancel` | Yes | Yes (detail reason dialog; `!ADMIN_UI_MOCK`) |
| Ride / food reassign | Yes `POST …/reassign` (TEST_ONLY) | Yes | Yes (detail reason dialog; eligibility heuristic on feature status) |
| Settlements | Yes `GET /v1/ops/settlements` (day buckets) | Yes | Yes (lines table; KPI/partner still fixture) |
| Role grants approve/reject | Yes approve/reject only (no ops list) | Paths reserved | Staff page still mock matrix |
| Auth methods (Passkey/SMS/Email) | Yes `GET/PATCH /v1/ops/auth-methods` | Yes | Yes (`/settings/auth-methods`; `!ADMIN_UI_MOCK`) |
| **Customers** list/detail | **No** ops users/customers list; **no** ops GET user-by-id | Paths reserved (`opsCustomers`) | **Fixtures** until Nest list exists — do not invent API |
| Drivers / stores / transactions / … | No | Paths reserved | Fixtures |
| Customer labels on food detail | Nest returns `customerId` on food order | N/A (via food BFF) | Live label `Khách · {id}` (not full profile) |
| Customer labels on ride detail | RideView omits `customerId` | N/A | Placeholder `Khách (Nest ẩn id)` |
