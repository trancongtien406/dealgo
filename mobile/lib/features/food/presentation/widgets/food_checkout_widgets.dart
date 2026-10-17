import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/components/dealgo_secondary_button.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../identity/domain/entities/auth_state.dart';
import '../../../identity/domain/phone_input.dart';
import '../../../identity/presentation/cubit/auth_cubit.dart';
import '../../domain/entities/food_models.dart';
import '../../domain/entities/food_money.dart';
import '../../domain/params/place_food_order_params.dart';
import '../cubit/food_cart_cubit.dart';
import 'food_widgets.dart';

class CheckoutBody extends StatelessWidget {
  const CheckoutBody({required this.phase, super.key});

  final CheckoutPhase phase;

  @override
  Widget build(BuildContext context) {
    return switch (phase) {
      CheckoutSubmitting(:final attempt) => _SubmittingBody(attempt: attempt),
      CheckoutOffline(:final attempt) => _OfflineBody(attempt: attempt),
      final CheckoutRepriced repriced => _RepricedBody(phase: repriced),
      CheckoutPlaced(:final order) => _Receipt(order: order, placed: true),
      CheckoutRejected(:final message) => _Receipt(notice: message),
      CheckoutEditing() => const _Receipt(),
    };
  }
}

class CheckoutActions extends StatelessWidget {
  const CheckoutActions({
    required this.phase,
    required this.busy,
    required this.onSubmit,
    required this.onAccept,
    required this.onRetry,
    super.key,
  });

  final CheckoutPhase phase;
  final bool busy;
  final Future<void> Function({bool retry}) onSubmit;
  final VoidCallback onAccept;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final child = switch (phase) {
      CheckoutEditing() ||
      CheckoutRejected() => _PlaceButton(onSubmit: onSubmit),
      CheckoutOffline() => _OfflineButtons(onRetry: onRetry),
      CheckoutRepriced(:final nextTotalVnd) => _RepriceButtons(
        label: 'Đồng ý ${formatVnd(nextTotalVnd)}',
        onAccept: onAccept,
      ),
      _ => null,
    };
    if (child == null || busy && phase is! CheckoutOffline) {
      return const SizedBox.shrink();
    }
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          DealGoDimensions.pageGutter,
          DealGoSpacing.s12,
          DealGoDimensions.pageGutter,
          DealGoSpacing.s12,
        ),
        child: child,
      ),
    );
  }
}

class _PlaceButton extends StatelessWidget {
  const _PlaceButton({required this.onSubmit});

  final Future<void> Function({bool retry}) onSubmit;

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<FoodCartCubit>().state;
    return DealGoPrimaryButton(
      key: const Key('food-place-order'),
      label: 'Đặt hàng · ${formatVnd(cart.previewTotalVnd)}',
      trailingIcon: Icons.arrow_forward,
      enabled: cart.canCheckout,
      onPressed: () => onSubmit(),
    );
  }
}

class _OfflineButtons extends StatelessWidget {
  const _OfflineButtons({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: DealGoSecondaryButton(
            label: 'Quay về giỏ hàng',
            onPressed: () => _leave(context),
          ),
        ),
        const SizedBox(width: DealGoSpacing.s12),
        Expanded(
          child: DealGoPrimaryButton(
            key: const Key('food-retry-order'),
            label: 'Thử đặt lại',
            onPressed: onRetry,
          ),
        ),
      ],
    );
  }
}

class _RepriceButtons extends StatelessWidget {
  const _RepriceButtons({required this.label, required this.onAccept});

  final String label;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: DealGoSecondaryButton(
            label: 'Quay lại giỏ',
            onPressed: () => _leave(context),
          ),
        ),
        const SizedBox(width: DealGoSpacing.s12),
        Expanded(
          child: DealGoPrimaryButton(label: label, onPressed: onAccept),
        ),
      ],
    );
  }
}

void _leave(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  }
}

class _Receipt extends StatelessWidget {
  const _Receipt({this.order, this.notice, this.placed = false});

