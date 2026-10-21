import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../food/domain/entities/food_models.dart';
import '../../../food/domain/entities/food_money.dart';
import '../cubit/merchant_queue_cubit.dart';
import '../utils/merchant_routes.dart';
import '../cubit/merchant_states.dart';
import '../widgets/merchant_widgets.dart';
import '../../../../core/format/short_ref.dart';
import '../../../../l10n/app_localizations.dart';

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
    final queue = context.read<MerchantQueueCubit>();
    queue.setTokenSource(
      () => context.mounted ? merchantAccessToken(context) : null,
    );
    unawaited(queue.load(merchantAccessToken(context)));
  }

  @override
  Widget build(BuildContext context) {
    final queue = context.watch<MerchantQueueCubit>().state;
    return switch (queue) {
      MerchantQueueLoading() => MerchantQueueLoadingView(
        title: AppLocalizations.of(context).merchantQueueTitle,
      ),
      MerchantQueueIneligible() => MerchantIneligibleView(
        title: AppLocalizations.of(context).merchantQueueTitle,
        onRetry: _load,
      ),
      MerchantQueueFailed(:final saved, :final syncedAt, :final cause) =>
        MerchantQueueErrorView(
          saved: saved,
          syncedAt: syncedAt,
          cause: cause,
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
    final l10n = AppLocalizations.of(context);
    final focus = _focusOrder(orders);
    final others = [
      for (final order in orders)
        if (order.id != focus.id) order,
    ];
    final placed = merchantQueueTotals(orders).placed;
    final storeId = focus.storeId;
    return MerchantPageFrame(
      title: l10n.merchantQueueTitle,
      onBack: () => merchantBack(context),
      footer: MerchantPrimaryBar(
        buttonKey: Key('merchant-open-${focus.id}'),
        label: l10n.merchantQueueViewOrder(shortRef(focus.id)),
        onPressed: () => _open(context, focus),
      ),
      body: ListView(
        padding: merchantPagePadding,
        children: [
          MerchantPanel(
            elevated: true,
            child: Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: DealGoColors.subtlePurple,
                    borderRadius: BorderRadius.circular(DealGoRadius.input),
                  ),
                  child: const SizedBox(
                    width: 48,
                    height: 48,
                    child: Icon(DealGoIcons.store, color: DealGoColors.primary),
                  ),
                ),
                const SizedBox(width: DealGoSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.merchantQueueYourShop,
                        style: textTheme.titleMedium,
                      ),
                      Text(shortRef(storeId), style: textTheme.bodySmall),
                      const SizedBox(height: DealGoSpacing.s8),
                      Text(
                        l10n.merchantQueueNewToConfirm,
                        style: textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                Text(
                  merchantCountLabel(placed),
                  style: textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: DealGoSpacing.s12),
          Text(l10n.merchantQueueToHandle, style: textTheme.titleMedium),
          const SizedBox(height: DealGoSpacing.s8),
          _OrderCard(order: focus, onOpen: () => _open(context, focus)),
          if (others.isNotEmpty) ...[
            const SizedBox(height: DealGoSpacing.s16),
            Text(l10n.merchantQueueOthers, style: textTheme.titleMedium),
            const SizedBox(height: DealGoSpacing.s8),
            for (final order in others) ...[
              _OrderCard(order: order, onOpen: () => _open(context, order)),
              const SizedBox(height: DealGoSpacing.s8),
            ],
          ],
          const SizedBox(height: DealGoSpacing.s12),
          MerchantNote(
            tone: MerchantNoteTone.green,
            message: l10n.merchantNoNewOrdersNote,
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
    final l10n = AppLocalizations.of(context);
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
                  child: Text(
                    AppLocalizations.of(context).orderRef(shortRef(order.id)),
                    style: textTheme.titleMedium,
                  ),
                ),
                MerchantChip(
                  label: order.status == 'PLACED'
                      ? l10n.merchantQueueNewChip
                      : merchantStatusLabel(l10n, order.status),
                  tone: merchantStatusTone(order.status),
                ),
              ],
            ),
            if (order.customerName != null || order.driverName != null) ...[
              const SizedBox(height: DealGoSpacing.s8),
              Wrap(
                spacing: DealGoSpacing.s8,
                runSpacing: DealGoSpacing.s4,
                children: [
                  if (order.customerName case final name?)
                    MerchantChip(
                      label: l10n.merchantOrderCustomerName(name),
                      tone: MerchantChipTone.neutral,
                    ),
                  if (order.driverName case final name?)
                    MerchantChip(
                      label: l10n.merchantOrderDriverName(name),
                      tone: MerchantChipTone.green,
                    ),
                ],
              ),
            ],
            const SizedBox(height: DealGoSpacing.s12),
            MerchantMoneyRow(
              label: l10n.merchantQueueDeliverTo,
              value: order.dropoff.label,
            ),
            MerchantMoneyRow(
              label: l10n.merchantQueueItemsFood,
              value: '${order.lineCount} · ${formatVnd(order.subtotalVnd)}',
            ),
            MerchantMoneyRow(
              label: l10n.merchantQueueDeliveryFee,
              value: formatVnd(order.deliveryFareVnd),
            ),
            MerchantMoneyRow(
              label: l10n.merchantQueueTotal,
              value: formatVnd(order.totalVnd),
              emphasize: true,
            ),
          ],
        ),
      ),
    );
  }
}
