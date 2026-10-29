import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/components/dealgo_chip.dart';
import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/components/dealgo_secondary_button.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/maps/map_controls.dart';
import '../../../../core/maps/map_lat_lng.dart';
import '../../../../core/maps/map_port.dart';
import '../../../../core/maps/route_geometry.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../live_location/domain/map_routing.dart';
import '../../../address_book/domain/repositories/address_book_repository.dart';
import '../../../places/domain/place.dart';
import '../../../places/presentation/current_place.dart';
import '../../../places/presentation/place_picker_page.dart';
import '../../domain/entities/ride_models.dart';
import '../../domain/stops/ride_stops_client.dart';
import '../cubit/ride_destination.dart';
import '../cubit/ride_session.dart';
import '../utils/ride_distance.dart';
import '../utils/ride_routes.dart';
import '../widgets/ride_widgets.dart';

const _suggestionLimit = 5;

/// Fast ride entry (inDrive-like): GPS fills the pickup in the background and
/// the destination picker opens first; the sheet lists pickup on top and the
/// destination below, then map + sheet confirm before class/fare.
class RideMapPage extends StatefulWidget {
  const RideMapPage({super.key});

  @override
  State<RideMapPage> createState() => _RideMapPageState();
}

class _RideMapPageState extends State<RideMapPage> {
  PlaceOption? _pickup;
  PlaceOption? _dropoff;

