import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../core/design_system/icons/dealgo_icons.dart';
import '../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../places/presentation/place_picker_page.dart';
import '../../ride/presentation/cubit/ride_destination.dart';

/// C001 service tiles: one Ride entry (class chosen in booking flow) + Food.
/// DG-DEC-VEH-001: MOTORBIKE + CAR live under the same Ride booking path.
class ServiceRow extends StatelessWidget {
  const ServiceRow({required this.onRide, required this.onFood, super.key});

  final VoidCallback onRide;
  final VoidCallback onFood;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _ServiceCard(
              key: const Key('home-service-ride'),
              title: l10n.serviceRideTitle,
              subtitle: l10n.homeServiceRideSub,
              fallbackColor: DealGoColors.subtlePurple,
              iconBackground: DealGoColors.primary,
              icon: DealGoIcons.motorbike,
              backgroundArt: 'assets/images/service_ride_bg.png',
              onTap: onRide,
            ),
          ),
          const SizedBox(width: DealGoSpacing.s12),
          Expanded(
            child: _ServiceCard(
              key: const Key('home-service-food'),
              title: l10n.homeCatFood,
              subtitle: l10n.homeServiceFoodSub,
              fallbackColor: DealGoColors.greenSurface,
              iconBackground: DealGoColors.brandGreen,
              icon: DealGoIcons.shoppingBag,
              backgroundArt: 'assets/images/service_food_bg.png',
              onTap: onFood,
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.title,
    required this.subtitle,
    required this.fallbackColor,
    required this.iconBackground,
    required this.icon,
    required this.backgroundArt,
    required this.onTap,
    super.key,
  });

  final String title;
  final String subtitle;
  final Color fallbackColor;
  final Color iconBackground;
  final IconData icon;
  final String backgroundArt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // On a 320 pt phone each card is ~140 pt wide: the subtitle would shrink
    // to unreadable size under the art, so keep just the title there.
    final body = LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 160;
        return Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              backgroundArt,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              filterQuality: FilterQuality.high,
              errorBuilder: (context, error, stack) {
                return ColoredBox(color: fallbackColor);
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 10, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: 0.55,
                  heightFactor: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _IconChip(
                        background: iconBackground,
                        icon: icon,
                        foreground: Colors.white,
                      ),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.bottomLeft,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.titleMedium?.copyWith(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: DealGoColors.text,
                                  height: 1.1,
                                ),
                              ),
                              if (!compact) ...[
                                const SizedBox(height: 2),
                                Text(
                                  subtitle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.bodySmall?.copyWith(
                                    height: 1.15,
                                    fontSize: 11,
                                    color: DealGoColors.textSecondary,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 4),
                              const _ArrowChip(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
    return Material(
      color: fallbackColor,
      borderRadius: BorderRadius.circular(DealGoRadius.card),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: AspectRatio(aspectRatio: 4 / 3, child: body),
      ),
    );
  }
}

class _IconChip extends StatelessWidget {
  const _IconChip({
    required this.background,
    required this.icon,
    required this.foreground,
  });

  final Color background;
  final IconData icon;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: SizedBox(
        width: 30,
        height: 30,
        child: Icon(icon, color: foreground, size: 16),
      ),
    );
  }
}

class _ArrowChip extends StatelessWidget {
  const _ArrowChip();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const SizedBox(
        width: 26,
        height: 26,
        child: Icon(DealGoIcons.arrowRight, color: DealGoColors.text, size: 16),
      ),
    );
  }
}

class QuickBookCard extends StatelessWidget {
  const QuickBookCard({required this.onBook, super.key});

  final VoidCallback onBook;

