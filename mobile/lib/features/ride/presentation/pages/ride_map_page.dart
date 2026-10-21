import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/components/dealgo_secondary_button.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/maps/map_lat_lng.dart';
import '../../../../core/maps/map_port.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../address_book/domain/repositories/address_book_repository.dart';
import '../../../places/domain/place.dart';
import '../../../places/presentation/current_place.dart';
import '../../../places/presentation/place_picker_page.dart';
import '../../domain/entities/ride_models.dart';
import '../cubit/ride_destination.dart';
import '../cubit/ride_session.dart';
import '../utils/ride_routes.dart';
import '../widgets/ride_widgets.dart';
import '../../../../core/design_system/components/dealgo_app_header.dart';

const _suggestionLimit = 5;

/// Fast ride entry (Grab / inDrive style): GPS pickup in background, destination
/// first, auto-advance to route when both points are ready.
class RideMapPage extends StatefulWidget {
  const RideMapPage({super.key});

  @override
  State<RideMapPage> createState() => _RideMapPageState();
}

class _RideMapPageState extends State<RideMapPage> {
  PlaceOption? _pickup;
  PlaceOption? _dropoff;
  var _locating = false;
  var _suggestions = const <PlaceOption>[];
  var _autoAdvanced = false;

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
    final place = await pickPlace(context, PlacePickPurpose.dropoff);
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
      _autoAdvanced = false;
    });
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
    if (_autoAdvanced || _places == null || _samePlace) {
      return;
    }
    _autoAdvanced = true;
    _continue();
  }

  void _continue() {
    final places = _places;
    if (places == null || _samePlace) {
      return;
    }
    context.push(RideRoutes.routeOverview, extra: places);
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/customer');
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

    return BlocListener<RideDestinationCubit, PlaceOption?>(
      listenWhen: (_, next) => next != null,
      listener: (context, _) {
        final place = context.read<RideDestinationCubit>().take();
        if (place != null) {
          setState(() {
            _dropoff = place;
            _autoAdvanced = false;
          });
          _tryAutoAdvance();
        }
      },
      child: Material(
        color: DealGoColors.canvas,
        child: Stack(
          children: [
            Positioned.fill(
              child: context.read<MapPort>().buildMap(
                center: center,
                markers: [
                  if (pickup != null)
                    MapLatLng(lat: pickup.lat, lng: pickup.lng),
                  if (dropoff != null)
                    MapLatLng(lat: dropoff.lat, lng: dropoff.lng),
                ],
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: DealGoAppHeader(
                title: l10n.rideBookTitle,
                onBack: _back,

                backgroundColor: DealGoColors.card.withValues(alpha: 0.94),
                applySafeArea: true,
              ),
            ),
            Positioned(
              right: DealGoDimensions.pageGutter,
              bottom: MediaQuery.sizeOf(context).height * 0.38 + 8,
              child: Material(
                color: DealGoColors.card,
                shape: const CircleBorder(),
                elevation: 2,
                child: IconButton(
                  tooltip: l10n.mapRecenter,
                  onPressed: _locating ? null : _locatePickup,
                  icon: const Icon(
                    DealGoIcons.myLocation,
                    color: DealGoColors.primary,
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: 0.42,
                widthFactor: 1,
                child: RideBottomSheet(
                  child: Column(
                    children: [
                      Expanded(
                        child: ListView(
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
                            // Destination first — primary action.
                            RideStopField(
                              key: const Key('ride-dropoff-label'),
                              icon: DealGoIcons.search,
                              tone: DealGoColors.primary,
                              caption: l10n.rideDropoff,
                              value: dropoff?.label,
                              placeholder: l10n.rideDropoffPlaceholder,
                              onTap: () => _pickDropoff(),
                            ),
                            const SizedBox(height: DealGoSpacing.s8),
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
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: textTheme.bodyMedium
                                                        ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                  ),
                                                  if (place.address.isNotEmpty)
                                                    Text(
                                                      place.address,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
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
                            if (pendingRideId != null) ...[
                              const SizedBox(height: DealGoSpacing.s12),
                              DealGoSecondaryButton(
                                label: l10n.rideOpenPendingOffers,
                                onPressed: () => context.push(
                                  RideRoutes.offers(pendingRideId),
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
                          DealGoSpacing.s12 +
                              MediaQuery.viewPaddingOf(context).bottom,
                        ),
                        child: DealGoPrimaryButton(
                          key: const Key('ride-open-route-overview'),
                          label: l10n.rideCheckRoute,
                          trailingIcon: DealGoIcons.arrowRight,
                          enabled: _places != null && !_samePlace,
                          isLoading: _locating && _dropoff != null,
                          onPressed: _continue,
                        ),
                      ),
                    ],
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
