import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/mock/merchant_kitchen_lines.dart';
import '../../../../core/network/api_exception.dart';
import '../../../food/domain/entities/food_models.dart';
import '../../domain/params/merchant_order_action_params.dart';
import '../../domain/usecases/accept_merchant_order.dart';
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
  });

  final MerchantQueueOrder order;
  final List<MerchantKitchenLine> kitchenLines;
  final bool busy;
  final bool conflict;
  final bool network;
  final bool handoffDone;
  final String? message;

  MerchantOrderViewReady copyWith({
    MerchantQueueOrder? order,
    List<MerchantKitchenLine>? kitchenLines,
    bool? busy,
    bool? conflict,
    bool? network,
    bool? handoffDone,
    String? message,
    bool clearMessage = false,
  }) {
    return MerchantOrderViewReady(
      order: order ?? this.order,
      kitchenLines: kitchenLines ?? this.kitchenLines,
      busy: busy ?? this.busy,
      conflict: conflict ?? this.conflict,
      network: network ?? this.network,
      handoffDone: handoffDone ?? this.handoffDone,
      message: clearMessage ? null : (message ?? this.message),
    );
  }
}

class MerchantOrderCubit extends Cubit<MerchantOrderViewState> {
  MerchantOrderCubit({
    required GetMerchantOrder getMerchantOrder,
    required AcceptMerchantOrder acceptMerchantOrder,
    required MarkMerchantOrderReady markMerchantOrderReady,
    required this.queue,
    required MerchantQueueOrder order,
  }) : _getMerchantOrder = getMerchantOrder,
       _acceptMerchantOrder = acceptMerchantOrder,
       _markMerchantOrderReady = markMerchantOrderReady,
       super(MerchantOrderViewReady(order: order, kitchenLines: const []));

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
      emit(current.copyWith(kitchenLines: kitchenLinesFromDetail(detail)));
    } catch (_) {
      // Queue summary remains; kitchen panel stays empty until retry.
    }
  }

  Future<void> accept(String? accessToken) {
    return _mutate(accessToken, _acceptMerchantOrder);
  }

  Future<void> markReady(String? accessToken) {
    return _mutate(accessToken, _markMerchantOrderReady);
  }

  void markHandoffDone() {
    emit(_ready.copyWith(handoffDone: true));
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
      emit(current.copyWith(message: 'Phiên đăng nhập không còn hiệu lực'));
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
      emit(current.copyWith(busy: false, message: error.message));
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
