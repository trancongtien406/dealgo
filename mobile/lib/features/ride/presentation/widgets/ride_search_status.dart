import 'package:flutter/material.dart';

import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/ride_money.dart';

/// How many drivers currently have this request open.
class RideViewerBanner extends StatelessWidget {
  const RideViewerBanner({required this.count, super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final watching = count > 0;
    final faces = watching ? (count > 3 ? 3 : count) : 0;
    return DecoratedBox(
      key: const Key('ride-viewers'),
      decoration: BoxDecoration(
        color: watching ? DealGoColors.greenSurface : DealGoColors.lavender,
        borderRadius: BorderRadius.circular(DealGoRadius.card),
        border: Border.all(
          color: watching
              ? DealGoColors.brandGreen.withValues(alpha: 0.28)
              : DealGoColors.border,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DealGoSpacing.s12,
          vertical: DealGoSpacing.s12,
        ),
        child: Row(
          children: [
            if (faces == 0) const _ViewerMark() else _ViewerStack(count: faces),
            const SizedBox(width: DealGoSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    watching
                        ? l10n.rideViewersCount(count)
                        : l10n.rideViewersNotifying,
                    key: const Key('ride-viewers-title'),
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    watching ? l10n.rideViewersNotifying : l10n.rideViewersNone,
                    style: text.bodySmall?.copyWith(
                      color: DealGoColors.textSecondary,
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

class _ViewerMark extends StatelessWidget {
  const _ViewerMark();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DealGoColors.card,
        shape: BoxShape.circle,
      ),
      child: SizedBox(
        width: 40,
        height: 40,
        child: Icon(
          DealGoIcons.visibility,
          color: DealGoColors.primary,
          size: 20,
        ),
      ),
    );
  }
}

class _ViewerStack extends StatelessWidget {
  const _ViewerStack({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    const size = 32.0;
    const overlap = 12.0;
    final width = size + (count - 1) * (size - overlap);
    return SizedBox(
      width: width,
      height: size,
      child: Stack(
        children: [
          for (var i = 0; i < count; i++)
            Positioned(
              left: i * (size - overlap),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: i.isEven
                      ? DealGoColors.subtlePurple
                      : DealGoColors.card,
                  shape: BoxShape.circle,
                  border: Border.all(color: DealGoColors.card, width: 2),
                ),
                child: const SizedBox(
                  width: size,
                  height: size,
                  child: Icon(
                    DealGoIcons.userRound,
                    size: 16,
                    color: DealGoColors.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Opt in to taking a driver who agrees to the customer's exact fare.
class RideAutoAcceptSwitch extends StatelessWidget {
  const RideAutoAcceptSwitch({
    required this.priceVnd,
    required this.enabled,
    required this.busy,
    required this.onChanged,
    super.key,
  });

  final int priceVnd;
  final bool enabled;
  final bool busy;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final price = formatRideVnd(priceVnd);
    return DecoratedBox(
      key: const Key('ride-auto-accept'),
      decoration: BoxDecoration(
        color: DealGoColors.card,
        borderRadius: BorderRadius.circular(DealGoRadius.card),
        border: Border.all(color: DealGoColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          DealGoSpacing.s12,
          DealGoSpacing.s8,
          DealGoSpacing.s4,
          DealGoSpacing.s8,
        ),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: DealGoColors.lavender,
                shape: BoxShape.circle,
              ),
              child: SizedBox(
                width: 36,
                height: 36,
                child: Icon(
                  DealGoIcons.bolt,
                  color: DealGoColors.primary,
                  size: 18,
                ),
              ),
            ),
            const SizedBox(width: DealGoSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.rideAutoAcceptLabel(price),
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.rideAutoAcceptHint,
                    style: text.bodySmall?.copyWith(
                      color: DealGoColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              key: const Key('ride-auto-accept-switch'),
              value: enabled,
              onChanged: busy ? null : onChanged,
              thumbColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return DealGoColors.card;
                }
                return DealGoColors.textSecondary;
              }),
              trackColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return DealGoColors.brandGreen;
                }
                return DealGoColors.border;
              }),
            ),
          ],
        ),
      ),
    );
  }
}
