# Food Customer Redesign — P3 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Spec:** `docs/superpowers/specs/2026-11-03-food-customer-redesign-design.md` (§6.1, §6.2, §6.4, §6.5, §7.2, §8, §13)
**Phase:** P3 — dish search, voucher wall, reorder, `closesAtToday`, trust strip
**Prerequisite:** P2 merged on `feat/food-customer-redesign-p1` (`ac3e8e8..a6656d5`)

**Goal:** A customer can type a dish name and get that dish (with its store) above the store results,
see today's closing time and delivery-from fee on a store, see usable vouchers and one-tap reorder on
the discovery feed, and see accompanying dishes on the item page.

**Architecture:** Two additive read endpoints (`GET /v1/food/search`, `GET /v1/food/stores/:id/suggestions`)
and one additive field (`closesAtToday`) in the food-order module, then Flutter consumes them with a
new `FoodSearchCubit` (search page) plus small stateful blocks on discovery and the item page. No
existing response shape changes; everything new is optional.

**Tech Stack:** NestJS 12 + Prisma 7/PostgreSQL (raw SQL for browse), Flutter 3.47 / Dart 3.13,
flutter_bloc, go_router, gen-l10n, `flutter_test`, Vitest + Postgres integration specs.

## P3 exit criteria (spec §13)

- Typing a dish name returns a dish section (dish first, stores second); tapping a dish opens the item page.
- A store card shows "Mở đến HH:mm"; the store hero shows "Mở đến" and "Phí giao từ" only with real data.
- Discovery shows a voucher wall (usable FOOD vouchers) and a "Đặt lại đơn quen" block when eligible.
- Item page shows up to 6 accompanying dishes from the same store.
- `flutter analyze` clean, mobile food suite green, backend `npm test` + `npm run test:e2e` green.

## What P3 does NOT do

- Realtime search suggestions while typing (no autocomplete endpoint) — keyword chips come from
  categories + featured dish names already loaded.
- New payment, fare or voucher rules. The wall only lists campaigns the user can already use.
- P4 golden/motion work, tracking summary and fare storytelling.
- Reworking `food_discovery_page.dart` beyond the two new blocks; it is already 1 088 lines and is
  split only where a new block is added.

## Global Constraints

- Backend: additive only. New fields optional/nullable; no route or status-code change for existing calls.
- Notes/queries are user data: never log the search string, never put it in analytics.
- `closesAtToday` is derived data: never hardcode a store's hours on the client.
- Mobile: tokens only; `copyWith(fontSize:` stays forbidden in `lib/features/food/presentation`.
- New files ≤ 500 lines; do not grow `food_discovery_page.dart` past its current size — new blocks go
  into `widgets/`.
- Every task stages only its own files. The working tree also carries unrelated P3/driver-credit WIP:
  never `git add -A`.

---

## Task 1 — `closesAtToday` on browse items and store detail

**Files:**
- Modify: `backend/src/modules/food-order/store-schedule.ts`
- Modify: `backend/src/modules/food-order/food.repository.ts:103-123` (`StoreBrowseItem`), `:216-224` (`StoreDetail`)
- Modify: `backend/src/modules/food-order/food.repository.ts` memory `listStores` + `findStore`
- Modify: `backend/src/modules/food-order/food-prisma.repository.ts:299-360` (browse SQL), `:3419-3440` (`scheduleFromRow`), `toStoreDetail`
- Modify: `backend/src/modules/food-order/food.service.ts:130-148` (`PublicStoreBrowseItem`)
- Test: `backend/src/modules/food-order/store-schedule.spec.ts`
- Test: `backend/test/integration/food-order/food.http.spec.ts`

**Interfaces:**
- Produces: `closesAtToday(schedule: StoreSchedule, now?: Date): string | null` — `"23:30"` for the
  shift currently taking orders, `null` when the store has no hours, is closed, or is closed today.
- Produces: `StoreBrowseItem.closesAtToday: string | null`, `StoreDetail.closesAtToday: string | null`,
  `PublicStoreBrowseItem.closesAtToday: string | null`, `PublicStoreDetail.closesAtToday`.

- [ ] **Step 1: Write the failing unit test**

