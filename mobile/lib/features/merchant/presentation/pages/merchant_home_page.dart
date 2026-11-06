import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/components/dealgo_banner.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../food/domain/entities/food_models.dart';
import '../../../food/domain/entities/food_money.dart';
import '../../../food/presentation/widgets/food_widgets.dart';
import '../../../food/presentation/widgets/store_meta.dart';
import '../../domain/merchant_stats.dart';
import '../../domain/usecases/get_merchant_catalog.dart';
import '../cubit/merchant_queue_cubit.dart';
import '../cubit/merchant_stats_cubit.dart';
import '../utils/merchant_routes.dart';
import '../cubit/merchant_states.dart';
import '../widgets/merchant_widgets.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/format/short_ref.dart';
import '../../../../core/design_system/components/dealgo_nav_insets.dart';
import '../../../../core/design_system/components/dealgo_refresh.dart';

class MerchantHomePage extends StatefulWidget {
  const MerchantHomePage({super.key});

  @override
  State<MerchantHomePage> createState() => _MerchantHomePageState();
}

class _MerchantHomePageState extends State<MerchantHomePage> {
  late final MerchantStatsCubit _stats = MerchantStatsCubit(
    stats: context.read<MerchantStatsRepository>(),
    catalog: context.read<GetMerchantCatalog>(),
  );

  // QA M2 — back in the foreground: refetch silently (sockets may have been
  // suspended while the app was in the background).
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    onResume: () {
      if (mounted) unawaited(context.read<MerchantQueueCubit>().refresh());
    },
  );

  @override
  void initState() {
    super.initState();
    _lifecycle;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _stats.close();
    super.dispose();
  }

  Future<void> _load({bool silentQueue = false}) async {
    if (!mounted) {
      return;
    }
    final queue = context.read<MerchantQueueCubit>();
    queue.setTokenSource(() {
      if (!mounted) return null;
      return merchantAccessToken(context);
    });
    final token = merchantAccessToken(context);
    final queueFuture = silentQueue ? queue.refresh() : queue.load(token);
    final statsFuture = _stats.load(
      token,
      days: 1,
      includeStatement: false,
    );
    // DEC-PROD-043: subscribe store: even when the queue is empty.
    unawaited(_bindStoreRoom(token, afterStats: statsFuture));
    await Future.wait([queueFuture, statsFuture]);
  }

  Future<void> _bindStoreRoom(
    String? token, {
    required Future<void> afterStats,
  }) async {
    final access = token?.trim() ?? '';
    if (access.isEmpty || !mounted) return;
    try {
      await afterStats;
      if (!mounted) return;
      final statsState = _stats.state;
      final store = statsState is MerchantStatsReady
          ? statsState.store
          : await context.read<GetMerchantCatalog>()(access);
      if (!mounted || store == null) return;
      await context.read<MerchantQueueCubit>().listenStore(
        storeId: store.id,
        tokenSource: () {
          if (!mounted) return null;
          return merchantAccessToken(context);
        },
      );
    } catch (_) {
      // Catalog may 403 when ineligible; queue load surfaces that state.
    }
  }

  @override
  Widget build(BuildContext context) {
    final queue = context.watch<MerchantQueueCubit>().state;
    final l10n = AppLocalizations.of(context);
    return BlocProvider.value(value: _stats, child: _body(queue, l10n));
  }

  Widget _body(MerchantQueueState queue, AppLocalizations l10n) {
    return switch (queue) {
      MerchantQueueLoading() => MerchantQueueLoadingView(
        title: l10n.merchantHomeTitle,
      ),
      MerchantQueueIneligible() => MerchantIneligibleView(
        title: l10n.merchantHomeTitle,
        onRetry: _load,
      ),
      MerchantQueueFailed(:final saved, :final syncedAt, :final cause) =>
        MerchantQueueErrorView(
          saved: saved,
          syncedAt: syncedAt,
          cause: cause,
          onRetry: _load,
        ),
      MerchantQueueReady(:final orders) => _Dashboard(
        orders: orders,
        onRefresh: _load,
        onPullRefresh: () => _load(silentQueue: true),
      ),
    };
  }
}

class _Dashboard extends StatelessWidget {
  const _Dashboard({
    required this.orders,
    required this.onRefresh,
    required this.onPullRefresh,
  });

  final List<MerchantQueueOrder> orders;

