import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/components/dealgo_chip.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../identity/presentation/widgets/auth_widgets.dart';
import '../../domain/entities/food_models.dart';
import '../../domain/entities/food_money.dart';
import '../../domain/usecases/list_food_stores.dart';
import '../cubit/food_discovery_cubit.dart';
import '../utils/food_routes.dart';
import '../widgets/food_widgets.dart';

/// C024 — category / nearby store results list.
class FoodCategoryPage extends StatelessWidget {
  const FoodCategoryPage({this.category, super.key});

  final String? category;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          FoodDiscoveryCubit(listFoodStores: context.read<ListFoodStores>())
            ..load(currentAccessToken(context)),
      child: _FoodCategoryView(category: category),
    );
  }
}

class _FoodCategoryView extends StatefulWidget {
  const _FoodCategoryView({this.category});

  final String? category;

  @override
  State<_FoodCategoryView> createState() => _FoodCategoryViewState();
}

class _FoodCategoryViewState extends State<_FoodCategoryView> {
  var _sort = 'near';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final discovery = context.watch<FoodDiscoveryCubit>().state;
    final stores = switch (discovery) {
      FoodDiscoveryReady(:final stores) => stores,
      _ => const <FoodStoreSummary>[],
    };
    final loading = discovery is FoodDiscoveryLoading;
    final title = widget.category?.isNotEmpty == true
        ? widget.category!
        : l10n.foodCategoryTitle;

    return Scaffold(
      backgroundColor: DealGoColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            FoodScreenHeader(title: title, trailing: const DealGoWordmark()),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DealGoDimensions.pageGutter,
              ),
              child: InkWell(
                onTap: () => context.push(FoodRoutes.search),
                borderRadius: BorderRadius.circular(DealGoRadius.input),
                child: InputDecorator(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(
                      Icons.search,
                      color: DealGoColors.primary,
                    ),
                    suffixIcon: const Icon(
                      Icons.edit_outlined,
                      color: DealGoColors.textSecondary,
                    ),
                    filled: true,
                    fillColor: DealGoColors.subtlePurple,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(DealGoRadius.input),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  child: Text(
                    l10n.foodCategorySearchPlaceholder,
                    style: textTheme.bodyMedium?.copyWith(
                      color: DealGoColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: DealGoSpacing.s12),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: DealGoDimensions.pageGutter,
                ),
                children: [
                  for (final entry in [
                    ('near', l10n.foodCategorySortNear),
                    ('rating', l10n.foodCategorySortRating),
                    ('freeship', l10n.foodCategorySortFreeship),
                  ]) ...[
                    DealGoChip(
                      label: entry.$2,
                      selected: _sort == entry.$1,
                      tone: DealGoChipTone.brand,
                      onTap: () => setState(() => _sort = entry.$1),
                    ),
                    const SizedBox(width: DealGoSpacing.s8),
                  ],
                  DealGoChip(
                    label: l10n.foodCategoryFilter,
                    tone: DealGoChipTone.neutral,
                    leading: const Icon(Icons.tune, size: 14),
                    onTap: () {},
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  DealGoDimensions.pageGutter,
                  DealGoSpacing.s16,
                  DealGoDimensions.pageGutter,
                  DealGoSpacing.s24,
                ),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.foodCategoryAroundYou,
                              style: textTheme.titleMedium,
                            ),
                            Text(
                              l10n.foodCategoryAroundHint(stores.length),
                              style: textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      DecoratedBox(
                        decoration: const BoxDecoration(
                          color: DealGoColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const SizedBox(
                          width: 40,
                          height: 40,
                          child: Icon(
                            Icons.map_outlined,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: DealGoSpacing.s16),
                  if (loading)
                    const Center(child: CircularProgressIndicator())
                  else
                    for (final store in stores) ...[
                      _StoreRow(
                        store: store,
                        onTap: () => context.push(FoodRoutes.store(store.id)),
                      ),
                      const SizedBox(height: DealGoSpacing.s12),
                    ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoreRow extends StatelessWidget {
  const _StoreRow({required this.store, required this.onTap});

  final FoodStoreSummary store;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DealGoRadius.card),
        child: FoodPanel(
          child: Row(
            children: [
              const FoodThumb(),
              const SizedBox(width: DealGoSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(store.name, style: textTheme.titleMedium),
                    Text(
                      '★ 4.8 · ${l10n.foodCategoryVietnamese}',
                      style: textTheme.bodySmall,
                    ),
                    Text('⏱ 20–30 phút · 1,2 km', style: textTheme.bodySmall),
                    const SizedBox(height: DealGoSpacing.s8),
                    DealGoChip(
                      label: l10n.foodFreeshipChip,
                      tone: DealGoChipTone.success,
                    ),
                  ],
                ),
              ),
              Text(
                formatVnd(35000),
                style: textTheme.titleSmall?.copyWith(
                  color: DealGoColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