```ts
// backend/src/modules/food-order/store-schedule.spec.ts (append)
import { closesAtToday } from './store-schedule.js';

const weekday = 1; // Monday
const mondayTen = new Date('2026-11-02T03:00:00.000Z'); // 10:00 Vietnam

it('closesAtToday returns the closing time of the shift taking orders', () => {
  const schedule = {
    hoursConfigured: true,
    lastOrderMinutes: 30,
    hours: [{ weekday, opensMinute: 8 * 60, closesMinute: 22 * 60 }],
    closures: [],
  };
  expect(closesAtToday(schedule, mondayTen)).toBe('22:00');
});

it('closesAtToday returns null without hours, when closed, or on a closure date', () => {
  const alwaysOpen = { hoursConfigured: false, lastOrderMinutes: 0, hours: [], closures: [] };
  expect(closesAtToday(alwaysOpen, mondayTen)).toBeNull();
  expect(
    closesAtToday(
      { hoursConfigured: true, lastOrderMinutes: 0, hours: [], closures: [] },
      mondayTen,
    ),
  ).toBeNull();
  expect(
    closesAtToday(
      {
        hoursConfigured: true,
        lastOrderMinutes: 0,
        hours: [{ weekday, opensMinute: 8 * 60, closesMinute: 22 * 60 }],
        closures: [{ date: '2026-11-02', note: null }],
      },
      mondayTen,
    ),
  ).toBeNull();
});

it('closesAtToday reports the next morning for an overnight shift', () => {
  const schedule = {
    hoursConfigured: true,
    lastOrderMinutes: 0,
    hours: [{ weekday, opensMinute: 18 * 60, closesMinute: 2 * 60 }],
    closures: [],
  };
  const mondayLate = new Date('2026-11-02T20:00:00.000Z'); // 03:00 Tuesday Vietnam
  expect(closesAtToday(schedule, mondayLate)).toBe('02:00');
});
```

- [ ] **Step 2: Run it to verify it fails**

```bash
cd backend && npx vitest run src/modules/food-order/store-schedule.spec.ts
```
Expected: FAIL — `closesAtToday is not a function`.

- [ ] **Step 3: Implement the pure function**

```ts
// store-schedule.ts — after withinSchedule()
/**
 * Closing time (HH:mm, Vietnam local) of the shift that is taking orders right now.
 * Null when the store has no hours, is closed, or is closed for the whole day — a
 * card must never print "Mở đến …" for a store that is not open.
 */
export function closesAtToday(schedule: StoreSchedule, now: Date = new Date()): string | null {
  const today = vnClock(now);
  const yesterday = vnClock(new Date(now.getTime() - 24 * 60 * 60 * 1000));
  const closedOn = (date: string) => schedule.closures.some((closure) => closure.date === date);
  if (closedOn(today.date) || (schedule.hoursConfigured && !withinSchedule(schedule, now))) {
    return null;
  }
  const shift = schedule.hours.find(
    (row) =>
      (row.weekday === today.weekday &&
        row.opensMinute <= today.minute &&
        today.minute < shiftOrderEnd(row, schedule.lastOrderMinutes)) ||
      (row.weekday === yesterday.weekday &&
        isOvernight(row) &&
        today.minute + 1440 < shiftOrderEnd(row, schedule.lastOrderMinutes)),
  );
  return shift ? formatClock(shift.closesMinute % 1440) : null;
}
```

- [ ] **Step 4: Run the unit test again**

```bash
cd backend && npx vitest run src/modules/food-order/store-schedule.spec.ts
```
Expected: PASS (all cases, including existing availability tests).

- [ ] **Step 5: Add the browse column and the detail field**

Browse (Prisma raw SQL, inside `listStores`) — reuse the shift predicate of `openNowSql` and format
only when open; this keeps closures, cut-off and overnight shifts in one place:

```sql
LEFT JOIN LATERAL (
  SELECT h."closesMinute" AS closes_minute
  FROM "food_store_hours" h
  WHERE h."storeId" = s."id"
    AND (
      (h."weekday" = ${today.weekday}
        AND h."opensMinute" <= ${today.minute}
        AND ${today.minute} < (CASE WHEN h."closesMinute" < h."opensMinute"
          THEN h."closesMinute" + 1440 ELSE h."closesMinute" END) - s."lastOrderMinutes")
      OR (h."weekday" = ${yesterday.weekday}
        AND h."closesMinute" < h."opensMinute"
        AND ${today.minute} + 1440 < h."closesMinute" + 1440 - s."lastOrderMinutes")
    )
  LIMIT 1
) shift_today ON TRUE
```

```ts
closesAtToday: row.open_now && row.closes_minute !== null
  ? formatClock(row.closes_minute % 1440)
  : null,
```

Memory repository (`food.repository.ts` `listStores`/`listStoresPage`): build `StoreAvailability`
with `memoryAvailability(store, now)` and set
`closesAtToday: availability.openNow ? closesAtToday(store.schedule ?? ALWAYS_OPEN, now) : null`.
Detail: same expression where `StoreDetail` is assembled (memory `findStore`, Prisma `toStoreDetail`
using `scheduleFromRow`).

- [ ] **Step 6: Add the integration assertions**

```ts
// food.http.spec.ts, inside the browse test
const stores = await api.get('/v1/food/stores?lat=16.05&lng=108.20&limit=5');
expect(stores.status).toBe(200);
for (const store of stores.body.items) {
  expect(store).toHaveProperty('closesAtToday');
  if (store.openNow) expect(store.closesAtToday).toMatch(/^\d{2}:\d{2}$/);
  else expect(store.closesAtToday).toBeNull();
}
const detail = await api.get(`/v1/food/stores/${stores.body.items[0].id}`);
expect(detail.body).toHaveProperty('closesAtToday');
```

- [ ] **Step 7: Run backend gates and commit**

