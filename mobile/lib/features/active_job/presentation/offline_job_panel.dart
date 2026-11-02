import 'package:flutter/material.dart';

import '../../../core/design_system/components/dealgo_card.dart';
import '../../../core/design_system/components/tracking_layout.dart';
import '../../../core/design_system/icons/dealgo_icons.dart';
import '../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../driver_card/presentation/driver_card_tile.dart';
import '../../driver_card/presentation/driver_detail_sheet.dart';
import '../../ride/domain/entities/ride_money.dart';
import '../domain/active_job_snapshot.dart';
import 'active_job_cache.dart';

/// Loads the cached snapshot of job [id] once; [builder] gets null while
/// reading, when nothing usable is cached or outside the app's providers.
class ActiveJobSnapshotBuilder extends StatefulWidget {
  const ActiveJobSnapshotBuilder({
    required this.id,
    required this.builder,
    super.key,
  });

  final String id;
  final Widget Function(
    BuildContext context,
    ActiveJobSnapshot? snapshot,
    bool waiting,
  )
  builder;

  @override
  State<ActiveJobSnapshotBuilder> createState() =>
      _ActiveJobSnapshotBuilderState();
}

class _ActiveJobSnapshotBuilderState extends State<ActiveJobSnapshotBuilder> {
  late Future<ActiveJobSnapshot?> _lookup;

  @override
  void initState() {
    super.initState();
    _lookup = _read();
  }

  @override
  void didUpdateWidget(ActiveJobSnapshotBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) _lookup = _read();
  }

  Future<ActiveJobSnapshot?> _read() async =>
      maybeActiveJobCache(context)?.lookup(id: widget.id);

  @override
  Widget build(BuildContext context) => FutureBuilder<ActiveJobSnapshot?>(
    future: _lookup,
    builder: (context, result) => widget.builder(
      context,
      result.data,
      result.connectionState != ConnectionState.done,
    ),
  );
}

/// The last server copy of a job shown without network: who is coming (with
/// a phone dial that needs no data), the handover code, places and price.
class OfflineJobPanel extends StatelessWidget {
  const OfflineJobPanel({
    required this.snapshot,
    required this.statusTitle,
    super.key,
  });

  final ActiveJobSnapshot snapshot;
  final String statusTitle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final isRide = snapshot.kind == ActiveJobKind.ride;
    final driver = snapshot.driver;
    final code = snapshot.code;
    final amount = snapshot.amountVnd;
    final cashDue = snapshot.cashDueVnd;
    final updatedAt = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(snapshot.savedAt.toLocal()),
      alwaysUse24HourFormat: true,
    );
    return DealGoCard(
      key: const Key('offline-job-panel'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            statusTitle,
            key: const Key('offline-job-status'),
            style: textTheme.titleMedium,
          ),
          const SizedBox(height: DealGoSpacing.s4),
          Text(
            l10n.offlineJobUpdatedAt(updatedAt),
            key: const Key('offline-job-updated-at'),
            style: textTheme.bodySmall?.copyWith(
              color: DealGoColors.textSecondary,
            ),
          ),
          if (driver case final card?)
            TrackingSection(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DriverCardRow(
                    card: card,
                    onOpenDetail: () => showDriverDetailSheet(context, card),
                  ),
                  if (card.phone != null) ...[
                    const SizedBox(height: DealGoSpacing.s8),
                    Text(
                      l10n.offlineJobCallHint,
                      key: const Key('offline-job-call-hint'),
                      style: textTheme.bodySmall?.copyWith(
                        color: DealGoColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          if (code != null)
            TrackingSection(
              child: TrackingCodeRow(
                key: const Key('offline-job-code-row'),
                icon: DealGoIcons.shield,
                label: isRide
                    ? l10n.ridePickupCodeTitle
                    : l10n.foodDeliveryCodeTitle,
                code: isRide ? code.split('').join(' ') : code,
                codeKey: const Key('offline-job-code'),
              ),
            ),
          TrackingSection(
            child: Column(
              children: [
                if (snapshot.storeName case final store?)
                  _Line(label: l10n.foodInvoiceStore, value: store),
                if (isRide && snapshot.pickupLabel != null)
                  _Line(label: l10n.ridePickup, value: snapshot.pickupLabel!),
                for (final stop in snapshot.stopLabels)
                  _Line(label: '•', value: stop),
                if (snapshot.dropoffLabel case final dropoff?)
                  _Line(
                    label: isRide
                        ? l10n.rideDropoff
                        : l10n.merchantQueueDeliverTo,
                    value: dropoff,
                  ),
              ],
            ),
          ),
          if (amount != null)
            TrackingSection(
              child: Column(
                children: [
                  _Line(
                    label: isRide
                        ? l10n.rideAgreedFare
                        : l10n.foodTrackingCodDue,
                    value: formatRideVnd(amount),
                    emphasize: cashDue == null,
                  ),
                  if (cashDue != null)
                    _Line(
                      label: l10n.rideCashDueLabel,
                      value: formatRideVnd(cashDue),
                      emphasize: true,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Text(
              label,
              style: textTheme.bodyMedium?.copyWith(
                color: DealGoColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: DealGoSpacing.s16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: emphasize
                  ? textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)
                  : textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
