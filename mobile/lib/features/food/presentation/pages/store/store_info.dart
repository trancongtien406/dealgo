part of '../food_store_page.dart';

class _StoreStatus extends StatelessWidget {
  const _StoreStatus({
    required this.loading,
    required this.failure,
    required this.onRetry,
  });

  final bool loading;
  final Object? failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.all(DealGoDimensions.pageGutter),
        child: DealGoSkeletonList(itemCount: 5, padding: EdgeInsets.zero),
      );
    }
    final l10n = AppLocalizations.of(context);
    final message = failure is ApiException
        ? apiErrorText(l10n, failure as ApiException)
        : l10n.errorLoadFailed;
    return DealGoStateView.failure(
      context,
      onRetry: onRetry,
      cause: failure,
      message: message,
    );
  }
}

class _StoreInfo extends StatelessWidget {
  const _StoreInfo({required this.store, required this.onOpenMaps});

  final FoodStoreDetail store;
  final VoidCallback onOpenMaps;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final category = foodCategoryLabel(context, store.category);
    Widget row(IconData icon, String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: DealGoSpacing.s4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: DealGoColors.textSecondary),
          const SizedBox(width: DealGoSpacing.s8),
          SizedBox(width: 96, child: Text(label, style: textTheme.bodySmall)),
          Expanded(child: Text(value, style: textTheme.bodyMedium)),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (store.hasLocation) ...[
          _StoreMapCard(store: store, onOpenMaps: onOpenMaps, height: 200),
          const SizedBox(height: DealGoSpacing.s12),
        ] else if (store.addressLabel?.trim().isNotEmpty == true) ...[
          _StoreLocationCard(
            address: store.addressLabel!.trim(),
            onOpenMaps: onOpenMaps,
          ),
          const SizedBox(height: DealGoSpacing.s12),
        ],
        FoodPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              row(DealGoIcons.store, l10n.foodStoreInfoName, store.name),
              if (store.description != null)
                row(DealGoIcons.info, l10n.foodStoreAbout, store.description!),
              if (category != null)
                row(
                  DealGoIcons.restaurant,
                  l10n.foodStoreInfoCategory,
                  category,
                ),
              row(
                DealGoIcons.pin,
                l10n.foodStoreInfoAddress,
                store.addressLabel ?? l10n.foodStoreInfoAddressMissing,
              ),
              if (store.schedule.hoursConfigured)
                row(
                  DealGoIcons.clock,
                  l10n.foodStoreInfoHours,
                  [
                    for (var day = 1; day <= 7; day++)
                      '${_dayShort(l10n, day)}  ${switch (store.schedule.day(day)) {
                        final hours? => '${hours.opensAt} – ${hours.closesAt}',
                        null => l10n.merchantHoursClosed,
                      }}',
                  ].join('\n'),
                ),
              if (store.estimatedPrepMinutes != null)
                row(
                  DealGoIcons.timer,
                  l10n.foodStoreInfoPrep,
                  l10n.foodStorePrepChip(store.estimatedPrepMinutes!),
                ),
              row(
                DealGoIcons.shoppingBag,
                l10n.foodStoreInfoMinOrder,
                store.minOrderVnd > 0
                    ? formatVnd(store.minOrderVnd)
                    : l10n.foodStoreInfoNoMinOrder,
              ),
              row(
                DealGoIcons.wallet,
                l10n.foodStoreInfoPayment,
                l10n.foodStoreInfoPaymentCod,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _dayShort(AppLocalizations l10n, int weekday) => switch (weekday) {
  1 => l10n.dayShortMon,
  2 => l10n.dayShortTue,
  3 => l10n.dayShortWed,
  4 => l10n.dayShortThu,
  5 => l10n.dayShortFri,
  6 => l10n.dayShortSat,
  _ => l10n.dayShortSun,
};
