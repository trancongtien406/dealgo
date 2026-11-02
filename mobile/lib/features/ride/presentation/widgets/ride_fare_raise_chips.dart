import 'package:flutter/material.dart';

import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../domain/entities/ride_money.dart';
import '../../domain/ride_fare_presets.dart';

/// Quick-raise chips. Each chip shows only the resulting price. The amounts
/// are slices of the configurable headroom and stay inside the bid band.
class RideFareRaiseChips extends StatelessWidget {
  const RideFareRaiseChips({
    required this.presets,
    required this.selectedVnd,
    required this.onPick,
    this.enabled = true,
    this.keyPrefix = 'ride-fare-preset',
    this.keySuffix = '',
    super.key,
  });

  final List<RideFarePreset> presets;
  final int? selectedVnd;
  final ValueChanged<int> onPick;
  final bool enabled;
  final String keyPrefix;

  /// Appended after the percent (the ride id suffix on the driver list).
  final String keySuffix;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < presets.length; i++) ...[
          if (i > 0) const SizedBox(width: DealGoSpacing.s8),
          Expanded(
            child: _RaiseChip(
              key: Key('$keyPrefix-${presets[i].percent}$keySuffix'),
              percent: presets[i].percent,
              amount: presets[i].amountVnd,
              selected: selectedVnd == presets[i].amountVnd,
              onTap: enabled && presets[i].enabled
                  ? () => onPick(presets[i].amountVnd)
                  : null,
            ),
          ),
        ],
      ],
    );
  }
}

class _RaiseChip extends StatelessWidget {
  const _RaiseChip({
    required this.percent,
    required this.amount,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final int percent;
  final int amount;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // The border marks the choice; screen readers get it from `selected`.
    final disabled = onTap == null;
    final fg = selected
        ? Colors.white
        : disabled
        ? DealGoColors.textSecondary.withValues(alpha: 0.5)
        : DealGoColors.text;
    return Semantics(
      button: true,
      selected: selected,
      enabled: !disabled,
      label: formatRideVnd(amount),
      excludeSemantics: true,
      child: Material(
        color: selected ? DealGoColors.primary : DealGoColors.canvas,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DealGoSpacing.s12),
          side: BorderSide(
            color: selected ? DealGoColors.primary : DealGoColors.border,
            width: selected ? 1.4 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            // t73u (owner): amount only — the +10/20/30% stays internal.
            padding: const EdgeInsets.symmetric(
              vertical: DealGoSpacing.s8,
              horizontal: DealGoSpacing.s4,
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                formatRideVnd(amount),
                maxLines: 1,
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(color: fg, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
