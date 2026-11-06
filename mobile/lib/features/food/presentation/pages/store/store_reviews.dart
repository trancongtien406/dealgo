part of '../food_store_page.dart';

class _Reviews extends StatelessWidget {
  const _Reviews({
    required this.reviews,
    required this.filtered,
    required this.stars,
    required this.busy,
    required this.onFilter,
    required this.onMore,
  });

  /// Unfiltered first page: carries the summary.
  final StoreReviews? reviews;

  /// What the list shows: [reviews] or the star-filtered pages.
  final StoreReviews? filtered;
  final int? stars;
  final bool busy;
  final ValueChanged<int?> onFilter;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final data = reviews;
    if (data == null) {
      return FoodPanel(child: Text(l10n.foodStoreReviewsUnavailable));
    }
    final summary = data.summary;
    final average = summary.average;
    final distribution = summary.distribution;
    final total = distribution?.fold<int>(0, (sum, n) => sum + n) ?? 0;
    final list = filtered;
    final dateFormat = DateFormat('dd/MM/yyyy');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FoodPanel(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (average != null) ...[
                Column(
                  children: [
                    Text(
                      formatRatingAverage(context, average),
                      style: textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: DealGoColors.text,
                      ),
                    ),
                    _Stars(value: average.round(), size: 14),
                  ],
                ),
                const SizedBox(width: DealGoSpacing.s16),
              ] else ...[
                const Icon(DealGoIcons.starFilled, color: DealGoColors.amber),
                const SizedBox(width: DealGoSpacing.s8),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      average == null
                          ? (summary.count == 0
                                ? l10n.foodStoreReviewsNone
                                : l10n.foodStoreReviewsHidden(summary.count))
                          : l10n.foodStoreReviewsSummary(
                              formatRatingAverage(context, average),
                              summary.count,
                            ),
                      key: const Key('food-store-review-summary'),
                      style: textTheme.titleSmall,
                    ),
                    if (distribution != null && total > 0) ...[
                      const SizedBox(height: DealGoSpacing.s8),
                      for (var star = 5; star >= 1; star--)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 14,
                                child: Text(
                                  '$star',
                                  style: textTheme.labelSmall,
                                ),
                              ),
                              const Icon(
                                DealGoIcons.starFilled,
                                size: 10,
                                color: DealGoColors.amber,
                              ),
                              const SizedBox(width: DealGoSpacing.s6),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: TweenAnimationBuilder<double>(
                                    tween: Tween(
                                      begin: 0,
                                      end: distribution.length >= star
                                          ? distribution[star - 1] / total
                                          : 0,
                                    ),
                                    duration: const Duration(milliseconds: 420),
                                    curve: Curves.easeOutCubic,
                                    builder: (context, value, _) =>
                                        LinearProgressIndicator(
                                          key: Key('food-review-bar-$star'),
                                          value: value,
                                          minHeight: 6,
                                          color: DealGoColors.amber,
                                          backgroundColor: DealGoColors.divider,
                                        ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        if (data.items.isNotEmpty || stars != null) ...[
          const SizedBox(height: DealGoSpacing.s12),
          Row(
            children: [
              for (final (index, value) in <int?>[
                null,
                5,
                4,
                3,
                2,
                1,
              ].indexed) ...[
                if (index > 0) const SizedBox(width: DealGoSpacing.s6),
                Expanded(
                  child: _ReviewStarFilter(
                    key: Key('food-review-filter-${value ?? 'all'}'),
                    starCount: value,
                    selected: stars == value,
                    onTap: () => onFilter(value),
                  ),
                ),
              ],
            ],
          ),
        ],
        if (list == null && busy)
          const Padding(
            padding: EdgeInsets.only(top: DealGoSpacing.s12),
            child: DealGoSkeletonList(itemCount: 2, padding: EdgeInsets.zero),
          )
        else if (list != null && list.items.isEmpty && stars != null)
          Padding(
            padding: const EdgeInsets.only(top: DealGoSpacing.s12),
            child: FoodPanel(child: Text(l10n.foodStoreReviewsFilterNone)),
          ),
        for (final (index, review)
            in (list?.items ?? const <StoreReview>[]).indexed) ...[
          const SizedBox(height: DealGoSpacing.s12),
          DealGoStaggerIn(
            index: index,
            child: FoodPanel(
              key: Key('food-review-${review.id.isEmpty ? index : review.id}'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _Stars(value: review.stars, size: 14),
                      const Spacer(),
                      Text(
                        dateFormat.format(review.createdAt),
                        style: textTheme.labelSmall?.copyWith(
                          color: DealGoColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  if (review.tags.isNotEmpty) ...[
                    const SizedBox(height: DealGoSpacing.s8),
                    Wrap(
                      spacing: DealGoSpacing.s6,
                      runSpacing: DealGoSpacing.s6,
                      children: [
                        for (final tag in review.tags)
                          FoodInfoChip(label: ratingTagLabel(l10n, tag)),
                      ],
                    ),
                  ],
                  if (review.comment != null) ...[
                    const SizedBox(height: DealGoSpacing.s8),
                    Text(review.comment!, style: textTheme.bodyMedium),
                  ],
                  if (review.merchantReply != null) ...[
                    const SizedBox(height: DealGoSpacing.s8),
                    Container(
                      key: Key('food-review-reply-${review.id}'),
                      width: double.infinity,
                      padding: const EdgeInsets.all(DealGoSpacing.s12),
                      decoration: BoxDecoration(
                        color: DealGoColors.lavender,
                        borderRadius: BorderRadius.circular(DealGoRadius.input),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.foodStoreMerchantReply,
                            style: textTheme.labelMedium?.copyWith(
                              color: DealGoColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: DealGoSpacing.s4),
                          Text(
                            review.merchantReply!,
                            style: textTheme.bodySmall?.copyWith(
                              color: DealGoColors.text,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
        if (list != null && list.hasMore) ...[
          const SizedBox(height: DealGoSpacing.s12),
          Center(
            child: OutlinedButton(
              key: const Key('food-reviews-more'),
              onPressed: busy ? null : onMore,
              child: Text(l10n.foodStoreReviewsMore),
            ),
          ),
        ],
      ],
    );
  }
}

/// One star filter in the single-row strip: the equal-width cells keep all six
/// choices visible, so the row never wraps into a second line.
class _ReviewStarFilter extends StatelessWidget {
  const _ReviewStarFilter({
    required this.starCount,
    required this.selected,
    required this.onTap,
    super.key,
  });

  /// Null = every rating.
  final int? starCount;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final radius = BorderRadius.circular(DealGoRadius.pill);
    final style = (Theme.of(context).textTheme.labelSmall ?? const TextStyle())
        .copyWith(
          color: selected ? DealGoColors.primary : DealGoColors.textSecondary,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          fontSize: 12,
        );
    final semanticLabel = starCount == null
        ? l10n.foodStoreReviewsAll
        : l10n.rateStarTooltip(starCount!);
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      child: Material(
        color: selected ? DealGoColors.subtlePurple : DealGoColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: selected ? DealGoColors.primary : DealGoColors.border,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 38),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DealGoSpacing.s6,
                  ),
                  child: starCount == null
                      ? Text(
                          l10n.foodStoreReviewsAll,
                          maxLines: 1,
                          softWrap: false,
                          style: style,
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              DealGoIcons.starFilled,
                              size: 11,
                              color: selected
                                  ? DealGoColors.primary
                                  : DealGoColors.amber,
                            ),
                            const SizedBox(width: 2),
                            Text('$starCount', style: style),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.value, this.size = 14});

  final int value;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 5; i++)
          Icon(
            DealGoIcons.starFilled,
            size: size,
            color: i < value ? DealGoColors.amber : DealGoColors.border,
          ),
      ],
    );
  }
}