  final PlacedFoodOrder? order;
  final String? notice;
  final bool placed;

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<FoodCartCubit>().state;
    final subtotal = order?.subtotalVnd ?? cart.subtotalVnd;
    final delivery = order?.deliveryFareVnd ?? cart.deliveryFareVnd;
    final total = order?.totalVnd ?? cart.previewTotalVnd;
    final lines = order == null
        ? [
            for (final line in cart.lines)
              (
                name: line.name,
                quantity: line.quantity,
                unit: line.unitPriceVnd,
                total: line.lineTotalVnd,
              ),
          ]
        : [
            for (final line in order!.lines)
              (
                name: line.name,
                quantity: line.quantity,
                unit: line.unitPriceVnd,
                total: line.lineTotalVnd,
              ),
          ];
    final shownLines = lines.isEmpty && order == null ? lines : lines;
    final textTheme = Theme.of(context).textTheme;
    final profile = context.watch<AuthCubit>().state;
    final phone = profile is AuthSignedIn ? profile.profile.phone : null;
    final recipient = phone == null ? 'Người nhận' : formatDisplayPhone(phone);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        DealGoDimensions.pageGutter,
        DealGoSpacing.s8,
        DealGoDimensions.pageGutter,
        DealGoSpacing.s24,
      ),
      children: [
        if (notice != null) ...[
          FoodNote(message: notice!, tone: FoodNoteTone.danger),
          const SizedBox(height: DealGoSpacing.s16),
        ],
        FoodPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Người nhận và địa chỉ', style: textTheme.titleMedium),
              const SizedBox(height: DealGoSpacing.s12),
              Row(
                children: [
                  const CircleAvatar(
                    radius: 20,
                    backgroundColor: DealGoColors.subtlePurple,
                    child: Icon(Icons.person, color: DealGoColors.primary),
                  ),
                  const SizedBox(width: DealGoSpacing.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          recipient,
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: DealGoColors.text,
                          ),
                        ),
                        Text(cart.dropoffLabel, style: textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: DealGoSpacing.s16),
        FoodPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Danh sách món', style: textTheme.titleMedium),
              if ((cart.storeName ?? '').isNotEmpty) ...[
                const SizedBox(height: DealGoSpacing.s8),
                Text(
                  cart.storeName!,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: DealGoColors.text,
                  ),
                ),
              ],
              for (final line in shownLines)
                FoodLineSummary(
                  name: line.name,
                  quantity: line.quantity,
                  unitPriceVnd: line.unit,
                  lineTotalVnd: line.total,
                ),
            ],
          ),
        ),
        const SizedBox(height: DealGoSpacing.s16),
        FoodPanel(
          color: DealGoColors.subtlePurple,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tổng thanh toán', style: textTheme.titleMedium),
              const SizedBox(height: DealGoSpacing.s8),
              FoodMoneyRow(label: 'Tiền món', amount: formatVnd(subtotal)),
              FoodMoneyRow(label: 'Phí giao', amount: formatVnd(delivery)),
              const FoodMoneyRow(label: 'Giảm giá', amount: '0đ'),
              const Divider(height: 24),
              FoodMoneyRow(
                label: 'Tổng COD',
                amount: formatVnd(total),
                emphasize: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: DealGoSpacing.s16),
        FoodPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Thanh toán', style: textTheme.titleMedium),
              const SizedBox(height: DealGoSpacing.s8),
              const DecoratedBox(
                decoration: BoxDecoration(
                  color: DealGoColors.amberSurface,
                  borderRadius: BorderRadius.all(Radius.circular(999)),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: DealGoSpacing.s12,
                    vertical: DealGoSpacing.s4,
                  ),
                  child: Text(
                    'COD · Chưa thu tiền',
                    style: TextStyle(
                      color: DealGoColors.warning,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: DealGoSpacing.s8),
              Text(
                placed
                    ? 'Máy chủ đã ghi nhận đơn. Chưa thu COD.'
                    : 'Không ghi thanh toán thành công tại bước đặt đơn.',
                style: textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SubmittingBody extends StatelessWidget {
  const _SubmittingBody({required this.attempt});

  final CheckoutHeldAttempt attempt;

  @override
  Widget build(BuildContext context) {
    final preview = attempt.previewTotalVnd;
    return ListView(
      padding: const EdgeInsets.all(DealGoDimensions.pageGutter),
      children: [
        const SizedBox(height: DealGoSpacing.s24),
        const Center(
          child: FoodStateIcon(
            icon: Icons.more_horiz,
            background: Color(0xFFE8F1FF),
            foreground: Color(0xFF2563EB),
          ),
        ),
        const SizedBox(height: DealGoSpacing.s16),
        Text(
          'Đơn đang được xử lý',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: DealGoSpacing.s8),
        Text(
          'Đã gửi yêu cầu tạo đơn; đang chờ máy chủ xác nhận kết quả. Vui lòng không đặt lại.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: DealGoSpacing.s16),
        FoodPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Yêu cầu đang chờ',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: DealGoSpacing.s8),
              const DecoratedBox(
                decoration: BoxDecoration(
                  color: DealGoColors.amberSurface,
                  borderRadius: BorderRadius.all(Radius.circular(999)),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: DealGoSpacing.s8,
                    vertical: DealGoSpacing.s4,
                  ),
                  child: Text(
                    'PROCESSING',
                    style: TextStyle(
                      color: DealGoColors.warning,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: DealGoSpacing.s12),
              FoodMoneyRow(label: 'Giỏ hàng', amount: _draftCode(attempt)),
              FoodMoneyRow(
                label: 'Số tiền dự kiến',
                amount: formatVnd(preview),
              ),
            ],
          ),
        ),
        const SizedBox(height: DealGoSpacing.s16),
        const FoodNote(
          tone: FoodNoteTone.amber,
          message: 'Nút đặt hàng được khóa tạm thời. Retry tự động phải cùng idempotency key.',
        ),
      ],
    );
  }
}

class _OfflineBody extends StatelessWidget {
  const _OfflineBody({required this.attempt});

  final CheckoutHeldAttempt attempt;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(DealGoDimensions.pageGutter),
      children: [
        const SizedBox(height: DealGoSpacing.s24),
        const Center(
          child: FoodStateIcon(
            icon: Icons.wifi_off,
            background: DealGoColors.dangerSurface,
            foreground: DealGoColors.danger,
          ),
        ),
        const SizedBox(height: DealGoSpacing.s16),
        Text(
          'Bạn đang ngoại tuyến',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: DealGoSpacing.s8),
        Text(
          'Chưa thể gửi đơn đến hệ thống. Giỏ hàng vẫn được giữ trên thiết bị.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: DealGoSpacing.s16),
        FoodPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Giỏ hàng chưa gửi',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: DealGoSpacing.s8),
              FoodMoneyRow(label: 'Giỏ hàng', amount: _draftCode(attempt)),
              FoodMoneyRow(
                label: 'Tổng dự kiến',
                amount: formatVnd(attempt.previewTotalVnd),
                emphasize: true,
              ),
              const FoodMoneyRow(label: 'Thanh toán', amount: 'COD · Chưa thu'),
            ],
          ),
        ),
        const SizedBox(height: DealGoSpacing.s16),
        const FoodNote(
          tone: FoodNoteTone.amber,
          message: 'Không hiển thị mã đơn chính thức và không tạo đơn cho tới khi máy chủ xác nhận.',
        ),
      ],
    );
  }
}

