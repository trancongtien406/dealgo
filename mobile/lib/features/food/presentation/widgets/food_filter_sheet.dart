import 'package:flutter/material.dart';

import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/design_system/tokens/dealgo_type_scale.dart';
import '../../../../core/motion/dealgo_sheet.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../rating/domain/service_rating.dart';
import '../../domain/entities/food_models.dart';

/// Quick-pick radius presets in kilometres shown under the distance slider.
const kFoodDistancePresetKms = <int>[1, 2, 3, 5, 10, 15];

/// Maximum specific radius on the interactive slider; 16 means "any distance".
const _kMaxSliderKm = 15;
const _kAnyDistanceSliderStep = 16;

/// Minimum star rating options offered in the food filter sheet.
const kFoodMinRatingOptions = <double>[3.5, 4.0, 4.5];

/// Maximum delivery ETA options (in minutes) offered in the food filter sheet.
const kFoodMaxEtaOptions = <int>[20, 30, 45];

/// Server-side sort plus the client-visible filters offered on food lists.
class FoodFilters {
  const FoodFilters({
    this.sortBy = 'distance',
    this.maxKm,
    this.minRating,
    this.maxEtaMinutes,
    this.openNow = false,
    this.offersOnly = false,
    this.noMinOrder = false,
  });

  final String sortBy;
  final int? maxKm;
  final double? minRating;
  final int? maxEtaMinutes;
  final bool openNow;
  final bool offersOnly;
  final bool noMinOrder;

  bool get isDefault =>
      sortBy == 'distance' &&
      maxKm == null &&
      minRating == null &&
      maxEtaMinutes == null &&
      !openNow &&
      !offersOnly &&
      !noMinOrder;

  int get activeCount =>
      (sortBy != 'distance' ? 1 : 0) +
      (maxKm != null ? 1 : 0) +
      (minRating != null ? 1 : 0) +
      (maxEtaMinutes != null ? 1 : 0) +
      (openNow ? 1 : 0) +
      (offersOnly ? 1 : 0) +
      (noMinOrder ? 1 : 0);

  /// Whether a store passes all active client-side filter criteria.
  bool matches(FoodStoreSummary store, {StoreRating? rating}) {
    if (openNow && !store.openNow) {
      return false;
    }
    if (offersOnly && store.offers.isEmpty) {
      return false;
    }
    if (noMinOrder && store.minOrderVnd > 0) {
      return false;
    }
    final km = maxKm;
    if (km != null && store.distanceKm != null && store.distanceKm! > km) {
      return false;
    }
    final requiredStars = minRating;
    if (requiredStars != null) {
      final average = rating?.average ?? store.ratingAverage;
      if (average == null || average < requiredStars) {
        return false;
      }
    }
    final maxEta = maxEtaMinutes;
    if (maxEta != null) {
      final eta = store.etaMinutes;
      if (eta == null || eta > maxEta) {
        return false;
      }
    }
    return true;
  }

  @override
  bool operator ==(Object other) =>
      other is FoodFilters &&
      other.sortBy == sortBy &&
      other.maxKm == maxKm &&
      other.minRating == minRating &&
      other.maxEtaMinutes == maxEtaMinutes &&
      other.openNow == openNow &&
      other.offersOnly == offersOnly &&
      other.noMinOrder == noMinOrder;

  @override
  int get hashCode => Object.hash(
    sortBy,
    maxKm,
    minRating,
    maxEtaMinutes,
    openNow,
    offersOnly,
    noMinOrder,
  );

  FoodFilters copyWith({
    String? sortBy,
    int? maxKm,
    bool clearMaxKm = false,
    double? minRating,
    bool clearMinRating = false,
    int? maxEtaMinutes,
    bool clearMaxEtaMinutes = false,
    bool? openNow,
    bool? offersOnly,
    bool? noMinOrder,
  }) {
    return FoodFilters(
      sortBy: sortBy ?? this.sortBy,
      maxKm: clearMaxKm ? null : (maxKm ?? this.maxKm),
      minRating: clearMinRating ? null : (minRating ?? this.minRating),
      maxEtaMinutes: clearMaxEtaMinutes
          ? null
          : (maxEtaMinutes ?? this.maxEtaMinutes),
      openNow: openNow ?? this.openNow,
      offersOnly: offersOnly ?? this.offersOnly,
      noMinOrder: noMinOrder ?? this.noMinOrder,
    );
  }
}