  Future<void> _pickDestination(BuildContext context) async {
    final destination = context.read<RideDestinationCubit>();
    final place = await pickPlace(context, PlacePickPurpose.dropoff);
    if (place == null || !context.mounted) {
      return;
    }
    destination.choose(place);
    onBook();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DealGoColors.card,
        borderRadius: BorderRadius.circular(DealGoRadius.button),
        border: Border.all(color: DealGoColors.border),
        boxShadow: DealGoShadows.card,
      ),
      child: Padding(
        padding: const EdgeInsets.all(DealGoSpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  DealGoIcons.car,
                  color: DealGoColors.primary,
                  size: 20,
                ),
                const SizedBox(width: DealGoSpacing.s8),
                Expanded(
                  child: Text(
                    l10n.homeQuickBookTitle,
                    style: textTheme.titleMedium,
                  ),
                ),
                const _VehicleChip(),
              ],
            ),
            const SizedBox(height: DealGoSpacing.s12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      _StopLine(
                        color: DealGoColors.brandGreen,
                        label: l10n.ridePickup,
                        value: l10n.homeQuickBookPickup,
                        style: textTheme,
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 3),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            width: 2,
                            height: 14,
                            margin: const EdgeInsets.symmetric(vertical: 2),
                            color: DealGoColors.border,
                          ),
                        ),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          key: const Key('home-where-to'),
                          borderRadius: BorderRadius.circular(
                            DealGoRadius.input,
                          ),
                          onTap: () => _pickDestination(context),
                          child: _StopLine(
                            color: DealGoColors.danger,
                            label: l10n.rideDropoff,
                            value: l10n.rideWhereTo,
                            style: textTheme,
                            muted: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: DealGoSpacing.s4),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: DealGoColors.canvas,
                    shape: BoxShape.circle,
                    border: Border.all(color: DealGoColors.border),
                  ),
                  child: IconButton(
                    onPressed: () => _pickDestination(context),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 36,
                      height: 36,
                    ),
                    icon: const Icon(
                      DealGoIcons.swapVert,
                      color: DealGoColors.textSecondary,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: DealGoSpacing.s8),
                const SizedBox(
                  height: 72,
                  child: VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: DealGoColors.border,
                  ),
                ),
                const SizedBox(width: DealGoSpacing.s8),
                Flexible(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: DealGoColors.lavender,
                      borderRadius: BorderRadius.circular(DealGoRadius.input),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DealGoSpacing.s8,
                        vertical: DealGoSpacing.s8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.homeQuickBookEstimate,
                            style: textTheme.labelSmall?.copyWith(
                              color: DealGoColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: DealGoSpacing.s2),
                          Text(
                            l10n.homeQuickBookEtaPrice,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleMedium?.copyWith(
                              color: DealGoColors.primary,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: DealGoSpacing.s4),
                          Row(
                            children: [
                              const Icon(
                                DealGoIcons.clock,
                                size: 12,
                                color: DealGoColors.textSecondary,
                              ),
                              const SizedBox(width: DealGoSpacing.s4),
                              Flexible(
                                child: Text(
                                  l10n.homeQuickBookEtaTime,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.labelSmall?.copyWith(
                                    color: DealGoColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: DealGoSpacing.s16),
            DealGoPrimaryButton(
              label: l10n.actionBookRideNow,
              onPressed: onBook,
              trailingIcon: DealGoIcons.arrowRight,
            ),
          ],
        ),
      ),
    );
  }
}

class _VehicleChip extends StatelessWidget {
  const _VehicleChip();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DealGoColors.canvas,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: DealGoColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DealGoSpacing.s8,
          vertical: DealGoSpacing.s4,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppLocalizations.of(context).homeQuickBookVehicle,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: DealGoColors.text,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 2),
            const Icon(
              DealGoIcons.chevronRight,
              size: 14,
              color: DealGoColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _StopLine extends StatelessWidget {
  const _StopLine({
    required this.color,
    required this.label,
    required this.value,
    required this.style,
    this.muted = false,
  });

  final Color color;
  final String label;
  final String value;
  final TextTheme style;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: DecoratedBox(
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: const SizedBox(width: 8, height: 8),
          ),
        ),
        const SizedBox(width: DealGoSpacing.s8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: style.bodySmall),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: style.bodySmall?.copyWith(
                  color: muted ? DealGoColors.textSecondary : DealGoColors.text,
                  fontWeight: muted ? FontWeight.w500 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