```bash
cd backend && npx prisma validate && npm run build && npm test -- --run store-schedule food.http
git add backend/src/modules/food-order/store-schedule.ts backend/src/modules/food-order/store-schedule.spec.ts \
  backend/src/modules/food-order/food.repository.ts backend/src/modules/food-order/food-prisma.repository.ts \
  backend/src/modules/food-order/food.service.ts backend/test/integration/food-order/food.http.spec.ts
git commit -m "feat(food): expose today's closing time on store browse and detail"
```

---

## Task 2 — `GET /v1/food/search` (dishes + stores)

**Files:**
- Modify: `backend/src/modules/food-order/food.dto.ts` (new `SearchFoodDto`)
- Modify: `backend/src/modules/food-order/food.controller.ts:46-53`
- Modify: `backend/src/modules/food-order/food.service.ts` (new `searchFood`)
- Modify: `backend/src/modules/food-order/food.repository.ts` (new `searchDishes`)
- Modify: `backend/src/modules/food-order/food-prisma.repository.ts` (new `searchDishes`)
- Test: `backend/test/integration/food-order/food.http.spec.ts`

**Interfaces:**
- Consumes: `listStores` (Task 1 output), `openNowSql`.
- Produces: `GET /v1/food/search?q&lat&lng&page&limit&sort_by` →
  `{ dishes: PageResult<DishHit>, stores: PageResult<PublicStoreBrowseItem> }`;

```ts
type DishHit = {
  item: {
    id: string; name: string; priceVnd: number; originalPriceVnd: number | null;
    imageUrl: string | null; soldCount: number; prepMinutes: number;
  };
  store: {
    id: string; name: string; distanceKm: number | null; etaMinutes: number | null;
    deliveryFeeFromVnd: number | null; openNow: boolean;
    closedReason: 'PAUSED' | 'CLOSED' | null;
  };
};
```

- [ ] **Step 1: Write the failing integration test**

```ts
it('searches dishes and stores, dishes first, without leaking closed stores', async () => {
  const res = await api.get('/v1/food/search?q=bun&lat=16.05&lng=108.20&limit=5');
  expect(res.status).toBe(200);
  expect(res.body.dishes).toEqual(
    expect.objectContaining({ page: 1, limit: 5, total: expect.any(Number) }),
  );
  expect(Array.isArray(res.body.dishes.items)).toBe(true);
  for (const hit of res.body.dishes.items) {
    expect(hit.item.name.toLowerCase()).toContain('bun');
    expect(hit.store).toEqual(
      expect.objectContaining({ id: expect.any(String), name: expect.any(String) }),
    );
    expect(hit.item.priceVnd).toBeGreaterThan(0);
  }
  expect(res.body.stores.items.every((s: any) => !s.isDishOnly)).toBe(true);
});

it('search requires q and caps limit', async () => {
  expect((await api.get('/v1/food/search')).status).toBe(400);
  expect((await api.get('/v1/food/search?q=a&limit=999')).status).toBe(400);
});
```

- [ ] **Step 2: Run it to verify it fails**

```bash
cd backend && npm run test:e2e -- --runFood food.http -t "searches dishes"
```
Expected: 404 (route does not exist).

- [ ] **Step 3: Add the DTO and route**

```ts
// food.dto.ts
export const FOOD_SEARCH_MAX_LIMIT = 20;

export class SearchFoodDto extends ListFoodStoresQueryDto {
  @IsString()
  @MinLength(1)
  @MaxLength(120)
  q!: string;
}
```

```ts
// food.controller.ts — before `stores/:id` so the literal route wins
@Get('search')
@ApiOperation({ summary: 'Search dishes and stores by dish name (dishes first)' })
searchFood(@CurrentActor() actor: RequestActor, @Query() query: SearchFoodDto) {
  return this.food.searchFood(actor, query);
}
```

- [ ] **Step 4: Implement the service**

```ts
// food.service.ts
async searchFood(actor: RequestActor, query: SearchFoodDto) {
  await this.requireActiveCustomer(actor.userId);
  const page = normalizePage(query.page);
  const limit = normalizeLimit(query.limit, FOOD_SEARCH_MAX_LIMIT);
  const [dishes, stores] = await Promise.all([
    this.food.searchDishes({ ...query, page, limit }),
    this.listStores(actor, { ...query, search: query.q, page, limit }),
  ]);
  return { dishes, stores };
}
```

`searchDishes` (Prisma) selects available, approved items whose `name ILIKE %q%`, joins the store with
the same `openNowSql`/distance expressions as `listStores`, orders by `soldCount DESC, name ASC`,
`COUNT(*)` for the total, and returns `PageResult<DishHit>`. `prepMinutes` is `item.prepMinutes ??
store.defaultPrepMinutes`. `distanceKm`/`etaMinutes`/`deliveryFeeFromVnd` are `null` without a GPS fix
(the service already has `quoteReferenceFareVnd` for the fee).

Memory repository: filter `StoredItem`s by name across stores, skip `available === false` and
`moderationStatus === 'PENDING'`, sort by `soldCount`.

