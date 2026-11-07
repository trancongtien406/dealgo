import 'package:dealgo/core/network/api_exception.dart';
import 'package:dealgo/core/realtime/fake_snapshot_realtime.dart';
import 'package:dealgo/features/active_job/data/active_job_snapshot_store.dart';
import 'package:dealgo/features/active_job/domain/active_job_snapshot.dart';
import 'package:dealgo/features/active_job/presentation/active_job_cache.dart';
import 'package:dealgo/features/food/domain/entities/food_models.dart';
import 'package:dealgo/features/food/domain/repositories/food_repository.dart';
import 'package:dealgo/features/food/domain/usecases/get_food_order.dart';
import 'package:dealgo/features/food/presentation/cubit/food_tracking_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    '404 order clears its matching offline snapshot and stops realtime',
    () async {
      const orderId = '30b21cb5-537c-4bbb-8694-ed99ff39da0a';
      final store = MemoryActiveJobSnapshotStore();
      final cache = ActiveJobCache(store: store)..bindUser('customer-1');
      await cache.recordJob(
        ActiveJobSnapshot(
          kind: ActiveJobKind.foodOrder,
          id: orderId,
          status: 'PLACED',
          savedAt: DateTime(2026, 11, 7),
          pickupLabel: 'Cửa hàng',
          dropoffLabel: 'Nhà',
          amountVnd: 100000,
        ),
        terminal: false,
        assignedDriverId: null,
      );
      final realtime = FakeSnapshotRealtime();
      final cubit = FoodTrackingCubit(
        getFoodOrder: GetFoodOrder(_MissingFoodRepository()),
        realtime: realtime,
        offlineCache: cache,
      );

      await cubit.start(orderId: orderId, accessToken: 'token');

      expect(cubit.state, isA<FoodTrackingMissing>());
      expect(await cache.lookup(), isNull);
      expect(realtime.subscribed, isEmpty);
      await cubit.close();
      await realtime.dispose();
    },
  );
}

class _MissingFoodRepository implements FoodRepository {
  @override
  Future<FoodOrderDetail> getOrder({
    required String accessToken,
    required String orderId,
  }) {
    throw const ApiException(
      statusCode: 404,
      message: 'Food order not found',
      errorCode: 'FOOD_ORDER_NOT_FOUND',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
