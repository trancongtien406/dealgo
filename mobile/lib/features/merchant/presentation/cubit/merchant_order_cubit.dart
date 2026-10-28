import 'dart:async';

import '../../../../core/l10n/ui_message.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../utils/merchant_kitchen_lines.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/realtime/snapshot_binding.dart';
import '../../../../core/realtime/snapshot_realtime.dart';
import '../../../food/domain/entities/food_models.dart';
import '../../domain/params/merchant_order_action_params.dart';
import '../../domain/usecases/accept_merchant_order.dart';
import '../../domain/usecases/reject_merchant_order.dart';
import '../../domain/usecases/get_merchant_order.dart';
import '../../domain/usecases/mark_merchant_order_ready.dart';
import 'merchant_queue_cubit.dart';

sealed class MerchantOrderViewState {
  const MerchantOrderViewState();
}

final class MerchantOrderViewReady extends MerchantOrderViewState {
  const MerchantOrderViewReady({
    required this.order,
    required this.kitchenLines,
    this.busy = false,
    this.conflict = false,
    this.network = false,
    this.handoffDone = false,
    this.message,
    this.handoverCode,
    this.pendingChange,
  });

  /// Edit waiting for the customer; "ready" is blocked meanwhile.
  final FoodOrderChange? pendingChange;

  /// DEC-PROD-036: store-only code the driver enters at pickup (when the setting is on).
  final String? handoverCode;

  final MerchantQueueOrder order;
  final List<MerchantKitchenLine> kitchenLines;
  final bool busy;
  final bool conflict;
  final bool network;
  final bool handoffDone;
  final UiMessage? message;

  MerchantOrderViewReady copyWith({
    MerchantQueueOrder? order,
    List<MerchantKitchenLine>? kitchenLines,
    bool? busy,
    bool? conflict,
    bool? network,
    bool? handoffDone,
    UiMessage? message,
    bool clearMessage = false,
    String? handoverCode,
    bool clearHandoverCode = false,
    FoodOrderChange? pendingChange,
    bool clearPendingChange = false,
  }) {
    return MerchantOrderViewReady(
      order: order ?? this.order,
      kitchenLines: kitchenLines ?? this.kitchenLines,
      busy: busy ?? this.busy,
      conflict: conflict ?? this.conflict,
      network: network ?? this.network,
      handoffDone: handoffDone ?? this.handoffDone,
      message: clearMessage ? null : (message ?? this.message),
      handoverCode: clearHandoverCode
          ? null
          : (handoverCode ?? this.handoverCode),
      pendingChange: clearPendingChange
          ? null
          : (pendingChange ?? this.pendingChange),
    );
  }
}

class MerchantOrderCubit extends Cubit<MerchantOrderViewState> {
  MerchantOrderCubit({
    required this._getMerchantOrder,
    required this._acceptMerchantOrder,
    required this._markMerchantOrderReady,
    required this.queue,
    this._rejectMerchantOrder,
    required MerchantQueueOrder order,
    this.realtime,
    this.refreshInterval = const Duration(seconds: 10),
  }) : super(MerchantOrderViewReady(order: order, kitchenLines: const []));

  /// Poll fallback when the store socket is disconnected (DEC-PROD-041).
  final Duration refreshInterval;
  final SnapshotRealtime? realtime;
  Timer? _refreshTimer;
  SnapshotBinding? _storeBinding;
  String? Function()? _tokenSource;
  var _refreshing = false;

  /// Statuses where the next transition is made by another actor.
  static const awaitingStatuses = {
    'PLACED',
    'PREPARING',
    'READY',
    'READY_FOR_PICKUP',
  };

  bool get autoRefreshActive => _refreshTimer?.isActive ?? false;

  void startAutoRefresh(String? Function() token) {
    _tokenSource = token;
    unawaited(_startStoreRealtime());
    _syncAutoRefresh();
  }

  Future<void> _startStoreRealtime() async {
    final rt = realtime;
    final token = _tokenSource?.call()?.trim() ?? '';
    if (rt == null || token.isEmpty) return;
    await _storeBinding?.stop();
    final binding = SnapshotBinding(
      realtime: rt,
      room: StoreSnapshotRoom(_ready.order.storeId),
      onInvalidate: () {
        unawaited(_tick());
        _syncAutoRefresh();
      },
    );
    _storeBinding = binding;
    await binding.start(accessToken: token);
    _syncAutoRefresh();
  }

  void _syncAutoRefresh() {
    if (isClosed || _tokenSource == null) return;
    final waiting = awaitingStatuses.contains(_ready.order.status);
    // Poll only while waiting AND socket is down (or realtime not wired).
    final socketUp = realtime?.isConnected ?? false;
    final shouldPoll = waiting && !socketUp;
    if (shouldPoll && !autoRefreshActive) {
      _refreshTimer = Timer.periodic(refreshInterval, (_) => _tick());
    } else if (!shouldPoll) {
      _refreshTimer?.cancel();
      _refreshTimer = null;
    }
  }

  Future<void> _tick() async {
    final current = _ready;
    if (_refreshing || current.busy || current.conflict) return;
    _refreshing = true;
    try {
      await loadLines(_tokenSource?.call());
    } finally {
      _refreshing = false;
    }
  }

  @override
  Future<void> close() async {
    _refreshTimer?.cancel();
    await _storeBinding?.stop();
    _storeBinding = null;
    return super.close();
  }

  final RejectMerchantOrder? _rejectMerchantOrder;

  final GetMerchantOrder _getMerchantOrder;
  final AcceptMerchantOrder _acceptMerchantOrder;
  final MarkMerchantOrderReady _markMerchantOrderReady;
  final MerchantQueueCubit queue;