- [ ] **Step 5: Run the integration test**

```bash
cd backend && npm run test:e2e -- --runFood food.http -t "searches dishes"
```
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
cd backend && npm run build
git add backend/src/modules/food-order/food.dto.ts backend/src/modules/food-order/food.controller.ts \
  backend/src/modules/food-order/food.service.ts backend/src/modules/food-order/food.repository.ts \
  backend/src/modules/food-order/food-prisma.repository.ts backend/test/integration/food-order/food.http.spec.ts
git commit -m "feat(food): search dishes and stores in one call"
```

---

## Task 3 — `GET /v1/food/stores/:id/suggestions`

**Files:**
- Modify: `backend/src/modules/food-order/food.dto.ts` (`SuggestFoodItemsDto`)
- Modify: `backend/src/modules/food-order/food.controller.ts`
- Modify: `backend/src/modules/food-order/food.service.ts`
- Modify: `backend/src/modules/food-order/food.repository.ts`, `food-prisma.repository.ts`
- Test: `backend/test/integration/food-order/food.http.spec.ts`

**Interfaces:**
- Produces: up to 6 `StoreFeaturedItem` for the same store, available, `menuCategoryId` different from
  the item named in `exclude` (comma-separated ids), best sellers first, `[]` when fewer than 2 qualify.

- [ ] **Step 1: Failing test**

```ts
it('suggests other-category dishes for the item page', async () => {
  const menu = await api.get(`/v1/food/stores/${storeId}`);
  const item = menu.body.items[0];
  const res = await api.get(`/v1/food/stores/${storeId}/suggestions?exclude=${item.id}`);
  expect(res.status).toBe(200);
  expect(res.body.length).toBeLessThanOrEqual(6);
  for (const suggestion of res.body) {
    expect(suggestion.id).not.toBe(item.id);
    expect(suggestion.available).not.toBe(false);
  }
  const single = await api.get(`/v1/food/stores/${storeId}/suggestions?exclude=${item.id}`);
  if (single.body.length === 1) expect(single.body).toEqual([]);
});
```

- [ ] **Step 2: Run to verify failure** — `npm run test:e2e -- --runFood food.http -t "suggests other-category"` → 404.

- [ ] **Step 3: Implement**

```ts
// service
async suggestItems(actor: RequestActor, storeId: string, exclude: string[]) {
  await this.requireActiveCustomer(actor.userId);
  const moderationRequired = await this.itemModerationRequired();
  return this.food.listItemSuggestions({ storeId, exclude, limit: 6, moderationRequired });
}
```

Repository: pick the categories of `exclude` items, then return available approved items in other
categories of the same store ordered by `soldCount DESC, createdAt DESC`, limited to 6; the service
returns `[]` when the result has fewer than 2 entries.

- [ ] **Step 4: Test + commit**

```bash
cd backend && npm run build && npm run test:e2e -- --runFood food.http -t "suggests other-category"
git add backend/src/modules/food-order/food.dto.ts backend/src/modules/food-order/food.controller.ts \
  backend/src/modules/food-order/food.service.ts backend/src/modules/food-order/food.repository.ts \
  backend/src/modules/food-order/food-prisma.repository.ts backend/test/integration/food-order/food.http.spec.ts
