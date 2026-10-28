import 'package:dealgo/features/food/data/food_category_remote_datasource.dart';
import 'package:dealgo/features/food/domain/entities/food_category.dart';
import 'package:dealgo/features/food/presentation/food_categories_store.dart';
import 'package:flutter_test/flutter_test.dart';

const _tea = FoodCategory(
  code: 'tea',
  nameVi: 'Trà sữa',
  nameEn: 'Milk tea',
  icon: 'cup-soda',
  tone: 'pink',
);

void main() {
  test('decodes the public payload, skipping malformed rows', () {
    final items = decodeFoodCategories({
      'items': [
        {
          'code': 'pho',
          'nameVi': 'Phở',
          'nameEn': '',
          'icon': 'soup',
          'tone': 'orange',
          'imageUrl': '/v1/public/food-categories/images/pho/a.png',
        },
        {'nameVi': 'no code'},
        'junk',
      ],
    });
    expect(items, hasLength(1));
    expect(items.single.nameEn, 'Phở', reason: 'blank English falls back');
    expect(items.single.imageUrl, isNotNull);
    expect(FoodCategory.fromJson(items.single.toJson()), items.single);
  });

  test('cache first, then the network replaces it and is cached', () async {
    final cache = MemoryFoodCategoriesCache([_tea]);
    final repo = FakeFoodCategoryRepository();
    final store = FoodCategoriesStore(repo.list, cache: cache);
    final seen = <int>[];
    store.addListener(() => seen.add(store.items.length));

    await store.load();
    expect(seen, [1, 9], reason: 'cached tile draws before the fetch');
    expect(store.status, FoodCategoriesStatus.ready);
    expect(cache.value, hasLength(9));
    expect(store.byCode('TEA')?.nameVi, 'Trà sữa');
  });

  test('network failure keeps the cached list; no cache = failed', () async {
    final cached = FoodCategoriesStore(
      FakeFoodCategoryRepository(error: Exception('offline')).list,
      cache: MemoryFoodCategoriesCache([_tea]),
    );
    await cached.load();
    expect(cached.status, FoodCategoriesStatus.ready);
    expect(cached.items, [_tea]);

    final empty = FoodCategoriesStore(
      FakeFoodCategoryRepository(error: Exception('offline')).list,
      cache: MemoryFoodCategoriesCache(),
    );
    await empty.load();
    expect(empty.status, FoodCategoriesStatus.failed);
    expect(empty.items, isEmpty);
  });

  test(
    'concurrent loads share one request; same data does not notify',
    () async {
      final repo = FakeFoodCategoryRepository();
      final store = FoodCategoriesStore(
        repo.list,
        cache: MemoryFoodCategoriesCache(),
      );
      await Future.wait([store.load(), store.load()]);
      expect(repo.calls, 1);
      var notified = 0;
      store.addListener(() => notified++);
      await store.load();
      expect(repo.calls, 2);
      expect(notified, 0);
    },
  );
}