class _RepricedBody extends StatelessWidget {
  const _RepricedBody({required this.phase});

  final CheckoutRepriced phase;

  @override
  Widget build(BuildContext context) {
    final order = phase.order;
    final previousFare = phase.previousTotalVnd - phase.previousSubtotalVnd;
    final fareDelta = order == null ? 0 : order.deliveryFareVnd - previousFare;
    final serverSubtotal = order?.subtotalVnd;
    final serverDelivery = order?.deliveryFareVnd;
    final serverTotal = phase.nextTotalVnd;
    return ListView(
      padding: const EdgeInsets.all(DealGoDimensions.pageGutter),
      children: [
        const SizedBox(height: DealGoSpacing.s24),
        const Center(
          child: FoodStateIcon(
            icon: Icons.priority_high,
            background: DealGoColors.warningSurface,
            foreground: DealGoColors.warning,
          ),
        ),
        const SizedBox(height: DealGoSpacing.s16),
        Text(
          'Giá giỏ hàng đã thay đổi',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: DealGoSpacing.s8),
        Text(
          'Cửa hàng cập nhật giá hoặc phí giao, cần xác nhận lại tổng tiền trước khi gửi đơn.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: DealGoSpacing.s16),
        FoodPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Đối chiếu thay đổi',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: DealGoSpacing.s8),
              FoodMoneyRow(
                label: 'Tổng giá trước',
                amount: formatVnd(phase.previousTotalVnd),
              ),
              if (serverSubtotal != null)
                FoodMoneyRow(
                  label: 'Tiền món',
                  amount: formatVnd(serverSubtotal),
                ),
              if (serverDelivery != null && fareDelta != 0)
                FoodMoneyRow(
                  label: 'Phí giao tăng',
                  amount: formatVndDelta(fareDelta),
                )
              else if (serverDelivery != null)
                FoodMoneyRow(
                  label: 'Phí giao',
                  amount: formatVnd(serverDelivery),
                ),
              FoodMoneyRow(
                label: 'Tổng giá mới',
                amount: formatVnd(serverTotal),
                emphasize: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: DealGoSpacing.s16),
        FoodNote(
          tone: FoodNoteTone.amber,
          message: order == null
              ? 'Giỏ hàng là bản nháp; chỉ tạo đơn sau khi khách đồng ý phiên giá mới.'
              : 'Máy chủ đã ghi nhận đơn theo giá mới. Chưa thu COD.',
        ),
      ],
    );
  }
}

class CheckoutHeldAttempt {
  const CheckoutHeldAttempt({
    required this.request,
    required this.subtotalVnd,
    required this.previewTotalVnd,
    required this.storeName,
  });

