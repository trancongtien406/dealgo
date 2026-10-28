import 'package:dealgo/features/food/domain/entities/food_models.dart';
import 'package:dealgo/features/merchant/domain/repositories/merchant_orders_repository.dart';
import 'package:dealgo/features/merchant/domain/usecases/accept_merchant_order.dart';
import 'package:dealgo/features/merchant/domain/usecases/get_merchant_order.dart';
import 'package:dealgo/features/merchant/domain/usecases/list_merchant_order_queue.dart';
import 'package:dealgo/features/merchant/domain/usecases/mark_merchant_order_ready.dart';
import 'package:dealgo/features/merchant/presentation/cubit/merchant_order_cubit.dart';
import 'package:dealgo/features/merchant/presentation/cubit/merchant_queue_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

const _drop = FoodDropoff(lat: 16.06, lng: 108.22, label: 'x');

class _Repo implements MerchantOrdersRepository {
  _Repo(this.status);
  String status;
  int gets = 0;

  @override
  Future<FoodOrderDetail> getOrder({
    required String accessToken,
    required String orderId,
  }) async {
    gets++;
    return FoodOrderDetail(
      id: orderId,
      status: status,
      subtotalVnd: 1,
      deliveryFareVnd: 1,
      totalVnd: 2,
      dropoff: _drop,
      lines: const [],
    );
  }

  @override
  Future<List<MerchantQueueOrder>> listOrderQueue(String accessToken) async =>
      const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

MerchantOrderCubit _cubit(_Repo repo) => MerchantOrderCubit(
  getMerchantOrder: GetMerchantOrder(repo),
  acceptMerchantOrder: AcceptMerchantOrder(repo),
  markMerchantOrderReady: MarkMerchantOrderReady(repo),
  queue: MerchantQueueCubit(
    listMerchantOrderQueue: ListMerchantOrderQueue(repo),
    pollInterval: Duration.zero,
  ),
  order: const MerchantQueueOrder(
    id: 'o1',
    storeId: 's1',
    status: 'ASSIGNED',
    deliveryFareVnd: 1,
    subtotalVnd: 1,
    totalVnd: 2,
    dropoff: _drop,
    lineCount: 1,
    createdAt: '2026-10-28T00:00:00Z',
  ),
  refreshInterval: Duration.zero,
);

void main() {
  test(
    'QA M1: handoff is not marked until the server shows driver pickup',
    () async {
      final repo = _Repo('ASSIGNED');
      final cubit = _cubit(repo);
      await cubit.confirmHandoff('tok');
      var s = cubit.state as MerchantOrderViewReady;
      expect(repo.gets, 1, reason: 'reads the order from the API');
      expect(s.handoffDone, isFalse);
      expect(s.message, isNotNull);
      expect(s.busy, isFalse);

      repo.status = 'PICKED_UP';
      await cubit.confirmHandoff('tok');
      s = cubit.state as MerchantOrderViewReady;
      expect(s.handoffDone, isTrue);
      expect(s.order.status, 'PICKED_UP');
      await cubit.close();
    },
  );
}
