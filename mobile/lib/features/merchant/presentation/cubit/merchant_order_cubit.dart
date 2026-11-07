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
    this.detail,
    this.loadingLines = false,
    this.busy = false,
    this.conflict = false,
    this.network = false,
    this.handoffDone = false,
    this.message,
    this.handoverCode,
    this.pendingChange,
    this.orderNote,
    this.utensils = true,
  });

  /// Full order detail fetched from the server.
  final FoodOrderDetail? detail;

  /// Whether lines/details are actively loading from the server.
  final bool loadingLines;

  /// Edit waiting for the customer; "ready" is blocked meanwhile.
  final FoodOrderChange? pendingChange;

  /// Customer note to the kitchen and courier; null = none.
  final String? orderNote;

  /// Whether the customer asked for cutlery.
  final bool utensils;

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
    FoodOrderDetail? detail,
    bool? loadingLines,
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
    String? orderNote,
    bool clearOrderNote = false,
    bool? utensils,
  }) {
    return MerchantOrderViewReady(
      order: order ?? this.order,
      kitchenLines: kitchenLines ?? this.kitchenLines,
      detail: detail ?? this.detail,
      loadingLines: loadingLines ?? this.loadingLines,
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
      orderNote: clearOrderNote ? null : (orderNote ?? this.orderNote),
      utensils: utensils ?? this.utensils,
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
  }) : super(
         MerchantOrderViewReady(
           order: order,
           kitchenLines: const [],
           loadingLines: true,
         ),
       );

  // t50u: no poll fallback. REST reload on open, store:{id} hint and socket
  // reconnect (SnapshotBinding), never on a timer.
  final SnapshotRealtime? realtime;
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

  void startAutoRefresh(String? Function() token) {
    _tokenSource = token;
    unawaited(_startStoreRealtime());
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
      },
    );
    _storeBinding = binding;
    await binding.start(accessToken: token);
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
      if (_ready.loadingLines) {
        emit(_ready.copyWith(loadingLines: false));
      }
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
      final order = MerchantQueueOrder(
        id: detail.id,
        storeId: detail.storeId ?? latest.order.storeId,
        status: detail.status,
        deliveryFareVnd: detail.deliveryFareVnd,
        subtotalVnd: detail.subtotalVnd,
        totalVnd: detail.totalVnd,
        dropoff: detail.dropoff.label.isNotEmpty
            ? detail.dropoff
            : latest.order.dropoff,
        lineCount: detail.lines.isNotEmpty
            ? detail.lines.length
            : latest.order.lineCount,
        createdAt: latest.order.createdAt,
        customerName: detail.customerName ?? latest.order.customerName,
        customerAvatarUrl:
            detail.customerAvatarUrl ?? latest.order.customerAvatarUrl,
        driverName: detail.driverName ?? latest.order.driverName,
        driverAvatarUrl:
            detail.driverAvatarUrl ?? latest.order.driverAvatarUrl,
      );
      if (changed) {
        queue.replace(order);
      }
      emit(
        latest.copyWith(
          order: order,
          detail: detail,
          loadingLines: false,
          kitchenLines: kitchenLinesFromDetail(detail),
          handoverCode: detail.handoverCode,
          clearHandoverCode: detail.handoverCode == null,
          pendingChange: detail.pendingChange,
          clearPendingChange: detail.pendingChange?.pending != true,
          orderNote: detail.note,
          clearOrderNote: detail.note == null,
          utensils: detail.utensils,
          handoffDone:
              latest.handoffDone || handedOverStatuses.contains(detail.status),
        ),
      );
    } catch (_) {
      if (!isClosed) {
        emit(_ready.copyWith(loadingLines: false));
      }
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