git commit -m "feat(food): suggest same-store dishes for the item page"
```

---

## Task 4 — Mobile data layer

**Files:**
- Modify: `mobile/lib/features/food/domain/entities/food_models.dart`
- Modify: `mobile/lib/core/network/api_paths.dart`
- Modify: `mobile/lib/features/food/data/datasources/food_remote_datasource.dart`
- Modify: `mobile/lib/features/food/data/datasources/dio_food_remote_datasource.dart`
- Modify: `mobile/lib/features/food/data/datasources/fake_food_client.dart` (`core/mock`)
- Modify: `mobile/lib/features/food/data/repositories/food_repository_impl.dart`
- Modify: `mobile/lib/features/food/domain/repositories/food_repository.dart`
- Test: `mobile/test/features/food/food_search_decode_test.dart`

**Interfaces:**
- Produces: `FoodStoreSummary.closesAtToday` (`String?`), `FoodStoreDetail.closesAtToday` (`String?`),
  `FoodDishHit`, `FoodSearchResult`, `Future<FoodSearchResult> FoodRepository.searchFood(...)`,
  `Future<List<FoodFeaturedItem>> FoodRepository.listStoreSuggestions(...)`.
- `FoodSearchResult { List<FoodDishHit> dishes; int dishTotal; List<FoodStoreSummary> stores; int storeTotal; }`
  (the name avoids clashing with the `FoodSearchPage` widget in `food_search_page.dart`).

- [ ] **Step 1: Failing decode test**

```dart
test('decodes closesAtToday and dish search hits', () {
  final page = decodeFoodSearchResult({
    'dishes': {
      'items': [
        {
          'item': {
            'id': 'item-1', 'name': 'Bún bò', 'priceVnd': 45000,
            'originalPriceVnd': 55000, 'imageUrl': null, 'soldCount': 120, 'prepMinutes': 15,
          },
          'store': {
            'id': 'store-1', 'name': 'Bún Bò Huế', 'distanceKm': 1.2,
            'etaMinutes': 25, 'deliveryFeeFromVnd': 15000,
            'openNow': true, 'closedReason': null,
          },
        },
      ],
      'page': 1, 'limit': 20, 'total': 1,
    },
    'stores': {'items': [], 'page': 1, 'limit': 20, 'total': 0},
  });
  expect(page.dishes.single.item.name, 'Bún bò');
  expect(page.dishes.single.store.etaMinutes, 25);
  expect(page.storeTotal, 0);
});
```

- [ ] **Step 2: Run it** — `cd mobile && flutter test test/features/food/food_search_decode_test.dart`
  Expected: undefined `decodeFoodSearchResult`.

- [ ] **Step 3: Implement models, decode, paths, repository**

- `FoodStoreSummary`/`FoodStoreDetail`: `final String? closesAtToday;` parsed from `closesAtToday`
  (reject anything not matching `^\d{2}:\d{2}$`).
- `FoodDishHit(item, store)` with `FoodDishHitStore(id, name, distanceKm, etaMinutes, deliveryFeeFromVnd, openNow, closedReason)`.
- `decodeFoodSearchResult(Object? raw)` next to `decodeFoodStorePage`.
- `ApiPaths.foodSearch = '/v1/food/search'`, `ApiPaths.foodStoreSuggestions(id)` returning
  `'/v1/food/stores/$id/suggestions'`.
- `searchFood(accessToken, {q, lat, lng, sortBy, page, limit})` and
  `listStoreSuggestions(accessToken, storeId, {exclude})` in interface, impl, Dio datasource and
  `FakeFoodClient` (fields `searchFoodHandler`, `suggestions`).

- [ ] **Step 4: Test + commit**

```bash
cd mobile && flutter analyze lib/features/food && flutter test test/features/food/food_search_decode_test.dart
git add mobile/lib/core/network/api_paths.dart mobile/lib/features/food/domain/entities/food_models.dart \
  mobile/lib/features/food/domain/repositories/food_repository.dart \
  mobile/lib/features/food/data mobile/lib/core/mock/fake_food_client.dart \
  mobile/test/features/food/food_search_decode_test.dart
git commit -m "feat(food): decode dish search hits and today's closing time"
```

---

## Task 5 — Search page dish results

**Files:**
- Create: `mobile/lib/features/food/presentation/widgets/food_dish_hit_row.dart`
- Create: `mobile/lib/features/food/presentation/cubit/food_search_cubit.dart`
- Modify: `mobile/lib/features/food/presentation/pages/food_search_page.dart`
- Test: `mobile/test/features/food/food_search_dishes_test.dart`
- Test fixtures: `mobile/lib/core/mock/fake_food_client.dart`

**Interfaces:**
- Consumes: `FoodRepository.searchFood`, `FoodDishHit` (Task 4).
- Produces: `FoodSearchCubit.load(token, {q, lat, lng, sortBy})`, `loadMore()`, states
  `FoodSearchIdle`, `FoodSearchLoading`, `FoodSearchFailed`, `FoodSearchReady(dishes, stores, totals, isRefreshing, loadingMore, loadMoreFailed)`.

- [ ] **Step 1: Failing widget test**

```dart
testWidgets('dish hits render above store results and open the item page', (tester) async {
  final food = FakeFoodClient()
    ..searchFoodHandler = (q) => FoodSearchResult(
      dishes: [dishHit(name: 'Bún bò', storeId: 'store-1', itemId: 'item-bun')],
      dishTotal: 1,
      stores: [storeSummary(id: 'store-1', name: 'Bún Bò Huế')],
      storeTotal: 1,
    );
  await pumpSignedIn(tester, profile: customerProfile, foodClient: food);
  await tester.tap(find.byKey(const Key('food-search-entry')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('food-search-field')), 'bún');
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();

  expect(find.byKey(const Key('food-dish-hits')), findsOneWidget);
  expect(find.text('Món ăn'), findsOneWidget);
  expect(find.text('Quán'), findsOneWidget);
  expect(find.byKey(const Key('food-dish-hit-item-bun')), findsOneWidget);

  await tester.tap(find.byKey(const Key('food-dish-hit-item-bun')));
  await tester.pumpAndSettle();
  expect(find.text('Bún bò'), findsWidgets);
});

testWidgets('no dish hits means no dish heading', (tester) async {
  final food = FakeFoodClient()
    ..searchFoodHandler = (q) => FoodSearchResult(
      dishes: const [], dishTotal: 0,
      stores: [storeSummary(id: 'store-1', name: 'Bún Bò Huế')], storeTotal: 1,
    );
  ...
  expect(find.text('Món ăn'), findsNothing);
  expect(find.byKey(const Key('food-dish-hits')), findsNothing);
});
```

- [ ] **Step 2: Run to verify failure** — `flutter test test/features/food/food_search_dishes_test.dart`.

- [ ] **Step 3: Implement the cubit**

```dart
class FoodSearchCubit extends Cubit<FoodSearchState> {
  FoodSearchCubit(this._search);
  final FoodRepository _search;
  var _generation = 0;