/// Soft-square (`8pt` radius) sort & filter control button.
///
/// Replaces [DealGoChip] (`StadiumBorder` status badge) on filter bars and
/// filter sheets so filter controls read as crisp interactive buttons rather
/// than bloated capsule badges, while still keeping a comfortable hit target.
class FoodFilterPill extends StatelessWidget {
  const FoodFilterPill({
    required this.label,
    this.icon,
    this.selected = false,
    this.onTap,
    super.key,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final background = selected ? DealGoColors.subtlePurple : DealGoColors.card;
    final borderColor = selected ? DealGoColors.primary : DealGoColors.border;
    final foreground = selected
        ? DealGoColors.primary
        : DealGoColors.textSecondary;
    final borderRadius = BorderRadius.circular(DealGoRadius.small);
    final shape = RoundedRectangleBorder(
      borderRadius: borderRadius,
      side: BorderSide(color: borderColor, width: selected ? 1.2 : 1),
    );

    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 34),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DealGoSpacing.s12,
          vertical: DealGoSpacing.s6,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: foreground),
              const SizedBox(width: DealGoSpacing.s6),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DealGoType.micro(Theme.of(context).textTheme).copyWith(
                  color: foreground,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final painted = Material(
      color: background,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? content
          : InkWell(onTap: onTap, customBorder: shape, child: content),
    );

    return Semantics(
      label: label,
      button: onTap != null,
      selected: onTap != null ? selected : null,
      child: painted,
    );
  }
}

/// Square filter button beside the search bar with an active-filter count badge.
class FoodFilterIconButton extends StatelessWidget {
  const FoodFilterIconButton({
    required this.activeCount,
    required this.onTap,
    this.buttonKey,
    super.key,
  });

  final int activeCount;
  final VoidCallback onTap;
  final Key? buttonKey;

