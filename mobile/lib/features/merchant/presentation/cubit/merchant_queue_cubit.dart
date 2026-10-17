import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_exception.dart';
import '../../../food/domain/entities/food_models.dart';
import '../../domain/usecases/list_merchant_order_queue.dart';

sealed class MerchantQueueState {
  const MerchantQueueState();
}

final class MerchantQueueLoading extends MerchantQueueState {
  const MerchantQueueLoading();
}

final class MerchantQueueReady extends MerchantQueueState {
  const MerchantQueueReady(this.orders);

  final List<MerchantQueueOrder> orders;
}

final class MerchantQueueIneligible extends MerchantQueueState {
  const MerchantQueueIneligible();
}

final class MerchantQueueFailed extends MerchantQueueState {
  const MerchantQueueFailed({required this.saved, required this.syncedAt});

  final List<MerchantQueueOrder> saved;
  final DateTime? syncedAt;
}

class MerchantQueueCubit extends Cubit<MerchantQueueState> {
  MerchantQueueCubit({required ListMerchantOrderQueue listMerchantOrderQueue})
    : _listMerchantOrderQueue = listMerchantOrderQueue,
      super(const MerchantQueueLoading());

  final ListMerchantOrderQueue _listMerchantOrderQueue;
  var _generation = 0;
  DateTime? _syncedAt;

  Future<void> load(String? accessToken) async {
    final generation = ++_generation;
    final saved = _ordersOf(state);
    final token = accessToken?.trim() ?? '';
    if (token.isEmpty) {
      emit(MerchantQueueFailed(saved: saved, syncedAt: _syncedAt));
      return;
    }
    emit(const MerchantQueueLoading());
    try {
      final queue = await _listMerchantOrderQueue(token);
      if (isClosed || generation != _generation) {
        return;
      }
      _syncedAt = DateTime.now();
      emit(MerchantQueueReady(List.unmodifiable(queue)));
    } on ApiException catch (error) {
      if (isClosed || generation != _generation) {
        return;
      }
      if (error.statusCode == 403 && error.errorCode == 'ROLE_NOT_ACTIVE') {
        emit(const MerchantQueueIneligible());
        return;
      }
      emit(MerchantQueueFailed(saved: saved, syncedAt: _syncedAt));
    } catch (_) {
      if (isClosed || generation != _generation) {
        return;
      }
      emit(MerchantQueueFailed(saved: saved, syncedAt: _syncedAt));
    }
  }

  void replace(MerchantQueueOrder order) {
    final current = state;
    if (current is! MerchantQueueReady) {
      return;
    }
    emit(
      MerchantQueueReady(
        List.unmodifiable([
          for (final item in current.orders)
            if (item.id == order.id) order else item,
        ]),
      ),
    );
  }
}

List<MerchantQueueOrder> _ordersOf(MerchantQueueState state) {
  return switch (state) {
    MerchantQueueReady(:final orders) => orders,
    MerchantQueueFailed(:final saved) => saved,
    _ => const [],
  };
}

MerchantQueueOrder? merchantOrderFrom(MerchantQueueState state, String id) {
  for (final order in _ordersOf(state)) {
    if (order.id == id) {
      return order;
    }
  }
  return null;
}