  MerchantOrderViewReady get _ready => state as MerchantOrderViewReady;

  Future<void> loadLines(String? accessToken) async {
    final token = accessToken?.trim() ?? '';
    if (token.isEmpty) {
      return;
    }
    final current = _ready;
    try {
      final detail = await _getMerchantOrder(
        MerchantOrderActionParams(
          accessToken: token,
          orderId: current.order.id,
        ),
      );
      if (isClosed) {
        return;
      }
      final latest = _ready;
      final changed = detail.status != latest.order.status;
      final order = changed
          ? latest.order.apply(
              MerchantOrderUpdate(id: latest.order.id, status: detail.status),
            )
          : latest.order;
      if (changed) {
        queue.replace(order);
      }
      emit(
        latest.copyWith(
          order: order,
          kitchenLines: kitchenLinesFromDetail(detail),
          handoverCode: detail.handoverCode,
          clearHandoverCode: detail.handoverCode == null,
          pendingChange: detail.pendingChange,
          clearPendingChange: detail.pendingChange?.pending != true,
          handoffDone:
              latest.handoffDone || handedOverStatuses.contains(detail.status),
        ),
      );
      _syncAutoRefresh();
    } catch (_) {
      // Queue summary remains; kitchen panel stays empty until retry.
    }
  }

  Future<void> accept(String? accessToken) {
    return _mutate(accessToken, _acceptMerchantOrder.call);
  }

  /// Declines the order on the server; true when it is now CANCELLED.
  Future<bool> reject(
    String? accessToken, {
    required FoodRejectReason reason,
    String? note,
  }) async {
    final reject = _rejectMerchantOrder;
    if (reject == null) return false;
    await _mutate(
      accessToken,
      (params) => reject(params, reason: reason, note: note),
    );
    return !isClosed && _ready.order.status == 'CANCELLED';
  }

  Future<void> markReady(String? accessToken) {
    return _mutate(accessToken, _markMerchantOrderReady.call);
  }

  /// After the store sent an edit: show it as pending right away, then refetch.
  Future<void> changeProposed(
    FoodOrderChange change,
    String? accessToken,
  ) async {
    emit(_ready.copyWith(pendingChange: change, clearMessage: true));
    await loadLines(accessToken);
  }

  /// Food has left the store once the driver confirmed pickup (DEC-PROD-036:
  /// ASSIGNED → PICKED_UP is the driver's call, with the handover code).
  static const handedOverStatuses = {'PICKED_UP', 'DELIVERING', 'DELIVERED'};

  /// QA M1 — "Đã bàn giao hàng" is never a local-only flag: re-read the order
  /// from the server and only mark it handed over when the driver's pickup is
  /// recorded; otherwise explain that the driver confirms with the code.
  Future<void> confirmHandoff(String? accessToken) async {
    final token = accessToken?.trim() ?? '';
    if (token.isEmpty || _ready.busy) return;
    emit(_ready.copyWith(busy: true, clearMessage: true));
    await loadLines(token);
    if (isClosed) return;
    final done = handedOverStatuses.contains(_ready.order.status);
    emit(
      _ready.copyWith(
        busy: false,
        handoffDone: done,
        message: done
            ? null
            : UiMessage((l10n) => l10n.merchantHandoffAwaitDriver),
      ),
    );
  }

  Future<void> reload(String? accessToken) async {
    await queue.load(accessToken);
    if (isClosed) {
      return;
    }
    final fresh = merchantOrderFrom(queue.state, _ready.order.id);
    if (fresh == null) {
      emit(_ready.copyWith(network: false, conflict: true));
      return;
    }
    emit(
      _ready.copyWith(
        order: fresh,
        network: false,
        conflict: false,
        clearMessage: true,
      ),
    );
    await loadLines(accessToken);
  }

  void clearNetworkBanner() {
    emit(_ready.copyWith(network: false));
  }

  Future<void> _mutate(
    String? accessToken,
    Future<MerchantOrderUpdate> Function(MerchantOrderActionParams params) send,
  ) async {
    final current = _ready;
    if (current.busy || current.conflict || current.network) {
      return;
    }
    final token = accessToken?.trim() ?? '';
    if (token.isEmpty) {
      emit(
        current.copyWith(
          message: UiMessage((l10n) => l10n.errorSessionExpired),
        ),
      );
      return;
    }
    emit(current.copyWith(busy: true, clearMessage: true));
    try {
      final update = await send(
        MerchantOrderActionParams(
          accessToken: token,
          orderId: current.order.id,
        ),
      );
      if (isClosed) {
        return;
      }
      if (update.id != current.order.id) {
        emit(current.copyWith(busy: false, conflict: true));
        return;
      }
      final next = current.order.apply(update);
      queue.replace(next);
      emit(current.copyWith(order: next, busy: false));
      _syncAutoRefresh();
    } on ApiException catch (error) {
      if (isClosed) {
        return;
      }
      if (_merchantOrderMissing(error)) {
        emit(current.copyWith(busy: false, conflict: true, clearMessage: true));
        return;
      }
      if (_merchantNetworkFailure(error)) {
        emit(current.copyWith(busy: false, network: true, clearMessage: true));
        return;
      }
      emit(current.copyWith(busy: false, message: UiMessage.error(error)));
    } catch (_) {
      if (isClosed) {
        return;
      }
      emit(current.copyWith(busy: false, network: true, clearMessage: true));
    }
  }
}

bool _merchantOrderMissing(ApiException error) {
  return error.statusCode == 404 ||
      error.statusCode == 409 ||
      error.errorCode == 'ORDER_NOT_FOUND';
}

bool _merchantNetworkFailure(ApiException error) {
  return error.statusCode == 0 || error.errorCode == 'NETWORK_ERROR';
}