  factory CheckoutHeldAttempt.fromCart(FoodCartState cart, String token) {
    final storeId = cart.storeId;
    if (storeId == null) {
      throw StateError('Cart has no store');
    }
    return CheckoutHeldAttempt(
      subtotalVnd: cart.subtotalVnd,
      previewTotalVnd: cart.previewTotalVnd,
      storeName: cart.storeName ?? 'Quán DealGo',
      request: PlaceFoodRequest(
        accessToken: token,
        idempotencyKey: cart.idempotencyKey,
        storeId: storeId,
        items: [
          for (final line in cart.lines)
            FoodOrderItem(itemId: line.placeItemId, quantity: line.quantity),
        ],
        dropoff: FoodDropoff(
          lat: cart.dropoffLat,
          lng: cart.dropoffLng,
          label: cart.dropoffLabel.trim(),
        ),
        deliveryFareVnd: cart.deliveryFareVnd,
      ),
    );
  }

  final PlaceFoodRequest request;
  final int subtotalVnd;
  final int previewTotalVnd;
  final String storeName;
}

int foodCatalogSubtotal(FoodCartState cart, FoodStoreDetail store) {
  final byId = {for (final item in store.items) item.id: item};
  var subtotal = 0;
  for (final line in cart.lines) {
    final item = byId[line.placeItemId];
    if (item != null && item.available) {
      subtotal += item.priceVnd * line.quantity;
    }
  }
  return subtotal;
}

CheckoutPhase checkoutFailurePhase(Object error, CheckoutHeldAttempt attempt) {
  if (_unreachable(error)) {
    return CheckoutOffline(attempt);
  }
  if (error is ApiException) {
    return CheckoutRejected(_messageFor(error));
  }
  return CheckoutOffline(attempt);
}

bool _unreachable(Object error) {
  if (error is ApiException) {
    return error.statusCode == 0 || error.errorCode == 'NETWORK_ERROR';
  }
  return true;
}

String _messageFor(ApiException error) {
  return switch (error.errorCode) {
    'FOOD_ORDER_ALREADY_OPEN' => 'Bạn đang có một đơn đồ ăn chưa kết thúc.',
    'FOOD_ITEM_UNAVAILABLE' => 'Một món vừa hết. Hãy chọn lại thực đơn.',
    'FOOD_DELIVERY_FARE_OUT_OF_RANGE' =>
      'Phí giao phải từ 5.000đ đến 100.000đ.',
    'FOOD_STORE_NOT_FOUND' => 'Không tìm thấy cửa hàng.',
    _ => 'Không gửi được đơn. Giỏ hàng vẫn còn trên máy.',
  };
}

String _draftCode(CheckoutHeldAttempt attempt) {
  final raw = attempt.request.idempotencyKey.replaceAll(
    RegExp(r'[^A-Za-z0-9]'),
    '',
  );
  final tail = raw.length >= 3
      ? raw.substring(raw.length - 3).toUpperCase()
      : '014';
  return 'CART-$tail';
}

sealed class CheckoutPhase {
  const CheckoutPhase();
}

class CheckoutEditing extends CheckoutPhase {
  const CheckoutEditing();
}

class CheckoutSubmitting extends CheckoutPhase {
  const CheckoutSubmitting(this.attempt);

  final CheckoutHeldAttempt attempt;
}

class CheckoutOffline extends CheckoutPhase {
  const CheckoutOffline(this.attempt);

  final CheckoutHeldAttempt attempt;
}

class CheckoutRepriced extends CheckoutPhase {
  const CheckoutRepriced({
    required this.previousTotalVnd,
    required this.previousSubtotalVnd,
    required this.nextTotalVnd,
    this.order,
    this.catalog,
  });

  final int previousTotalVnd;
  final int previousSubtotalVnd;
  final int nextTotalVnd;
  final PlacedFoodOrder? order;
  final FoodStoreDetail? catalog;
}

class CheckoutPlaced extends CheckoutPhase {
  const CheckoutPlaced(this.order);

  final PlacedFoodOrder order;
}

class CheckoutRejected extends CheckoutPhase {
  const CheckoutRejected(this.message);

  final String message;
}
