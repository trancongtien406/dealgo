import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/request_failure.dart';
import '../../../active_job/presentation/active_job_cache.dart';
import '../utils/food_offline_snapshot.dart';
import '../../../../core/realtime/snapshot_binding.dart';
import '../../../../core/realtime/snapshot_realtime.dart';
import '../../domain/entities/food_models.dart';
import '../../domain/params/get_food_order_params.dart';
import '../../domain/usecases/get_food_order.dart';

sealed class FoodTrackingState {
  const FoodTrackingState();

  FoodOrderDetail? get order;
  bool get busy;
}

final class FoodTrackingLoading extends FoodTrackingState {
  const FoodTrackingLoading({this.order, this.busy = true});

  @override
  final FoodOrderDetail? order;

  @override
  final bool busy;
}

final class FoodTrackingReady extends FoodTrackingState {
  const FoodTrackingReady(this.order, {this.busy = false});

  @override
  final FoodOrderDetail order;

  @override
  final bool busy;
}

final class FoodTrackingOffline extends FoodTrackingState {
  const FoodTrackingOffline({this.order, this.busy = false, this.cause});

  @override
  final FoodOrderDetail? order;

  @override
  final bool busy;

  final Object? cause;
}

/// The route points at an order that no longer exists for this customer.
final class FoodTrackingMissing extends FoodTrackingState {
  const FoodTrackingMissing();

  @override
  FoodOrderDetail? get order => null;

  @override
  bool get busy => false;
}

class FoodTrackingCubit extends Cubit<FoodTrackingState> {
  FoodTrackingCubit({
    required this.getFoodOrder,
    required this.realtime,
    this._offlineCache,
  }) : super(const FoodTrackingLoading());

  final GetFoodOrder getFoodOrder;
  final SnapshotRealtime realtime;
  final ActiveJobCache? _offlineCache;

  SnapshotBinding? _binding;
  String? _orderId;
  String? _accessToken;
  var _inFlight = false;

  Future<void> start({
    required String orderId,
    required String? accessToken,
  }) async {
    _orderId = orderId;
    _accessToken = accessToken;
    await refresh();
    if (state is FoodTrackingMissing) return;
    await _binding?.stop();
    final binding = SnapshotBinding(
      realtime: realtime,
      room: FoodSnapshotRoom(orderId),
      onInvalidate: () {
        refresh();
      },
    );
    _binding = binding;
    await binding.start(accessToken: accessToken);
  }

  Future<void> refresh() async {
    if (_inFlight) {
      return;
    }
    final orderId = _orderId;
    final token = _accessToken;
    if (orderId == null) {
      return;
    }
    if (token == null || token.isEmpty) {
      emit(
        FoodTrackingOffline(order: state.order, cause: sessionExpiredFailure),
      );
      return;
    }
    _inFlight = true;
    final previous = state.order;
    emit(
      previous == null
          ? const FoodTrackingLoading()
          : FoodTrackingReady(previous, busy: true),
    );
    try {
      final order = await getFoodOrder(
        GetFoodOrderParams(accessToken: token, orderId: orderId),
      );
      if (isClosed) {
        return;
      }
      emit(FoodTrackingReady(order));
      unawaited(
        _offlineCache?.recordJob(
          foodOfflineSnapshot(order),
          terminal: foodOrderEnded(order),
          assignedDriverId: order.assignedDriverId,
        ),
      );
    } catch (error) {
      if (isClosed) {
        return;
      }
      if (error is ApiException &&
          error.statusCode == 404 &&
          error.errorCode == 'FOOD_ORDER_NOT_FOUND') {
        await _offlineCache?.clearIfMatches(orderId);
        if (!isClosed) emit(const FoodTrackingMissing());
        return;
      }
      emit(FoodTrackingOffline(order: previous, cause: error));
    } finally {
      _inFlight = false;
    }
  }

  @override
  Future<void> close() async {
    await _binding?.stop();
    _binding = null;
    return super.close();
  }
}
