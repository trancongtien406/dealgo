import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/request_failure.dart';
import '../../../../core/realtime/snapshot_binding.dart';
import '../../../../core/realtime/snapshot_realtime.dart';
import '../../../food/domain/entities/food_models.dart';
import '../../domain/params/merchant_order_action_params.dart';
import '../../domain/usecases/accept_merchant_order.dart';
import '../../domain/usecases/list_merchant_order_queue.dart';
import '../../domain/usecases/mark_merchant_order_ready.dart';

sealed class MerchantQueueState {
  const MerchantQueueState();
}

final class MerchantQueueLoading extends MerchantQueueState {
  const MerchantQueueLoading();
}

final class MerchantQueueReady extends MerchantQueueState {
  const MerchantQueueReady(this.orders, {this.busyIds = const {}});

  final List<MerchantQueueOrder> orders;

  /// Orders with a quick action (accept / ready) in flight.
  final Set<String> busyIds;
}

/// Next one-tap step for an order in the list: PLACED -> accept, PREPARING -> ready.
enum MerchantQuickAction { accept, ready }

MerchantQuickAction? merchantQuickActionFor(MerchantQueueOrder order) =>
    switch (order.status) {
      'PLACED' => MerchantQuickAction.accept,
      'PREPARING' => MerchantQuickAction.ready,
      _ => null,
    };

/// Statuses that leave the "to handle" list (they live in history instead).
const merchantQueueClosedStatuses = {'CANCELLED', 'DELIVERED', 'FAILED'};

