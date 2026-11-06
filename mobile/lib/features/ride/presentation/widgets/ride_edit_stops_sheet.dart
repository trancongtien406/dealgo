import 'package:flutter/material.dart';

import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/motion/dealgo_sheet.dart';
import '../../../../core/maps/map_lat_lng.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../places/presentation/place_picker_page.dart';
import '../../domain/entities/ride_models.dart';

/// Picks a stop place; injectable so tests skip the real picker route.
typedef RideStopPicker = Future<RidePoint?> Function(BuildContext context);

Future<RidePoint?> defaultRideStopPicker(
  BuildContext context, {
  MapLatLng? near,
}) async {
  final place = await pickPlace(context, PlacePickPurpose.dropoff, near: near);
  if (place == null) {
    return null;
  }
  return RidePoint(lat: place.lat, lng: place.lng, label: place.label);
}

/// Customer edits the stop list of a NEGOTIATING ride. Resolves with the new
/// list (possibly empty) or null when dismissed / unchanged.
Future<List<RidePoint>?> showRideEditStopsSheet({
  required BuildContext context,
  required List<RidePoint> current,
  required int maxStops,
  required RideStopPicker pick,
}) {
  return showDealGoSheet<List<RidePoint>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) =>
        _EditStopsSheet(current: current, maxStops: maxStops, pick: pick),
  );
}

class _EditStopsSheet extends StatefulWidget {
  const _EditStopsSheet({
    required this.current,
    required this.maxStops,
    required this.pick,
  });

  final List<RidePoint> current;
  final int maxStops;
  final RideStopPicker pick;

  @override
  State<_EditStopsSheet> createState() => _EditStopsSheetState();
}

class _EditStopsSheetState extends State<_EditStopsSheet> {
  late final List<RidePoint> _stops = [...widget.current];

  bool get _changed {
    if (_stops.length != widget.current.length) {
      return true;
    }
    for (var i = 0; i < _stops.length; i++) {
      final a = _stops[i];
      final b = widget.current[i];
      if (a.lat != b.lat || a.lng != b.lng || a.label != b.label) {
        return true;
      }
    }
    return false;
  }

  Future<void> _add() async {
    final point = await widget.pick(context);
    if (!mounted || point == null) {
      return;
    }
    setState(() => _stops.add(point));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DealGoSpacing.s16,
        DealGoSpacing.s16,
        DealGoSpacing.s16,
        DealGoSpacing.s16,
      ),
      child: Column(
        key: const Key('ride-edit-stops-sheet'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.rideEditStops,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: DealGoSpacing.s4),
          Text(
            l10n.rideStopsMax(widget.maxStops),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: DealGoSpacing.s12),
          if (_stops.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: DealGoSpacing.s8),
              child: Text(l10n.rideStopsNone),
            ),
          for (var i = 0; i < _stops.length; i++)
            ListTile(
              key: Key('ride-edit-stop-$i'),
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                radius: 12,
                backgroundColor: DealGoColors.amber,
                child: Text(
                  '${i + 1}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
              title: Text(l10n.rideStopNumbered(i + 1)),
              subtitle: Text(_stops[i].label),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (i > 0)
                    IconButton(
                      key: Key('ride-edit-stop-up-$i'),
                      tooltip: l10n.rideMoveStopUp,
                      icon: const Icon(DealGoIcons.chevronUp),
                      onPressed: () => setState(() {
                        final s = _stops.removeAt(i);
                        _stops.insert(i - 1, s);
                      }),
                    ),
                  IconButton(
                    key: Key('ride-edit-stop-remove-$i'),
                    tooltip: l10n.rideRemoveStop,
                    icon: const Icon(DealGoIcons.close),
                    onPressed: () => setState(() => _stops.removeAt(i)),
                  ),
                ],
              ),
            ),
          if (_stops.length < widget.maxStops)
            TextButton.icon(
              key: const Key('ride-edit-stop-add'),
              onPressed: _add,
              icon: const Icon(DealGoIcons.add),
              label: Text(l10n.rideAddStop),
            ),
          const SizedBox(height: DealGoSpacing.s12),
          DealGoPrimaryButton(
            key: const Key('ride-edit-stops-save'),
            label: l10n.rideEditStopsSave,
            enabled: _changed,
            onPressed: () =>
                Navigator.of(context).pop(List<RidePoint>.of(_stops)),
          ),
        ],
      ),
    );
  }
}
