# Food Customer Redesign — P2 Implementation Plan

**Spec:** `docs/superpowers/specs/2026-11-03-food-customer-redesign-design.md` (§6.6, §6.7, §6.10, §7.1–7.3, §13)
**Phase:** P2 — order notes, utensils, cart upsell, delivery-fee block
**Prerequisite:** P1 merged on `feat/food-customer-redesign-p1` (commits `d2e3c38..cbd4f3e`)

## P2 exit criteria (spec §13)

An order carrying a note shows that note unchanged to the customer, the store, the driver and ops.
Notes survive the cart draft, the place-order request, every read view and the invoice.
No route, deep link or colour changes. `flutter analyze` clean, backend `npm test` and
`npm run test:e2e` unaffected, new tests for each block.

## What P2 does NOT do

- Dish search hits (`GET /v1/food/search`) — P3.
- `GET /v1/food/stores/:id/suggestions` — P3. P2 upsell reads `store.items` already loaded (spec `FOOD-CX-OD-03`).
- `closesAtToday`, voucher wall, reorder, trust strip — P3.
- Tracking summary/fare storytelling golden work — P4.

## Contract (from spec §7)

```prisma
model FoodOrderLine {
  /// Customer note for this line ("ít cay, không hành"); null = none.
  note String? @db.VarChar(200)
}

model FoodOrder {
  /// Customer note for the store / driver; null = none.
  note String? @db.VarChar(300)
  /// Cutlery requested with this order.
  utensils Boolean @default(true)
}
```

`POST /v1/food/orders` gains `note?`, `utensils?`, and `note?` per item.
Every read view that returns lines returns the line `note`; order detail returns `note` and `utensils`.

`FOOD-CX-OD-01` (utensils default) stays open in `docs/00-governance`, but the column default is
`true` per spec §7.1; a later migration can flip it without backfilling because the client always
sends its own value.

## Task order and gates

### Task 1 — Backend schema and migration
- `backend/prisma/schema.prisma`: the three fields above.
- New migration `backend/prisma/migrations/<ts>_food_order_notes/migration.sql`, `ADD COLUMN` only,
  nullable or defaulted, no backfill.
- Gate: `npx prisma validate`, `npx prisma migrate diff --from-schema-datasource … --to-schema-datamodel …`
  prints no unexpected statements; `npm run build` clean.

### Task 2 — Backend write path
- `food.dto.ts`: `PlaceFoodOrderDto.note?` (`@MaxLength(300)`), `utensils?` (boolean),
  `FoodLineDto.note?` (`@MaxLength(200)`); trim, empty → null.
- `food.service.ts#place`: pass trimmed values into the repository input.
- `food-prisma.repository.ts#place` + the in-memory `food.repository.ts#place`: persist order note,
  utensils, and each line note.
- Gate: integration test in `backend/test/integration/food-order/food.http.spec.ts` — place an order
  with an order note, utensils disabled and one line note; read it back.

### Task 3 — Backend read views
- `FoodLineView.note`, `FoodOrderView.note/utensils`, `PublicFoodOrder` and the line mapper.
- Order detail, customer list and ops list/detail carry the new fields; no shape change elsewhere.
- Gate: integration test asserts the placed note/utensils arrive on `GET /v1/food/orders/:id` and in
  the customer list; existing contract snapshots still pass.

### Task 4 — Mobile models and cart state
- `FoodOrderLine.note`, `FoodOrderDetail.note/utensils`, `PlacedFoodOrder.note/utensils`.
- `PlaceFoodOrderBody` / `PlaceFoodOrderParams` / `FoodOrderItem` gain `note`, order `note`, `utensils`.
- `FoodCartLine.note`; `FoodCartCubit` gains `note`, `utensils`, `setNote`, `setLineNote`,
  `setUtensils`; switching store resets both; `copyWith` keeps them for the same store.
- `food_cart_draft.dart` persists and restores `note`, `utensils`, per-line `note`.
- Gate: unit tests for reset-on-store-change, draft round trip, and body JSON keys.

### Task 5 — Cart UI
- Per-line note: sheet with 0/200 counter, opened from the line row; the line shows the note in quotes.
- Order note field 0/300 and an utensils toggle (Có/Không) above the totals.
- Upsell strip: up to 6 sellable items from the loaded store, excluding groups already in the cart and
  items already present; tapping adds one unit.
- Gate: widget tests — note survives a quantity change, utensils toggle updates the cubit, upsell hides
  sold-out and in-cart items.

### Task 6 — Checkout
- Send `note`, `utensils` and line notes; show the utensils choice and an editable note in the summary.
- Delivery-fee block: keep the existing quote-driven panel; verify `NEGOTIATE` vs `FIXED` copy matches
  spec §6.7 and that no bound is hardcoded.
- Gate: widget test asserts the place body carries note/utensils; a fixed-fee mode test asserts no stepper.

### Task 7 — Read surfaces
- Invoice: order note, utensils, per-line notes.
- Merchant order detail: per-line note, order note, utensils.
- Driver job detail: order note and utensils (driver currently sees `lineCount` only).
- Customer tracking: order note line in the summary block.
- Gate: one widget test per surface.

### Task 8 — Docs and status
- `docs/10-ai-execution/screen-inventory.md` C027/C028/C032/C033/C037 notes.
- Spec status → `P2_IMPLEMENTED`; `FOOD-CX-OD-01` recorded as implemented-with-default, still open.

## Constraints (all tasks)

- Backend: no breaking response change; new fields are additive and may be null.
- Notes are user data: render escaped, never log them, never include them in analytics.
- Mobile: tokens only, `copyWith(fontSize:` stays forbidden in `lib/features/food/presentation`.
- Files ≤ 500 lines; `food_cart_page.dart` and `food_checkout_page.dart` are already near the limit —
  extract widgets under `widgets/` instead of growing them.
- Every task stages only its own files.
