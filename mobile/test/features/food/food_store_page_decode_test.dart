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
