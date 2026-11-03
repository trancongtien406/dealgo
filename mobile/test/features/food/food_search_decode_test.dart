import 'package:dealgo/core/network/api_exception.dart';
import 'package:dealgo/features/food/data/datasources/dio_food_remote_datasource.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
