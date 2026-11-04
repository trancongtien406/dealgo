import 'package:flutter/material.dart';

import '../../../../core/design_system/components/dealgo_chip.dart';
import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/motion/dealgo_sheet.dart';
import '../../../../l10n/app_localizations.dart';

/// Server-side sort plus the client-visible filters offered on food lists.
class FoodFilters {
  const FoodFilters({
    this.sortBy = 'distance',
    this.maxKm,
    this.openNow = false,
    this.offersOnly = false,
  });

  final String sortBy;
  final int? maxKm;
  final bool openNow;
  final bool offersOnly;

  bool get isDefault =>
      sortBy == 'distance' && maxKm == null && !openNow && !offersOnly;

  @override
  bool operator ==(Object other) =>
      other is FoodFilters &&
      other.sortBy == sortBy &&
      other.maxKm == maxKm &&
      other.openNow == openNow &&
      other.offersOnly == offersOnly;

  @override
  int get hashCode => Object.hash(sortBy, maxKm, openNow, offersOnly);

  FoodFilters copyWith({
    String? sortBy,
    int? maxKm,
    bool clearMaxKm = false,
    bool? openNow,
    bool? offersOnly,
  }) {
    return FoodFilters(
      sortBy: sortBy ?? this.sortBy,
      maxKm: clearMaxKm ? null : (maxKm ?? this.maxKm),
      openNow: openNow ?? this.openNow,
      offersOnly: offersOnly ?? this.offersOnly,
    );
  }
}

Future<FoodFilters?> showFoodFilterSheet({
  required BuildContext context,
  required FoodFilters current,
}) {
  return showDealGoSheet<FoodFilters>(
    context: context,
    useRootNavigator:  true,
    isScrollControlled: true,
    builder: (_) => _FoodFilterSheet(initial: current),
  );
}

class _FoodFilterSheet extends StatefulWidget {
  const _FoodFilterSheet({required this.initial});

  final FoodFilters initial;

  @override
  State<_FoodFilterSheet> createState() => _FoodFilterSheetState();
}

class _FoodFilterSheetState extends State<_FoodFilterSheet> {
  late var _sortBy = widget.initial.sortBy;
  late var _maxKm = widget.initial.maxKm;
  late var _openNow = widget.initial.openNow;
  late var _offersOnly = widget.initial.offersOnly;

  void _apply() {
    Navigator.of(context).pop(
      FoodFilters(
        sortBy: _sortBy,
        maxKm: _maxKm,
        openNow: _openNow,
        offersOnly: _offersOnly,
      ),
    );
  }

  void _reset() {
    setState(() {
      _sortBy = 'distance';
      _maxKm = null;
      _openNow = false;
      _offersOnly = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Column(
          key: const Key('food-filter-sheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DealGoDimensions.pageGutter,
                DealGoSpacing.s16,
                DealGoSpacing.s8,
                DealGoSpacing.s8,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.foodFilterTitle,
                      style: textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: MaterialLocalizations.of(context)
                        .closeButtonTooltip,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(DealGoIcons.close),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  DealGoDimensions.pageGutter,
                  DealGoSpacing.s8,
                  DealGoDimensions.pageGutter,
                  DealGoSpacing.s16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.foodFilterSort, style: textTheme.labelLarge),
                    const SizedBox(height: DealGoSpacing.s8),
                    Wrap(
                      spacing: DealGoSpacing.s8,
                      runSpacing: DealGoSpacing.s8,
                      children: [
                        DealGoChip(
                          key: const Key('food-filter-sort-distance'),
                          label: l10n.foodFilterNear,
                          tone: DealGoChipTone.brand,
                          selected: _sortBy == 'distance',
                          onTap: () => setState(() => _sortBy = 'distance'),
                        ),
                        DealGoChip(
                          key: const Key('food-filter-sort-rating'),
                          label: l10n.foodFilterRating,
                          tone: DealGoChipTone.brand,
                          selected: _sortBy == 'rating',
                          onTap: () => setState(() => _sortBy = 'rating'),
                        ),
                      ],
                    ),
                    const SizedBox(height: DealGoSpacing.s20),
                    Text(l10n.foodFilterDistance, style: textTheme.labelLarge),
                    const SizedBox(height: DealGoSpacing.s8),
                    Wrap(
                      spacing: DealGoSpacing.s8,
                      runSpacing: DealGoSpacing.s8,
                      children: [
                        DealGoChip(
                          key: const Key('food-filter-km-any'),
                          label: l10n.foodFilterAnyDistance,
                          tone: DealGoChipTone.neutral,
                          selected: _maxKm == null,
                          onTap: () => setState(() => _maxKm = null),
                        ),
                        for (final km in const [1, 3, 5])
                          DealGoChip(
                            key: Key('food-filter-km-$km'),
                            label: l10n.foodFilterKm(km),
                            tone: DealGoChipTone.neutral,
                            selected: _maxKm == km,
                            onTap: () => setState(() => _maxKm = km),
                          ),
                      ],
                    ),
                    const SizedBox(height: DealGoSpacing.s20),
                    Wrap(
                      spacing: DealGoSpacing.s8,
                      runSpacing: DealGoSpacing.s8,
                      children: [
                        DealGoChip(
                          key: const Key('food-filter-open'),
                          label: l10n.foodFilterOpenNow,
                          tone: DealGoChipTone.success,
                          selected: _openNow,
                          leading: const Icon(DealGoIcons.clock, size: 14),
                          onTap: () => setState(() => _openNow = !_openNow),
                        ),
                        DealGoChip(
                          key: const Key('food-filter-offers'),
                          label: l10n.foodFilterOffers,
                          tone: DealGoChipTone.promo,
                          selected: _offersOnly,
                          leading: const Icon(DealGoIcons.tag, size: 14),
                          onTap: () =>
                              setState(() => _offersOnly = !_offersOnly),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DealGoDimensions.pageGutter,
                DealGoSpacing.s8,
                DealGoDimensions.pageGutter,
                DealGoSpacing.s16,
              ),
              child: Row(
                children: [
                  TextButton(
                    key: const Key('food-filter-reset'),
                    onPressed: _reset,
                    child: Text(l10n.foodFilterReset),
                  ),
                  const SizedBox(width: DealGoSpacing.s12),
                  Expanded(
                    child: DealGoPrimaryButton(
                      key: const Key('food-filter-apply'),
                      label: l10n.foodFilterApply,
                      onPressed: _apply,
                    ),
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
