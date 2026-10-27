import 'package:dealgo/core/realtime/fake_snapshot_realtime.dart';
import 'package:dealgo/core/realtime/snapshot_realtime.dart';
import 'package:dealgo/features/merchant/domain/repositories/merchant_orders_repository.dart';
import 'package:dealgo/features/merchant/domain/usecases/list_merchant_order_queue.dart';
import 'package:dealgo/features/merchant/presentation/cubit/merchant_queue_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

class _Repo implements MerchantOrdersRepository {
  int calls = 0;
  @override
  Future<List<Never>> listOrderQueue(String accessToken) async {
    calls++;
    return const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'empty queue still joins store room and reloads on new order hint',
    () async {
      final rt = FakeSnapshotRealtime();
      final repo = _Repo();
      final cubit = MerchantQueueCubit(
        listMerchantOrderQueue: ListMerchantOrderQueue(repo),
        realtime: rt,
        resolveStoreId: (_) async => 'store-1',
      );
      cubit.setTokenSource(() => 'tok');
      await cubit.load('tok');
      expect(rt.subscribed, contains('store:store-1'));
      expect(repo.calls, 1);

      rt.emitHint(
        SnapshotHint(
          aggregateType: 'FoodOrder',
          aggregateId: 'order-9',
          status: 'PLACED',
          revision: '1',
          occurredAt: '2026-10-24T00:00:00Z',
          storeId: 'store-1',
        ),
      );
      await pumpEventQueue();
      expect(repo.calls, 2);
      await cubit.close();
      await rt.dispose();
    },
  );

  test('store id lookup failure does not break the queue', () async {
    final rt = FakeSnapshotRealtime();
    final cubit = MerchantQueueCubit(
      listMerchantOrderQueue: ListMerchantOrderQueue(_Repo()),
      realtime: rt,
      resolveStoreId: (_) async => throw StateError('no store'),
    );
    cubit.setTokenSource(() => 'tok');
    await cubit.load('tok');
    expect(cubit.state, isA<MerchantQueueReady>());
    expect(rt.subscribed, isEmpty);
    await cubit.close();
  });
}
