import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../food/domain/entities/food_models.dart';
import '../../../food/domain/entities/food_money.dart';
import '../cubit/merchant_queue_cubit.dart';
import '../utils/merchant_routes.dart';
import '../cubit/merchant_states.dart';
import '../widgets/merchant_widgets.dart';

class MerchantOrdersPage extends StatefulWidget {
  const MerchantOrdersPage({super.key});

  @override
  State<MerchantOrdersPage> createState() => _MerchantOrdersPageState();
}

class _MerchantOrdersPageState extends State<MerchantOrdersPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    if (!mounted) {
      return;
    }
    unawaited(
      context.read<MerchantQueueCubit>().load(merchantAccessToken(context)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final queue = context.watch<MerchantQueueCubit>().state;
    return switch (queue) {
      MerchantQueueLoading() => const MerchantQueueLoadingView(
        title: 'Hàng đợi đơn của Shop',
      ),
      MerchantQueueIneligible() => MerchantIneligibleView(
        title: 'Hàng đợi đơn của Shop',
        onRetry: _load,
      ),
      MerchantQueueFailed(:final saved, :final syncedAt) =>
        MerchantQueueErrorView(
          saved: saved,
          syncedAt: syncedAt,
          onRetry: _load,
        ),
      MerchantQueueReady(:final orders) when orders.isEmpty =>
        MerchantQueueEmptyView(onCheck: _load),
      MerchantQueueReady(:final orders) => _QueueList(orders: orders),
    };
  }
}

class _QueueList extends StatelessWidget {
  const _QueueList({required this.orders});

  final List<MerchantQueueOrder> orders;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final focus = _focusOrder(orders);
    final others = [
      for (final order in orders)
        if (order.id != focus.id) order,
    ];
    final placed = merchantQueueTotals(orders).placed;
    final storeId = focus.storeId;
    return MerchantPageFrame(
      title: 'Hàng đợi đơn của Shop',
      onBack: () => merchantBack(context),
      footer: MerchantPrimaryBar(
        buttonKey: Key('merchant-open-${focus.id}'),
        label: 'Xem đơn ${focus.id}',
        onPressed: () => _open(context, focus),
      ),
      body: ListView(
        padding: merchantPagePadding,
        children: [
          MerchantPanel(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Cửa hàng của bạn', style: textTheme.titleMedium),
                      Text(storeId, style: textTheme.bodySmall),
                      const SizedBox(height: DealGoSpacing.s12),
                      Text('Đơn mới cần xác nhận', style: textTheme.bodyMedium),
                    ],
                  ),
                ),
                Text(
                  merchantCountLabel(placed),
                  style: textTheme.headlineMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: DealGoSpacing.s12),
          Text('Đơn cần xử lý', style: textTheme.titleMedium),
          const SizedBox(height: DealGoSpacing.s8),
          _OrderCard(order: focus, onOpen: () => _open(context, focus)),
          if (others.isNotEmpty) ...[
            const SizedBox(height: DealGoSpacing.s16),
            Text('Hàng đợi khác', style: textTheme.titleMedium),
            const SizedBox(height: DealGoSpacing.s8),
            for (final order in others) ...[
              _OrderCard(order: order, onOpen: () => _open(context, order)),
              const SizedBox(height: DealGoSpacing.s8),
            ],
          ],
          const SizedBox(height: DealGoSpacing.s12),
          const MerchantNote(
            tone: MerchantNoteTone.green,
            message: 'Shop chỉ được xác nhận đơn thuộc cửa hàng đang quản lý; phân quyền kiểm tra tại backend.',
          ),
        ],
      ),
    );
  }

  void _open(BuildContext context, MerchantQueueOrder order) {
    context.push(MerchantRoutes.order(order.id), extra: order);
  }
}

MerchantQueueOrder _focusOrder(List<MerchantQueueOrder> orders) {
  for (final order in orders) {
    if (order.status == 'PLACED') {
      return order;
    }
  }
  for (final order in orders) {
    if (order.status == 'PREPARING') {
      return order;
    }
  }
  return orders.first;
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onOpen});

  final MerchantQueueOrder order;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return MerchantPanel(
      child: InkWell(
        key: Key('merchant-order-${order.id}'),
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Đơn #${order.id}', style: textTheme.titleMedium),
                ),
                MerchantChip(
                  label: order.status == 'PLACED'
                      ? 'NEW · Chờ Shop xác nhận'
                      : merchantStatusLabel(order.status),
                  tone: merchantStatusTone(order.status),
                ),
              ],
            ),
            const SizedBox(height: DealGoSpacing.s12),
            MerchantMoneyRow(label: 'Giao đến', value: order.dropoff.label),
            MerchantMoneyRow(
              label: 'Số món · Tiền món',
              value: '${order.lineCount} · ${formatVnd(order.subtotalVnd)}',
            ),
            MerchantMoneyRow(
              label: 'Phí giao (server)',
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
    );
  }
}
