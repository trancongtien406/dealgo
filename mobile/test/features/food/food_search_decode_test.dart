import 'dart:convert';
import 'dart:typed_data';

import 'package:dealgo/core/mock/fake_food_client.dart';
import 'package:dealgo/core/network/api_exception.dart';
import 'package:dealgo/features/food/data/datasources/dio_food_remote_datasource.dart';
import 'package:dealgo/features/food/domain/entities/food_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _SearchAdapter implements HttpClientAdapter {
  static const _searchPayload = {
    'dishes': {'items': <Object?>[], 'page': 1, 'limit': 20, 'total': 0},
    'stores': {'items': <Object?>[], 'page': 1, 'limit': 20, 'total': 0},
  };

  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode({'success': true, 'data': _searchPayload}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('decodes closesAtToday and dish search hits', () {
    final page = decodeFoodSearchResult({
      'dishes': {
        'items': [
          {
            'item': {
              'id': 'item-1',
              'name': 'Bún bò',
              'priceVnd': 45000,
              'originalPriceVnd': 55000,
              'imageUrl': null,
              'soldCount': 120,
              'prepMinutes': 15,
            },
            'store': {
              'id': 'store-1',
              'name': 'Bún Bò Huế',
              'distanceKm': 1.2,
              'etaMinutes': 25,
              'deliveryFeeFromVnd': 15000,
              'openNow': true,
              'closedReason': null,
            },
          },
        ],
        'page': 1,
        'limit': 20,
        'total': 1,
      },
      'stores': {'items': [], 'page': 1, 'limit': 20, 'total': 0},
    });
    expect(page.dishes.single.item.name, 'Bún bò');
    expect(page.dishes.single.item.priceVnd, 45000);
    expect(page.dishes.single.item.originalPriceVnd, 55000);
    expect(page.dishes.single.store.etaMinutes, 25);
    expect(page.dishes.single.store.deliveryFeeFromVnd, 15000);
    expect(page.dishes.single.store.openNow, isTrue);
    expect(page.storeTotal, 0);
  });

  test('reads a search response wrapped in the API envelope', () {
    final page = decodeFoodSearchResult({
      'success': true,
      'data': {
        'dishes': {'items': <Object?>[], 'page': 1, 'limit': 20, 'total': 3},
        'stores': {
          'items': [
            {'id': 'store-1', 'name': 'Bún Bò Huế', 'closesAtToday': '22:00'},
          ],
          'page': 1,
          'limit': 20,
          'total': 1,
        },
      },
    });
    expect(page.dishTotal, 3);
    expect(page.dishes, isEmpty);
    expect(page.stores.single.closesAtToday, '22:00');
  });

  test('keeps a midnight closing time and drops malformed ones', () {
    final page = decodeFoodSearchResult({
      'dishes': {'items': <Object?>[], 'total': 0},
      'stores': {
        'items': [
          {'id': 's1', 'name': 'Quán 1', 'closesAtToday': '00:00'},
          {'id': 's2', 'name': 'Quán 2', 'closesAtToday': '7:00'},
          {'id': 's3', 'name': 'Quán 3', 'closesAtToday': '22:00:00'},
          {'id': 's4', 'name': 'Quán 4', 'closesAtToday': 2200},
          {'id': 's5', 'name': 'Quán 5'},
        ],
        'total': 5,
      },
    });
    expect(
      [for (final store in page.stores) store.closesAtToday],
      ['00:00', null, null, null, null],
    );
  });

  test('decodes closesAtToday on a store detail', () {
    final detail = decodeFoodStoreDetail({
      'success': true,
      'data': {
        'id': 'store-1',
        'name': 'Bún Bò Huế',
        'closesAtToday': '21:30',
        'items': <Object?>[],
      },
    });
    expect(detail.closesAtToday, '21:30');

    final malformed = decodeFoodStoreDetail({
      'success': true,
      'data': {
        'id': 'store-1',
        'name': 'Bún Bò Huế',
        'closesAtToday': 'late',
        'items': <Object?>[],
      },
    });
    expect(malformed.closesAtToday, isNull);
  });

  test(
    'skips malformed dish hits and never reports fewer rows than received',
    () {
      final page = decodeFoodSearchResult({
        'dishes': {
          'items': [
            {
              'item': {'id': 'item-1', 'name': 'Bún bò', 'priceVnd': 45000},
              'store': {'id': 'store-1', 'name': 'Bún Bò Huế'},
            },
            {
              'item': {'id': 'item-2', 'name': 'Phở', 'priceVnd': 40000},
              'store': {'id': 'store-2', 'name': 'Phở Thìn'},
            },
            {
              'item': {'id': 'item-3'},
              'store': {'id': 'store-3', 'name': 'X'},
            },
            'not-a-map',
          ],
          'total': 1,
        },
        'stores': {
          'items': [
            {'id': 'store-1', 'name': 'Bún Bò Huế'},
            {'id': 'store-2', 'name': 'Phở Thìn'},
          ],
          'total': 0,
        },
      });
      expect(
        [for (final hit in page.dishes) hit.item.id],
        ['item-1', 'item-2'],
      );
      expect(page.dishTotal, 2);
      expect(page.storeTotal, 2);
    },
  );

  test('surfaces an error envelope instead of an empty page', () {
    expect(
      () => decodeFoodSearchResult({
        'success': false,
        'statusCode': 400,
        'message': 'q must be longer than or equal to 1 characters',
        'errorCode': 'VALIDATION_ERROR',
      }),
      throwsA(
        isA<ApiException>()
            .having((error) => error.errorCode, 'errorCode', 'VALIDATION_ERROR')
            .having((error) => error.statusCode, 'statusCode', 400),
      ),
    );
  });

  test('decodes same-store suggestions and ignores their extra fields', () {
    final suggestions = decodeFoodItemSuggestions({
      'success': true,
      'data': [
        {
          'id': 'item-9',
          'name': 'Chả giò',
          'priceVnd': 25000,
          'originalPriceVnd': null,
          'imageUrl': '/v1/public/menu-items/item-9/a.jpg',
          'soldCount': 30,
          'addedAt': '2026-10-01T03:00:00.000Z',
          'available': true,
          'menuCategoryId': 'cat-2',
        },
      ],
    });
    expect(suggestions.single.id, 'item-9');
    expect(suggestions.single.soldCount, 30);
    expect(suggestions.single.originalPriceVnd, isNull);
    expect(suggestions.single.imageUrl, '/v1/public/menu-items/item-9/a.jpg');
  });

  test('searchFood forwards sortBy only when the caller sets it', () async {
    final adapter = _SearchAdapter();
    final source = DioFoodRemoteDataSource(
      dio: Dio(BaseOptions(baseUrl: 'https://api.test'))
        ..httpClientAdapter = adapter,
    );

    await source.searchFood('tok', q: '  bún bò  ', lat: 16.05, lng: 108.2);
    await source.searchFood(
      'tok',
      q: 'bún bò',
      lat: 16.05,
      lng: 108.2,
      sortBy: 'rating',
    );

    final defaulted = adapter.requests.first.queryParameters;
    expect(defaulted.containsKey('sort_by'), isFalse);
    expect(defaulted['q'], 'bún bò');
    expect(defaulted['lat'], 16.05);
    expect(defaulted['lng'], 108.2);
    expect(adapter.requests.last.queryParameters['sort_by'], 'rating');
  });

  test('treats a search section without items as empty', () {
    final emptySections = decodeFoodSearchResult({
      'dishes': <String, Object?>{},
      'stores': <String, Object?>{},
    });
    expect(emptySections.dishes, isEmpty);
    expect(emptySections.stores, isEmpty);
    expect(emptySections.dishTotal, 0);
    expect(emptySections.storeTotal, 0);

    final absentSections = decodeFoodSearchResult(<String, Object?>{});
    expect(absentSections.dishes, isEmpty);
    expect(absentSections.stores, isEmpty);
    expect(absentSections.dishTotal, 0);
    expect(absentSections.storeTotal, 0);

    final missingTotals = decodeFoodSearchResult({
      'dishes': {
        'items': [
          {
            'item': {'id': 'item-1', 'name': 'Bún bò', 'priceVnd': 45000},
            'store': {'id': 'store-1', 'name': 'Bún Bò Huế'},
          },
        ],
      },
      'stores': {
        'items': [
          {'id': 'store-1', 'name': 'Bún Bò Huế'},
        ],
      },
    });
    expect(missingTotals.dishTotal, 1);
    expect(missingTotals.storeTotal, 1);
  });

  test('store list endpoints stay strict about a missing items array', () {
    expect(
      () => decodeFoodStoreList({
        'success': true,
        'data': {'total': 0},
      }),
      throwsA(
        isA<ApiException>().having(
          (error) => error.errorCode,
          'errorCode',
          'INVALID_RESPONSE',
        ),
      ),
    );
    expect(
      () => decodeFoodStorePage(
        {
          'success': true,
          'data': {'total': 0},
        },
        page: 1,
        limit: 20,
      ),
      throwsA(
        isA<ApiException>().having(
          (error) => error.errorCode,
          'errorCode',
          'INVALID_RESPONSE',
        ),
      ),
    );
  });

  test('fake search mirrors the datasource trimming and exclusions', () async {
    final fake = FakeFoodClient(
      suggestions: const [
        FoodFeaturedItem(id: 'item-9', name: 'Chả giò', priceVnd: 25000),
      ],
    );

    await fake.searchFood('tok', q: '  bún bò  ');
    expect(fake.searchQueries, ['bún bò']);

    final suggestions = await fake.listStoreSuggestions(
      'tok',
      'store-1',
      exclude: [' item-1 ', '', '   '],
    );
    expect(fake.suggestionCalls.single.exclude, ['item-1']);
    expect(suggestions.single.id, 'item-9');
    expect(
      () => suggestions.add(
        const FoodFeaturedItem(id: 'x', name: 'X', priceVnd: 1),
      ),
      throwsUnsupportedError,
    );
  });
}
