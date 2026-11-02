import 'package:flutter/material.dart';

import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../presence/domain/entities/driver_service_prefs.dart';
import '../utils/driver_service_icons.dart';
import 'driver_widgets.dart';

enum DriverServiceKind { ride, food, parcel }

/// Enabled services in the same order as the overview and settings screens.
List<DriverServiceKind> enabledDriverServices(
  DriverServicePrefs prefs,
  String? vehicleClassCode,
) => [
  if (prefs.rideEnabled) DriverServiceKind.ride,
  if (prefs.foodEnabled && driverFoodServiceVisible(vehicleClassCode))
    DriverServiceKind.food,
  if (prefs.parcelEnabled) DriverServiceKind.parcel,
];

String driverServiceLabel(AppLocalizations l10n, DriverServiceKind kind) {
  return switch (kind) {
    DriverServiceKind.ride => l10n.driverServicePassenger,
    DriverServiceKind.food => l10n.driverServicesFoodTitle,
    DriverServiceKind.parcel => l10n.driverServiceParcel,
  };
}

/// Wraps one pill per enabled service so every name stays readable.
/// A single ellipsized sentence cannot fit ride + food + parcel next to
/// the duty badge and the settings button.
class DriverServiceStrip extends StatelessWidget {
  const DriverServiceStrip({
    required this.prefs,
    required this.vehicleClassCode,
    this.onOpenSettings,
    this.settingsKey,
    this.showStatus = false,
    this.online = false,
    this.pillKeyFor,
    super.key,
  });

  final DriverServicePrefs prefs;
  final String? vehicleClassCode;
  final VoidCallback? onOpenSettings;
  final Key? settingsKey;
  final bool showStatus;
  final bool online;
  final Key? Function(DriverServiceKind kind)? pillKeyFor;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final kinds = enabledDriverServices(prefs, vehicleClassCode);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showStatus || onOpenSettings != null) ...[
          Row(
            children: [
              if (showStatus)
                DriverChip(
                  label: online
                      ? l10n.driverOnlineBadge
                      : l10n.driverOfflineChip,
                  tone: online ? DriverChipTone.green : DriverChipTone.warning,
                ),
              const Spacer(),
              if (onOpenSettings != null)
                IconButton(
                  key: settingsKey,
                  tooltip: l10n.driverServiceSettings,
                  visualDensity: VisualDensity.compact,
                  onPressed: onOpenSettings,
                  icon: const Icon(DealGoIcons.tune, size: 20),
                ),
            ],
          ),
          const SizedBox(height: DealGoSpacing.s8),
        ],
        if (kinds.isEmpty)
          Text(
            l10n.driverNoServiceOn,
            style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final available = constraints.maxWidth;
              final maxLabel = available <= 36
                  ? available
                  : (available - 36).clamp(0.0, available);
              return Wrap(
                spacing: DealGoSpacing.s8,
                runSpacing: DealGoSpacing.s8,
                children: [
                  for (final kind in kinds)
                    _ServicePill(
                      key: pillKeyFor?.call(kind),
                      label: driverServiceLabel(l10n, kind),
                      maxLabelWidth: maxLabel,
                      icon: _ServiceGlyph(
                        kind: kind,
                        vehicleClassCode: vehicleClassCode,
                      ),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }
}

class _ServiceGlyph extends StatelessWidget {
  const _ServiceGlyph({required this.kind, required this.vehicleClassCode});

  final DriverServiceKind kind;
  final String? vehicleClassCode;

  @override
  Widget build(BuildContext context) {
    return switch (kind) {
      DriverServiceKind.ride => DriverVehicleVisual(
        vehicleClassCode: vehicleClassCode,
        size: 16,
      ),
      DriverServiceKind.food => const Icon(
        DriverServiceIcons.food,
        size: 16,
        color: DealGoColors.primary,
      ),
      DriverServiceKind.parcel => const Icon(
        DriverServiceIcons.parcel,
        size: 16,
        color: DealGoColors.primary,
      ),
    };
  }
}

class _ServicePill extends StatelessWidget {
  const _ServicePill({
    required this.icon,
    required this.label,
    required this.maxLabelWidth,
    super.key,
  });

  final Widget icon;
  final String label;
  final double maxLabelWidth;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DealGoColors.subtlePurple,
        borderRadius: BorderRadius.circular(DealGoRadius.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DealGoSpacing.s8,
          vertical: DealGoSpacing.s6,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Center(child: icon),
              ),
            ),
            const SizedBox(width: DealGoSpacing.s4),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxLabelWidth),
              child: Text(
                label,
                softWrap: true,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: DealGoColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
