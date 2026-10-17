import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/mock/merchant_kitchen_lines.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../food/domain/entities/food_models.dart';
import '../../../food/domain/entities/food_money.dart';
import '../../domain/usecases/accept_merchant_order.dart';
import '../../domain/usecases/get_merchant_order.dart';
import '../../domain/usecases/mark_merchant_order_ready.dart';
import '../cubit/merchant_order_cubit.dart';
import '../cubit/merchant_queue_cubit.dart';
import '../cubit/merchant_states.dart';
import '../widgets/merchant_widgets.dart';

class MerchantMissingOrderPage extends StatelessWidget {
  const MerchantMissingOrderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: MerchantPageFrame(
        title: 'Đơn hàng',
        insetBottom: true,
        body: Center(child: Text('Không tìm thấy đơn')),
      ),
    );
  }
}

class MerchantOrderPage extends StatelessWidget {
  const MerchantOrderPage({required this.order, super.key});

  final MerchantQueueOrder order;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => MerchantOrderCubit(
        getMerchantOrder: context.read<GetMerchantOrder>(),
        acceptMerchantOrder: context.read<AcceptMerchantOrder>(),
        markMerchantOrderReady: context.read<MarkMerchantOrderReady>(),
        queue: context.read<MerchantQueueCubit>(),
        order: order,
      )..loadLines(merchantAccessToken(context)),
      child: const _MerchantOrderView(),
    );
  }
}

class _MerchantOrderView extends StatelessWidget {
  const _MerchantOrderView();

