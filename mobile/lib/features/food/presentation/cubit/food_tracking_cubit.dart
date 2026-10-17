import 'package:flutter_bloc/flutter_bloc.dart';

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
  const FoodTrackingOffline({this.order, this.busy = false});

  @override
  final FoodOrderDetail? order;

  @override
  final bool busy;
}

class FoodTrackingCubit extends Cubit<FoodTrackingState> {
  FoodTrackingCubit({
    required GetFoodOrder getFoodOrder,
    required this.realtime,
  }) : _getFoodOrder = getFoodOrder,
       super(const FoodTrackingLoading());

  final GetFoodOrder _getFoodOrder;
  final SnapshotRealtime realtime;

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
      emit(FoodTrackingOffline(order: state.order));
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
      final order = await _getFoodOrder(
        GetFoodOrderParams(accessToken: token, orderId: orderId),
      );
      if (isClosed) {
        return;
      }
      emit(FoodTrackingReady(order));
    } catch (_) {
      if (isClosed) {
        return;
      }
      emit(FoodTrackingOffline(order: previous));
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
