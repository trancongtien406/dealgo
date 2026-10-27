import 'package:dealgo/features/food/domain/entities/food_models.dart';
import 'package:dealgo/features/merchant/presentation/cubit/merchant_queue_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

MerchantQueueOrder _o(String id, String status) => MerchantQueueOrder(
  id: id,
  storeId: 's',
  status: status,
  deliveryFareVnd: 15000,
  subtotalVnd: 100000,
  totalVnd: 115000,
  dropoff: const FoodDropoff(lat: 16.07, lng: 108.22, label: 'x'),
  lineCount: 1,
  createdAt: '2026-10-25T00:00:00Z',
);

void main() {
  test('cancelled/delivered orders leave the to-handle list', () {
    final list = merchantQueueToHandle([
      _o('a', 'PLACED'),
      _o('b', 'CANCELLED'),
      _o('c', 'PREPARING'),
      _o('d', 'DELIVERED'),
    ]);
    expect(list.map((o) => o.id), ['a', 'c']);
  });
}