  /// Intermediate stops (multi-stop; admin-flagged, hidden when off).
  final _stops = <PlaceOption>[];
  var _multiStop = MultiStopSettings.disabled;
  var _locating = false;
  var _suggestions = const <PlaceOption>[];
  var _route = RouteGeometry.unavailable;
  RideDistance? _distance;
  var _routeSeq = 0;
  @override
  void initState() {
    super.initState();
    _dropoff = context.read<RideDestinationCubit>().take();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_locatePickup());
      unawaited(_loadSuggestions());
      unawaited(_loadMultiStop());
      // Destination-first: open picker immediately when nothing pre-filled.
      if (_dropoff == null) {
        unawaited(_pickDropoff(autoOpen: true));
      } else {
        _tryAutoAdvance();
      }
    });
  }

  Future<void> _locatePickup() async {
    setState(() => _locating = true);
    final result =
        await locateCurrentPlace(
          context,
          accessToken: rideAccessToken(context),
        ).timeout(
          const Duration(seconds: 8),
          onTimeout: () => const CurrentPlaceFailed(),
        );
    if (!mounted) {
      return;
    }
    setState(() {
      _locating = false;
      if (result is CurrentPlaceFound && _pickup == null) {
        _pickup = result.place;
      }
    });
    _tryAutoAdvance();
  }

  /// Admin multi-stop flags; any failure keeps the single-destination UI.
  Future<void> _loadMultiStop() async {
    final token = rideAccessToken(context);
    RideStopsClient? client;
    try {
      client = context.read<RideStopsClient>();
    } on ProviderNotFoundException {
      client = null;
    }
    if (token == null || client == null) {
      return;
    }
    MultiStopSettings settings;
    try {
      settings = await client.config(accessToken: token);
    } catch (_) {
      settings = MultiStopSettings.disabled;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _multiStop = settings;
      final max = settings.maxStopsAnyService;
      if (_stops.length > max) {
        _stops.removeRange(max, _stops.length);
      }
    });
  }

  int get _maxStops => _multiStop.maxStopsAnyService;

  Future<void> _addStop() async {
    if (_stops.length >= _maxStops) {
      return;
    }
    final pickup = _pickup;
    final place = await pickPlace(
      context,
      PlacePickPurpose.dropoff,
      near: pickup == null ? null : MapLatLng(lat: pickup.lat, lng: pickup.lng),
    );
    if (!mounted || place == null) {
      return;
    }
    setState(() => _stops.add(place));
    _tryAutoAdvance();
  }

  Future<void> _editStop(int index) async {
    final place = await pickPlace(context, PlacePickPurpose.dropoff);
    if (!mounted || place == null || index >= _stops.length) {
      return;
    }
    setState(() => _stops[index] = place);
    _tryAutoAdvance();
  }

  void _removeStop(int index) {
    setState(() => _stops.removeAt(index));
    _tryAutoAdvance();
  }

  /// Reorder: move stop [index] one place earlier.
  void _moveStopUp(int index) {
    if (index <= 0 || index >= _stops.length) {
      return;
    }
    setState(() {
      final stop = _stops.removeAt(index);
      _stops.insert(index - 1, stop);
    });
    _tryAutoAdvance();
  }

  Future<void> _loadSuggestions() async {
    final token = rideAccessToken(context);
    if (token == null) {
      return;
    }
    final places = context.read<PlacesRepository>();
    final book = context.read<AddressBookRepository>();
    final recent = await places
        .recentDestinations(accessToken: token)
        .then((rows) => rows, onError: (_) => const <PlaceOption>[]);
    final saved = await book
        .list(accessToken: token)
        .then(
          (rows) => [
            for (final row in rows)
              if (row.lat != null && row.lng != null)
                PlaceOption(
                  name: row.label,
                  address: row.addressLine,
                  lat: row.lat!,
                  lng: row.lng!,
                  source: PlaceSource.saved,
                ),
          ],
          onError: (_) => const <PlaceOption>[],
        );
    if (!mounted) {
      return;
    }
    setState(() {
      _suggestions = [...saved, ...recent].take(_suggestionLimit).toList();
    });
  }

  Future<void> _pickDropoff({bool autoOpen = false}) async {
    // Drop-off results rank around the pickup, not wherever the phone is.
    final pickup = _pickup;
    final place = await pickPlace(
      context,
      PlacePickPurpose.dropoff,
      near: pickup == null ? null : MapLatLng(lat: pickup.lat, lng: pickup.lng),
    );
    if (!mounted) {
      return;
    }
    if (place == null) {
      // User dismissed the auto-opened picker — stay on map.
      if (autoOpen) {
        return;
      }
      return;
    }
    setState(() => _dropoff = place);
    _tryAutoAdvance();
  }

  Future<void> _pickPickup() async {
    final place = await pickPlace(context, PlacePickPurpose.pickup);
    if (!mounted || place == null) {
      return;
    }
    setState(() => _pickup = place);
    _tryAutoAdvance();
  }

  void _chooseSuggestion(PlaceOption place) {
    setState(() => _dropoff = place);
    _tryAutoAdvance();
  }

  void _swap() {
    setState(() {
      final pickup = _pickup;
      _pickup = _dropoff;
      _dropoff = pickup;
      final reversed = _stops.reversed.toList();
      _stops
        ..clear()
        ..addAll(reversed);
    });
    _tryAutoAdvance();
  }

  RidePlaces? get _places {
    final pickup = _pickup;
    final dropoff = _dropoff;
    if (pickup == null || dropoff == null) {
      return null;
    }
    final places = RidePlaces(
      pickup: RidePoint(lat: pickup.lat, lng: pickup.lng, label: pickup.label),
      dropoff: RidePoint(
        lat: dropoff.lat,
        lng: dropoff.lng,
        label: dropoff.label,
      ),
      stops: [
        for (final s in _stops)
          RidePoint(lat: s.lat, lng: s.lng, label: s.label),
      ],
    );
    return places.canContinue ? places : null;
  }

  bool get _samePlace {
    final pickup = _pickup;
    final dropoff = _dropoff;
    return pickup != null &&
        dropoff != null &&
        (pickup.lat - dropoff.lat).abs() < 0.0001 &&
        (pickup.lng - dropoff.lng).abs() < 0.0001;
  }

  void _tryAutoAdvance() {
    // inDrive-like: keep map + sheet visible with A/B filled; user taps CTA.
    // (Previously auto-pushed to fare and skipped the confirmation sheet.)
    unawaited(_loadRoute());
  }

  /// A/B chosen → road route + km from Nest `GET /v1/rides/route` (the
  /// server's ROUTING_PROVIDER). Without a road route only a `~` straight-line
  /// km is shown and no line is drawn (never a fake straight polyline).
  Future<void> _loadRoute() async {
    final pickup = _pickup;
    final dropoff = _dropoff;
    final seq = ++_routeSeq;
    if (pickup == null || dropoff == null || _samePlace) {
      if (_distance != null || _route.hasRoadPolyline) {
        setState(() {
          _route = RouteGeometry.unavailable;
          _distance = null;
        });
      }
      return;
    }
    final a = MapLatLng(lat: pickup.lat, lng: pickup.lng);
    final b = MapLatLng(lat: dropoff.lat, lng: dropoff.lng);
    final via = [for (final s in _stops) MapLatLng(lat: s.lat, lng: s.lng)];
    // Straight-line estimate right away; replaced by the road km when ready.
    var straightKm = 0.0;
    var from = a;
    for (final point in [...via, b]) {
      straightKm += haversineKm(from, point);
      from = point;
    }
    setState(() {
      _route = RouteGeometry.unavailable;
      _distance = RideDistance(km: straightKm, road: false);
    });
    final token = rideAccessToken(context);
    MapRoutingRepository? routing;
    try {
      routing = context.read<MapRoutingRepository>();
    } on ProviderNotFoundException {
      routing = null;
    }
    if (token == null || routing == null) {
      return;
    }
    RouteGeometry route;
    try {
      route = await routing.route(accessToken: token, from: a, to: b, via: via);
    } catch (_) {
      route = RouteGeometry.unavailable;
    }
    if (!mounted || seq != _routeSeq) {
      return;
    }
    setState(() {
      _route = route;
      _distance = route.hasRoadPolyline || via.isEmpty
          ? RideDistance.from(route, a, b)
          : RideDistance(km: straightKm, road: false);
    });
  }

  void _continue() {
    final places = _places;
    if (places == null || _samePlace) {
      return;
    }
    // inDrive-like hot path: A/B → class+fare sheet (skip overview hop).
    context.push(RideRoutes.fare, extra: places);
  }

  /// Book is a tab root with the bar hidden: back returns to Home (the tab
  /// keeps its state in the indexed stack) unless something sits above it.
  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      // Leaving the booking tab abandons this draft.
      _resetDraft();
      context.go('/customer');
    }
  }

  /// The tab stays alive in the shell, so a used or abandoned A/B would
  /// otherwise greet the next booking. Pickup is located again from GPS;
  /// recent places stay suggestions only.
  void _resetDraft() {
    setState(() {
      _pickup = null;
      _dropoff = null;
      _stops.clear();
      _route = RouteGeometry.unavailable;
      _distance = null;
      _routeSeq++;
    });
    unawaited(_locatePickup());
    unawaited(_loadSuggestions());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final pendingRideId = context.watch<RideSessionCubit>().state;
    final pickup = _pickup;
    final dropoff = _dropoff;
    final center = pickup != null
        ? MapLatLng(lat: pickup.lat, lng: pickup.lng)
        : dropoff != null
        ? MapLatLng(lat: dropoff.lat, lng: dropoff.lng)
        : danangViewportCenter;

    return MultiBlocListener(
      listeners: [
        BlocListener<RideDestinationCubit, PlaceOption?>(
          listenWhen: (_, next) => next != null,
          listener: (context, _) {
            final place = context.read<RideDestinationCubit>().take();
            if (place != null) {
              setState(() {
                _dropoff = place;
              });
              _tryAutoAdvance();
            }
          },
        ),
        // A ride was created from this draft: it is used up. Cancelling or
        // finishing that ride then starts from an empty tab, while a ride
        // still waiting for offers stays one tap away ("ride-open-pending").
        BlocListener<RideSessionCubit, String?>(
          listenWhen: (previous, next) => next != null && next != previous,
          listener: (context, _) => _resetDraft(),
        ),
      ],
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) {
            _back();
          }
        },
        child: Material(
          color: DealGoColors.canvas,
          child: Stack(
            children: [
              Positioned.fill(
                child: Builder(
                  builder: (context) {
                    final media = MediaQuery.of(context);
                    return context.watch<MapPort>().buildMap(
                      center: center,
                      markers: [
                        if (pickup != null)
                          MapLatLng(lat: pickup.lat, lng: pickup.lng),
                        for (final s in _stops)
                          MapLatLng(lat: s.lat, lng: s.lng),
                        if (dropoff != null)
                          MapLatLng(lat: dropoff.lat, lng: dropoff.lng),
                      ],
                      // Destination-first: B alone must read "Đến", not "Đón".
                      firstMarkerIsPickup: pickup != null,
                      // Road line from Nest routing; never a straight A→B.
                      route: _route.polylineOr(const []),
                      fitPadding: EdgeInsets.fromLTRB(
                        40,
                        // Status bar + the full stop pin (chip above the tip) + margin.
                        media.padding.top + 80,
                        40,
                        media.size.height * 0.44,
                      ),
                    );
                  },
                ),
              ),
              // Tab root with the bar hidden: map stays full-bleed, floating
              // back on the left, map controls on the right.
              MapBackOverlay(
                buttonKey: const Key('ride-map-back'),
                onPressed: _back,
              ),
              Positioned(
                right: DealGoDimensions.pageGutter,
                top: MediaQuery.paddingOf(context).top + DealGoSpacing.s8,
                child: MapSideControls(
                  stylesAvailable: mapStylesAvailable(context.watch<MapPort>()),
                  locateKey: const Key('ride-map-recenter'),
                  onLocate: _locating ? null : _locatePickup,
                ),
              ),
              RideDraggableSheet(
                initialChildSize: 0.42,
                minChildSize: 0.26,
                // QA C8: stop the expanded sheet below the floating back
                // button so it never sits on the "Điểm đón" label.
                maxChildSize: rideSheetMaxSize(MediaQuery.of(context)),
                snapSizes: rideSheetSnapSizes(const [
                  0.26,
                  0.42,
                  0.68,
                ], rideSheetMaxSize(MediaQuery.of(context))),
                builder: (context, scrollController) {
                  return Column(
                    children: [
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(
                            DealGoDimensions.pageGutter,
                            DealGoSpacing.s12,
                            DealGoDimensions.pageGutter,
                            DealGoSpacing.s8,
                          ),
                          children: [
                            const RideSheetHandle(),
                            const SizedBox(height: DealGoSpacing.s12),
                            Text(l10n.rideWhereTo, style: textTheme.titleLarge),
                            const SizedBox(height: DealGoSpacing.s12),
                            // Pickup on top, destination below — same order as
                            // RideStopList on every later ride screen.
                            RideStopField(
                              key: const Key('ride-pickup-label'),
                              icon: DealGoIcons.myLocation,
                              tone: DealGoColors.brandGreen,
                              caption: l10n.ridePickup,
                              value: pickup?.label,
                              placeholder: _locating
                                  ? l10n.placeLocating
                                  : l10n.ridePickupPlaceholder,
                              onTap: _pickPickup,
                            ),
                            for (final (i, stop) in _stops.indexed) ...[
                              const SizedBox(height: DealGoSpacing.s8),
                              RideStopField(
                                key: Key('ride-stop-field-${i + 1}'),
                                icon: DealGoIcons.pin,
                                tone: DealGoColors.amber,
                                caption: l10n.rideStopNumbered(i + 1),
                                value: stop.label,
                                placeholder: l10n.rideAddStop,
                                onTap: () => _editStop(i),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (i > 0)
                                      IconButton(
                                        key: Key('ride-stop-up-${i + 1}'),
                                        tooltip: l10n.rideMoveStopUp,
                                        onPressed: () => _moveStopUp(i),
                                        icon: const Icon(
                                          DealGoIcons.chevronUp,
                                          color: DealGoColors.primary,
                                        ),
                                      ),
                                    IconButton(
                                      key: Key('ride-stop-remove-${i + 1}'),
                                      tooltip: l10n.rideRemoveStop,
                                      onPressed: () => _removeStop(i),
                                      icon: const Icon(
                                        DealGoIcons.close,
                                        color: DealGoColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: DealGoSpacing.s8),
                            RideStopField(
                              key: const Key('ride-dropoff-label'),
                              icon: DealGoIcons.pin,
                              tone: DealGoColors.danger,
                              caption: l10n.rideDropoff,
                              value: dropoff?.label,
                              placeholder: l10n.rideDropoffPlaceholder,
                              onTap: () => _pickDropoff(),
                              trailing: IconButton(
                                tooltip: l10n.rideRouteSwapTooltip,
                                onPressed: pickup == null && dropoff == null
                                    ? null
                                    : _swap,
                                icon: const Icon(
                                  DealGoIcons.swapVert,
                                  color: DealGoColors.primary,
                                ),
                              ),
                            ),
                            if (_maxStops > 0 &&
                                dropoff != null &&
                                _stops.length < _maxStops) ...[
                              const SizedBox(height: DealGoSpacing.s4),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  key: const Key('ride-add-stop'),
                                  onPressed: _addStop,
                                  icon: const Icon(DealGoIcons.add, size: 18),
                                  label: Text(
                                    '${l10n.rideAddStop} · '
                                    '${l10n.rideStopsMax(_maxStops)}',
                                  ),
                                ),
                              ),
                            ],
                            if (_distance case final distance?
                                when !_samePlace) ...[
                              const SizedBox(height: DealGoSpacing.s8),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: DealGoChip(
                                  key: const Key('ride-map-distance'),
                                  label: rideDistanceText(l10n, distance),
                                  tone: DealGoChipTone.brand,
                                  leading: const Icon(
                                    DealGoIcons.route,
                                    size: 14,
                                    color: DealGoColors.primary,
                                  ),
                                ),
                              ),
                            ],
                            if (_samePlace) ...[
                              const SizedBox(height: DealGoSpacing.s8),
                              RideNote(message: l10n.rideSamePlaces),
                            ],
                            if (_suggestions.isNotEmpty) ...[
                              const SizedBox(height: DealGoSpacing.s16),
                              Text(
                                l10n.rideSuggestionsTitle,
                                style: textTheme.titleSmall,
                              ),
                              const SizedBox(height: DealGoSpacing.s8),
                              for (final (index, place) in _suggestions.indexed)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: DealGoSpacing.s8,
                                  ),
                                  child: Material(
                                    key: Key('ride-suggestion-$index'),
                                    color: DealGoColors.card,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        DealGoRadius.input,
                                      ),
                                      side: const BorderSide(
                                        color: DealGoColors.border,
                                      ),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: InkWell(
                                      onTap: () => _chooseSuggestion(place),
                                      child: Padding(
                                        padding: const EdgeInsets.all(
                                          DealGoSpacing.s12,
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              place.source == PlaceSource.saved
                                                  ? DealGoIcons.pin
                                                  : DealGoIcons.history,
                                              color:
                                                  place.source ==
                                                      PlaceSource.saved
                                                  ? DealGoColors.primary
                                                  : DealGoColors.brandGreen,
                                            ),
                                            const SizedBox(
                                              width: DealGoSpacing.s12,
                                            ),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    place.name,
                                                    style: textTheme.bodyMedium
                                                        ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                  ),
                                                  if (place.address.isNotEmpty)
                                                    Text(
                                                      place.address,
                                                      style:
                                                          textTheme.bodySmall,
                                                    ),
                                                ],
                                              ),
                                            ),
                                            const Icon(
                                              DealGoIcons.chevronRight,
                                              color: DealGoColors.textTertiary,
                                              size: 18,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          DealGoDimensions.pageGutter,
                          DealGoSpacing.s8,
                          DealGoDimensions.pageGutter,
                          // Shell bar height (or system inset) lives in padding.
                          DealGoSpacing.s12 +
                              MediaQuery.paddingOf(context).bottom,
                        ),
                        child: IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (pendingRideId != null) ...[
                                Expanded(
                                  child: DealGoSecondaryButton(
                                    key: const Key('ride-open-pending'),
                                    label: l10n.rideOpenPendingOffers,
                                    compact: true,
                                    onPressed: () => context.push(
                                      RideRoutes.offers(pendingRideId),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: DealGoSpacing.s8),
                              ],
                              Expanded(
                                child: DealGoPrimaryButton(
                                  key: const Key('ride-open-route-overview'),
                                  label: l10n.rideRouteContinueBooking,
                                  trailingIcon: pendingRideId == null
                                      ? DealGoIcons.arrowRight
                                      : null,
                                  compact: true,
                                  enabled: _places != null && !_samePlace,
                                  isLoading: _locating && _dropoff != null,
                                  onPressed: _continue,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `3,2 km` from the road route, `~3,2 km` for the straight-line fallback.
String rideDistanceText(AppLocalizations l10n, RideDistance distance) {
  final text = l10n.rideDistanceKm(formatRideKm(distance.km));
  if (!distance.road) return '~$text';
  final minutes = distance.minutes;
  return minutes == null ? text : '$text · ${l10n.rideEtaMinutes(minutes)}';
}
