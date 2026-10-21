import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../core/design_system/icons/dealgo_icons.dart';
import '../../../core/network/api_exception.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/driver_card.dart';

/// Formats an average rating with the locale's decimal separator ("4,8").
String formatRatingAverage(BuildContext context, double average) {
  final text = average.toStringAsFixed(1);
  return Localizations.localeOf(context).languageCode == 'vi'
      ? text.replaceAll('.', ',')
      : text;
}

/// Driver row for the customer's own job, loaded from the backend
/// (`GET /v1/rides/:id/driver` or `/v1/food/orders/:id/courier`). Shows only
/// what the driver really declared; nothing is invented when a field is empty.
class DriverCardTile extends StatefulWidget {
  const DriverCardTile({
    required this.job,
    required this.jobId,
    required this.accessToken,
    this.offerId,
    this.assigned = true,
    this.trailing,
    super.key,
  });

  final DriverCardJob job;
  final String jobId;
  final String accessToken;
  final String? offerId;

  /// Whether the job already has a driver; nothing is fetched until it does.
  final bool assigned;
  final Widget? trailing;

  @override
  State<DriverCardTile> createState() => _DriverCardTileState();
}

class _DriverCardTileState extends State<DriverCardTile> {
  DriverCard? _card;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(DriverCardTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.jobId != widget.jobId ||
        (!oldWidget.assigned && widget.assigned)) {
      _load();
    }
  }

  Future<void> _load() async {
    if (!widget.assigned || widget.accessToken.isEmpty) {
      return;
    }
    try {
      final card = await context.read<DriverCardRepository>().fetch(
        accessToken: widget.accessToken,
        job: widget.job,
        jobId: widget.jobId,
        offerId: widget.offerId,
      );
      if (mounted) {
        setState(() => _card = card);
      }
    } on ApiException {
      // Not assigned yet / offline: keep the neutral fallback row.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final card = _card;
    final name = (card == null || card.displayName.isEmpty)
        ? l10n.rideTrackDriverFallback
        : card.displayName;
    final average = card?.ratingAverage;
    final rating = card == null
        ? null
        : (average == null || card.ratingCount == 0)
        ? l10n.driverCardNoRating
        : l10n.driverCardRating(
            formatRatingAverage(context, average),
            card.ratingCount,
          );
    final vehicle = card?.vehicleLine;
    return Row(
      key: const Key('driver-card-tile'),
      children: [
        CircleAvatar(
          backgroundColor: DealGoColors.subtlePurple,
          child: Text(
            name.characters.first.toUpperCase(),
            style: const TextStyle(
              color: DealGoColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: DealGoSpacing.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                key: const Key('driver-card-name'),
                style: textTheme.titleMedium,
              ),
              if (vehicle != null)
                Text(
                  vehicle,
                  key: const Key('driver-card-vehicle'),
                  style: textTheme.bodySmall,
                ),
              if (rating != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      DealGoIcons.star,
                      size: 12,
                      color: DealGoColors.amber,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        rating,
                        key: const Key('driver-card-rating'),
                        style: textTheme.bodySmall?.copyWith(
                          color: DealGoColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        ?widget.trailing,
      ],
    );
  }
}
