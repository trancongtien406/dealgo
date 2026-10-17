import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../food/domain/entities/food_models.dart';
import '../../../food/domain/entities/food_money.dart';
import '../cubit/merchant_queue_cubit.dart';
import '../utils/merchant_routes.dart';
import '../cubit/merchant_states.dart';
import '../widgets/merchant_widgets.dart';

class MerchantHomePage extends StatefulWidget {
  const MerchantHomePage({super.key});

  @override
  State<MerchantHomePage> createState() => _MerchantHomePageState();
}

class _MerchantHomePageState extends State<MerchantHomePage> {
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
        title: 'Tổng quan cửa hàng',
      ),
      MerchantQueueIneligible() => MerchantIneligibleView(
        title: 'Tổng quan cửa hàng',
        onRetry: _load,
      ),
      MerchantQueueFailed(:final saved, :final syncedAt) =>
        MerchantQueueErrorView(
          saved: saved,
          syncedAt: syncedAt,
          onRetry: _load,
        ),
      MerchantQueueReady(:final orders) => _Dashboard(orders: orders),
    };
  }
}

class _Dashboard extends StatelessWidget {
  const _Dashboard({required this.orders});

  final List<MerchantQueueOrder> orders;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final totals = merchantQueueTotals(orders);
    return MerchantPageFrame(
      title: 'Tổng quan cửa hàng',
      onBack: () => merchantBack(context),
      body: ListView(
        padding: merchantPagePadding,
        children: [
          MerchantPanel(
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: Image.asset(
                      'assets/images/food_bun_bo_hue.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) {
                        return const ColoredBox(
                          color: DealGoColors.subtlePurple,
                          child: Icon(
                            Icons.restaurant,
                            color: DealGoColors.primary,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: DealGoSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Bún Bò Huế O Cô', style: textTheme.titleMedium),
                      Text(
                        'Đà Nẵng · Chi nhánh chính',
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const MerchantChip(
                  label: 'Đang mở',
                  tone: MerchantChipTone.green,
                ),
              ],
            ),
          ),
          const SizedBox(height: DealGoSpacing.s12),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: 'Đơn cần xác nhận',
                  value: merchantCountLabel(totals.placed),
                ),
              ),
              const SizedBox(width: DealGoSpacing.s12),
              Expanded(
                child: _StatTile(
                  label: 'Đang chuẩn bị',
                  value: merchantCountLabel(totals.preparing),
                ),
              ),
            ],
          ),
          const SizedBox(height: DealGoSpacing.s12),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: AppLocalizations.of(context).merchantHomeCompletedToday,
                  value: merchantCountLabel(totals.ready),
                ),
              ),
              const SizedBox(width: DealGoSpacing.s12),
              Expanded(
                child: _StatTile(
                  label: AppLocalizations.of(context).merchantHomeFoodToday,
                  value: formatVnd(totals.subtotalVnd),
                ),
              ),
            ],
          ),
          const SizedBox(height: DealGoSpacing.s12),
          MerchantPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Đơn cần xử lý', style: textTheme.titleMedium),
                const SizedBox(height: DealGoSpacing.s12),
                if (orders.isEmpty)
                  Text(
                    'Không có đơn đang mở trên hàng đợi.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: DealGoColors.textSecondary,
                    ),
                  )
                else
                  for (final order in orders.take(3)) ...[
                    _HomeOrderRow(order: order),
                    if (order != orders.take(3).last)
                      const SizedBox(height: DealGoSpacing.s12),
                  ],
              ],
            ),
          ),
          const SizedBox(height: DealGoSpacing.s12),
          MerchantPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context).merchantHomeFinanceTitle,
                  style: textTheme.titleMedium,
                ),
                const SizedBox(height: DealGoSpacing.s8),
                MerchantMoneyRow(
                  label: AppLocalizations.of(context).merchantHomeGrossFood,
                  value: formatVnd(totals.subtotalVnd),
                ),
                MerchantMoneyRow(
                  label: AppLocalizations.of(context).merchantHomePendingSettle,
                  value: formatVnd(totals.deliveryFareVnd),
                ),
                MerchantMoneyRow(
                  label: AppLocalizations.of(context).merchantHomeAvailable,
                  value: formatVnd(
                    totals.subtotalVnd > totals.deliveryFareVnd
                        ? totals.subtotalVnd - totals.deliveryFareVnd
                        : 0,
                  ),
                  emphasize: true,
                ),
                const SizedBox(height: DealGoSpacing.s8),
                MerchantNote(
                  tone: MerchantNoteTone.green,
                  message: AppLocalizations.of(context).merchantHomeFinanceHint,
                ),
              ],
            ),
          ),
          const SizedBox(height: DealGoSpacing.s16),
          Text(
            AppLocalizations.of(context).merchantSettingsShellTitle,
            style: textTheme.titleMedium,
          ),
          const SizedBox(height: DealGoSpacing.s12),
          MerchantPanel(
            child: Column(
              children: [
                _SettingsLink(
                  key: const Key('merchant-open-accept'),
                  icon: Icons.tune,
                  label: AppLocalizations.of(context).merchantAcceptTitle,
                  onTap: () => context.push(MerchantRoutes.acceptSettings),
                ),
                const SizedBox(height: DealGoSpacing.s8),
                _SettingsLink(
                  key: const Key('merchant-open-hours'),
                  icon: Icons.schedule,
                  label: AppLocalizations.of(context).merchantHoursTitle,
                  onTap: () => context.push(MerchantRoutes.hours),
                ),
                const SizedBox(height: DealGoSpacing.s8),
                _SettingsLink(
                  key: const Key('merchant-open-busy'),
                  icon: Icons.pause_circle_outline,
                  label: AppLocalizations.of(context).merchantBusyTitle,
                  onTap: () => context.push(MerchantRoutes.busy),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsLink extends StatelessWidget {
  const _SettingsLink({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(DealGoRadius.input),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: DealGoSpacing.s8),
        child: Row(
          children: [
            Icon(icon, color: DealGoColors.primary),
            const SizedBox(width: DealGoSpacing.s12),
            Expanded(child: Text(label)),
            const Icon(Icons.chevron_right, color: DealGoColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return MerchantPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: textTheme.bodySmall),
          const SizedBox(height: DealGoSpacing.s8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: textTheme.titleLarge),
          ),
        ],
      ),
    );
  }
}

class _HomeOrderRow extends StatelessWidget {
  const _HomeOrderRow({required this.order});

  final MerchantQueueOrder order;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      key: Key('merchant-home-order-${order.id}'),
      onTap: () => context.push(MerchantRoutes.order(order.id), extra: order),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              color: DealGoColors.subtlePurple,
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(Icons.receipt_long, color: DealGoColors.primary),
            ),
          ),
          const SizedBox(width: DealGoSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Đơn #${order.id}', style: textTheme.titleSmall),
                Text(
                  '${order.lineCount} món · ${formatVnd(order.subtotalVnd)} tiền món',
                  style: textTheme.bodySmall,
                ),
                const SizedBox(height: DealGoSpacing.s8),
                MerchantChip(
                  label: merchantStatusLabel(order.status),
                  tone: merchantStatusTone(order.status),
                ),
              ],
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: DealGoColors.subtlePurple,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DealGoSpacing.s12,
                vertical: DealGoSpacing.s8,
              ),
              child: Text(
                'Xem →',
                style: textTheme.labelSmall?.copyWith(
                  color: DealGoColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
