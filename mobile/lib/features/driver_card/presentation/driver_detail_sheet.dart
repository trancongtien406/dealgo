import 'package:flutter/material.dart';

import '../../../core/config/api_base_url.dart';
import '../../../core/design_system/components/dealgo_network_image.dart';
import '../../../core/design_system/icons/dealgo_icons.dart';
import '../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../core/motion/dealgo_sheet.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/driver_card.dart';
import 'contact_phone_line.dart';
import 'driver_avatar_preview.dart';
import 'driver_card_tile.dart';

Future<void> showDriverDetailSheet(BuildContext context, DriverCard card) {
  return showDealGoSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => DriverDetailSheet(card: card),
  );
}

/// Known class codes from KYC. Free-text values are shown as stored.
String? driverVehicleClassLabel(AppLocalizations l10n, String? type) {
  return switch (type) {
    'CAR_4' => l10n.rideVehicleCar4Title,
    'CAR_7' => l10n.rideVehicleCar7Title,
    'MOTORBIKE' => l10n.rideVehicleBikeTitle,
    null || '' => null,
    _ => type,
  };
}

class DriverDetailSheet extends StatelessWidget {
  const DriverDetailSheet({required this.card, super.key});

  final DriverCard card;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final name = card.displayName.isEmpty
        ? l10n.rideTrackDriverFallback
        : card.displayName;
    final average = card.ratingAverage;
    final rated = average != null && card.ratingCount > 0;
    final avatar = resolveMediaUrl(card.avatarUrl);
    final vehicleName = card.vehicleName;
    final classLabel = driverVehicleClassLabel(l10n, card.vehicleType);
    final plate = card.vehiclePlate;
    final trips = card.completedTrips;
    final phone = card.phone;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          DealGoSpacing.s20,
          DealGoSpacing.s8,
          DealGoSpacing.s20,
          DealGoSpacing.s16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.driverDetailTitle,
              key: const Key('driver-detail-title'),
              style: textTheme.titleMedium,
            ),
            const SizedBox(height: DealGoSpacing.s16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _DriverAvatar(
                  name: name,
                  imageUrl: avatar,
                  onOpen: switch (avatar) {
                    final url? => () => showDriverAvatarPreview(
                      context,
                      imageUrl: url,
                      name: name,
                    ),
                    null => null,
                  },
                ),
                const SizedBox(width: DealGoSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        key: const Key('driver-detail-name'),
                        style: textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      if (rated)
                        Row(
                          children: [
                            const Icon(
                              DealGoIcons.star,
                              size: 14,
                              color: DealGoColors.amber,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                l10n.driverCardRating(
                                  formatRatingAverage(context, average),
                                  card.ratingCount,
                                ),
                                key: const Key('driver-detail-rating'),
                                style: textTheme.bodySmall?.copyWith(
                                  color: DealGoColors.textSecondary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          l10n.driverCardNew,
                          key: const Key('driver-detail-new'),
                          style: textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: DealGoColors.primary,
                          ),
                        ),
                      if (trips != null)
                        Text(
                          l10n.driverCardTrips(formatTripCount(context, trips)),
                          key: const Key('driver-detail-trips'),
                          style: textTheme.bodySmall?.copyWith(
                            color: DealGoColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (vehicleName != null)
              _Fact(label: l10n.driverDetailVehicle, value: vehicleName)
            else if (classLabel != null)
              _Fact(label: l10n.driverDetailVehicle, value: classLabel),
            if (plate != null)
              _Fact(
                label: l10n.driverDetailPlate,
                value: plate,
                valueKey: const Key('driver-detail-plate'),
              ),
            if (vehicleName != null &&
                classLabel != null &&
                classLabel != vehicleName)
              _Fact(
                label: l10n.driverDetailClass,
                value: classLabel,
                valueKey: const Key('driver-detail-class'),
              ),
            if (phone != null) ...[
              const SizedBox(height: DealGoSpacing.s16),
              Align(
                alignment: Alignment.centerLeft,
                child: ContactPhoneLine(phone: phone),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DriverAvatar extends StatelessWidget {
  const _DriverAvatar({
    required this.name,
    required this.imageUrl,
    this.onOpen,
  });

  final String name;
  final String? imageUrl;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    final initial = Text(
      name.characters.first.toUpperCase(),
      style: Theme.of(context).textTheme.titleLarge
          ?.copyWith(color: DealGoColors.primary, fontWeight: FontWeight.w800),
    );
    Widget photoMark() => ColoredBox(
      color: DealGoColors.subtlePurple,
      child: Center(
        child: Text(
          name.characters.first.toUpperCase(),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: DealGoColors.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
    final mark = url == null
        ? CircleAvatar(
            key: const Key('driver-detail-avatar'),
            radius: 32,
            backgroundColor: DealGoColors.subtlePurple,
            child: initial,
          )
        : ClipOval(
            child: SizedBox(
              key: const Key('driver-detail-avatar'),
              width: 64,
              height: 64,
              child: DealGoNetworkImage(
                url,
                width: 64,
                height: 64,
                placeholder: photoMark(),
                fallback: photoMark(),
              ),
            ),
          );
    final open = onOpen;
    if (open == null) return mark;
    final l10n = AppLocalizations.of(context);
    return Semantics(
      button: true,
      label: l10n.driverAvatarOpen,
      child: InkWell(
        key: const Key('driver-detail-avatar-open'),
        customBorder: const CircleBorder(),
        onTap: open,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            mark,
            Positioned(
              right: -2,
              bottom: -2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: DealGoColors.card,
                  shape: BoxShape.circle,
                  border: Border.all(color: DealGoColors.border),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(3),
                  child: Icon(
                    DealGoIcons.image,
                    size: 12,
                    color: DealGoColors.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value, this.valueKey});

  final String label;
  final String value;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: DealGoSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: textTheme.labelSmall?.copyWith(
              color: DealGoColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            key: valueKey,
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
