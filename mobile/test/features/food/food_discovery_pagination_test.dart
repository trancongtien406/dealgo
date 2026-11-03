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