  @override
  Widget build(BuildContext context) {
    final view = context.watch<MerchantOrderCubit>().state;
    if (view is! MerchantOrderViewReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final queue = context.watch<MerchantQueueCubit>().state;
    final cubit = context.read<MerchantOrderCubit>();
    if (view.network) {
      final saved = queue is MerchantQueueReady
          ? queue.orders
          : <MerchantQueueOrder>[view.order];
      final syncedAt = queue is MerchantQueueFailed ? queue.syncedAt : null;
      return Scaffold(
        body: MerchantQueueErrorView(
          saved: saved,
          syncedAt: syncedAt,
          onRetry: () {
            cubit.clearNetworkBanner();
            cubit.reload(merchantAccessToken(context));
          },
        ),
      );
    }
    if (view.conflict) {
      return Scaffold(
        body: _Conflict(
          order: view.order,
          onReload: () => cubit.reload(merchantAccessToken(context)),
        ),
      );
    }
    return Scaffold(
      body: _Detail(
        order: view.order,
        kitchenLines: view.kitchenLines,
        busy: view.busy,
        message: view.message,
        handoffDone: view.handoffDone,
        onAccept: () => cubit.accept(merchantAccessToken(context)),
        onReady: () => cubit.markReady(merchantAccessToken(context)),
        onHandoff: cubit.markHandoffDone,
      ),
    );
  }
}

String merchantHandoffCode(String orderId) {
  var hash = 0;
  for (final unit in orderId.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return '${(hash % 9000) + 1000}';
}

class _Detail extends StatelessWidget {
  const _Detail({
    required this.order,
    required this.kitchenLines,
    required this.busy,
    required this.message,
    required this.handoffDone,
    required this.onAccept,
    required this.onReady,
    required this.onHandoff,
  });

  final MerchantQueueOrder order;
  final List<MerchantKitchenLine> kitchenLines;
  final bool busy;
  final String? message;
  final bool handoffDone;
  final VoidCallback onAccept;
  final VoidCallback onReady;
  final VoidCallback onHandoff;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ready = order.status == 'READY' || order.status == 'READY_FOR_PICKUP';
    final preparing = order.status == 'PREPARING';
    final l10n = AppLocalizations.of(context);
    final isPlaced = order.status == 'PLACED';
    final title = switch (order.status) {
      'PLACED' => 'Chi tiết đơn mới',
      'PREPARING' => 'Đơn đang chuẩn bị',
      'READY' || 'READY_FOR_PICKUP' => 'Bàn giao cho tài xế',
      _ => 'Chi tiết đơn',
    };
    final lines = kitchenLines;
    final code = merchantHandoffCode(order.id);
    final Widget? footer;
    if (isPlaced) {
      footer = MerchantFooter(
        secondaryLabel: l10n.merchantRejectOrder,
        primaryLabel: l10n.merchantAcceptOrder,
        primaryKey: const Key('merchant-accept'),
        primaryEnabled: !busy,
        primaryLoading: busy,
        onSecondary: () => _confirmReject(context),
        onPrimary: onAccept,
      );
    } else if (preparing) {
      footer = MerchantPrimaryBar(
        label: 'Đã chuẩn bị xong',
        buttonKey: const Key('merchant-ready'),
        enabled: !busy,
        loading: busy,
        onPressed: onReady,
      );
    } else if (ready && !handoffDone) {
      footer = MerchantPrimaryBar(
        label: 'Đã bàn giao hàng',
        buttonKey: const Key('merchant-handoff'),
        enabled: !busy,
        loading: busy,
        onPressed: onHandoff,
      );
    } else {
      footer = null;
    }
    return MerchantPageFrame(
      title: title,
      insetBottom: true,
      onBack: () => merchantBack(context),
      footer: footer,
      body: ListView(
        padding: merchantPagePadding,
        children: [
          MerchantPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(switch (order.status) {
                  'PLACED' => 'Đơn chờ xác nhận',
                  'PREPARING' => 'Đơn đã nhận',
                  'READY' || 'READY_FOR_PICKUP' => 'Đơn đã sẵn sàng',
                  _ => 'Đơn của Shop',
                }, style: textTheme.titleMedium),
                const SizedBox(height: DealGoSpacing.s8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Đơn #${order.id}',
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const MerchantChip(
                      label: 'v1 · Dữ liệu đồng bộ',
                      tone: MerchantChipTone.neutral,
                    ),
                  ],
                ),
                if (isPlaced) ...[
                  const SizedBox(height: DealGoSpacing.s12),
                  Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: DealGoColors.subtlePurple,
                        child: Text(
                          'M',
                          style: TextStyle(
                            color: DealGoColors.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: DealGoSpacing.s12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Trần Thị Mai', style: textTheme.titleMedium),
                            Text(
                              order.dropoff.label,
                              style: textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: DealGoSpacing.s8),
                  const MerchantChip(
                    label: 'NEW · Chờ Shop xác nhận',
                    tone: MerchantChipTone.warning,
                  ),
                ] else ...[
                  const SizedBox(height: DealGoSpacing.s8),
                  Wrap(
                    spacing: DealGoSpacing.s8,
                    runSpacing: DealGoSpacing.s8,
                    children: [
                      MerchantChip(
                        label: ready ? 'READY_FOR_PICKUP' : order.status,
                        tone: merchantStatusTone(order.status),
                      ),
                      MerchantChip(
                        label: merchantStatusLabel(order.status),
                        tone: merchantStatusTone(order.status),
                      ),
                    ],
                  ),
                ],
                if (preparing) ...[
                  const SizedBox(height: DealGoSpacing.s12),
                  const MerchantMoneyRow(label: 'Giờ bắt đầu', value: '13:30'),
                  const MerchantMoneyRow(label: 'Dự kiến xong', value: '13:45'),
                ],
              ],
            ),
          ),
          if (isPlaced) ...[
            const SizedBox(height: DealGoSpacing.s12),
            MerchantPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.merchantOrderItemsTitle, style: textTheme.titleMedium),
                  for (final line in lines) ...[
                    const SizedBox(height: DealGoSpacing.s8),
                    Row(
                      children: [
                        const SizedBox(
                          width: 40,
                          height: 40,
                          child: ColoredBox(color: DealGoColors.subtlePurple),
                        ),
                        const SizedBox(width: DealGoSpacing.s12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(line.name, style: textTheme.titleMedium),
                              Text(
                                'x${line.qty} · ${formatVnd(line.unitPriceVnd)} / món',
                                style: textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Text(
                          formatVnd(line.unitPriceVnd * line.qty),
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (preparing) ...[
            const SizedBox(height: DealGoSpacing.s12),
            MerchantPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Món cần chuẩn bị', style: textTheme.titleMedium),
                  for (final line in lines) ...[
                    const SizedBox(height: DealGoSpacing.s8),
                    Row(
                      children: [
                        const SizedBox(
                          width: 40,
                          height: 40,
                          child: ColoredBox(color: DealGoColors.subtlePurple),
                        ),
                        const SizedBox(width: DealGoSpacing.s12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(line.name, style: textTheme.titleMedium),
                              Text(
                                'x${line.qty} · ${formatVnd(line.unitPriceVnd)} / món',
                                style: textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Text(
                          formatVnd(line.unitPriceVnd * line.qty),
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: DealGoSpacing.s12),
            MerchantPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Trạng thái bếp', style: textTheme.titleMedium),
                  const SizedBox(height: DealGoSpacing.s8),
                  for (final line in lines) ...[
                    Row(
                      children: [
                        Icon(
                          line.kitchen == 'Đã xong'
                              ? Icons.check_circle
                              : Icons.circle,
                          size: 18,
                          color: line.kitchen == 'Đã xong'
                              ? DealGoColors.brandGreen
                              : DealGoColors.amber,
                        ),
                        const SizedBox(width: DealGoSpacing.s8),
                        Expanded(
                          child: Text(
                            '${line.name} · ${line.kitchen}',
                            style: textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: DealGoSpacing.s8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: DealGoSpacing.s12),
            const MerchantNote(
              tone: MerchantNoteTone.green,
              message: 'Chỉ đánh dấu READY_FOR_PICKUP khi đã đủ món và có thể bàn giao.',
            ),
          ],
          if (ready) ...[
            const SizedBox(height: DealGoSpacing.s12),
            MerchantPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tài xế nhận món', style: textTheme.titleMedium),
                  const SizedBox(height: DealGoSpacing.s12),
                  Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: DealGoColors.subtlePurple,
                        child: Text(
                          'A',
                          style: TextStyle(
                            color: DealGoColors.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: DealGoSpacing.s12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Trần Minh Anh', style: textTheme.titleMedium),
                            Text(
                              'Honda Vision · xe máy · 43H1-123.45',
                              style: textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const MerchantChip(
                        label: 'Xác minh hợp lệ',
                        tone: MerchantChipTone.green,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: DealGoSpacing.s12),
            MerchantPanel(
              color: DealGoColors.subtlePurple,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Đối chiếu khi giao', style: textTheme.titleMedium),
                  const SizedBox(height: DealGoSpacing.s8),
                  MerchantMoneyRow(
                    label: 'Mã bàn giao',
                    value: code,
                    emphasize: true,
                  ),
                  MerchantMoneyRow(
                    label: 'Số túi',
                    value: '${order.lineCount > 1 ? 2 : 1} túi',
                  ),
                  MerchantMoneyRow(
                    label: 'Tổng số món',
                    value: '${order.lineCount} món',
                  ),
                  MerchantMoneyRow(
                    label: 'Số tiền COD',
                    value: formatVnd(order.subtotalVnd),
                    emphasize: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: DealGoSpacing.s12),
            MerchantNote(
              tone: MerchantNoteTone.green,
              message: handoffDone
                  ? 'Đã xác nhận bàn giao mã $code trên máy (mock). Tài xế cần xác nhận PICKED_UP.'
                  : 'Shop xác nhận đã bàn giao cùng mã $code; tài xế phải xác nhận nhận đủ hàng để chuyển sang PICKED_UP.',
            ),
          ],
          if (!preparing) ...[
            const SizedBox(height: DealGoSpacing.s12),
            MerchantPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.merchantOrderValueTitle,
                    style: textTheme.titleMedium,
                  ),
                  const SizedBox(height: DealGoSpacing.s8),
                  MerchantMoneyRow(
                    label: 'Tiền món',
                    value: formatVnd(order.subtotalVnd),
                  ),
                  MerchantMoneyRow(
                    label: 'Phí giao',
                    value: formatVnd(order.deliveryFareVnd),
                  ),
                  MerchantMoneyRow(
                    label: l10n.merchantOrderDiscount,
                    value: formatVnd(0),
                  ),
                  const Divider(height: DealGoSpacing.s24),
                  MerchantMoneyRow(
                    label: l10n.merchantOrderCodTotal,
                    value: formatVnd(order.totalVnd),
                    emphasize: true,
                  ),
                  MerchantMoneyRow(
                    label: l10n.merchantOrderFoodRevenue,
                    value: formatVnd(order.subtotalVnd),
                    emphasize: true,
                  ),
                ],
              ),
            ),
          ],
          if (!preparing && !ready) ...[
            const SizedBox(height: DealGoSpacing.s12),
            MerchantNote(
              tone: MerchantNoteTone.green,
              message: l10n.merchantOrderCodNote,
            ),
          ],
          if (message != null) ...[
            const SizedBox(height: DealGoSpacing.s12),
            MerchantNote(message: message!),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmReject(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.merchantRejectConfirmTitle),
          content: Text(l10n.merchantRejectConfirmBody),
          actions: [
            TextButton(
              key: const Key('merchant-reject-keep'),
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.merchantRejectKeep),
            ),
            TextButton(
              key: const Key('merchant-reject-confirm'),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.merchantRejectConfirmCta),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.merchantRejectDone)),
    );
    merchantBack(context);
  }
}

class _Conflict extends StatelessWidget {
  const _Conflict({required this.order, required this.onReload});

  final MerchantQueueOrder order;
  final Future<void> Function() onReload;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return MerchantPageFrame(
      title: 'Xác nhận đơn Shop',
      subtitle: merchantStateSubtitle,
      insetBottom: true,
      onBack: () => merchantBack(context),
      footer: MerchantFooter(
        secondaryLabel: 'Về danh sách đơn',
        primaryLabel: 'Xem trạng thái mới',
        primaryKey: const Key('merchant-refresh-conflict'),
        onSecondary: () => merchantBack(context),
        onPrimary: () => onReload(),
      ),
      body: ListView(
        padding: merchantPagePadding,
        children: [
          const MerchantHero(
            icon: Icons.swap_horiz,
            iconColor: DealGoColors.amber,
            background: DealGoColors.amberSurface,
            title: 'Đơn đã được xử lý',
            message:
                'Một nhân viên khác hoặc hệ thống đã xử lý đơn này trước bạn.',
          ),
          const SizedBox(height: DealGoSpacing.s24),
          MerchantPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Đơn hàng đang xử lý', style: textTheme.titleMedium),
                const SizedBox(height: DealGoSpacing.s8),
                MerchantMoneyRow(label: 'Mã đơn', value: '#${order.id}'),
                MerchantMoneyRow(label: 'Cửa hàng', value: order.storeId),
                MerchantMoneyRow(
                  label: 'Tiền món',
                  value: formatVnd(order.subtotalVnd),
                ),
                MerchantMoneyRow(
                  label: 'Phí giao',
                  value: formatVnd(order.deliveryFareVnd),
                ),
                MerchantMoneyRow(
                  label: 'Tổng',
                  value: formatVnd(order.totalVnd),
                  emphasize: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: DealGoSpacing.s12),
          const MerchantNote(
            message: 'Không gửi lại thao tác xác nhận cũ; cập nhật trạng thái mới nhất từ máy chủ.',
          ),
        ],
      ),
    );
  }
}
