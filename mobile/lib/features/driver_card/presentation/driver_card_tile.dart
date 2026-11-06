import '../../../core/config/api_base_url.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/design_system/components/dealgo_image_cache.dart';
import '../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../core/design_system/icons/dealgo_icons.dart';
import '../../../core/network/api_exception.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/driver_card.dart';
import 'contact_phone_line.dart';
import 'driver_detail_sheet.dart';

/// Formats an average rating with the locale's decimal separator ("4,8").
String formatRatingAverage(BuildContext context, double average) {
  final text = average.toStringAsFixed(1);
  return Localizations.localeOf(context).languageCode == 'vi'
      ? text.replaceAll('.', ',')
      : text;
}

/// "1.234" in Vietnamese, "1,234" in English.
String formatTripCount(BuildContext context, int count) =>
    NumberFormat.decimalPattern(Localizations.localeOf(context).toLanguageTag())
        .format(count);

/// Loads the driver of the customer's own job (`GET /v1/rides/:id/driver`,
/// `/v1/rides/:id/offers/:offerId/driver` or `/v1/food/orders/:id/courier`)
/// and hands it to [builder]; null while loading, offline or unassigned.
class DriverCardLoader extends StatefulWidget {
  const DriverCardLoader({
    required this.job,
    required this.jobId,
    required this.accessToken,
    required this.builder,
    this.offerId,
    this.assigned = true,
    this.refreshKey,
    this.onLoaded,
    super.key,
  });

  final DriverCardJob job;
  final String jobId;
  final String accessToken;
  final String? offerId;

  /// Whether the job already has a driver; nothing is fetched until it does.
  final bool assigned;

  /// Reloads when it changes (e.g. the job status, so the phone appears and
  /// disappears with the server's sharing window).
  final Object? refreshKey;
  final ValueChanged<DriverCard>? onLoaded;
  final Widget Function(BuildContext context, DriverCard? card) builder;

  @override
  State<DriverCardLoader> createState() => _DriverCardLoaderState();
}

class _DriverCardLoaderState extends State<DriverCardLoader> {
  DriverCard? _card;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(DriverCardLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.jobId != widget.jobId ||
        oldWidget.offerId != widget.offerId ||
        oldWidget.refreshKey != widget.refreshKey ||
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
        widget.onLoaded?.call(card);
      }
    } on ApiException {
      // Not assigned yet / offline: keep the neutral fallback row.
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _card);
}

/// Driver row for the customer's own job, loaded from the backend. Shows only
/// what the driver really declared; nothing is invented when a field is empty.
class DriverCardTile extends StatelessWidget {
  const DriverCardTile({
    required this.job,
    required this.jobId,
    required this.accessToken,
    this.offerId,
    this.assigned = true,
    this.refreshKey,
    this.onLoaded,
    this.trailing,
    this.openDetail = true,
    super.key,
  });

  final DriverCardJob job;
  final String jobId;
  final String accessToken;
  final String? offerId;
  final bool assigned;
  final Object? refreshKey;
  final ValueChanged<DriverCard>? onLoaded;
  final Widget? trailing;
  final bool openDetail;

  @override
  Widget build(BuildContext context) => DriverCardLoader(
    job: job,
    jobId: jobId,
    accessToken: accessToken,
    offerId: offerId,
    assigned: assigned,
    refreshKey: refreshKey,
    onLoaded: onLoaded,
    builder: (context, card) => DriverCardRow(
      card: card,
      trailing: trailing,
      onOpenDetail: openDetail && card != null
          ? () => showDriverDetailSheet(context, card)
          : null,
    ),
  );
}

/// Avatar, full name, rating, the driver's own vehicle and — while the job is
/// running — their phone with a dial button.
class DriverCardRow extends StatelessWidget {
  const DriverCardRow({
    required this.card,
    this.trailing,
    this.onOpenDetail,
    super.key,
  });

  final DriverCard? card;
  final Widget? trailing;
  final VoidCallback? onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final card = this.card;
    final name = (card == null || card.displayName.isEmpty)
        ? l10n.rideTrackDriverFallback
        : card.displayName;
    final average = card?.ratingAverage;
    // t81u: real stars only; a driver without ratings shows "Mới" (no "0 sao").
    final rated = card != null && average != null && card.ratingCount > 0;
    final trips = card?.completedTrips;
    final vehicle = card?.vehicleLine;
    final phone = card?.phone;
    final avatar = resolveMediaUrl(card?.avatarUrl);
    final onOpenDetail = this.onOpenDetail;
    final row = Row(
      key: const Key('driver-card-tile'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          key: const Key('driver-card-avatar'),
          radius: 26,
          backgroundColor: DealGoColors.subtlePurple,
          foregroundImage: avatar == null
              ? null
              : DealGoImageCache.provider(avatar, decodeWidth: 260),
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
              // A long name wraps onto its own lines instead of being cut;
              // the rating follows it.
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                children: [
                  Text(
                    name,
                    key: const Key('driver-card-name'),
                    style: textTheme.titleMedium,
                  ),
                  if (card != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (rated) ...[
                          Text(
                            formatRatingAverage(context, average),
                            key: const Key('driver-card-rating'),
                            style: textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: DealGoColors.text,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(
                            DealGoIcons.star,
                            size: 13,
                            color: DealGoColors.amber,
                          ),
                        ] else
                          Text(
                            l10n.driverCardNew,
                            key: const Key('driver-card-new'),
                            style: textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: DealGoColors.primary,
                            ),
                          ),
                        if (trips != null && trips > 0)
                          Text(
                            ' · ${l10n.driverCardTrips(formatTripCount(context, trips))}',
                            key: const Key('driver-card-trips'),
                            style: textTheme.labelSmall?.copyWith(
                              color: DealGoColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                ],
              ),
              if (vehicle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    vehicle,
                    key: const Key('driver-card-vehicle'),
                    style: textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: DealGoColors.text,
                    ),
                  ),
                ),
              if (phone != null) ...[
                const SizedBox(height: DealGoSpacing.s8),
                ContactPhoneLine(phone: phone),
              ],
            ],
          ),
        ),
        if (onOpenDetail != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 4),
            child: Icon(
              DealGoIcons.chevronRight,
              size: 18,
              color: DealGoColors.textSecondary,
            ),
          ),
        if (trailing != null) ...[
          const SizedBox(width: DealGoSpacing.s8),
          trailing!,
        ],
      ],
    );
    if (onOpenDetail == null) return row;
    return Semantics(
      button: true,
      label: l10n.driverDetailOpen,
      child: InkWell(
        key: const Key('driver-card-open-detail'),
        onTap: onOpenDetail,
        borderRadius: BorderRadius.circular(DealGoRadius.card),
        child: row,
      ),
    );
  }
}