  bool get _active => activeCount > 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: _active ? DealGoColors.primary : DealGoColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DealGoRadius.input),
        side: BorderSide(
          color: _active ? DealGoColors.primary : DealGoColors.border,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: buttonKey,
        onTap: onTap,
        child: Semantics(
          button: true,
          label: l10n.foodFilterButton,
          child: SizedBox(
            width: 52,
            height: 52,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  DealGoIcons.filter,
                  color: _active ? Colors.white : DealGoColors.primary,
                ),
                if (_active)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(DealGoRadius.pill),
                      ),
                      child: Text(
                        '$activeCount',
                        style: DealGoType.micro(textTheme).copyWith(
                          color: DealGoColors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String foodSortLabel(AppLocalizations l10n, String sortBy) => switch (sortBy) {
  'rating' => l10n.foodFilterRating,
  'createdAt' => l10n.foodSearchSortNewest,
  'name' => l10n.foodFilterSortName,
  _ => l10n.foodFilterNear,
};

IconData foodSortIcon(String sortBy) => switch (sortBy) {
  'rating' => DealGoIcons.starFilled,
  'createdAt' => DealGoIcons.stars,
  'name' => DealGoIcons.list,
  _ => DealGoIcons.myLocation,
};

String formatMinRatingLabel(AppLocalizations l10n, double stars) =>
    l10n.foodFilterRatingFrom(stars.toStringAsFixed(1));

Future<FoodFilters?> showFoodFilterSheet({
  required BuildContext context,
  required FoodFilters current,
}) {
  return showDealGoSheet<FoodFilters>(
    context: context,
    useRootNavigator: true,
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
  late var _minRating = widget.initial.minRating;
  late var _maxEtaMinutes = widget.initial.maxEtaMinutes;
  late var _openNow = widget.initial.openNow;
  late var _offersOnly = widget.initial.offersOnly;
  late var _noMinOrder = widget.initial.noMinOrder;

  FoodFilters get _draft => FoodFilters(
    sortBy: _sortBy,
    maxKm: _maxKm,
    minRating: _minRating,
    maxEtaMinutes: _maxEtaMinutes,
    openNow: _openNow,
    offersOnly: _offersOnly,
    noMinOrder: _noMinOrder,
  );

  void _apply() {
    Navigator.of(context).pop(_draft);
  }

  void _reset() {
    setState(() {
      _sortBy = 'distance';
      _maxKm = null;
      _minRating = null;
      _maxEtaMinutes = null;
      _openNow = false;
      _offersOnly = false;
      _noMinOrder = false;
    });
  }

  void _stepKm(int delta) {
    final current = _maxKm;
    if (current == null) {
      setState(() => _maxKm = delta < 0 ? _kMaxSliderKm : 3);
      return;
    }
    final next = current + delta;
    setState(() {
      if (next > _kMaxSliderKm) {
        _maxKm = null;
      } else {
        _maxKm = next.clamp(1, _kMaxSliderKm);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final draft = _draft;
    final activeCount = draft.activeCount;
    final applyLabel = activeCount > 0
        ? '${l10n.foodFilterApply} ($activeCount)'
        : l10n.foodFilterApply;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: Column(
          key: const Key('food-filter-sheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: DealGoSpacing.s8),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: DealGoColors.border,
                  borderRadius: BorderRadius.circular(DealGoRadius.pill),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DealGoDimensions.pageGutter,
                DealGoSpacing.s8,
                DealGoSpacing.s8,
                DealGoSpacing.s8,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.foodFilterTitle,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
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
            Divider(height: 1, color: DealGoColors.divider),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  DealGoDimensions.pageGutter,
                  DealGoSpacing.s16,
                  DealGoDimensions.pageGutter,
                  DealGoSpacing.s16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Sort by
                    _SectionTitle(title: l10n.foodFilterSort),
                    const SizedBox(height: DealGoSpacing.s8),
                    Wrap(
                      spacing: DealGoSpacing.s8,
                      runSpacing: DealGoSpacing.s8,
                      children: [
                        FoodFilterPill(
                          key: const Key('food-filter-sort-distance'),
                          label: l10n.foodFilterNear,
                          icon: DealGoIcons.myLocation,
                          selected: _sortBy == 'distance',
                          onTap: () => setState(() => _sortBy = 'distance'),
                        ),
                        FoodFilterPill(
                          key: const Key('food-filter-sort-rating'),
                          label: l10n.foodFilterRating,
                          icon: DealGoIcons.starFilled,
                          selected: _sortBy == 'rating',
                          onTap: () => setState(() => _sortBy = 'rating'),
                        ),
                        FoodFilterPill(
                          key: const Key('food-filter-sort-newest'),
                          label: l10n.foodSearchSortNewest,
                          icon: DealGoIcons.stars,
                          selected: _sortBy == 'createdAt',
                          onTap: () => setState(() => _sortBy = 'createdAt'),
                        ),
                        FoodFilterPill(
                          key: const Key('food-filter-sort-name'),
                          label: l10n.foodFilterSortName,
                          icon: DealGoIcons.list,
                          selected: _sortBy == 'name',
                          onTap: () => setState(() => _sortBy = 'name'),
                        ),
                      ],
                    ),
                    const SizedBox(height: DealGoSpacing.s16),
                    Divider(height: 1, color: DealGoColors.divider),
                    const SizedBox(height: DealGoSpacing.s16),

                    // 2. Interactive Distance (Slider + +/- Stepper + Quick Presets)
                    _DistanceSelectorSection(
                      maxKm: _maxKm,
                      onChanged: (km) => setState(() => _maxKm = km),
                      onStep: _stepKm,
                    ),
                    const SizedBox(height: DealGoSpacing.s16),
                    Divider(height: 1, color: DealGoColors.divider),
                    const SizedBox(height: DealGoSpacing.s16),

                    // 3. Minimum Rating
                    _SectionTitle(title: l10n.foodFilterMinRatingTitle),
                    const SizedBox(height: DealGoSpacing.s8),
                    Wrap(
                      spacing: DealGoSpacing.s8,
                      runSpacing: DealGoSpacing.s8,
                      children: [
                        FoodFilterPill(
                          key: const Key('food-filter-rating-any'),
                          label: l10n.foodFilterRatingAny,
                          selected: _minRating == null,
                          onTap: () => setState(() => _minRating = null),
                        ),
                        for (final stars in kFoodMinRatingOptions)
                          FoodFilterPill(
                            key: Key(
                              'food-filter-rating-${(stars * 10).round()}',
                            ),
                            label: formatMinRatingLabel(l10n, stars),
                            icon: DealGoIcons.starFilled,
                            selected: _minRating == stars,
                            onTap: () => setState(
                              () => _minRating = _minRating == stars
                                  ? null
                                  : stars,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: DealGoSpacing.s16),
                    Divider(height: 1, color: DealGoColors.divider),
                    const SizedBox(height: DealGoSpacing.s16),

                    // 4. Estimated Delivery Time
                    _SectionTitle(title: l10n.foodFilterEtaTitle),
                    const SizedBox(height: DealGoSpacing.s8),
                    Wrap(
                      spacing: DealGoSpacing.s8,
                      runSpacing: DealGoSpacing.s8,
                      children: [
                        FoodFilterPill(
                          key: const Key('food-filter-eta-any'),
                          label: l10n.foodFilterEtaAny,
                          selected: _maxEtaMinutes == null,
                          onTap: () => setState(() => _maxEtaMinutes = null),
                        ),
                        for (final minutes in kFoodMaxEtaOptions)
                          FoodFilterPill(
                            key: Key('food-filter-eta-$minutes'),
                            label: l10n.foodFilterEtaMax(minutes),
                            icon: DealGoIcons.timer,
                            selected: _maxEtaMinutes == minutes,
                            onTap: () => setState(
                              () => _maxEtaMinutes = _maxEtaMinutes == minutes
                                  ? null
                                  : minutes,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: DealGoSpacing.s16),
                    Divider(height: 1, color: DealGoColors.divider),
                    const SizedBox(height: DealGoSpacing.s16),

                    // 5. Store Status & Perks
                    _SectionTitle(title: l10n.foodFilterStatusTitle),
                    const SizedBox(height: DealGoSpacing.s8),
                    Wrap(
                      spacing: DealGoSpacing.s8,
                      runSpacing: DealGoSpacing.s8,
                      children: [
                        FoodFilterPill(
                          key: const Key('food-filter-open'),
                          label: l10n.foodFilterOpenNow,
                          icon: DealGoIcons.clock,
                          selected: _openNow,
                          onTap: () => setState(() => _openNow = !_openNow),
                        ),
                        FoodFilterPill(
                          key: const Key('food-filter-offers'),
                          label: l10n.foodFilterOffers,
                          icon: DealGoIcons.tag,
                          selected: _offersOnly,
                          onTap: () =>
                              setState(() => _offersOnly = !_offersOnly),
                        ),
                        FoodFilterPill(
                          key: const Key('food-filter-no-min-order'),
                          label: l10n.foodFilterNoMinOrder,
                          icon: DealGoIcons.successOutline,
                          selected: _noMinOrder,
                          onTap: () =>
                              setState(() => _noMinOrder = !_noMinOrder),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Divider(height: 1, color: DealGoColors.divider),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DealGoDimensions.pageGutter,
                DealGoSpacing.s12,
                DealGoDimensions.pageGutter,
                DealGoSpacing.s16,
              ),
              child: Row(
                children: [
                  TextButton(
                    key: const Key('food-filter-reset'),
                    onPressed: draft.isDefault ? null : _reset,
                    child: Text(l10n.foodFilterReset),
                  ),
                  const SizedBox(width: DealGoSpacing.s12),
                  Expanded(
                    child: DealGoPrimaryButton(
                      key: const Key('food-filter-apply'),
                      label: applyLabel,
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.labelLarge
          ?.copyWith(fontWeight: FontWeight.w700, color: DealGoColors.text),
    );
  }
}

/// User-friendly distance control with live badge, `-`/`+` 1-km stepper buttons,
/// smooth slider (`1..15 km` + `Any`), and 1-tap preset chips.
class _DistanceSelectorSection extends StatelessWidget {
  const _DistanceSelectorSection({
    required this.maxKm,
    required this.onChanged,
    required this.onStep,
  });

  final int? maxKm;
  final ValueChanged<int?> onChanged;
  final ValueChanged<int> onStep;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final currentKm = maxKm;
    final sliderValue = (currentKm == null || currentKm > _kMaxSliderKm)
        ? _kAnyDistanceSliderStep.toDouble()
        : currentKm.clamp(1, _kMaxSliderKm).toDouble();
    final badgeText = currentKm == null
        ? l10n.foodFilterAnyDistance
        : l10n.foodFilterKm(currentKm);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionTitle(title: l10n.foodFilterDistance),
                  const SizedBox(height: DealGoSpacing.s2),
                  Text(
                    l10n.foodFilterDistanceHint,
                    style: DealGoType.micro(textTheme)
                        .copyWith(color: DealGoColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: DealGoSpacing.s8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: DealGoSpacing.s12,
                vertical: DealGoSpacing.s6,
              ),
              decoration: BoxDecoration(
                color: DealGoColors.subtlePurple,
                borderRadius: BorderRadius.circular(DealGoRadius.small),
                border: Border.all(
                  color: DealGoColors.primary.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    DealGoIcons.pin,
                    size: 14,
                    color: DealGoColors.primary,
                  ),
                  const SizedBox(width: DealGoSpacing.s4),
                  Text(
                    badgeText,
                    key: const Key('food-filter-km-value'),
                    style: DealGoType.micro(textTheme).copyWith(
                      color: DealGoColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: DealGoSpacing.s12),
        Container(
          padding: const EdgeInsets.fromLTRB(
            DealGoSpacing.s8,
            DealGoSpacing.s6,
            DealGoSpacing.s8,
            DealGoSpacing.s8,
          ),
          decoration: BoxDecoration(
            color: DealGoColors.card,
            borderRadius: BorderRadius.circular(DealGoRadius.button),
            border: Border.all(color: DealGoColors.border),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  _StepIconButton(
                    buttonKey: const Key('food-filter-km-dec'),
                    icon: DealGoIcons.remove,
                    enabled: currentKm == null || currentKm > 1,
                    onTap: () => onStep(-1),
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: DealGoColors.primary,
                        inactiveTrackColor: DealGoColors.subtlePurple,
                        thumbColor: DealGoColors.primary,
                        overlayColor: DealGoColors.primary.withValues(
                          alpha: 0.12,
                        ),
                        trackHeight: 4,
                      ),
                      child: Slider(
                        key: const Key('food-filter-km-slider'),
                        value: sliderValue,
                        min: 1,
                        max: _kAnyDistanceSliderStep.toDouble(),
                        divisions: _kAnyDistanceSliderStep - 1,
                        label: badgeText,
                        onChanged: (value) {
                          final rounded = value.round();
                          onChanged(
                            rounded >= _kAnyDistanceSliderStep ? null : rounded,
                          );
                        },
                      ),
                    ),
                  ),
                  _StepIconButton(
                    buttonKey: const Key('food-filter-km-inc'),
                    icon: DealGoIcons.add,
                    enabled: currentKm != null,
                    onTap: () => onStep(1),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: DealGoSpacing.s12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (final label in const [
                      '1 km',
                      '5 km',
                      '10 km',
                      '15 km+',
                    ])
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DealGoType.micro(textTheme)
                              .copyWith(color: DealGoColors.textSecondary),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: DealGoSpacing.s12),
        Wrap(
          spacing: DealGoSpacing.s8,
          runSpacing: DealGoSpacing.s8,
          children: [
            FoodFilterPill(
              key: const Key('food-filter-km-any'),
              label: l10n.foodFilterAnyDistance,
              selected: currentKm == null,
              onTap: () => onChanged(null),
            ),
            for (final km in kFoodDistancePresetKms)
              FoodFilterPill(
                key: Key('food-filter-km-$km'),
                label: '$km km',
                icon: DealGoIcons.pin,
                selected: currentKm == km,
                onTap: () => onChanged(currentKm == km ? null : km),
              ),
          ],
        ),
      ],
    );
  }
}

class _StepIconButton extends StatelessWidget {
  const _StepIconButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
    this.buttonKey,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(DealGoRadius.small),
      side: BorderSide(color: DealGoColors.border),
    );
    return Material(
      color: enabled ? DealGoColors.subtlePurple : DealGoColors.canvas,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: buttonKey,
        onTap: enabled ? onTap : null,
        customBorder: shape,
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(
            icon,
            size: 16,
            color: enabled ? DealGoColors.primary : DealGoColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