  Future<void> load(String token, {required String q, double? lat, double? lng, String? sortBy}) async {
    final gen = ++_generation;
    if (q.trim().isEmpty) {
      emit(const FoodSearchIdle());
      return;
    }
    emit(FoodSearchLoading(previous: state is FoodSearchReady ? (state as FoodSearchReady).copyWith(isRefreshing: true) : null));
    try {
      final page = await _search.searchFood(token, q: q, lat: lat, lng: lng, sortBy: sortBy, page: 1);
      if (isClosed || gen != _generation) return;
      emit(FoodSearchReady(dishes: page.dishes, stores: page.stores, dishTotal: page.dishTotal, storeTotal: page.storeTotal, page: 1));
    } catch (error) {
      if (isClosed || gen != _generation) return;
      emit(FoodSearchFailed(error));
    }
  }
  // loadMore(): page+1, append, dedupe by item id / store id, keep hasMore = items.length < total.
}
```

- [ ] **Step 4: Wire the page**

- Replace the `FoodDiscoveryCubit` provider on search with `FoodSearchCubit`; the sort chips call
  `load(...)` again and reset the page.
- `ListView` order: refreshing bar → `food-dish-hits` block (heading `foodSearchDishes`, rows built with
  `FoodDishHitRow`, tap → `FoodRoutes.item(storeId, itemId)`) → heading `foodSearchStores` → store cards
  → `FoodFeedFooter`. Empty dish results hide the dish heading entirely.
- Debounce stays 350 ms; ignore a response whose `q` no longer matches the box.
- Empty query state keeps history and category chips, and adds up to 6 keyword chips built from the
  featured dish names of the stores already loaded (`food-search-keyword-<name>`), tapping one fills
  the box and runs the search (spec §6.2 "Gợi ý từ khoá").
- Add l10n keys to **both** `app_vi.arb` and `app_en.arb` (then regenerate):
  `foodSearchDishes` = "Món ăn"/"Dishes", `foodSearchStores` = "Quán"/"Stores".
- `FoodDishHitRow`: 64 px thumb, dish name (`subtitle`), store name + `★`/distance/ETA (`meta`), price
  (`FoodMoneyRow`-style, right aligned), 44 px min height, key `food-dish-hit-<itemId>`.

- [ ] **Step 5: Test + commit**

```bash
cd mobile && flutter analyze lib/features/food && flutter test test/features/food/food_search_dishes_test.dart
git add mobile/lib/features/food/presentation/widgets/food_dish_hit_row.dart \
  mobile/lib/features/food/presentation/cubit/food_search_cubit.dart \
  mobile/lib/features/food/presentation/pages/food_search_page.dart \
  mobile/lib/l10n mobile/lib/core/mock/fake_food_client.dart \
  mobile/test/features/food/food_search_dishes_test.dart
git commit -m "feat(food): show dish results in search"
```

---

## Task 6 — Card "Mở đến", store hero trust strip, category empty states

**Files:**
- Modify: `mobile/lib/features/food/presentation/widgets/store_meta.dart`
- Modify: `mobile/lib/features/food/presentation/widgets/food_store_card.dart`
- Modify: `mobile/lib/features/food/presentation/pages/store/` hero widget (find it with
  `rg -l "store-hero|trust" mobile/lib/features/food/presentation/pages/store`)
- Modify: `mobile/lib/features/food/presentation/pages/food_category_page.dart`
- Modify: `mobile/lib/l10n/app_vi.arb`, `mobile/lib/l10n/app_en.arb`
- Test: `mobile/test/features/food/food_store_trust_test.dart`

**Interfaces:**
- Consumes: `closesAtToday` (Task 4).
- Produces: `store-open-until-<storeId>` text in the card meta line and
  `store-trust-strip` on the hero, each hidden when `closesAtToday == null`.

- [ ] **Step 1: Failing test**

```dart
testWidgets('card and hero show "Mở đến" only with data', (tester) async {
  final store = storeSummary(id: 'store-1', name: 'Bún Bò Huế', closesAtToday: '22:00');
  await tester.pumpWidget(foodTestApp(FoodStoreCard(store: store, onTap: () {})));
  expect(find.byKey(const Key('store-open-until-store-1')), findsOneWidget);
  expect(find.text('Mở đến 22:00'), findsOneWidget);

  final closed = storeSummary(id: 'store-2', name: 'Quán đóng', closesAtToday: null);
  await tester.pumpWidget(foodTestApp(FoodStoreCard(store: closed, onTap: () {})));
  expect(find.byKey(const Key('store-open-until-store-2')), findsNothing);
});
```

- [ ] **Step 2: Run to verify failure**, then implement:
  - `store_meta.dart`: append `Key('store-open-until-${store.id}')` text to the first meta line when
    `store.closesAtToday != null`, using `l10n.foodStoreOpenUntil(time)` and `DealGoType.meta`.
  - Hero: the trust strip renders up to two items — "Mở đến {time}" and "Phí giao từ {fee}" — as
    `meta` on `card`, separated by `·`; skip a missing item; hide the row when both are missing.
    Verified badge is **not** rendered (spec §6.4).
  - Category page empty state distinguishes "no stores in this category" from "DealGo does not deliver
    here": when the customer has no GPS fix or the list is empty for a location reason use
    `foodEmptyOutOfArea`, otherwise `foodEmptyNoStoresInCategory` (new keys in both ARB files; also add
    `foodStoreOpenUntil` if it is missing).
- [ ] **Step 3: Test + commit**

```bash
cd mobile && flutter analyze lib/features/food && flutter test test/features/food/food_store_trust_test.dart
git add mobile/lib/features/food/presentation/widgets/store_meta.dart \
  mobile/lib/features/food/presentation/widgets/food_store_card.dart \
  mobile/lib/features/food/presentation/pages/store \
  mobile/lib/features/food/presentation/pages/food_category_page.dart \
  mobile/lib/l10n mobile/test/features/food/food_store_trust_test.dart