/// Only orders the store still has to act on or follow.
List<MerchantQueueOrder> merchantQueueToHandle(
  Iterable<MerchantQueueOrder> orders,
) => List.unmodifiable(
  orders.where((o) => !merchantQueueClosedStatuses.contains(o.status)),
);

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
    required this._listMerchantOrderQueue,
    this.realtime,
    this.acceptMerchantOrder,
    this.markMerchantOrderReady,
    this.resolveStoreId,
    this.onNewOrders,
    String? Function()? tokenSource,
  }) : super(const MerchantQueueLoading()) {
    _tokenSource = tokenSource;
  }

  // t50u: no periodic poll. The queue reloads over REST only on load,
  // foreground resume, a store:{id} socket hint and socket reconnect
  // (SnapshotBinding re-fetches on every reconnect).

  final ListMerchantOrderQueue _listMerchantOrderQueue;
  final AcceptMerchantOrder? acceptMerchantOrder;
  final MarkMerchantOrderReady? markMerchantOrderReady;
  final SnapshotRealtime? realtime;

  /// Looks up the merchant's own store id so an empty queue still joins
  /// store:{id} and sees the first new order without a manual reload.
  final Future<String?> Function(String accessToken)? resolveStoreId;

  /// A reload found PLACED orders the store had not seen yet (not on the first load):
  /// the app plays the "quán có đơn mới" alert (debounced with the push).
  final void Function()? onNewOrders;
  Set<String>? _seenPlacedIds;
  var _generation = 0;
  DateTime? _syncedAt;
  SnapshotBinding? _storeBinding;
  String? _boundStoreId;
  String? Function()? _tokenSource;

  void setTokenSource(String? Function() tokenSource) {
    _tokenSource = tokenSource;
  }

  /// Silent refetch (foreground resume, socket hint, reconnect): keeps the list on
  /// screen instead of flashing the loading view.
  Future<void> refresh() async {
    final source = _tokenSource;
    if (source == null || isClosed) return;
    final token = source();
    if (token == null || token.isEmpty) return;
    await load(token, silent: true);
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
    // Home + list both bind the same store: re-joining would unsubscribe the
    // live room mid-flight, so keep the existing binding.
    if (_storeBinding != null && _boundStoreId == storeId) return;
    await _storeBinding?.stop();
    _boundStoreId = storeId;
    final binding = SnapshotBinding(
      realtime: rt,
      room: StoreSnapshotRoom(storeId),
      onInvalidate: () {
        unawaited(load(tokenSource(), silent: true));
      },
    );
    _storeBinding = binding;
    await binding.start(accessToken: token);
    // Close the gap between the first GET and the join: an order placed in
    // between produced its snapshot before we were in the room.
    if (!isClosed && identical(_storeBinding, binding)) {
      unawaited(load(tokenSource(), silent: true));
    }
  }

  Future<void> load(String? accessToken, {bool silent = false}) async {
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
    if (!silent || state is! MerchantQueueReady) {
      emit(const MerchantQueueLoading());
    }
    try {
      final queue = await _listMerchantOrderQueue(token);
      if (isClosed || generation != _generation) {
        return;
      }
      _syncedAt = DateTime.now();
      emit(MerchantQueueReady(merchantQueueToHandle(queue)));
      _noticeNewOrders(queue);
      if (_storeBinding == null && _tokenSource != null) {
        String? storeId = queue.isNotEmpty ? queue.first.storeId : null;
        if (storeId == null && resolveStoreId != null) {
          try {
            storeId = await resolveStoreId!(token);
          } catch (_) {
            storeId = null;
          }
        }
        if (storeId != null && storeId.isNotEmpty && !isClosed) {
          await listenStore(storeId: storeId, tokenSource: _tokenSource!);
        }
      }
    } on ApiException catch (error) {
      if (isClosed || generation != _generation) {
        return;
      }
      if (error.statusCode == 403 && error.errorCode == 'ROLE_NOT_ACTIVE') {
        emit(const MerchantQueueIneligible());
        return;
      }
      // A background refetch never replaces a good list with an error.
      if (silent && state is MerchantQueueReady) return;
      emit(
        MerchantQueueFailed(saved: saved, syncedAt: _syncedAt, cause: error),
      );
    } catch (error) {
      if (isClosed || generation != _generation) {
        return;
      }
      // A background refetch never replaces a good list with an error.
      if (silent && state is MerchantQueueReady) return;
      emit(
        MerchantQueueFailed(saved: saved, syncedAt: _syncedAt, cause: error),
      );
    }
  }

  void _noticeNewOrders(List<MerchantQueueOrder> queue) {
    final placed = {
      for (final o in queue)
        if (o.status == 'PLACED') o.id,
    };
    final seen = _seenPlacedIds;
    _seenPlacedIds = {...?seen, ...placed};
    if (seen != null && placed.any((id) => !seen.contains(id))) {
      onNewOrders?.call();
    }
  }

  void replace(MerchantQueueOrder order) {
    final current = state;
    if (current is! MerchantQueueReady) {
      return;
    }
    emit(
      MerchantQueueReady(
        merchantQueueToHandle([
          for (final item in current.orders)
            if (item.id == order.id) order else item,
        ]),
        busyIds: current.busyIds,
      ),
    );
  }

  /// One-tap accept/ready from the list (same server calls as the order page).
  /// Returns false when nothing was sent or the server refused; state is then reloaded.
  Future<bool> runQuickAction(
    String? accessToken,
    MerchantQueueOrder order,
  ) async {
    final action = merchantQuickActionFor(order);
    final current = state;
    final token = accessToken?.trim() ?? '';
    if (action == null ||
        current is! MerchantQueueReady ||
        current.busyIds.contains(order.id) ||
        token.isEmpty) {
      return false;
    }
    final send = switch (action) {
      MerchantQuickAction.accept => acceptMerchantOrder?.call,
      MerchantQuickAction.ready => markMerchantOrderReady?.call,
    };
    if (send == null) return false;
    _setBusy(order.id, true);
    try {
      final update = await send(
        MerchantOrderActionParams(accessToken: token, orderId: order.id),
      );
      if (isClosed) return false;
      _setBusy(order.id, false);
      if (update.id != order.id) return false;
      replace(order.apply(update));
      return true;
    } catch (_) {
      if (isClosed) return false;
      _setBusy(order.id, false);
      // Conflict / stale status: refresh from the server rather than guess.
      await load(token);
      return false;
    }
  }

  void _setBusy(String id, bool busy) {
    final current = state;
    if (current is! MerchantQueueReady) return;
    final ids = {...current.busyIds};
    busy ? ids.add(id) : ids.remove(id);
    emit(MerchantQueueReady(current.orders, busyIds: Set.unmodifiable(ids)));
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
