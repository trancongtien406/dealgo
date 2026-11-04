# Food Customer Redesign — P1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Customer Food discovery and menu surfaces dense, paginated and consistent with the six-tier type scale, without touching the backend.

**Architecture:** P1 is client-only. The Nest `GET /v1/food/stores` already accepts `page`, `limit`, `search` and `category` and returns `{ items, page, limit, total }`, so the work is: a paged contract in the Flutter data layer, pagination state in `FoodDiscoveryCubit`, one shared `FoodStoreCard`, a vertical `CustomScrollView` feed, a dish gallery, and a mechanical split of the 2 581-line store page into `part` files.

**Tech Stack:** Flutter 3.47 / Dart 3.13, flutter_bloc, go_router, gen-l10n, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-11-03-food-customer-redesign-design.md`

## Global Constraints

- Run every command from `mobile/`.
- **No backend change in P1.** `backend/` is untouched; the server contract already supports paging.
- **No new route, deep link, tab or permission.** `FoodRoutes` stays as is.
- **No new accent hue.** Only `DealGoColors` / `DealGoPalette` tokens; the brand stays `#6D28D9`.
- **No invented data.** A null field hides its element; never render `★ 0` or a fake ETA.
- **Type scale:** inside `lib/features/food/presentation` a `copyWith(fontSize:` is forbidden; use `DealGoType`.
- **Copy:** Vietnamese strings in `lib/l10n/app_vi.arb`, English in `app_en.arb`, same key in both; regenerate with `flutter gen-l10n`.
- **File size:** every new or rewritten file ≤ 500 lines; after Task 8 `food_store_page.dart` must be ≤ 500 lines.
- **Quality gate per task:** `flutter analyze` reports no issues for touched files and the listed tests pass. Never report PASS without running the command.
- Accessibility floor: tap targets ≥ `DealGoDimensions.minTapTarget` (48), no colour-only state, honour `MediaQuery.disableAnimationsOf(context)`.
- **Staging:** the working tree also holds unrelated in-progress work. Stage only the exact files named in the task's commit step; never `git add -A`, `git add test`, or `git add lib`.

## Scope Note

This plan is **P1 only** (typography, density, card, vertical feed + pagination, dish gallery, store-page split). P2 (notes, utensils, upsell, checkout fare hero), P3 (dish search, voucher wall, reorder, `closesAtToday`) and P4 (tracking summary, goldens) get their own plan files after P1 lands and is reviewed:

- `docs/superpowers/plans/<date>-food-customer-redesign-p2.md`
- `docs/superpowers/plans/<date>-food-customer-redesign-p3.md`
- `docs/superpowers/plans/<date>-food-customer-redesign-p4.md`

## File Map

| File | Responsibility |
|---|---|
| `lib/core/design_system/tokens/dealgo_tokens.dart` | + `DealGoDensity` |
| `lib/core/design_system/tokens/dealgo_type_scale.dart` (new) | Six text roles for Food |
| `lib/features/food/domain/entities/food_models.dart` | + `FoodStorePageResult` |
| `lib/features/food/domain/repositories/food_repository.dart` | Paged `listStores` |
| `lib/features/food/domain/usecases/list_food_stores.dart` | Paged pass-through |
| `lib/features/food/data/datasources/food_remote_datasource.dart` | Paged interface |
| `lib/features/food/data/datasources/dio_food_remote_datasource.dart` | `page`/`limit`/`category` + `decodeFoodStorePage` |
| `lib/features/food/data/repositories/food_repository_impl.dart` | Pass-through |
| `lib/features/food/presentation/cubit/food_discovery_cubit.dart` | `loadMore`, `total`, `hasMore` |
| `lib/features/food/presentation/widgets/food_store_card.dart` (new) | `FoodStoreCard` feed/compact |
| `lib/features/food/presentation/widgets/food_feed_footer.dart` (new) | loading-more / retry / end |
| `lib/features/food/presentation/widgets/food_dish_gallery.dart` (new) | PageView gallery + counter |
| `lib/features/food/presentation/widgets/store_meta.dart` | `StoreMetaLine` → `FoodMetaLine` |
| `lib/features/food/presentation/pages/food_discovery_page.dart` | Vertical sliver feed |
| `lib/features/food/presentation/pages/food_category_page.dart` | Server-side category + paging |
| `lib/features/food/presentation/pages/food_search_page.dart` | Paging footer |
| `lib/features/food/presentation/pages/food_item_options_page.dart` | Gallery hero |
| `lib/features/food/presentation/pages/food_store_page.dart` | Keep page shell; parts move out |
| `lib/features/food/presentation/pages/store/*.dart` (new, 8 parts) | Extracted store widgets |
| `lib/features/shell/presentation/home_sections.dart` | Reads `.items` |
| `lib/core/mock/fake_food_client.dart` | Paged fake |
| `lib/l10n/app_vi.arb`, `app_en.arb` | New keys |

---

### Task 1: Type scale and density tokens

**Files:**
- Create: `lib/core/design_system/tokens/dealgo_type_scale.dart`
- Create: `test/features/food/food_type_scale_guard_test.dart`
- Modify: `lib/core/design_system/tokens/dealgo_tokens.dart:157-177`
- Modify: `lib/features/food/presentation/pages/food_discovery_page.dart:860-870,925-935`

**Interfaces:**
- Produces: `DealGoType.display/title/subtitle/body/meta/micro(TextTheme) → TextStyle`, `DealGoDensity.blockGap/groupGap/cardPad/rowMinHeight/metaGap`.

- [ ] **Step 1: Write the guard test**

```dart
// test/features/food/food_type_scale_guard_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('food presentation has no ad-hoc font sizes', () {
    final root = Directory('lib/features/food/presentation');
    expect(root.existsSync(), isTrue, reason: 'run from mobile/');

    final offenders = <String>[];
    for (final entity in root.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].contains('copyWith(fontSize:')) {
          offenders.add('${entity.path}:${i + 1}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'Use DealGoType instead of copyWith(fontSize:):\n'
          '${offenders.join('\n')}',
    );
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/features/food/food_type_scale_guard_test.dart`
Expected: FAIL listing `food_discovery_page.dart:` twice.

- [ ] **Step 3: Add the six roles**

```dart
// lib/core/design_system/tokens/dealgo_type_scale.dart
import 'package:flutter/material.dart';

/// Six text roles for Food surfaces (design spec §4.1).
///
/// The global [TextTheme] is intentionally untouched so other features keep
/// their current scale while Food converges on one hierarchy.
abstract final class DealGoType {
  static TextStyle display(TextTheme text) => text.headlineMedium!.copyWith(
    fontSize: 24,
    height: 28 / 24,
    fontWeight: FontWeight.w700,
  );

  static TextStyle title(TextTheme text) => text.headlineSmall!.copyWith(
    fontSize: 20,
    height: 26 / 20,
    fontWeight: FontWeight.w700,
  );

  static TextStyle subtitle(TextTheme text) => text.titleMedium!.copyWith(
    fontSize: 16,
    height: 22 / 16,
    fontWeight: FontWeight.w700,
  );

  static TextStyle body(TextTheme text) => text.bodyMedium!.copyWith(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w400,
  );

  static TextStyle meta(TextTheme text) => text.bodySmall!.copyWith(
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w500,
  );

  static TextStyle micro(TextTheme text) => text.labelSmall!.copyWith(
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w500,
  );
}
```

- [ ] **Step 4: Add density tokens**

Append to `lib/core/design_system/tokens/dealgo_tokens.dart` after `DealGoDimensions`:

```dart
abstract final class DealGoDensity {
  /// Between blocks inside one screen.
  static const double blockGap = 20;

  /// Between blocks that change subject.
  static const double groupGap = 24;

  static const double cardPad = 12;

  /// Menu row and store row floor.
  static const double rowMinHeight = 96;

  static const double metaGap = 4;
}
```

- [ ] **Step 5: Replace the two ad-hoc sizes in discovery**

In `food_discovery_page.dart` import the new file and replace:

```dart
// line ~865 (_StoreTile)
style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 15),
// becomes
style: DealGoType.subtitle(Theme.of(context).textTheme),
```

```dart
// line ~931 (_WideStoreCard)
style: textTheme.titleMedium?.copyWith(fontSize: 16),
// becomes
style: DealGoType.subtitle(textTheme),
```

- [ ] **Step 6: Run the guard and the analyzer**

Run: `flutter test test/features/food/food_type_scale_guard_test.dart && flutter analyze`
Expected: PASS, `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add lib/core/design_system/tokens/dealgo_tokens.dart \
  lib/core/design_system/tokens/dealgo_type_scale.dart \
  lib/features/food/presentation/pages/food_discovery_page.dart \
  test/features/food/food_type_scale_guard_test.dart
git commit -m "feat(food): add six-tier type scale and density tokens"
```

---

### Task 2: Paged store contract