  /// Re-reads stats + store after M024 so the mode chip is current.
  final VoidCallback onRefresh;
  final Future<void> Function() onPullRefresh;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    final totals = merchantQueueTotals(orders);
    final statsState = context.watch<MerchantStatsCubit>().state;
    final ready = statsState is MerchantStatsReady ? statsState : null;
    final today = ready?.stats.today;
    final store = ready?.store;
    return MerchantPageFrame(
      title: l10n.merchantHomeTitle,
      showBack: false,
      body: DealGoRefresh(
        key: const Key('merchant-home-refresh'),
        onRefresh: onPullRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: dealGoScrollPadding(context, merchantPagePadding),
          children: [
            if (store != null && !store.hasLocation) ...[
              DealGoBanner(
                key: const Key('merchant-home-pin-missing'),
                tone: DealGoBannerTone.warning,
                message: l10n.merchantLocationUnset,
                actionLabel: l10n.merchantLocationPinNow,
                onAction: () async {
                  await context.push(MerchantRoutes.location);
                  onRefresh();
                },
              ),
              const SizedBox(height: DealGoSpacing.s12),
            ],
            MerchantPanel(
              child: Row(
                children: [
                  FoodThumb(
                    key: const Key('merchant-home-logo'),
                    size: 56,
                    imageUrl: store?.logoUrl,
                  ),
                  const SizedBox(width: DealGoSpacing.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          store?.name ?? l10n.merchantHomeShopFallback,
                          style: textTheme.titleMedium,
                        ),
                        if (store?.addressLabel case final address?)
                          Text(address, style: textTheme.bodySmall),
                        if (storeRatingText(context, ready?.rating)
                            case final rating?)
                          Padding(
                            padding: const EdgeInsets.only(
                              top: DealGoSpacing.s4,
                            ),
                            child: Row(
                              key: const Key('merchant-home-rating'),
                              children: [
                                const Icon(
                                  DealGoIcons.starFilled,
                                  size: 16,
                                  color: DealGoColors.amber,
                                ),
                                const SizedBox(width: DealGoSpacing.s4),
                                Flexible(
                                  child: Text(
                                    rating,
                                    style: textTheme.labelMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (store != null)
                    MerchantChip(
                      key: const Key('merchant-home-mode-chip'),
                      label: switch (store.serviceMode) {
                        StoreServiceMode.open => l10n.merchantHomeOpenChip,
                        StoreServiceMode.busy => l10n.merchantHomeBusyChip,
                        StoreServiceMode.paused => l10n.merchantHomePausedChip,
                      },
                      tone: switch (store.serviceMode) {
                        StoreServiceMode.open => MerchantChipTone.green,
                        StoreServiceMode.busy => MerchantChipTone.warning,
                        StoreServiceMode.paused => MerchantChipTone.neutral,
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: DealGoSpacing.s12),
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    icon: DealGoIcons.notificationsActive,
                    tint: DealGoColors.amber,
                    label: l10n.merchantHomeToConfirm,
                    value: merchantCountLabel(totals.placed),
                  ),
                ),
                const SizedBox(width: DealGoSpacing.s12),
                Expanded(
                  child: _StatTile(
                    icon: DealGoIcons.timer,
                    tint: DealGoColors.primary,
                    label: l10n.merchantHomePreparing,
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
                    icon: DealGoIcons.check,
                    tint: DealGoColors.brandGreen,
                    label: l10n.merchantHomeCompletedToday,
                    value: today == null
                        ? '—'
                        : merchantCountLabel(today.deliveredCount),
                  ),
                ),
                const SizedBox(width: DealGoSpacing.s12),
                Expanded(
                  child: _StatTile(
                    icon: DealGoIcons.wallet,
                    tint: DealGoColors.primaryDeep,
                    label: l10n.merchantHomeFoodToday,
                    value: today == null ? '—' : formatVnd(today.salesVnd),
                  ),
                ),
              ],
            ),
            const SizedBox(height: DealGoSpacing.s12),
            MerchantPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.merchantQueueToHandle,
                    style: textTheme.titleMedium,
                  ),
                  const SizedBox(height: DealGoSpacing.s12),
                  if (orders.isEmpty)
                    Text(
                      l10n.merchantHomeNoOrders,
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
                  // QA M5: today's food sales already sit in the stat tile above.
                  MerchantMoneyRow(
                    label: l10n.merchantHomeCancelledToday,
                    value: today == null
                        ? '—'
                        : merchantCountLabel(today.cancelledCount),
                  ),
                  MerchantMoneyRow(
                    label: l10n.merchantHomeOpenOrders,
                    value: merchantCountLabel(orders.length),
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
                    key: const Key('merchant-open-offers'),
                    icon: DealGoIcons.voucher,
                    label: AppLocalizations.of(context).merchantOffersTitle,
                    onTap: () => context.push(MerchantRoutes.offers),
                  ),
                  const SizedBox(height: DealGoSpacing.s8),
                  _SettingsLink(
                    key: const Key('merchant-open-reviews'),
                    icon: DealGoIcons.star,
                    label: AppLocalizations.of(context).merchantReviewsTitle,
                    onTap: () => context.push(MerchantRoutes.reviews),
                  ),
                  const SizedBox(height: DealGoSpacing.s8),
                  _SettingsLink(
                    key: const Key('merchant-open-accept'),
                    icon: DealGoIcons.filter,
                    label: AppLocalizations.of(context).merchantAcceptTitle,
                    onTap: () => context.push(MerchantRoutes.acceptSettings),
                  ),
                  const SizedBox(height: DealGoSpacing.s8),
                  _SettingsLink(
                    key: const Key('merchant-open-hours'),
                    icon: DealGoIcons.clock,
                    label: AppLocalizations.of(context).merchantHoursTitle,
                    onTap: () => context.push(MerchantRoutes.hours),
                  ),
                  const SizedBox(height: DealGoSpacing.s8),
                  _SettingsLink(
                    key: const Key('merchant-open-busy'),
                    icon: DealGoIcons.pause,
                    label: AppLocalizations.of(context).merchantBusyTitle,
                    onTap: () async {
                      await context.push(MerchantRoutes.busy);
                      onRefresh();
                    },
                  ),
                  const SizedBox(height: DealGoSpacing.s8),
                  _SettingsLink(
                    key: const Key('merchant-open-location'),
                    icon: DealGoIcons.pin,
                    label: AppLocalizations.of(context).merchantLocationTitle,
                    onTap: () => context.push(MerchantRoutes.location),
                  ),
                  const SizedBox(height: DealGoSpacing.s8),
                  _SettingsLink(
                    key: const Key('merchant-open-history-home'),
                    icon: DealGoIcons.history,
                    label: AppLocalizations.of(context).merchantProductsHistory,
                    onTap: () => context.push(MerchantRoutes.history),
                  ),
                ],
              ),
            ),
          ],
        ),
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
            Icon(DealGoIcons.chevronRight, color: DealGoColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.tint,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color tint;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return MerchantPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(DealGoRadius.small),
            ),
            child: Icon(icon, size: 18, color: tint),
          ),
          const SizedBox(height: DealGoSpacing.s8),
          SizedBox(height: 36, child: Text(label, style: textTheme.bodySmall)),
          const SizedBox(height: DealGoSpacing.s4),
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
          DecoratedBox(
            decoration: BoxDecoration(
              color: DealGoColors.subtlePurple,
              borderRadius: BorderRadius.circular(DealGoRadius.input),
            ),
            child: const SizedBox(
              width: 44,
              height: 44,
              child: Icon(DealGoIcons.receipt, color: DealGoColors.primary),
            ),
          ),
          const SizedBox(width: DealGoSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context).orderRef(shortRef(order.id)),
                  style: textTheme.titleSmall,
                ),
                Text(
                  AppLocalizations.of(context).merchantHomeOrderLine(
                    order.lineCount,
                    formatVnd(order.subtotalVnd),
                  ),
                  style: textTheme.bodySmall,
                ),
                const SizedBox(height: DealGoSpacing.s8),
                MerchantChip(
                  label: merchantStatusLabel(
                    AppLocalizations.of(context),
                    order.status,
                  ),
                  tone: merchantStatusTone(order.status),
                ),
              ],
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: DealGoColors.primary,
              borderRadius: BorderRadius.circular(DealGoRadius.pill),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DealGoSpacing.s12,
                vertical: DealGoSpacing.s8,
              ),
              child: Text(
                AppLocalizations.of(context).merchantHomeView,
                style: textTheme.labelSmall?.copyWith(
                  color: DealGoColors.card,
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
