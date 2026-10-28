import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/api_base_url.dart';
import '../../../core/design_system/icons/dealgo_icons.dart';
import '../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../activity/domain/entities/history_models.dart';
import '../../activity/domain/usecases/list_food_history.dart';
import '../../activity/domain/usecases/list_ride_history.dart';
import '../../food/domain/entities/food_category.dart';
import '../../food/domain/entities/food_models.dart';
import '../../food/domain/entities/food_money.dart';
import '../../food/domain/usecases/list_food_stores.dart';
import '../../food/presentation/food_categories_store.dart';
import '../../food/presentation/utils/food_routes.dart';
import '../../food/presentation/widgets/food_category_tile.dart';
import '../../food/presentation/widgets/store_meta.dart';
import '../../identity/domain/entities/auth_state.dart';
import '../../identity/presentation/cubit/auth_cubit.dart';
import '../../rating/domain/service_rating.dart';
import 'account_routes.dart';
import 'customer_activity_page.dart';
import 'home_shared.dart';
import '../../../core/design_system/components/dealgo_network_image.dart';

class SectionTitle extends StatelessWidget {
  const SectionTitle({
    required this.title,
    required this.action,
    required this.onAction,
    this.leadingIcon,
    super.key,
  });

  final String title;
  final String action;
  final VoidCallback onAction;
  final IconData? leadingIcon;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        if (leadingIcon != null) ...[
          Icon(leadingIcon, color: DealGoColors.primary, size: 20),
          const SizedBox(width: DealGoSpacing.s8),
        ],
        Expanded(child: Text(title, style: textTheme.titleMedium)),
        TextButton(
          onPressed: onAction,
          style: TextButton.styleFrom(
            foregroundColor: DealGoColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: DealGoSpacing.s8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                action,
                style: textTheme.labelLarge?.copyWith(
                  color: DealGoColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(DealGoIcons.arrowRight, size: 14),
            ],
          ),
        ),
      ],
    );
  }
}

/// C001 “Mua hàng nổi bật”: section title, round categories, store strip.
class FeaturedShoppingCard extends StatelessWidget {
  const FeaturedShoppingCard({required this.onOpen, super.key});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(
          title: AppLocalizations.of(context).homeShopTitle,
          action: AppLocalizations.of(context).actionSeeAll,
          onAction: onOpen,
        ),
        const SizedBox(height: DealGoSpacing.s12),
        const CategoryRow(),
        const SizedBox(height: DealGoSpacing.s16),
        StoreRow(onOpen: onOpen),
      ],
    );
  }
}

/// Food categories managed in Admin › Danh mục; each opens its store list.
/// Shimmer tiles while loading; hidden if the list failed with nothing cached.
class CategoryRow extends StatelessWidget {
  const CategoryRow({super.key});

