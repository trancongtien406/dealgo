import 'package:dealgo/features/activity/data/datasources/dio_history_remote_datasource.dart';
import 'package:dealgo/features/activity/domain/entities/history_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ride history amount includes the multi-stop wait fee', () {
    final items = decodeHistoryList({
      'success': true,
      'data': [
        {
          'id': 'r1',
          'status': 'COMPLETED',
          'agreedFareVnd': 36000,
          'waitFeeVnd': 3000,
          'dropoff': {'label': 'Cầu Rồng'},
          'createdAt': '2026-10-29T00:45:00Z',
        },
        {
          'id': 'r2',
          'status': 'COMPLETED',
          'agreedFareVnd': 20000,
          'dropoff': {'label': 'X'},
          'createdAt': '2026-10-29T00:45:00Z',
        },
      ],
    }, kind: HistoryKind.ride);
    expect(items.map((i) => i.amountVnd), [39000, 20000]);
  });
}