**Files:**
- Modify: `lib/features/food/domain/entities/food_models.dart:112-170`
- Modify: `lib/features/food/domain/repositories/food_repository.dart:5-12`
- Modify: `lib/features/food/domain/usecases/list_food_stores.dart`
- Modify: `lib/features/food/data/datasources/food_remote_datasource.dart:75-83`
- Modify: `lib/features/food/data/datasources/dio_food_remote_datasource.dart:208-234,899-952`
- Modify: `lib/features/food/data/repositories/food_repository_impl.dart:10-27`
- Modify: `lib/core/mock/fake_food_client.dart:347-365`
- Modify: `lib/features/shell/presentation/home_sections.dart:185-190`
- Modify: `test/qa_customer_fixes_test.dart:18-32`
- Create: `test/features/food/food_store_page_decode_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `FoodStorePageResult { List<FoodStoreSummary> items; int total; int page; int limit; bool get hasMore }`; `listStores(token, {lat, lng, search, sortBy, maxKm, category, page = 1, limit = 20}) → Future<FoodStorePageResult>`; `decodeFoodStorePage(body, {required int page, required int limit})`.

- [ ] **Step 1: Write the failing decode tests**

```dart
// test/features/food/food_store_page_decode_test.dart
import 'package:dealgo/features/food/data/datasources/dio_food_remote_datasource.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads items and total, then reports more pages', () {
    final page = decodeFoodStorePage({
      'success': true,
      'data': {
        'items': [
          {'id': 's1', 'name': 'Bún bò'},
          {'id': 's2', 'name': 'Trà sữa'},
        ],
        'page': 1,
        'limit': 2,
        'total': 5,
      },
    }, page: 1, limit: 2);

    expect([for (final store in page.items) store.id], ['s1', 's2']);
    expect(page.total, 5);
    expect(page.hasMore, isTrue);
  });

  test('falls back to the item count when total is missing', () {
    final page = decodeFoodStorePage({
      'success': true,
      'data': {
        'items': [
          {'id': 's1', 'name': 'Bún bò'},
        ],
        'page': 2,
        'limit': 20,
      },
    }, page: 2, limit: 20);

    expect(page.total, 1);
    expect(page.hasMore, isFalse);
  });

  test('never reports fewer items than it received', () {
    final page = decodeFoodStorePage({
      'success': true,
      'data': {
        'items': [
          {'id': 's1', 'name': 'Bún bò'},
          {'id': 's2', 'name': 'Trà sữa'},
        ],
        'total': 1,
      },
    }, page: 1, limit: 2);

    expect(page.total, 2);
    expect(page.hasMore, isFalse);
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/features/food/food_store_page_decode_test.dart`
Expected: FAIL — `decodeFoodStorePage` is not defined.

- [ ] **Step 3: Add the domain type**

In `food_models.dart`, after `FoodStoreSummary`:

```dart
/// One page of store browse results. [total] is the server count for the
/// current filter, so [hasMore] stays correct even when rows are de-duplicated.
class FoodStorePageResult {
  const FoodStorePageResult({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
  });

  final List<FoodStoreSummary> items;
  final int total;
  final int page;
  final int limit;

  bool get hasMore => page * limit < total;
}
```

- [ ] **Step 4: Decode the page**

In `dio_food_remote_datasource.dart`, directly after `decodeFoodStoreList`:

```dart
FoodStorePageResult decodeFoodStorePage(
  Object? body, {
  required int page,
  required int limit,
}) {
  final data = _successPayload(body);
  final map = asJsonMap(data);
  final items = decodeFoodStoreList(body);
  final reported = _asInt(map?['total']);
  return FoodStorePageResult(
    items: items,
    total: reported == null || reported < items.length ? items.length : reported,
    page: page,
    limit: limit,
  );
}
```

- [ ] **Step 5: Thread page/limit/category through the contract**

`food_remote_datasource.dart`:

```dart
  Future<FoodStorePageResult> listStores(
    String accessToken, {
    double? lat,
    double? lng,
    String? search,
    String? sortBy,
    int? maxKm,
    String? category,
    int page = 1,
    int limit = 20,
  });
```

`dio_food_remote_datasource.dart`:

```dart
  @override
  Future<FoodStorePageResult> listStores(
    String accessToken, {
    double? lat,
    double? lng,
    String? search,
    String? sortBy,
    int? maxKm,
    String? category,
    int page = 1,
    int limit = 20,
  }) {
    final hasGeo = lat != null && lng != null;
    final sort = sortBy ?? (hasGeo ? 'distance' : null);
    final trimmedCategory = category?.trim() ?? '';
    return _send(
      () => dio.get<Object?>(
        ApiPaths.foodStores,
        queryParameters: {
          if (hasGeo) ...{'lat': lat, 'lng': lng},
          'sort_by': ?sort,
          if (maxKm != null && maxKm > 0) 'max_km': maxKm,
          // QA C3 — name search runs on the server, not on the loaded page.
          if (search != null && search.trim().isNotEmpty)
            'search': search.trim(),
          if (trimmedCategory.isNotEmpty) 'category': trimmedCategory,
          'page': page,
          'limit': limit,
        },
        options: _auth(accessToken),
      ),
      (body) => decodeFoodStorePage(body, page: page, limit: limit),
    );
  }
```

`food_repository.dart`, `food_repository_impl.dart` and `list_food_stores.dart` mirror the same named parameters and return type; the impl and use case only forward.

- [ ] **Step 6: Update callers**

`home_sections.dart`:

```dart
      final stores = (await context.read<ListFoodStores>()(token, limit: 6))
          .items
          .take(6)
          .toList(growable: false);
```

`fake_food_client.dart` — record the request and slice the list:

```dart
  final storePages = <int>[];
  final storeLimits = <int>[];
  final storeCategories = <String?>[];

  @override
  Future<FoodStorePageResult> listStores(
    String accessToken, {
    double? lat,
    double? lng,
    String? search,
    String? sortBy,
    int? maxKm,
    String? category,
    int page = 1,
    int limit = 20,
  }) async {
    storeListGeo.add(lat != null && lng != null);
    storeSearches.add(search);
    storeSorts.add(sortBy);
    storeMaxKms.add(maxKm);
    storePages.add(page);
    storeLimits.add(limit);
    storeCategories.add(category);

    final q = search?.trim().toLowerCase() ?? '';
    final code = category?.trim().toLowerCase() ?? '';
    final filtered = [
      for (final store in stores)
        if ((q.isEmpty || store.name.toLowerCase().contains(q)) &&
            (code.isEmpty || store.category?.toLowerCase() == code))
          store,
    ];
    final start = (page - 1) * limit;
    final items = start >= filtered.length
        ? const <FoodStoreSummary>[]
        : filtered.sublist(start, (start + limit).clamp(0, filtered.length));
    return FoodStorePageResult(
      items: items,
      total: filtered.length,
      page: page,
      limit: limit,
    );
  }
```

`test/qa_customer_fixes_test.dart` fake:

```dart
  @override
  Future<FoodStorePageResult> listStores(
    String accessToken, {
    double? lat,
    double? lng,
    String? search,
    String? sortBy,
    int? maxKm,
    String? category,
    int page = 1,
    int limit = 20,
  }) async {
    searches.add(search);
    return FoodStorePageResult(
      items: const [],
      total: 0,
      page: page,
      limit: limit,
    );
  }
```

- [ ] **Step 7: Run the tests**

Run: `flutter test test/features/food/food_store_page_decode_test.dart test/qa_customer_fixes_test.dart && flutter analyze`
Expected: PASS and `No issues found!`

- [ ] **Step 8: Commit**

```bash
git add lib/features/food/domain/entities/food_models.dart \
  lib/features/food/domain/repositories/food_repository.dart \
  lib/features/food/domain/usecases/list_food_stores.dart \
  lib/features/food/data/datasources/food_remote_datasource.dart \
  lib/features/food/data/datasources/dio_food_remote_datasource.dart \
  lib/features/food/data/repositories/food_repository_impl.dart \
  lib/features/shell/presentation/home_sections.dart \
  lib/core/mock/fake_food_client.dart \
  test/features/food/food_store_page_decode_test.dart test/qa_customer_fixes_test.dart
git commit -m "feat(food): page the store browse contract"
```

---

### Task 3: Pagination state in `FoodDiscoveryCubit`

**Files:**
- Modify: `lib/features/food/presentation/cubit/food_discovery_cubit.dart`
- Create: `test/features/food/food_discovery_pagination_test.dart`

**Interfaces:**
- Consumes: `FoodStorePageResult`, paged `ListFoodStores`.
- Produces: `FoodDiscoveryReady(stores, {ratings, isRefreshing, isLoadingMore, hasMore, total, loadMoreFailed})`, `FoodDiscoveryCubit.load(..., String? category)`, `Future<void> loadMore()`.

- [ ] **Step 1: Write the failing cubit tests**

```dart
// test/features/food/food_discovery_pagination_test.dart
import 'package:dealgo/core/network/api_exception.dart';
import 'package:dealgo/features/food/domain/entities/food_models.dart';
import 'package:dealgo/features/food/domain/repositories/food_repository.dart';
import 'package:dealgo/features/food/domain/usecases/list_food_stores.dart';
import 'package:dealgo/features/food/presentation/cubit/food_discovery_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

FoodStoreSummary _store(String id) => FoodStoreSummary(id: id, name: 'Quán $id');

class _PagedRepo implements FoodRepository {
  _PagedRepo(this.pages, {this.total, this.failFrom});

  final List<List<FoodStoreSummary>> pages;
  final int? total;
  final int? failFrom;
  final calls = <int>[];
  final categories = <String?>[];

  @override
  Future<FoodStorePageResult> listStores(
    String accessToken, {
    double? lat,
    double? lng,
    String? search,
    String? sortBy,
    int? maxKm,
    String? category,
    int page = 1,
    int limit = 20,
  }) async {
    calls.add(page);
    categories.add(category);
    if (failFrom != null && page >= failFrom!) {
      throw const ApiException(
        statusCode: 500,
        message: 'boom',
        errorCode: 'INTERNAL',
      );
    }
    return FoodStorePageResult(
      items: page <= pages.length ? pages[page - 1] : const [],
      total: total ?? pages.fold(0, (sum, rows) => sum + rows.length),
      page: page,
      limit: limit,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('load exposes the total and the first page only', () async {
    final repo = _PagedRepo([
      [_store('s1'), _store('s2')],
      [_store('s3')],
    ], total: 25);
    final cubit = FoodDiscoveryCubit(listFoodStores: ListFoodStores(repo));

    await cubit.load('tok', category: 'noodles');

    final state = cubit.state as FoodDiscoveryReady;
    expect([for (final store in state.stores) store.id], ['s1', 's2']);
    expect(state.total, 25);
    expect(state.hasMore, isTrue);
    expect(repo.categories, ['noodles']);
    await cubit.close();
  });

  test('loadMore appends the next page and de-duplicates ids', () async {
    final repo = _PagedRepo([
      [_store('s1'), _store('s2')],
      [_store('s2'), _store('s3')],
    ], total: 25);
    final cubit = FoodDiscoveryCubit(listFoodStores: ListFoodStores(repo));
    await cubit.load('tok');

    await cubit.loadMore();

    final state = cubit.state as FoodDiscoveryReady;
    expect([for (final store in state.stores) store.id], ['s1', 's2', 's3']);
    expect(repo.calls, [1, 2]);
    expect(state.hasMore, isFalse);
    await cubit.close();
  });

  test('loadMore is a no-op once the last page arrived', () async {
    final repo = _PagedRepo([
      [_store('s1')],
    ]);
    final cubit = FoodDiscoveryCubit(listFoodStores: ListFoodStores(repo));
    await cubit.load('tok');

    await cubit.loadMore();

    expect(repo.calls, [1]);
    await cubit.close();
  });

  test('a failed loadMore keeps the rows and marks the retry', () async {
    final repo = _PagedRepo([
      [_store('s1')],
      [_store('s2')],
    ], total: 25, failFrom: 2);
    final cubit = FoodDiscoveryCubit(listFoodStores: ListFoodStores(repo));
    await cubit.load('tok');

    await cubit.loadMore();

    final state = cubit.state as FoodDiscoveryReady;
    expect([for (final store in state.stores) store.id], ['s1']);
    expect(state.loadMoreFailed, isTrue);
    expect(state.isLoadingMore, isFalse);
    await cubit.close();
  });

  test('a new load resets the page cursor', () async {
    final repo = _PagedRepo([
      [_store('s1')],
      [_store('s2')],
    ], total: 25);
    final cubit = FoodDiscoveryCubit(listFoodStores: ListFoodStores(repo));
    await cubit.load('tok');
    await cubit.loadMore();

    await cubit.load('tok');

    expect(repo.calls, [1, 2, 1]);
    final state = cubit.state as FoodDiscoveryReady;
    expect([for (final store in state.stores) store.id], ['s1']);
    await cubit.close();
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/features/food/food_discovery_pagination_test.dart`
Expected: FAIL — `loadMore` and the new `FoodDiscoveryReady` fields do not exist.

- [ ] **Step 3: Extend the state**

```dart
final class FoodDiscoveryReady extends FoodDiscoveryState {
  const FoodDiscoveryReady(
    this.stores, {
    this.ratings = const {},
    this.isRefreshing = false,
    this.isLoadingMore = false,
    this.hasMore = false,
    this.total = 0,
    this.loadMoreFailed = false,
  });

  final List<FoodStoreSummary> stores;

  /// Real store ratings by store id; empty until loaded (or if unavailable).
  final Map<String, StoreRating> ratings;

  /// A newer first-page request is in flight; current stores stay on screen.
  final bool isRefreshing;

  /// The next page is in flight.
  final bool isLoadingMore;

  /// The server reported more rows than the client holds.
  final bool hasMore;

  /// Server count for the active filter.
  final int total;

  /// The last `loadMore` failed; the rows above stay usable.
  final bool loadMoreFailed;

  FoodDiscoveryReady copyWith({
    List<FoodStoreSummary>? stores,
    Map<String, StoreRating>? ratings,
    bool? isRefreshing,
    bool? isLoadingMore,
    bool? hasMore,
    int? total,
    bool? loadMoreFailed,
  }) {
    return FoodDiscoveryReady(
      stores ?? this.stores,
      ratings: ratings ?? this.ratings,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      total: total ?? this.total,
      loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
    );
  }
}
```

- [ ] **Step 4: Rewrite the cubit body**

Replace everything from `class FoodDiscoveryCubit` to the end of `_loadRatings` with:

```dart
class FoodDiscoveryCubit extends Cubit<FoodDiscoveryState> {
  FoodDiscoveryCubit({
    required this._listFoodStores,
    this._ratings,
    this._location,
  }) : super(const FoodDiscoveryLoading());

  static const pageSize = 20;

  final ListFoodStores _listFoodStores;
  final RatingRepository? _ratings;

  /// Optional GPS fix so the backend can sort by real distance.
  final LocationService? _location;

  var _generation = 0;
  var _page = 1;
  var _loadingMore = false;
  String? _token;
  String? _search;
  double? _lat;
  double? _lng;
  String? _sortBy;
  int? _maxKm;
  String? _category;

  Future<void> load(
    String? accessToken, {
    String? search,
    double? lat,
    double? lng,
    String? sortBy,
    int? maxKm,
    String? category,
  }) async {
    final generation = ++_generation;
    final token = accessToken?.trim() ?? '';
    if (token.isEmpty) {
      emit(FoodDiscoveryFailed(UiMessage((l10n) => l10n.errorUnauthorized)));
      return;
    }
    _token = token;
    _search = search;
    _sortBy = sortBy;
    _maxKm = maxKm;
    _category = category;
    _page = 1;
    _loadingMore = false;

    final previous = state;
    if (previous is FoodDiscoveryReady) {
      emit(
        previous.copyWith(
          isRefreshing: true,
          isLoadingMore: false,
          loadMoreFailed: false,
        ),
      );
    } else {
      emit(const FoodDiscoveryLoading());
    }
    try {
      final fix = lat != null && lng != null
          ? (lat: lat, lng: lng)
          : await _position();
      if (isClosed || generation != _generation) {
        return;
      }
      _lat = fix?.lat;
      _lng = fix?.lng;
      final page = await _fetch(1);
      if (isClosed || generation != _generation) {
        return;
      }
      emit(
        FoodDiscoveryReady(
          List.unmodifiable(page.items),
          total: page.total,
          hasMore: page.hasMore,
        ),
      );
      await _loadRatings(token, generation);
    } on ApiException catch (error) {
      if (isClosed || generation != _generation) {
        return;
      }
      emit(FoodDiscoveryFailed(UiMessage.error(error)));
    } catch (error) {
      if (isClosed || generation != _generation) {
        return;
      }
      emit(
        FoodDiscoveryFailed(
          UiMessage.error(error, fallback: (l10n) => l10n.errorNetwork),
        ),
      );
    }
  }

  Future<void> loadMore() async {
    final current = state;
    final token = _token;
    if (current is! FoodDiscoveryReady ||
        !current.hasMore ||
        current.isLoadingMore ||
        current.isRefreshing ||
        _loadingMore ||
        token == null) {
      return;
    }
    final generation = _generation;
    _loadingMore = true;
    emit(current.copyWith(isLoadingMore: true, loadMoreFailed: false));
    try {
      final page = await _fetch(_page + 1);
      if (isClosed || generation != _generation) {
        return;
      }
      final seen = {for (final store in current.stores) store.id};
      final merged = <FoodStoreSummary>[
        ...current.stores,
        for (final store in page.items)
          if (seen.add(store.id)) store,
      ];
      _page += 1;
      emit(
        FoodDiscoveryReady(
          List.unmodifiable(merged),
          ratings: current.ratings,
          total: page.total,
          hasMore: page.hasMore,
        ),
      );
      await _loadRatings(token, generation);
    } on ApiException {
      if (isClosed || generation != _generation) {
        return;
      }
      emit(current.copyWith(isLoadingMore: false, loadMoreFailed: true));
    } catch (_) {
      if (isClosed || generation != _generation) {
        return;
      }
      emit(current.copyWith(isLoadingMore: false, loadMoreFailed: true));
    } finally {
      _loadingMore = false;
    }
  }

  Future<FoodStorePageResult> _fetch(int page) {
    return _listFoodStores(
      _token!,
      lat: _lat,
      lng: _lng,
      search: _search,
      sortBy: _sortBy,
      maxKm: _maxKm,
      category: _category,
      page: page,
      limit: pageSize,
    );
  }

  Future<({double lat, double lng})?> _position() async {
    final location = _location;
    if (location == null) {
      return null;
    }
    try {
      final position = await location.currentPosition().timeout(
        const Duration(seconds: 5),
      );
      return position == null
          ? null
          : (lat: position.latitude, lng: position.longitude);
    } catch (_) {
      return null;
    }
  }

  /// Best effort: cards show no rating line when this fails.
  Future<void> _loadRatings(String token, int generation) async {
    final ratings = _ratings;
    final current = state;
    if (ratings == null || current is! FoodDiscoveryReady || current.stores.isEmpty) {
      return;
    }
    try {
      final byStore = await ratings.storeRatings(
        accessToken: token,
        storeIds: [for (final store in current.stores.take(50)) store.id],
      );
      if (isClosed || generation != _generation) {
        return;
      }
      final latest = state;
      if (latest is FoodDiscoveryReady) {
        emit(latest.copyWith(ratings: Map.unmodifiable(byStore)));
      }
    } on ApiException {
      return;
    }
  }
}
```

- [ ] **Step 5: Run the tests**

Run: `flutter test test/features/food/food_discovery_pagination_test.dart test/qa_customer_fixes_test.dart && flutter analyze`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/food/presentation/cubit/food_discovery_cubit.dart \
  test/features/food/food_discovery_pagination_test.dart
git commit -m "feat(food): paginate discovery stores with loadMore"
```

---

### Task 4: One `FoodStoreCard` and `FoodMetaLine`

**Files:**
- Create: `lib/features/food/presentation/widgets/food_store_card.dart`
- Modify: `lib/features/food/presentation/widgets/food_badges.dart:292-385` (delete `FoodStoreListCard`)
- Modify: `lib/features/food/presentation/widgets/store_meta.dart:156-277` (rename)
- Modify: `lib/features/food/presentation/pages/food_discovery_page.dart:860-950`
- Modify: `lib/features/food/presentation/pages/food_category_page.dart:247`
- Modify: `lib/features/food/presentation/pages/food_search_page.dart:362`
- Modify: `lib/features/shell/presentation/home_sections.dart:304`
- Modify: `test/merchant_flow_test.dart:1091,1099,1106`
- Create: `test/features/food/food_store_card_test.dart`

**Interfaces:**
- Consumes: `DealGoType`, `DealGoDensity`, `FoodMetaLine`.
- Produces: `enum FoodStoreCardVariant { feed, compact }`, `FoodStoreCard({required store, required onTap, rating, variant = feed})`, `FoodMetaLine({required store, rating})`.

- [ ] **Step 1: Write the failing widget tests**

```dart
// test/features/food/food_store_card_test.dart
import 'package:dealgo/features/food/domain/entities/food_models.dart';
import 'package:dealgo/features/food/presentation/widgets/food_store_card.dart';
import 'package:dealgo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _store = FoodStoreSummary(
  id: 's1',
  name: 'Bún Bò Huế',
  category: 'noodles',
  distanceKm: 1.2,
  etaMinutes: 25,
  deliveryFeeFromVnd: 15000,
  minOrderVnd: 30000,
  featuredItems: [
    FoodFeaturedItem(id: 'i1', name: 'Bún đặc biệt', priceVnd: 60000),
    FoodFeaturedItem(id: 'i2', name: 'Bún tái', priceVnd: 55000),
  ],
);

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(
      locale: const Locale('vi'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  testWidgets('feed card shows the two signature dishes and the meta line', (
    tester,
  ) async {
    await _pump(
      tester,
      FoodStoreCard(store: _store, onTap: () {}),
    );

    expect(find.text('Bún Bò Huế'), findsOneWidget);
    expect(find.text('Bún đặc biệt'), findsOneWidget);
    expect(find.text('Bún tái'), findsOneWidget);
    expect(find.byKey(const Key('store-meta-s1')), findsOneWidget);
  });

  testWidgets('compact card drops the dish rows', (tester) async {
    await _pump(
      tester,
      FoodStoreCard(
        store: _store,
        variant: FoodStoreCardVariant.compact,
        onTap: () {},
      ),
    );

    expect(find.text('Bún Bò Huế'), findsOneWidget);
    expect(find.text('Bún đặc biệt'), findsNothing);
    expect(find.byKey(const Key('store-eta-fee-s1')), findsOneWidget);
  });

  testWidgets('a closed store keeps its label and never fakes a rating', (
    tester,
  ) async {
    await _pump(
      tester,
      FoodStoreCard(
        store: const FoodStoreSummary(
          id: 's2',
          name: 'Quán đóng',
          closedReason: StoreClosedReason.closed,
        ),
        onTap: () {},
      ),
    );

    expect(find.text(AppLocalizationsVi().foodStoreClosedLabel), findsOneWidget);
    expect(find.byKey(const Key('store-eta-fee-s2')), findsNothing);
  });

  testWidgets('tapping the card calls onTap', (tester) async {
    var taps = 0;
    await _pump(
      tester,
      FoodStoreCard(store: _store, onTap: () => taps++),
    );

    await tester.tap(find.text('Bún Bò Huế'));
    expect(taps, 1);
  });
}
```

Add `import 'package:dealgo/l10n/app_localizations_vi.dart';` for `AppLocalizationsVi`.

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/features/food/food_store_card_test.dart`
Expected: FAIL — `food_store_card.dart` not found.

- [ ] **Step 3: Write the card**

```dart
// lib/features/food/presentation/widgets/food_store_card.dart
import 'package:flutter/material.dart';

import '../../../../core/design_system/components/dealgo_haptics.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/design_system/tokens/dealgo_type_scale.dart';
import '../../../../core/motion/dealgo_motion_widgets.dart';
import '../../../rating/domain/service_rating.dart';
import '../../domain/entities/food_models.dart';
import 'food_badges.dart';
import 'food_category_tile.dart';
import 'food_widgets.dart';
import 'store_meta.dart';

enum FoodStoreCardVariant { feed, compact }

/// The single store row used by discovery, category, search and home.
///
/// [FoodStoreCardVariant.feed] carries up to two signature dishes;
/// [FoodStoreCardVariant.compact] is the short row for side rails.
class FoodStoreCard extends StatelessWidget {
  const FoodStoreCard({
    required this.store,
    required this.onTap,
    this.rating,
    this.variant = FoodStoreCardVariant.feed,
    super.key,
  });

  final FoodStoreSummary store;
  final StoreRating? rating;
  final VoidCallback onTap;
  final FoodStoreCardVariant variant;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final closed = store.closedReason != null;
    return DealGoPressScale(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(DealGoRadius.card),
          boxShadow: DealGoShadows.card,
        ),
        child: Material(
          color: DealGoColors.card,
          borderRadius: BorderRadius.circular(DealGoRadius.card),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              DealGoHaptics.tap();
              onTap();
            },
            child: Padding(
              padding: const EdgeInsets.all(DealGoDensity.cardPad),
              child: variant == FoodStoreCardVariant.compact
                  ? _CompactBody(store: store, rating: rating)
                  : _FeedBody(
                      store: store,
                      rating: rating,
                      textTheme: textTheme,
                      closed: closed,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeedBody extends StatelessWidget {
  const _FeedBody({
    required this.store,
    required this.rating,
    required this.textTheme,
    required this.closed,
  });

  final FoodStoreSummary store;
  final StoreRating? rating;
  final TextTheme textTheme;
  final bool closed;

  @override
  Widget build(BuildContext context) {
    final dishes = store.featuredItems.take(2).toList(growable: false);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Opacity(
          opacity: closed ? 0.5 : 1,
          child: FoodThumb(
            size: 88,
            imageUrl: store.imageUrl,
            placeholderAsset: foodDishFallbackImage(store.category),
          ),
        ),
        const SizedBox(width: DealGoSpacing.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(store.name, style: DealGoType.subtitle(textTheme)),
              const SizedBox(height: DealGoDensity.metaGap),
              FoodMetaLine(store: store, rating: rating),
              if (store.offers.isNotEmpty || store.minOrderVnd > 0) ...[
                const SizedBox(height: DealGoSpacing.s8),
                FoodStoreBadges(store: store),
              ],
              for (final dish in dishes)
                Padding(
                  padding: const EdgeInsets.only(top: DealGoSpacing.s4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          dish.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DealGoType.body(textTheme).copyWith(
                            color: DealGoColors.text,
                          ),
                        ),
                      ),
                      const SizedBox(width: DealGoSpacing.s8),
                      FoodPriceText(
                        priceVnd: dish.priceVnd,
                        originalPriceVnd: dish.originalPriceVnd,
                        size: 12,
                        showPercent: false,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CompactBody extends StatelessWidget {
  const _CompactBody({required this.store, required this.rating});

  final FoodStoreSummary store;
  final StoreRating? rating;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        FoodThumb(
          size: 64,
          imageUrl: store.imageUrl,
          placeholderAsset: foodDishFallbackImage(store.category),
        ),
        const SizedBox(width: DealGoSpacing.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                store.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DealGoType.subtitle(textTheme),
              ),
              const SizedBox(height: DealGoDensity.metaGap),
              FoodMetaLine(store: store, rating: rating),
            ],
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Rename `StoreMetaLine` to `FoodMetaLine`**

In `store_meta.dart` rename the class and constructor; keep the file name and the `store-meta-*`/`store-eta-fee-*` keys. Update all references:

```bash
rg -l "StoreMetaLine" lib test | xargs sed -i '' 's/StoreMetaLine/FoodMetaLine/g'
```

Then run `flutter analyze` and remove the now-unused import in `food_badges.dart` if it reports one.

- [ ] **Step 5: Delete `FoodStoreListCard` and point callers at the new card**

Delete `FoodStoreListCard` from `food_badges.dart` (class starts at `/// Store row for category and search results` and runs to the end of the file). Then:

`food_category_page.dart`:

```dart
    return FoodStoreCard(store: store, rating: rating, onTap: onTap);
```

`food_search_page.dart`:

```dart
    return FoodStoreCard(store: store, rating: rating, onTap: onTap);
```

`food_discovery_page.dart` — `_StoreTile` and `_WideStoreCard` both become the shared card (complete wiring happens in Task 5; for now replace the body):

```dart
// _StoreTile body
return FoodStoreCard(
  store: store,
  rating: rating,
  variant: FoodStoreCardVariant.compact,
  onTap: onTap,
);

// _WideStoreCard body
return FoodStoreCard(
  store: store,
  rating: rating,
  variant: FoodStoreCardVariant.compact,
  onTap: onTap,
);
```

Add `import '../widgets/food_store_card.dart';` to the three pages and to `home_sections.dart` if it still builds its own card (leave `home_sections` on `FoodMetaLine` only; its own `_StoreCard` stays for now).

- [ ] **Step 6: Run the tests**

Run: `flutter test test/features/food/food_store_card_test.dart test/merchant_flow_test.dart test/food_real_data_test.dart && flutter analyze`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/features/food/presentation/widgets/food_store_card.dart \
  lib/features/food/presentation/widgets/food_badges.dart \
  lib/features/food/presentation/widgets/store_meta.dart \
  lib/features/food/presentation/pages/food_discovery_page.dart \
  lib/features/food/presentation/pages/food_category_page.dart \
  lib/features/food/presentation/pages/food_search_page.dart \
  lib/features/shell/presentation/home_sections.dart \
  test/features/food/food_store_card_test.dart test/merchant_flow_test.dart
git commit -m "refactor(food): unify store cards and meta line"
```

---

### Task 5: Vertical discovery feed with load-more

**Files:**
- Create: `lib/features/food/presentation/widgets/food_feed_footer.dart`
- Modify: `lib/features/food/presentation/pages/food_discovery_page.dart`
- Modify: `lib/l10n/app_vi.arb`, `lib/l10n/app_en.arb`
- Modify: `test/food_real_data_test.dart:144-191` (drag target changes from `ListView` to `CustomScrollView`)
- Modify: `test/food_flow_test.dart:154-158,353-357`
- Modify: `test/ui_b_mock_depth_test.dart:170`
- Modify: `test/item_options_test.dart:526`
- Create: `test/features/food/food_discovery_feed_test.dart`

**Interfaces:**
- Consumes: `FoodDiscoveryReady.hasMore/isLoadingMore/loadMoreFailed/total`, `FoodStoreCard`, `loadMore()`.
- Produces: `FoodFeedFooter({required FoodDiscoveryReady? state, required VoidCallback onRetry})`; i18n keys `foodFeedEndOfList`.

- [ ] **Step 1: Add the copy**

In `app_vi.arb`:

```json
  "foodFeedEndOfList": "Bạn đã xem hết quán quanh đây",
```

In `app_en.arb`:

```json
  "foodFeedEndOfList": "You have seen every store nearby",
```

Run: `flutter gen-l10n`
Expected: `lib/l10n/app_localizations*.dart` regenerated, no error.

- [ ] **Step 2: Write the failing widget test**

```dart
// test/features/food/food_discovery_feed_test.dart
import 'package:dealgo/features/food/domain/entities/food_models.dart';
import 'package:dealgo/features/food/presentation/widgets/food_store_card.dart';
import 'package:dealgo/features/rating/data/rating_remote_datasource.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/auth_test_harness.dart';
import '../../support/fake_food_client.dart';
import '../../support/fake_identity_client.dart';
import '../../support/fake_location.dart';

List<FoodStoreSummary> _manyStores(int count) => [
  for (var i = 0; i < count; i++)
    FoodStoreSummary(
      id: 'store-$i',
      name: 'Quán $i',
      category: 'noodles',
    ),
];

Future<void> _pump(WidgetTester tester, FakeFoodClient food) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await pumpSignedIn(
    tester,
    profile: customerProfile,
    foodClient: food,
    ratings: FakeRatingRemoteDataSource(),
    locationOverride: FakeLocationService(),
  );
  await tester.tap(find.text('Đồ ăn').first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders the feed and loads page 2 on scroll', (tester) async {
    final food = FakeFoodClient(stores: _manyStores(25));
    await _pump(tester, food);

    expect(find.byType(FoodStoreCard), findsWidgets);
    expect(food.storePages.first, 1);

    for (var i = 0; i < 8 && !food.storePages.contains(2); i++) {
      await tester.drag(
        find.byType(CustomScrollView).first,
        const Offset(0, -1200),
      );
      await tester.pumpAndSettle();
    }

    expect(food.storePages, contains(2));
  });

  testWidgets('the end label appears once the last page landed', (
    tester,
  ) async {
    final food = FakeFoodClient(stores: _manyStores(3));
    await _pump(tester, food);

    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, -1200),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('food-feed-end')), findsOneWidget);
    expect(food.storePages, [1]);
  });
}
```

Update `test/food_real_data_test.dart` in the same task: both discovery tests drag `find.byType(ListView).first`, which no longer exists on this page. Use `find.byType(CustomScrollView).first`:

```dart
    await tester.dragUntilVisible(
      find.text('Đánh giá cao'),
      find.byType(CustomScrollView).first,
      const Offset(0, -300),
    );
```

The store cards now sit below the banner and categories, so tests that tap a card straight after opening the tab must scroll it into view first. Add this helper to `test/food_flow_test.dart` and `test/ui_b_mock_depth_test.dart` (both tap a discovery card without scrolling; `test/item_options_test.dart` already scrolls):

```dart
Future<void> tapFoodStoreCard(WidgetTester tester, String storeId) async {
  final card = find.byKey(Key('food-store-card-$storeId'));
  await tester.scrollUntilVisible(
    card,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(card);
  await tester.pumpAndSettle();
}
```

and replace every discovery `await tester.tap(find.byKey(const Key('food-store-card-...')));` with `await tapFoodStoreCard(tester, '<id>');` (in `food_flow_test.dart` that is line 157 and the helper at line 356). Cards on the category and search pages keep their direct taps.

- [ ] **Step 3: Run it and watch it fail**

Run: `flutter test test/features/food/food_discovery_feed_test.dart`
Expected: FAIL — no `CustomScrollView`, no `FoodStoreCard` in the tree.

- [ ] **Step 4: Write the footer widget**

```dart
// lib/features/food/presentation/widgets/food_feed_footer.dart
import 'package:flutter/material.dart';

import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/design_system/tokens/dealgo_type_scale.dart';
import '../../../../l10n/app_localizations.dart';
import '../cubit/food_discovery_cubit.dart';

/// Bottom of a paginated store list: spinner, retry, or the end label.
class FoodFeedFooter extends StatelessWidget {
  const FoodFeedFooter({required this.state, required this.onRetry, super.key});

  final FoodDiscoveryReady? state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ready = state;
    if (ready == null || ready.stores.isEmpty) {
      return const SizedBox.shrink();
    }
    if (ready.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: DealGoSpacing.s12),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (ready.loadMoreFailed) {
      return Center(
        child: TextButton(
          key: const Key('food-feed-retry'),
          onPressed: onRetry,
          child: Text(AppLocalizations.of(context).actionRetry),
        ),
      );
    }
    if (ready.hasMore) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DealGoSpacing.s12),
      child: Text(
        AppLocalizations.of(context).foodFeedEndOfList,
        key: const Key('food-feed-end'),
        textAlign: TextAlign.center,
        style: DealGoType.meta(Theme.of(context).textTheme).copyWith(
          color: DealGoColors.textTertiary,
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Rebuild the discovery body as slivers**

In `_FoodDiscoveryViewState`:

```dart
  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    if (position.maxScrollExtent <= 0) return;
    if (position.pixels < position.maxScrollExtent - 400) return;
    context.read<FoodDiscoveryCubit>().loadMore();
  }
```

Replace the whole `build` method with:

```dart
  @override
  Widget build(BuildContext context) {
    final discovery = context.watch<FoodDiscoveryCubit>().state;
    final ready = discovery is FoodDiscoveryReady ? discovery : null;
    final allStores = ready?.stores ?? const <FoodStoreSummary>[];
    final stores = [
      for (final store in allStores)
        if ((!_filters.openNow || store.openNow) &&
            (!_filters.offersOnly || store.offers.isNotEmpty))
          store,
    ];
    final fetched = ready?.ratings ?? const <String, StoreRating>{};
    final ratings = <String, StoreRating>{
      for (final store in stores)
        store.id: ?storeRatingOf(store, fetched[store.id]),
    };
    final offerStores = [
      for (final store in stores)
        if (store.offers.isNotEmpty && store.closedReason == null) store,
    ];
    final l10n = AppLocalizations.of(context);
    final dishes = [
      for (final store in stores)
        if (store.closedReason == null)
          for (final item in store.featuredItems) (store: store, item: item),
    ];
    final deals = [
      for (final dish in dishes)
        if ((dish.item.originalPriceVnd ?? 0) > dish.item.priceVnd) dish,
    ];
    final newDishes = [
      for (final dish in dishes)
        if (dish.item.isNew) dish,
    ];
    final loading = discovery is FoodDiscoveryLoading;
    final refreshing = ready?.isRefreshing ?? false;
    final error = discovery is FoodDiscoveryFailed ? discovery.message : null;
    final popular = _popularThisWeek(stores, ratings);
    final cartRoom = FoodCartBar.showsFor(context.watch<FoodCartCubit>().state)
        ? kFoodCartBarRoom
        : 0.0;
    final bottomInset = dealGoScrollPadding(context, EdgeInsets.zero).bottom;
    const gutter = DealGoDimensions.pageGutter;
    return Stack(
      children: [
        SafeArea(
          bottom: false,
          child: CustomScrollView(
            controller: _scroll,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  gutter,
                  DealGoSpacing.s8,
                  gutter,
                  0,
                ),
                sliver: SliverList.list(
                  children: [
                    _DiscoveryHeader(onPickAddress: _pickAddress),
                    const SizedBox(height: DealGoSpacing.s16),
                    _SearchRow(
                      onOpenSearch: () => context.push(FoodRoutes.search),
                      onOpenFilters: _openFilters,
                      filterActive: !_filters.isDefault,
                    ),
                    if (refreshing) ...[
                      const SizedBox(height: DealGoSpacing.s8),
                      const LinearProgressIndicator(minHeight: 2),
                    ],
                    if (!_filters.isDefault) ...[
                      const SizedBox(height: DealGoSpacing.s8),
                      _ActiveFilterSummary(
                        filters: _filters,
                        onEdit: _openFilters,
                        onClear: () {
                          setState(() => _filters = const FoodFilters());
                          _reload();
                        },
                      ),
                    ],
                    const SizedBox(height: DealGoSpacing.s16),
                    HomeBannerCarousel(
                      role: AppRole.customer,
                      service: 'FOOD',
                      gapBelow: 0,
                      empty: _FoodBanner(onExplore: _scrollToStores),
                    ),
                    const SizedBox(height: DealGoSpacing.s16),
                    _CategoryStrip(
                      selected: null,
                      onSelected: (code) =>
                          context.push(FoodRoutes.categoryOf(code)),
                    ),
                    if (offerStores.isNotEmpty) ...[
                      const SizedBox(height: DealGoSpacing.s16),
                      _SectionHeader(
                        title: l10n.foodOffersNearTitle,
                        onSeeAll: () =>
                            context.push(FoodRoutes.categoryOf(null)),
                      ),
                      const SizedBox(height: DealGoSpacing.s12),
                      _OfferStrip(stores: offerStores, onOpen: _openStore),
                    ],
                    const SizedBox(height: DealGoSpacing.s20),
                    KeyedSubtree(
                      key: _storesKey,
                      child: _SectionHeader(
                        title: l10n.foodCollectionNear,
                        onSeeAll: () => context.push(FoodRoutes.categoryOf(null)),
                      ),
                    ),
                    const SizedBox(height: DealGoSpacing.s12),
                  ],
                ),
              ),
              if (loading)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: gutter),
                  sliver: const SliverToBoxAdapter(
                    child: DealGoSkeletonList(itemCount: 4),
                  ),
                )
              else if (error != null)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: gutter),
                  sliver: SliverToBoxAdapter(
                    child: DealGoStateView.failure(
                      context,
                      onRetry: _reload,
                      cause: error.error,
                      message: error.resolve(l10n),
                    ),
                  ),
                )
              else if (stores.isEmpty)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: gutter),
                  sliver: SliverToBoxAdapter(
                    child: DealGoStateView(
                      art: DealGoStateArt.noSearch,
                      title: l10n.emptyStoresNearby,
                      message: l10n.emptyStoresNearbyBody,
                      compact: true,
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: gutter),
                  sliver: SliverList.separated(
                    itemCount: stores.length,
                    itemBuilder: (context, index) {
                      final store = stores[index];
                      return DealGoStaggerIn(
                        index: index,
                        child: FoodStoreCard(
                          key: Key('food-store-card-${store.id}'),
                          store: store,
                          rating: ratings[store.id],
                          onTap: () => _openStore(store),
                        ),
                      );
                    },
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: DealGoSpacing.s12),
                  ),
                ),
              if (stores.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    gutter,
                    DealGoSpacing.s12,
                    gutter,
                    0,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: FoodFeedFooter(
                      state: ready,
                      onRetry: () =>
                          context.read<FoodDiscoveryCubit>().loadMore(),
                    ),
                  ),
                ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  gutter,
                  DealGoSpacing.s20,
                  gutter,
                  DealGoSpacing.s16 + cartRoom + bottomInset,
                ),
                sliver: SliverList.list(
                  children: [
                    if (deals.isNotEmpty) ...[
                      _SectionHeader(
                        title: l10n.foodCollectionDeals,
                        onSeeAll: () =>
                            context.push(FoodRoutes.categoryOf(null)),
                      ),
                      const SizedBox(height: DealGoSpacing.s12),
                      _DishStrip(
                        key: const Key('food-deals-strip'),
                        dishes: deals,
                        onOpen: _openStore,
                      ),
                      const SizedBox(height: DealGoSpacing.s20),
                    ],
                    if (newDishes.isNotEmpty) ...[
                      _SectionHeader(
                        title: l10n.foodCollectionNewDishes,
                        onSeeAll: () =>
                            context.push(FoodRoutes.categoryOf(null)),
                      ),
                      const SizedBox(height: DealGoSpacing.s12),
                      _DishStrip(
                        key: const Key('food-new-strip'),
                        dishes: newDishes,
                        onOpen: _openStore,
                      ),
                      const SizedBox(height: DealGoSpacing.s20),
                    ],
                    if (popular.isNotEmpty) ...[
                      _SectionHeader(
                        title: l10n.foodCollectionTopRated,
                        onSeeAll: () =>
                            context.push(FoodRoutes.categoryOf(null)),
                      ),
                      const SizedBox(height: DealGoSpacing.s12),
                      for (final (index, store) in popular.indexed) ...[
                        DealGoStaggerIn(
                          index: index,
                          child: FoodStoreCard(
                            store: store,
                            rating: ratings[store.id],
                            variant: FoodStoreCardVariant.compact,
                            onTap: () => _openStore(store),
                          ),
                        ),
                        const SizedBox(height: DealGoSpacing.s12),
                      ],
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const Positioned(left: 0, right: 0, bottom: 0, child: FoodCartBar()),
      ],
    );
  }
```

- [ ] **Step 6: Extract the search row and delete the old store widgets**

Add to the same file:

```dart
class _SearchRow extends StatelessWidget {
  const _SearchRow({
    required this.onOpenSearch,
    required this.onOpenFilters,
    required this.filterActive,
  });

  final VoidCallback onOpenSearch;
  final VoidCallback onOpenFilters;
  final bool filterActive;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: onOpenSearch,
            borderRadius: BorderRadius.circular(DealGoRadius.button),
            child: InputDecorator(
              decoration: InputDecoration(
                filled: true,
                fillColor: DealGoColors.card,
                prefixIcon: const Icon(
                  DealGoIcons.search,
                  color: DealGoColors.primary,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: DealGoSpacing.s12,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(DealGoRadius.button),
                  borderSide: BorderSide(color: DealGoColors.border),
                ),
              ),
              child: Text(
                l10n.foodDiscoverySearchHint,
                style: DealGoType.body(Theme.of(context).textTheme).copyWith(
                  color: DealGoColors.textSecondary,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: DealGoSpacing.s8),
        _FilterButton(active: filterActive, onTap: onOpenFilters),
      ],
    );
  }
}
```

Delete `_StoreResults`, `_StoreTile`, `_StoreCover`, `_StoreLogo`, `_WideStoreCard` if no other widget in the file uses them (the offer strip uses `_StoreCover`, so keep `_StoreCover` only). Remove the `final visible = stores.take(8)` line and any import left unused (`flutter analyze` lists them). Keep the `dealgo_nav_insets.dart` and `food_cart_bar.dart` imports: the trailing sliver still pads with `dealGoScrollPadding` plus `kFoodCartBarRoom`.

- [ ] **Step 7: Run the tests**

Run: `flutter test test/features/food/food_discovery_feed_test.dart test/food_real_data_test.dart test/food_flow_test.dart test/ui_b_mock_depth_test.dart test/item_options_test.dart test/qa_customer_fixes_test.dart && flutter analyze`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add lib/features/food/presentation/pages/food_discovery_page.dart \
  lib/features/food/presentation/widgets/food_feed_footer.dart \
  lib/l10n/app_vi.arb lib/l10n/app_en.arb \
  lib/l10n/app_localizations.dart lib/l10n/app_localizations_en.dart \
  lib/l10n/app_localizations_vi.dart \
  test/features/food/food_discovery_feed_test.dart \
  test/food_real_data_test.dart test/food_flow_test.dart \
  test/ui_b_mock_depth_test.dart
git commit -m "feat(food): make discovery a paginated vertical feed"
```

---

### Task 6: Paginated category and search

**Files:**
- Modify: `lib/features/food/presentation/pages/food_category_page.dart`
- Modify: `lib/features/food/presentation/pages/food_search_page.dart`
- Create: `test/features/food/food_category_paging_test.dart`

**Interfaces:**
- Consumes: `FoodFeedFooter`, `FoodDiscoveryReady.total`.
- Produces: nothing new.

- [ ] **Step 1: Write the failing category test**

```dart
// test/features/food/food_category_paging_test.dart
import 'package:dealgo/features/food/domain/entities/food_models.dart';
import 'package:dealgo/features/rating/data/rating_remote_datasource.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/auth_test_harness.dart';
import '../../support/fake_food_client.dart';
import '../../support/fake_identity_client.dart';
import '../../support/fake_location.dart';

Future<void> _go(WidgetTester tester, String path) async {
  GoRouter.of(tester.element(find.byType(Scaffold).first)).push(path);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the category page asks for the code and the first page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final food = FakeFoodClient(
      stores: const [
        FoodStoreSummary(id: 's1', name: 'Bún bò', category: 'noodles'),
        FoodStoreSummary(id: 's2', name: 'Trà Sữa Mây', category: 'tea'),
      ],
    );

    await pumpSignedIn(
      tester,
      profile: customerProfile,
      foodClient: food,
      ratings: FakeRatingRemoteDataSource(),
      locationOverride: FakeLocationService(),
    );
    await _go(tester, '/customer/food/category?category=noodles');

    expect(food.storeCategories, contains('noodles'));
    expect(food.storePages, contains(1));
    expect(food.storeLimits, contains(20));
    expect(find.text('Trà Sữa Mây'), findsNothing);
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/features/food/food_category_paging_test.dart`
Expected: FAIL — `storeCategories` has `null`.

- [ ] **Step 3: Send the category to the server**

`food_category_page.dart`:

```dart
          )..load(
            currentAccessToken(context),
            lat: origin.lat,
            lng: origin.lng,
            sortBy: 'distance',
            category: categoryCode,
          ),
```

In `_FoodCategoryViewState` drop the client-side `code` filter:

```dart
    final stores = switch (discovery) {
      FoodDiscoveryReady(:final stores) => stores,
      _ => <FoodStoreSummary>[],
    };
```

and the heading count:

```dart
                            Text(
                              l10n.foodCategoryAroundHint(
                                discovery is FoodDiscoveryReady
                                    ? discovery.total
                                    : 0,
                              ),
                              style: textTheme.bodySmall,
                            ),
```

The failure retry must keep the filter and the GPS fix:

```dart
                  if (discovery is FoodDiscoveryFailed)
                    DealGoStateView.failure(
                      context,
                      onRetry: () {
                        final origin = foodCartOrigin(context);
                        context.read<FoodDiscoveryCubit>().load(
                          currentAccessToken(context),
                          lat: origin.lat,
                          lng: origin.lng,
                          sortBy: _sort == 'rating' ? 'rating' : 'distance',
                          category: widget.categoryCode,
                        );
                      },
                      cause: discovery.message.error,
                      message: discovery.message.resolve(l10n),
                      compact: true,
                    )
```

- [ ] **Step 4: Add load-more to the category list**

In `_FoodCategoryViewState`:

```dart
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    if (position.maxScrollExtent <= 0) return;
    if (position.pixels < position.maxScrollExtent - 400) return;
    context.read<FoodDiscoveryCubit>().loadMore();
  }
```

Pass `controller: _scroll` to the `ListView`, and after the store loop append:

```dart
                    FoodFeedFooter(
                      state: discovery is FoodDiscoveryReady ? discovery : null,
                      onRetry: () => context.read<FoodDiscoveryCubit>().loadMore(),
                    ),
```

`_setSort` must also pass the category back to the server:

```dart
    context.read<FoodDiscoveryCubit>().load(
      currentAccessToken(context),
      lat: origin.lat,
      lng: origin.lng,
      sortBy: sort == 'rating' ? 'rating' : 'distance',
      category: widget.categoryCode,
    );
```

- [ ] **Step 5: Add load-more to search**

In `_FoodSearchViewState` add the same controller, listener, `dispose`, and pass `controller: _scroll` to the results `ListView`. Append after the results loop:

```dart
                    if (q.isNotEmpty && q == _serverQuery)
                      FoodFeedFooter(
                        state: discovery is FoodDiscoveryReady ? discovery : null,
                        onRetry: () =>
                            context.read<FoodDiscoveryCubit>().loadMore(),
                      ),
```

- [ ] **Step 6: Run the tests**

Run: `flutter test test/features/food/food_category_paging_test.dart test/food_real_data_test.dart test/qa_customer_fixes_test.dart && flutter analyze`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/features/food/presentation/pages/food_category_page.dart \
  lib/features/food/presentation/pages/food_search_page.dart \
  test/features/food/food_category_paging_test.dart
git commit -m "feat(food): page category and search results"
```

---

### Task 7: Dish gallery

**Files:**
- Create: `lib/features/food/presentation/widgets/food_dish_gallery.dart`
- Modify: `lib/features/food/presentation/pages/food_item_options_page.dart:205-216`
- Modify: `lib/features/food/presentation/pages/food_store_page.dart:1953-1992` (`_photo`)
- Modify: `lib/l10n/app_vi.arb`, `lib/l10n/app_en.arb`
- Create: `test/features/food/food_dish_gallery_test.dart`

**Interfaces:**
- Produces: `FoodDishGallery({required imageUrls, fallbackImageUrl, required placeholderAsset, aspectRatio = 4 / 3})`; key `food-dish-gallery`; i18n `foodDishPhotoCount(index, total)`.

- [ ] **Step 1: Add the copy**

`app_vi.arb`:

```json
  "foodDishPhotoCount": "Ảnh {index}/{total}",
  "@foodDishPhotoCount": {
    "placeholders": {
      "index": { "type": "int" },
      "total": { "type": "int" }
    }
  },
```

`app_en.arb`:

```json
  "foodDishPhotoCount": "Photo {index}/{total}",
  "@foodDishPhotoCount": {
    "placeholders": {
      "index": { "type": "int" },
      "total": { "type": "int" }
    }
  },
```

Run: `flutter gen-l10n`

- [ ] **Step 2: Write the failing gallery test**

```dart
// test/features/food/food_dish_gallery_test.dart
import 'package:dealgo/features/food/presentation/widgets/food_dish_gallery.dart';
import 'package:dealgo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(
      locale: const Locale('vi'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SizedBox(width: 360, child: child)),
    ),
  );
}

void main() {
  testWidgets('one image renders no counter', (tester) async {
    await _pump(
      tester,
      const FoodDishGallery(
        imageUrls: [],
        fallbackImageUrl: null,
        placeholderAsset: 'assets/images/food_dish.jpg',
      ),
    );

    expect(find.byKey(const Key('food-dish-gallery')), findsNothing);
    expect(find.textContaining('/1'), findsNothing);
  });

  testWidgets('three images page and update the counter', (tester) async {
    await _pump(
      tester,
      const FoodDishGallery(
        imageUrls: ['a.jpg', 'b.jpg', 'c.jpg'],
        fallbackImageUrl: null,
        placeholderAsset: 'assets/images/food_dish.jpg',
      ),
    );

    expect(find.byKey(const Key('food-dish-gallery')), findsOneWidget);
    expect(find.text('Ảnh 1/3'), findsOneWidget);

    await tester.drag(
      find.byKey(const Key('food-dish-gallery')),
      const Offset(-400, 0),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ảnh 2/3'), findsOneWidget);
  });

  testWidgets('a duplicated cover is not shown twice', (tester) async {
    await _pump(
      tester,
      const FoodDishGallery(
        imageUrls: ['a.jpg', 'a.jpg'],
        fallbackImageUrl: 'a.jpg',
        placeholderAsset: 'assets/images/food_dish.jpg',
      ),
    );

    expect(find.byKey(const Key('food-dish-gallery')), findsNothing);
  });
}
```

- [ ] **Step 3: Run it and watch it fail**

Run: `flutter test test/features/food/food_dish_gallery_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 4: Write the gallery**

```dart
// lib/features/food/presentation/widgets/food_dish_gallery.dart
import 'package:flutter/material.dart';

import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import 'food_widgets.dart';

class FoodDishGallery extends StatefulWidget {
  const FoodDishGallery({
    required this.imageUrls,
    required this.placeholderAsset,
    this.fallbackImageUrl,
    this.aspectRatio = 4 / 3,
    super.key,
  });

  final List<String> imageUrls;
  final String? fallbackImageUrl;
  final String placeholderAsset;
  final double aspectRatio;

  @override
  State<FoodDishGallery> createState() => _FoodDishGalleryState();
}

class _FoodDishGalleryState extends State<FoodDishGallery> {
  final PageController _controller = PageController();
  var _index = 0;

  /// Cover first, then the gallery, without blank or repeated entries.
  List<String> get _images {
    final seen = <String>{};
    return [
      for (final url in [?widget.fallbackImageUrl, ...widget.imageUrls])
        if (url.trim().isNotEmpty && seen.add(url.trim())) url.trim(),
    ];
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = _images;
    if (images.length <= 1) {
      return FoodCoverImage(
        imageUrl: images.isEmpty ? null : images.first,
        aspectRatio: widget.aspectRatio,
        placeholderAsset: widget.placeholderAsset,
      );
    }
    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(DealGoRadius.card),
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              key: const Key('food-dish-gallery'),
              controller: _controller,
              itemCount: images.length,
              onPageChanged: (index) => setState(() => _index = index),
              itemBuilder: (context, index) => FoodCoverImage(
                imageUrl: images[index],
                aspectRatio: widget.aspectRatio,
                placeholderAsset: widget.placeholderAsset,
              ),
            ),
            Positioned(
              right: DealGoSpacing.s12,
              bottom: DealGoSpacing.s12,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: DealGoColors.scrim,
                  borderRadius: BorderRadius.circular(DealGoRadius.pill),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DealGoSpacing.s8,
                    vertical: DealGoSpacing.s4,
                  ),
                  child: Text(
                    AppLocalizations.of(context).foodDishPhotoCount(
                      _index + 1,
                      images.length,
                    ),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Use it on the item page**

Replace lines 207–215 of `food_item_options_page.dart`:

```dart
                  DealGoHero(
                    tag: foodItemHeroTag(item.id),
                    child: FoodDishGallery(
                      imageUrls: item.imageUrls,
                      fallbackImageUrl: item.imageUrl,
                      placeholderAsset: foodDishFallbackImage(
                        widget.args.store.category,
                      ),
                    ),
                  ),
```

Add `import '../widgets/food_dish_gallery.dart';`.

- [ ] **Step 6: Mark rows that have a gallery**

At the end of `_MenuItem._photo`'s `Stack` children (after the sold-out overlay):

```dart
        if (item.imageUrls.length > 1)
          Positioned(
            top: DealGoSpacing.s6,
            right: DealGoSpacing.s6,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: DealGoColors.scrim,
                borderRadius: BorderRadius.circular(DealGoRadius.pill),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: DealGoSpacing.s6,
                  vertical: 2,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      DealGoIcons.image,
                      size: 11,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${item.imageUrls.length}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
```

- [ ] **Step 7: Run the tests**

Run: `flutter test test/features/food/food_dish_gallery_test.dart test/food_store_redesign_test.dart && flutter analyze`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add lib/features/food/presentation/widgets/food_dish_gallery.dart \
  lib/features/food/presentation/pages/food_item_options_page.dart \
  lib/features/food/presentation/pages/food_store_page.dart \
  lib/l10n/app_vi.arb lib/l10n/app_en.arb \
  lib/l10n/app_localizations.dart lib/l10n/app_localizations_en.dart \
  lib/l10n/app_localizations_vi.dart \
  test/features/food/food_dish_gallery_test.dart
git commit -m "feat(food): show the dish photo gallery"
```

---

### Task 8: Split the store page into parts

**Files:**
- Modify: `lib/features/food/presentation/pages/food_store_page.dart`
- Create: `lib/features/food/presentation/pages/store/store_hero.dart`
- Create: `lib/features/food/presentation/pages/store/store_map.dart`
- Create: `lib/features/food/presentation/pages/store/store_offers.dart`
- Create: `lib/features/food/presentation/pages/store/store_menu_nav.dart`
- Create: `lib/features/food/presentation/pages/store/store_menu_board.dart`
- Create: `lib/features/food/presentation/pages/store/store_menu_item.dart`
- Create: `lib/features/food/presentation/pages/store/store_reviews.dart`
- Create: `lib/features/food/presentation/pages/store/store_info.dart`

**Interfaces:**
- Consumes: nothing new.
- Produces: the same private classes, now reachable through `part`.

- [ ] **Step 1: Declare the parts**

At the end of the import block in `food_store_page.dart`:

```dart
part 'store/store_hero.dart';
part 'store/store_map.dart';
part 'store/store_offers.dart';
part 'store/store_menu_nav.dart';
part 'store/store_menu_board.dart';
part 'store/store_menu_item.dart';
part 'store/store_reviews.dart';
part 'store/store_info.dart';
```

- [ ] **Step 2: Move the widget groups**

Cut each range from `food_store_page.dart` into the matching part file and start every part with:

```dart
part of '../food_store_page.dart';
```

| Part file | Classes to move |
|---|---|
| `store_hero.dart` | `_Hero`, `_StoreHeading` |
| `store_map.dart` | `_StoreMapCard`, `_StoreLocationCard` |
| `store_offers.dart` | `_StoreOffers`, `_StoreOffersSheet`, `_OfferTicket` |
| `store_menu_nav.dart` | `_Tabs`, `_MenuSearchBar`, `_CategoryRail`, `_CategoryRailState` |
| `store_menu_board.dart` | `_MenuBoard`, `_MenuBoardState`, `_MenuList`, `_ScrollBody` |
| `store_menu_item.dart` | `_MenuItem`, `_ItemMeta`, `_MenuAddControl`, `_StepButton` |
| `store_reviews.dart` | `_Reviews`, `_Stars` |
| `store_info.dart` | `_StoreStatus`, `_StoreInfo`, `_dayShort` |

Keep in `food_store_page.dart`: `FoodStorePage`, `_FoodStoreView`, `_FoodStorePageState`, `_storeBody`, `_StoreTab`, `_MenuGroup`, `_PinnedHeader`.

- [ ] **Step 3: Verify size and behaviour**

Run:

```bash
wc -l lib/features/food/presentation/pages/food_store_page.dart \
  lib/features/food/presentation/pages/store/*.dart
flutter analyze
flutter test test/food_store_redesign_test.dart test/food_real_data_test.dart test/screenshots/screens_capture_test.dart
```

Expected: `food_store_page.dart` ≤ 500 lines, every part ≤ 500 lines, `No issues found!`, tests PASS with no behaviour change.

`part` files inherit the imports of `food_store_page.dart`; do not add `import` lines inside them. If a part still exceeds 500 lines, split its class group again (for example `store_menu_item_add.dart` for `_MenuAddControl` and `_StepButton`) instead of moving unrelated classes into the page file.

- [ ] **Step 4: Commit**

```bash
git add lib/features/food/presentation/pages/food_store_page.dart \
  lib/features/food/presentation/pages/store
git commit -m "refactor(food): split store page into part files"
```

---

### Task 9: Docs and status

**Files:**
- Modify: `docs/10-ai-execution/screen-inventory.md:69-74`
- Modify: `docs/superpowers/specs/2026-11-03-food-customer-redesign-design.md:4`

- [ ] **Step 1: Update the inventory notes**

Replace the note cells with:

```markdown
| C022 | Khám phá đồ ăn | `/customer/shop` | LIVE | Vertical paginated feed (`page`/`limit`, load-more + end label); store cards show rating (count), km, ETA, fee or green "Miễn phí giao", offer pill, min order, up to two signature dishes; offers strip, deals, new dishes, top-rated |
| C023 | Tìm kiếm quán / món | `/customer/food/search` | LIVE | Server name/dish search, paginated results |
| C024 | Kết quả danh mục | `/customer/food/category?category=<code>` | LIVE | `category` filtered on the server; paginated |
| C025 | Chi tiết quán & menu | `/customer/food/stores/:storeId` | LIVE | Same behaviours as before; page split into `store/` part files (≤ 500 lines each); menu rows flag multi-photo dishes |
| C026 | Chi tiết món & tùy chọn | `/customer/food/stores/:storeId/items/:itemId` | LIVE | Real option groups/prices (DEC-PROD-033); dish photo gallery with counter; cart bar above the add button when the cart has items (DEC-PROD-068) |
```

- [ ] **Step 2: Mark the spec phase**

Change the front matter line to:

```yaml
status: "P1_IMPLEMENTED"
```

- [ ] **Step 3: Commit**

```bash
git add docs/10-ai-execution/screen-inventory.md \
  docs/superpowers/specs/2026-11-03-food-customer-redesign-design.md
git commit -m "docs(food): record P1 delivery state"
```

---

## Plan Self-Review

**Spec coverage (P1 items only):**

| Spec item | Task |
|---|---|
| §4.1 six-tier typography | 1 |
| §4.2 density tokens | 1 |
| §4.4 `FoodStoreCard`, `FoodMetaLine` | 4 |
| §6.1 vertical feed, pagination, remove 8-store slice | 3, 5 |
| §6.2 search pagination | 6 |
| §6.3 category via server filter | 6 |
| §6.4 store page ≤ 500 lines/file | 8 |
| §6.5 dish gallery | 7 |
| §12 tests per block | 1–7 |
| §13 P1 phase gate | all tasks |
| §14.1, §14.4, §14.7, §14.8 | 5, 7, global constraints |

**Intentionally out of P1:** notes/utensils/upsell (P2), dish search endpoint, voucher wall, reorder, `closesAtToday`, tracking summary, goldens (P3/P4).

**Deviations from the spec, with reasons:**

1. **Global theme untouched.** The spec says text styles come from `TextTheme`; changing `bodyMedium` app-wide would move every non-Food screen. `DealGoType` holds the six roles, and a guard test keeps ad-hoc sizes out of the Food feature.
2. **`part` files instead of separate libraries.** The store widgets are private; making them public would enlarge the API for no consumer. `part` preserves encapsulation while satisfying the ≤ 500-line rule.
3. **No backend work in P1.** The server already accepts `page`, `limit`, `category` and returns `total`; P1 only stops the client from ignoring it.

**Type consistency check:** `FoodStorePageResult` is the only page type; `hasMore` is derived in one place; `FoodDiscoveryReady` carries `total/hasMore/isLoadingMore/loadMoreFailed`; `FoodFeedFooter` takes `FoodDiscoveryReady?`; `FoodStoreCardVariant` is used by discovery only.

## Execution Handoff

Plan saved to `docs/superpowers/plans/2026-11-03-food-customer-redesign-p1.md`.

Two execution options:

1. **Subagent-Driven (recommended)** — one fresh subagent per task, review between tasks.
2. **Inline Execution** — run the tasks in this session with checkpoints.