git commit -m "feat(food): show today's closing time, trust strip and honest empty states"
```

---

## Task 7 — Voucher wall and "Đặt lại đơn quen" on discovery

**Files:**
- Create: `mobile/lib/features/food/presentation/widgets/food_voucher_wall.dart`
- Create: `mobile/lib/features/food/presentation/widgets/food_reorder_strip.dart`
- Modify: `mobile/lib/features/food/presentation/pages/food_discovery_page.dart`
- Modify: `mobile/lib/features/food/presentation/widgets/food_reorder_button.dart` (extract `reorderIntoCart`)
- Modify: `mobile/lib/l10n/app_vi.arb`, `mobile/lib/l10n/app_en.arb`
- Test: `mobile/test/features/food/food_discovery_wall_test.dart`

**Interfaces:**
- Consumes: `PromotionRepository.listAvailable(service: VoucherService.food)`,
  `HistoryRepository`/`ListFoodHistory` for the last completed order, `reorderIntoCart`.
- Produces: `food-voucher-wall` (hidden when no usable voucher), `food-reorder-strip`
  (hidden without a completed order), both above the category strip.

- [ ] **Step 1: Failing widget test**

```dart
testWidgets('feed shows usable vouchers and the last completed order', (tester) async {
  final food = FakeFoodClient()..orders = [completedFoodHistory(id: 'order-1', storeName: 'Bún Bò Huế')];
  final promotions = FakePromotionClient(available: [foodVoucher(code: 'FOOD20', title: 'Giảm 20K')]);
  await pumpSignedIn(tester, profile: customerProfile, foodClient: food, promotions: promotions);
  await tester.pumpAndSettle();

  expect(find.byKey(const Key('food-voucher-wall')), findsOneWidget);
  expect(find.text('Giảm 20K'), findsWidgets);
  expect(find.byKey(const Key('food-reorder-strip')), findsOneWidget);
  expect(find.text('Đặt lại'), findsOneWidget);
});

testWidgets('feed hides both blocks when there is nothing to show', (tester) async {
  await pumpSignedIn(tester, profile: customerProfile,
      foodClient: FakeFoodClient(), promotions: FakePromotionClient());
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('food-voucher-wall')), findsNothing);
  expect(find.byKey(const Key('food-reorder-strip')), findsNothing);
});
```

- [ ] **Step 2: Run to verify failure.**

- [ ] **Step 3: Implement**
  - `FoodVoucherWall`: horizontal strip of up to 3 ticket cards (`code`, title, min order, expiry) using
    the existing ticket styling from `food_voucher_picker_sheet.dart`; tap opens the voucher picker
    sheet (already used by checkout) or the vouchers page when the cart is empty; "Xem tất cả" →
    `FoodRoutes.vouchers`. Loading: 1-row skeleton; error: hide (never block the feed).
  - `FoodReorderStrip`: image, store name, "N món · tổng", button `Đặt lại`; tap fetches the order
    detail via `GetFoodOrder` and calls the shared `reorderIntoCart`, then opens checkout.
  - Extract from `FoodReorderButton._reorder` into a top-level
    `Future<void> reorderIntoCart(BuildContext context, FoodOrderDetail order)` in
    `food_reorder_button.dart`; the button and the strip both call it (`_busy` stays in the button).
  - Add keys/l10n: `foodVoucherWallTitle`, `foodVoucherWallSeeAll`, `foodReorderStripItems(count, total)`.

- [ ] **Step 4: Test + commit**

```bash
cd mobile && flutter analyze lib/features/food && flutter test test/features/food/food_discovery_wall_test.dart
git add mobile/lib/features/food/presentation/widgets/food_voucher_wall.dart \
  mobile/lib/features/food/presentation/widgets/food_reorder_strip.dart \
  mobile/lib/features/food/presentation/widgets/food_reorder_button.dart \
  mobile/lib/features/food/presentation/pages/food_discovery_page.dart \
  mobile/lib/l10n mobile/test/features/food/food_discovery_wall_test.dart