  @override
  Widget build(BuildContext context) {
    final store = maybeFoodCategories(context);
    final categories = store?.items ?? const <FoodCategory>[];
    final loading = store?.status == FoodCategoriesStatus.loading;
    if (categories.isEmpty && !loading) return const SizedBox.shrink();
    final language = Localizations.localeOf(context).languageCode;
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.isEmpty ? 5 : categories.length,
        separatorBuilder: (context, index) =>
            const SizedBox(width: DealGoSpacing.s12),
        itemBuilder: (context, index) {
          if (categories.isEmpty) {
            return const SizedBox(width: 72, child: FoodCategoryTileSkeleton());
          }
          final category = categories[index];
          return SizedBox(
            width: 72,
            child: InkWell(
              key: Key('home-category-${category.code}'),
              onTap: () => context.push(FoodRoutes.categoryOf(category.code)),
              borderRadius: BorderRadius.circular(DealGoRadius.input),
              child: Column(
                children: [
                  FoodCategoryAvatar(category: category),
                  const SizedBox(height: DealGoSpacing.s8),
                  Text(
                    category.name(language),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: DealGoColors.text, height: 1.2),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Real nearby stores (S013 strip). Hidden while loading or when there are none,
/// so the home screen never shows invented shops.
class StoreRow extends StatefulWidget {
  const StoreRow({required this.onOpen, super.key});

  final VoidCallback onOpen;

  @override
  State<StoreRow> createState() => _StoreRowState();
}

class _StoreRowState extends State<StoreRow> {
  List<FoodStoreSummary> _stores = const [];
  Map<String, StoreRating> _ratings = const {};

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final token = homeAccessToken(context);
    if (token == null) return;
    try {
      final stores = (await context.read<ListFoodStores>()(token))
          .take(6)
          .toList(growable: false);
      if (!mounted || stores.isEmpty) return;
      setState(() => _stores = stores);
      final ratings = await context.read<RatingRepository>().storeRatings(
        accessToken: token,
        storeIds: [for (final store in stores) store.id],
      );
      if (mounted) {
        setState(() => _ratings = ratings);
      }
    } on Object {
      // Optional section: failures leave it hidden.
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_stores.isEmpty) return const SizedBox.shrink();
    // Cover 118 + two-line name + up to three meta lines + padding.
    return SizedBox(
      height: 252,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _stores.length,
        separatorBuilder: (context, index) =>
            const SizedBox(width: DealGoSpacing.s12),
        itemBuilder: (context, index) {
          final store = _stores[index];
          return _StoreCard(
            key: Key('home-store-${store.id}'),
            store: store,
            rating: _ratings[store.id],
            onTap: () => context.push(FoodRoutes.store(store.id)),
          );
        },
      ),
    );
  }
}

class _StoreCard extends StatelessWidget {
  const _StoreCard({
    required this.store,
    required this.onTap,
    this.rating,
    super.key,
  });

  final FoodStoreSummary store;
  final StoreRating? rating;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SizedBox(
      width: 176,
      child: Material(
        color: DealGoColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DealGoRadius.button),
          side: const BorderSide(color: DealGoColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _StoreCover(imageUrl: store.imageUrl),
                    const Positioned(
                      top: DealGoSpacing.s8,
                      right: DealGoSpacing.s8,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: DealGoColors.card,
                          shape: BoxShape.circle,
                          boxShadow: DealGoShadows.card,
                        ),
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: Icon(
                            DealGoIcons.heart,
                            size: 14,
                            color: DealGoColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(DealGoSpacing.s12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      store.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium?.copyWith(fontSize: 14),
                    ),
                    const SizedBox(height: DealGoSpacing.s4),
                    StoreMetaLine(store: store, rating: rating),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoreCover extends StatelessWidget {
  const _StoreCover({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    const placeholder = ColoredBox(
      color: Color(0xFFFFF4EA),
      child: Center(
        child: Icon(DealGoIcons.food, color: Color(0xFFEA580C), size: 40),
      ),
    );
    final resolved = resolveMediaUrl(imageUrl);
    if (resolved == null || resolved.isEmpty) {
      return placeholder;
    }
    return DealGoNetworkImage(
      resolved,
      fit: BoxFit.cover,
      fallback: placeholder,
    );
  }
}

class VoucherBanner extends StatelessWidget {
  const VoucherBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    void openVouchers() =>
        context.push(AccountRoutes.vouchers('/customer/account'));
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DealGoColors.greenSurface,
        borderRadius: BorderRadius.circular(DealGoRadius.button),
        border: Border.all(color: DealGoColors.border),
        boxShadow: DealGoShadows.card,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: const Key('home-voucher-banner'),
          onTap: openVouchers,
          borderRadius: BorderRadius.circular(DealGoRadius.button),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DealGoSpacing.s16,
              vertical: DealGoSpacing.s12,
            ),
            child: Row(
              children: [
                const Icon(
                  DealGoIcons.voucher,
                  color: DealGoColors.primary,
                  size: 28,
                ),
                const SizedBox(width: DealGoSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.homeVoucherBadge,
                        style: textTheme.labelSmall?.copyWith(
                          color: DealGoColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        l10n.homeVoucherTitle,
                        style: textTheme.titleMedium?.copyWith(
                          fontSize: 14,
                          color: DealGoColors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: DealGoSpacing.s8),
                HomeOutlinePillButton(
                  key: const Key('home-voucher-see-all'),
                  label: l10n.homeVoucherSeeAll,
                  onPressed: openVouchers,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Latest ride (or food order) from the real history endpoints.
class RecentTripCard extends StatefulWidget {
  const RecentTripCard({super.key});

  @override
  State<RecentTripCard> createState() => _RecentTripCardState();
}

class _RecentTripCardState extends State<RecentTripCard> {
  HistoryItem? _item;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final token = homeAccessToken(context);
    HistoryItem? latest;
    if (token != null) {
      try {
        final rides = await context.read<ListRideHistory>()(token);
        latest = rides.firstOrNull;
        if (latest == null && mounted) {
          latest = (await context.read<ListFoodHistory>()(token)).firstOrNull;
        }
      } on Object {
        latest = null;
      }
    }
    if (mounted) {
      setState(() {
        _item = latest;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    final item = _item;
    final amount = item?.amountVnd;
    final bad = item != null && historyStatusIsBad(item.status);
    return Material(
      key: const Key('home-recent-activity'),
      color: DealGoColors.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DealGoRadius.button),
        side: const BorderSide(color: DealGoColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/customer/trips'),
        child: Padding(
          padding: const EdgeInsets.all(DealGoSpacing.s16),
          child: Row(
            children: [
              DecoratedBox(
                decoration: const BoxDecoration(
                  color: DealGoColors.subtlePurple,
                  shape: BoxShape.circle,
                ),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(
                    item?.kind == HistoryKind.food
                        ? DealGoIcons.food
                        : DealGoIcons.motorbike,
                    color: DealGoColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: DealGoSpacing.s12),
              Expanded(
                child: item == null
                    ? Text(
                        _loading ? '…' : l10n.homeRecentEmpty,
                        style: textTheme.bodyMedium,
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.meta, style: textTheme.bodySmall),
                          Text(
                            historyTitle(AppLocalizations.of(context), item),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
              if (item != null) ...[
                const SizedBox(width: DealGoSpacing.s8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (amount != null)
                      Text(
                        formatVnd(amount),
                        style: textTheme.titleMedium?.copyWith(fontSize: 15),
                      ),
                    const SizedBox(height: DealGoSpacing.s4),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: bad
                            ? DealGoColors.dangerSurface
                            : DealGoColors.greenSurface,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: DealGoSpacing.s8,
                          vertical: 2,
                        ),
                        child: Text(
                          historyStatusLabel(l10n, item.status),
                          style: textTheme.labelSmall?.copyWith(
                            color: bad
                                ? DealGoColors.danger
                                : DealGoColors.brandGreen,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String? homeAccessToken(BuildContext context) {
  final auth = context.read<AuthCubit>().state;
  return auth is AuthSignedIn ? auth.tokens.accessToken : null;
}
