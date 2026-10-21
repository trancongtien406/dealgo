import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/request_failure.dart';
import '../../../../core/realtime/snapshot_binding.dart';
import '../../../../core/realtime/snapshot_realtime.dart';
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
  const MerchantQueueFailed({
    required this.saved,
    required this.syncedAt,
    this.cause,
  });

  final List<MerchantQueueOrder> saved;
  final DateTime? syncedAt;
  final Object? cause;
}

class MerchantQueueCubit extends Cubit<MerchantQueueState> {
  MerchantQueueCubit({
    required ListMerchantOrderQueue listMerchantOrderQueue,
    this.realtime,
  }) : _listMerchantOrderQueue = listMerchantOrderQueue,
       super(const MerchantQueueLoading());

  final ListMerchantOrderQueue _listMerchantOrderQueue;
  final SnapshotRealtime? realtime;
  var _generation = 0;
  DateTime? _syncedAt;
  SnapshotBinding? _storeBinding;
  String? Function()? _tokenSource;

  void setTokenSource(String? Function() tokenSource) {
    _tokenSource = tokenSource;
  }

  /// Subscribe to store:{id} for new/status events; REST reload on each hint.
  Future<void> listenStore({
    required String storeId,
    required String? Function() tokenSource,
  }) async {
    _tokenSource = tokenSource;
    final rt = realtime;
    final token = tokenSource()?.trim() ?? '';
    if (rt == null || token.isEmpty || storeId.isEmpty) {
      return;
    }
    await _storeBinding?.stop();
    final binding = SnapshotBinding(
      realtime: rt,
      room: StoreSnapshotRoom(storeId),
      onInvalidate: () {
        unawaited(load(tokenSource()));
      },
    );
    _storeBinding = binding;
    await binding.start(accessToken: token);
  }

  Future<void> load(String? accessToken) async {
    final generation = ++_generation;
    final saved = _ordersOf(state);
    final token = accessToken?.trim() ?? '';
    if (token.isEmpty) {
      emit(
        MerchantQueueFailed(
          saved: saved,
          syncedAt: _syncedAt,
          cause: sessionExpiredFailure,
        ),
      );
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
      if (_storeBinding == null && queue.isNotEmpty && _tokenSource != null) {
        await listenStore(
          storeId: queue.first.storeId,
          tokenSource: _tokenSource!,
        );
      }
    } on ApiException catch (error) {
      if (isClosed || generation != _generation) {
        return;
      }
      if (error.statusCode == 403 && error.errorCode == 'ROLE_NOT_ACTIVE') {
        emit(const MerchantQueueIneligible());
        return;
      }
      emit(MerchantQueueFailed(saved: saved, syncedAt: _syncedAt, cause: error));
    } catch (error) {
      if (isClosed || generation != _generation) {
        return;
      }
      emit(MerchantQueueFailed(saved: saved, syncedAt: _syncedAt, cause: error));
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

  @override
  Future<void> close() async {
    await _storeBinding?.stop();
    _storeBinding = null;
    return super.close();
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