git commit -m "feat(food): add the voucher wall and one-tap reorder to discovery"
```

---

## Task 8 — "Món ăn kèm" on the item page

**Files:**
- Create: `mobile/lib/features/food/presentation/widgets/food_item_addons.dart`
- Modify: `mobile/lib/features/food/presentation/pages/food_item_options_page.dart`
- Test: `mobile/test/features/food/food_item_addons_test.dart`

**Interfaces:**
- Consumes: `FoodRepository.listStoreSuggestions`, `FoodFeaturedItem`.
- Produces: `food-item-addons` block above the sticky CTA; hidden when fewer than 2 suggestions.

- [ ] **Step 1: Failing test**

```dart
testWidgets('item page suggests at most 6 same-store add-ons and adds one unit', (tester) async {
  final food = FakeFoodClient()
    ..suggestions = [featuredItem(id: 'tra-dao', name: 'Trà đào', priceVnd: 20000)];
  await pumpSignedIn(tester, profile: customerProfile, foodClient: food);
  await tester.tap(find.byKey(const Key('food-open-item-store-1-item-bun')));
  await tester.pumpAndSettle();

  expect(find.byKey(const Key('food-item-addons')), findsOneWidget);
  await tester.tap(find.byKey(const Key('food-addon-tra-dao')));
  await tester.pumpAndSettle();
  expect(find.text('Trà đào'), findsWidgets);
});

testWidgets('fewer than two suggestions hides the block', (tester) async {
  final food = FakeFoodClient()..suggestions = [featuredItem(id: 'tra-dao', name: 'Trà đào', priceVnd: 20000)];
  ...
  expect(find.byKey(const Key('food-item-addons')), findsNothing);
});
```

- [ ] **Step 2: Run to verify failure.**

- [ ] **Step 3: Implement**
  - `FoodItemAddons` stateful: loads on `initState` with the access token + store id + `exclude` the
    current item id; renders a horizontal `ListView` height 96 of thumb + name + price + `+` button
    (48 px hit area); tapping adds one unit of the plain item (no options) and shows the cart bar.
  - Hide when `length < 2`; hide on error (never block adding the main dish).
  - Place above the sticky CTA inside the existing `SingleChildScrollView`, key `food-item-addons`.

- [ ] **Step 4: Test + commit**

```bash
cd mobile && flutter analyze lib/features/food && flutter test test/features/food/food_item_addons_test.dart
git add mobile/lib/features/food/presentation/widgets/food_item_addons.dart \
  mobile/lib/features/food/presentation/pages/food_item_options_page.dart \
  mobile/lib/core/mock/fake_food_client.dart \
  mobile/test/features/food/food_item_addons_test.dart
git commit -m "feat(food): suggest accompanying dishes on the item page"
```

---

## Task 9 — Docs and status

**Files:**
- Modify: `docs/10-ai-execution/screen-inventory.md` (C023, C025, C026, C022, C027 if upsell text changes)
- Modify: `docs/superpowers/specs/2026-11-03-food-customer-redesign-design.md` (status, §15.1)
- Modify: `docs/00-governance/decisions-and-assumptions.md` (`DEC-PROD-072` evidence + changelog `0.4.19`)

- [ ] **Step 1: Update the inventory**
  - C023: server search now returns dish hits above stores; sort chips still apply.
  - C025: trust strip shows opening time and delivery-from fee from the server.
  - C026: add-ons from `GET /v1/food/stores/:id/suggestions`.
  - C022: voucher wall (usable FOOD vouchers) and reorder strip.
- [ ] **Step 2: Update the spec**
  - `status: "P3_IMPLEMENTED"`; extend §15.1 with the P3 outcome; record `FOOD-CX-OD-04` (search shape)
    as implemented-default, still open, and `FOOD-CX-OD-06` (voucher wall source) likewise.
- [ ] **Step 3: Update governance** — add a `Bằng chứng` row for P3 in `DEC-PROD-072` and the
  `0.4.19` changelog line; stage only those hunks (the file also carries unrelated driver-credit WIP).
- [ ] **Step 4: Verify + commit**

```bash
cd mobile && flutter analyze && flutter test test/features/food
cd ../backend && npm run build && npm test -- --run food
git add docs/10-ai-execution/screen-inventory.md \
  docs/superpowers/specs/2026-11-03-food-customer-redesign-design.md
git add -p docs/00-governance/decisions-and-assumptions.md
git commit -m "docs(food): record P3 search, trust strip, voucher wall and reorder"
```

---

## Verification (phase gate)

```bash
cd backend && npx prisma validate && npm run build && npm test && npm run test:e2e
cd ../mobile && flutter analyze && flutter test
```

Expected: backend green; `flutter analyze` "No issues found!"; the mobile suite green except the three
known unrelated failures (`account_page_test.dart` role row, two `driver_history_test.dart` cases) that
predate P3 and belong to other in-flight work.
