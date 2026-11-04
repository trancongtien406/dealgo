part of '../food_store_page.dart';

class _StoreOffers extends StatelessWidget {
  const _StoreOffers({required this.offers, required this.storeId});

  final List<StoreOffer> offers;
  final String storeId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Column(
      key: const Key('food-store-offers'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.foodStoreOffersTitle,
                style: textTheme.titleMedium,
              ),
            ),
            if (offers.length > 1)
              TextButton(
                key: const Key('food-store-offers-all'),
                onPressed: () => showDealGoSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => BlocProvider.value(
                    value: context.read<FoodCartCubit>(),
                    child: _StoreOffersSheet(offers: offers),
                  ),
                ),
                child: Text(l10n.actionSeeAll),
              ),
          ],
        ),
        const SizedBox(height: DealGoSpacing.s8),
        // Natural height: every ticket grows to its tallest sibling, never clips.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (index, offer) in offers.indexed) ...[
                  if (index > 0) const SizedBox(width: DealGoSpacing.s12),
                  DealGoStaggerIn(
                    index: index,
                    child: SizedBox(
                      width: 300,
                      child: _OfferTicket(offer: offer),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StoreOffersSheet extends StatelessWidget {
  const _StoreOffersSheet({required this.offers});

  final List<StoreOffer> offers;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Column(
          key: const Key('food-store-offers-sheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DealGoDimensions.pageGutter,
                DealGoSpacing.s16,
                DealGoDimensions.pageGutter,
                DealGoSpacing.s8,
              ),
              child: Text(
                l10n.foodStoreOffersTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(
                  DealGoDimensions.pageGutter,
                  DealGoSpacing.s8,
                  DealGoDimensions.pageGutter,
                  DealGoSpacing.s24,
                ),
                itemCount: offers.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: DealGoSpacing.s12),
                itemBuilder: (context, index) => DealGoStaggerIn(
                  index: index,
                  child: _OfferTicket(offer: offers[index], inSheet: true),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfferTicket extends StatelessWidget {
  const _OfferTicket({required this.offer, this.inSheet = false});

  final StoreOffer offer;
  final bool inSheet;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final used = context.select<FoodCartCubit, bool>(
      (cart) => cart.state.voucherCode == offer.code,
    );
    final prefix = inSheet ? 'food-store-sheet-offer' : 'food-store-offer';
    return DealGoVoucherTicket(
      key: Key('$prefix-${offer.id}'),
      headline: storeOfferHeadline(l10n, offer),
      caption: offer.code,
      title: offer.name,
      conditions: storeOfferConditions(
        l10n,
        offer,
        locale: Localizations.localeOf(context).toLanguageTag(),
      ),
      highlighted: used,
      action: used
          ? DealGoTicketButton(
              key: Key('$prefix-used-${offer.id}'),
              label: l10n.voucherUsed,
              accent: DealGoColors.danger,
              done: true,
            )
          : DealGoTicketButton(
              key: Key('$prefix-use-${offer.id}'),
              label: l10n.foodStoreOfferUse,
              accent: DealGoColors.danger,
              onPressed: () {
                context.read<FoodCartCubit>().applyVoucher(code: offer.code);
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(
                      content: Text(l10n.foodStoreOfferApplied(offer.code)),
                    ),
                  );
              },
            ),
    );
  }
}
