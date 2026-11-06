import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_error_l10n.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/design_system/components/dealgo_bottom_bar.dart';
import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/components/dealgo_banner.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/config/api_base_url.dart';
import '../../../../core/maps/map_controls.dart';
import '../../../../core/maps/map_lat_lng.dart';
import '../../../../core/maps/map_port.dart';
import '../../../../core/maps/route_geometry.dart';
import '../../../pricing/domain/pricing.dart';
import '../../domain/entities/ride_money.dart';
import '../../domain/entities/ride_models.dart';
import '../../domain/params/create_ride_params.dart';
import '../../domain/ride_fare_presets.dart';
import '../../domain/ride_idempotency.dart';
import '../../domain/usecases/create_ride.dart';
import '../cubit/ride_fare_cubit.dart';
import '../utils/ride_routes.dart';
import '../utils/ride_vehicle_label.dart';
import '../cubit/ride_session.dart';
import '../widgets/ride_fare_raise_chips.dart';
import '../widgets/ride_widgets.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/l10n/api_error_text.dart';
import '../utils/ride_quote_error.dart';
import '../../../../core/storage/customer_booking_prefs.dart';
import '../../../../core/design_system/components/dealgo_network_image.dart';

/// inDrive-like: map-first sheet with vehicle cards + large bid fare + Find driver.
class RideFarePage extends StatelessWidget {
  const RideFarePage({required this.places, this.initialFareVnd, super.key});

  final RidePlaces places;

  /// Defaults to the selected class reference fare.
  final int? initialFareVnd;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          RideFareCubit(createRide: context.read<CreateRide>()),
      child: _RideFareView(places: places, initialFareVnd: initialFareVnd),
    );
  }
}

class _RideFareView extends StatefulWidget {
  const _RideFareView({required this.places, this.initialFareVnd});

  final RidePlaces places;
  final int? initialFareVnd;

  @override
  State<_RideFareView> createState() => _RideFarePageState();
}

class _RideFarePageState extends State<_RideFareView> {
  /// MOB-001: step comes from the server quote (fallback 1.000đ).
  int get _fareStepVnd => _quote.fareStepVnd;

  late RidePlaces _places;
  late List<RideQuote> _options;
  late final TextEditingController _fare;
  CreateRideRequest? _attempt;
  String? _openRideId;
  var _busy = false;
  var _offline = false;
  var _quoting = false;
  var _quoteFailed = false;
  Object? _quoteError;
  String? _message;

  RideQuote? get _quoteOrNull => _places.quote;
  RideQuote get _quote => _places.quote!;

  @override
  void initState() {
    super.initState();
    _places = widget.places;
    final seed = widget.places.quote;
    if (seed == null) {
      _options = const [];
      _fare = TextEditingController(
        text: widget.initialFareVnd == null ? '' : '${widget.initialFareVnd}',
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_loadQuote());
        }
      });
      return;
    }
    _options = seed.options.isNotEmpty
        ? List<RideQuote>.from(seed.options)
        : [seed];
    // Smart default: explicit choice > last used class > server default.
    final preferredCode =
        widget.places.vehicleClassCode?.trim().isNotEmpty == true
        ? widget.places.vehicleClassCode!.trim()
        : CustomerBookingPrefs.lastVehicleClass ?? seed.vehicleClassCode;
    final matchIndex = preferredCode == null
        ? 0
        : _options.indexWhere((o) => o.vehicleClassCode == preferredCode);
    final selected = _options[matchIndex >= 0 ? matchIndex : 0];
    _places = widget.places.selectClass(selected);
    final initial = widget.initialFareVnd ?? selected.referenceFareVnd;
    _fare = TextEditingController(text: '$initial');
  }

  @override
  void dispose() {
    _fare.dispose();
    super.dispose();
  }

  Future<void> _loadQuote() async {
    final token = rideAccessToken(context);
    setState(() {
      _quoting = true;
      _quoteFailed = false;
      _message = null;
    });
    if (token == null) {
      setState(() {
        _quoting = false;
        _quoteFailed = true;
        _message = sessionExpiredMessage(context);
      });
      return;
    }
    try {
      final quote = await context.read<PricingRepository>().quoteRide(
        accessToken: token,
        pickup: (
          lat: _places.pickup.lat,
          lng: _places.pickup.lng,
          label: _places.pickup.label,
        ),
        dropoff: (
          lat: _places.dropoff.lat,
          lng: _places.dropoff.lng,
          label: _places.dropoff.label,
        ),
        stops: [
          for (final s in _places.stops)
            (lat: s.lat, lng: s.lng, label: s.label),
        ],
      );
      if (!mounted) {
        return;
      }
      // Multi-stop: classes whose service cannot carry these stops are hidden.
      final options = quote.options.isNotEmpty
          ? [
              for (final o in quote.options)
                if (o.available) o,
            ]
          : [quote];
      if (options.isEmpty) {
        options.add(quote);
      }
      final preferredCode = _places.vehicleClassCode?.trim().isNotEmpty == true
          ? _places.vehicleClassCode!.trim()
          : CustomerBookingPrefs.lastVehicleClass ?? quote.vehicleClassCode;
      final matchIndex = preferredCode == null
          ? 0
          : options.indexWhere((o) => o.vehicleClassCode == preferredCode);
      final selected = options[matchIndex >= 0 ? matchIndex : 0];
      final initial = widget.initialFareVnd ?? selected.referenceFareVnd;
      setState(() {
        _options = options;
        _places = _places.selectClass(selected);
        _fare.text = formatRideAmount(initial);
        _quoting = false;
        _quoteFailed = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _quoting = false;
        _quoteFailed = true;
        _quoteError = error;
      });
    }
  }

  int? get _amount => parseRideFareInput(_fare.text);

  void _selectClass(RideQuote option) {
    if (_busy) {
      return;
    }
    setState(() {
      _places = RidePlaces(
        pickup: _places.pickup,
        dropoff: _places.dropoff,
        quote: option,
        vehicleClassCode: option.vehicleClassCode,
        stops: _places.stops,
      );
      _fare.text = formatRideAmount(option.referenceFareVnd);
      _message = null;
      _openRideId = null;
      _attempt = null;
    });
  }

  void _nudgeFare(int delta) {
    if (_busy || _quoteOrNull == null) {
      return;
    }
    final current = _amount ?? _quote.referenceFareVnd;
    final next = (current + delta).clamp(_quote.minBidVnd, _quote.maxBidVnd);
    _fare.text = formatRideAmount(next);
    setState(() => _message = null);
  }

  String _rangeLabel(BuildContext context) => AppLocalizations.of(context)
      .rideFareRange(
        formatRideVnd(_quote.minBidVnd),
        formatRideVnd(_quote.maxBidVnd),
      );

  Future<void> _submit() async {
    if (_busy || _quoteOrNull == null) {
      return;
    }
    final openRideId = _openRideId;
    final amount = _amount;
    if (openRideId != null &&
        _attempt != null &&
        amount == _attempt!.offeredFareVnd) {
      await context.push(RideRoutes.matching(openRideId));
      return;
    }
    if (amount == null || !_quote.allows(amount)) {
      setState(() {
        _offline = false;
        _message = _rangeLabel(context);
      });
      return;
    }
    final token = rideAccessToken(context);
    if (token == null) {
      setState(() {
        _offline = false;
        _message = sessionExpiredMessage(context);
      });
      return;
    }
    final pickup = _places.pickup;
    final dropoff = _places.dropoff;
    final previous = _attempt;
    final CreateRideRequest request;
    final vehicleClassCode = _places.vehicleClassCode?.trim();
    if (vehicleClassCode == null || vehicleClassCode.isEmpty) {
      setState(() {
        _busy = false;
        _message = AppLocalizations.of(context).ridePickVehicleClassFirst;
      });
      return;
    }
    if (previous != null &&
        previous.offeredFareVnd == amount &&
        previous.vehicleClassCode == vehicleClassCode &&
        previous.pickup.label == pickup.label &&
        previous.dropoff.label == dropoff.label &&
        _sameStops(previous.stops, _places.stops)) {
      request = previous;
    } else {
      request = CreateRideRequest(
        accessToken: token,
        idempotencyKey: createRideIdempotencyKey(),
        pickup: pickup,
        dropoff: dropoff,
        offeredFareVnd: amount,
        vehicleClassCode: vehicleClassCode,
        stops: _places.stops,
      );
    }
    _attempt = request;
    setState(() {
      _busy = true;
      _offline = false;
      _message = null;
    });
    try {
      final ride = await context.read<RideFareCubit>().create(request);
      if (!mounted) {
        return;
      }
      context.read<RideSessionCubit>().remember(ride.id);
      unawaited(CustomerBookingPrefs.rememberVehicleClass(vehicleClassCode));
      setState(() {
        _busy = false;
        _openRideId = ride.id;
      });
      await _openCreatedRide(ride);
    } catch (error) {
      if (!mounted) {
        return;
      }
      final alreadyOpen =
          error is ApiException && error.errorCode == 'RIDE_ALREADY_OPEN';
      // The customer still has a live request (e.g. left the waiting screen):
      // reopen it instead of a dead-end message, so its driver offers are seen.
      final openId = alreadyOpen
          ? context.read<RideSessionCubit>().state
          : null;
      if (openId != null) {
        setState(() {
          _busy = false;
          _offline = false;
          _message = null;
        });
        await context.push(RideRoutes.matching(openId));
        return;
      }
      setState(() {
        _busy = false;
        if (rideFailureIsOffline(error)) {
          _offline = true;
          _message = null;
        } else {
          _offline = false;
          _message = alreadyOpen
              ? AppLocalizations.of(context).rideFarePendingExists
              : error is ApiException
              ? apiErrorText(AppLocalizations.of(context), error)
              : AppLocalizations.of(context).rideFareSendFailed;
        }
      });
    }
  }

  Future<void> _openCreatedRide(RideView ride) async {
    if (ride.status.hasDriver) {
      await context.push(RideRoutes.tracking(ride.id));
      return;
    }
    // Quotes are answered inline on the waiting sheet.
    await context.push(RideRoutes.matching(ride.id));
  }

  @override
  Widget build(BuildContext context) {
    final quote = _quoteOrNull;
    final amount = _amount;
    final allowed = quote != null && amount != null && quote.allows(amount);
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    final viewExisting =
        _openRideId != null &&
        _attempt != null &&
        amount == _attempt!.offeredFareVnd;
    final selectedCode = _places.vehicleClassCode ?? quote?.vehicleClassCode;
    final route = (quote?.route ?? RouteGeometry.unavailable).polylineOr([
      MapLatLng(lat: _places.pickup.lat, lng: _places.pickup.lng),
      MapLatLng(lat: _places.dropoff.lat, lng: _places.dropoff.lng),
    ]);
    final media = MediaQuery.of(context);
    // Keep A/B + polyline in the visible band above the sheet.
    final fitPadding = EdgeInsets.fromLTRB(
      40,
      // Status bar + the full stop pin (chip above the tip) + margin.
      media.padding.top + 80,
      40,
      media.size.height * 0.58,
    );

    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        backgroundColor: DealGoColors.canvas,
        body: Stack(
          children: [
            Positioned.fill(
              child: context.watch<MapPort>().buildMap(
                center: MapLatLng(
                  lat: _places.pickup.lat,
                  lng: _places.pickup.lng,
                ),
                markers: [
                  MapLatLng(lat: _places.pickup.lat, lng: _places.pickup.lng),
                  MapLatLng(lat: _places.dropoff.lat, lng: _places.dropoff.lng),
                ],
                route: route,
                pulseRoute: true,
                fitPadding: fitPadding,
              ),
            ),
            RideDraggableSheet(
              initialChildSize: 0.56,
              // Owner t63u: sheet never sinks below 40%.
              minChildSize: 0.4,
              // Max + snaps together keep the sheet under the back button.
              maxChildSize: rideSheetMaxSize(MediaQuery.of(context)),
              snapSizes: rideSheetSnapSizes(const [
                0.4,
                0.56,
                0.78,
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
                          const SizedBox(height: DealGoSpacing.s8),
                          RideStopList(
                            pickup: _places.pickup.label,
                            dropoff: _places.dropoff.label,
                            stops: [for (final s in _places.stops) s.label],
                          ),
                          if (quote != null && quote.intercity) ...[
                            const SizedBox(height: DealGoSpacing.s12),
                            DealGoBanner(
                              key: const Key('ride-intercity-banner'),
                              tone: DealGoBannerTone.info,
                              title: l10n.rideIntercityQuote(
                                quote.distanceKm.toStringAsFixed(0),
                                "${quote.durationMin}",
                              ),
                              message: l10n.rideIntercityNote,
                            ),
                          ],
                          if (quote != null) ...[
                            const SizedBox(height: DealGoSpacing.s12),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: RideTripSummary(
                                distanceKm: quote.distanceKm,
                                durationMin: quote.durationMin,
                              ),
                            ),
                          ],
                          const SizedBox(height: DealGoSpacing.s12),
                          Row(
                            children: [
                              Text(
                                l10n.rideVehicleLabel,
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: DealGoSpacing.s12),
                          if (_quoting)
                            const Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: DealGoSpacing.s24,
                              ),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          else if (_quoteFailed)
                            Builder(
                              builder: (context) {
                                final zone = rideQuoteZoneErrorText(
                                  l10n,
                                  _quoteError,
                                );
                                return DealGoBanner(
                                  key: Key(
                                    zone == null
                                        ? 'ride-quote-error'
                                        : 'ride-quote-zone-error',
                                  ),
                                  tone: DealGoBannerTone.warning,
                                  message: zone ?? l10n.rideQuoteError,
                                  actionLabel: zone == null
                                      ? l10n.actionRetry
                                      : null,
                                  onAction: zone == null
                                      ? () => unawaited(_loadQuote())
                                      : null,
                                );
                              },
                            )
                          else if (_options.isEmpty)
                            RideInfoBanner(
                              message: l10n.rideVehicleClassesUnavailable,
                            )
                          else
                            for (var i = 0; i < _options.length; i++) ...[
                              if (i > 0)
                                const SizedBox(height: DealGoSpacing.s8),
                              _ClassTile(
                                option: _options[i],
                                selected:
                                    _options[i].vehicleClassCode ==
                                    selectedCode,
                                onTap: () => _selectClass(_options[i]),
                              ),
                            ],
                        ],
                      ),
                    ),
                    // Pinned so the offer input and "find driver" CTA stay in
                    // reach; inside the sheet, so the keyboard pushes both up
                    // instead of covering them.
                    MediaQuery.removePadding(
                      context: context,
                      removeBottom: true,
                      child: DealGoBottomBar(
                        key: const Key('ride-quote-bar'),
                        padding: EdgeInsets.fromLTRB(
                          DealGoDimensions.pageGutter,
                          DealGoSpacing.s12,
                          DealGoDimensions.pageGutter,
                          rideSheetFooterBottom(context),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (quote != null) ...[
                              Text(
                                l10n.rideYourOffer,
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: DealGoSpacing.s4),
                              Text(
                                l10n.rideRecommendedFareLabel(
                                  formatRideVnd(quote.referenceFareVnd),
                                ),
                                style: textTheme.bodySmall?.copyWith(
                                  color: DealGoColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: DealGoSpacing.s8),
                              // C10: one control — the amount itself is
                              // editable between −/+, with the presets
                              // underneath.
                              _FareControl(
                                controller: _fare,
                                presets: rideFareRaisePresets(
                                  suggestedVnd: quote.referenceFareVnd,
                                  minBidVnd: quote.minBidVnd,
                                  maxBidVnd: quote.maxBidVnd,
                                  stepVnd: _fareStepVnd,
                                  maxHeadroomPercent: quote.bidHeadroomPercent,
                                ),
                                selectedPreset: amount,
                                hintText: l10n.rideEnterAmount,
                                enabled: !_busy,
                                onMinus: () => _nudgeFare(-_fareStepVnd),
                                onPlus: () => _nudgeFare(_fareStepVnd),
                                onPreset: (preset) {
                                  _fare.text = formatRideAmount(preset);
                                  setState(() => _message = null);
                                },
                                onChanged: () =>
                                    setState(() => _message = null),
                              ),
                            ],
                            if (_offline) ...[
                              const SizedBox(height: DealGoSpacing.s8),
                              RideOfflineNotice(detail: l10n.rideFareOffline),
                            ],
                            if (_message != null) ...[
                              const SizedBox(height: DealGoSpacing.s8),
                              RideNote(message: _message!),
                            ],
                            const SizedBox(height: DealGoSpacing.s8),
                            DealGoPrimaryButton(
                              key: const Key('ride-submit-fare'),
                              label: viewExisting
                                  ? l10n.rideSeeDriverOffers
                                  : amount == null
                                  ? l10n.rideFindDriverPlain
                                  : l10n.rideFindDriverCta(
                                      formatRideVnd(amount),
                                    ),
                              trailingIcon: DealGoIcons.arrowRight,
                              compact: true,
                              isLoading: _busy,
                              enabled: viewExisting || allowed,
                              onPressed: _submit,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            // Floating back over the sheet, as on the driver search; inert
            // (still shown) while a request is being sent, like PopScope.
            MapBackOverlay(
              buttonKey: const Key('ride-fare-back'),
              enabled: !_busy,
            ),
          ],
        ),
      ),
    );
  }
}

class _FareControl extends StatelessWidget {
  const _FareControl({
    required this.controller,
    required this.presets,
    required this.selectedPreset,
    required this.onPreset,
    required this.hintText,
    required this.enabled,
    required this.onMinus,
    required this.onPlus,
    required this.onChanged,
  });

  final TextEditingController controller;
  final List<RideFarePreset> presets;
  final int? selectedPreset;
  final ValueChanged<int> onPreset;
  final String hintText;
  final bool enabled;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final amountStyle = textTheme.headlineMedium?.copyWith(
      color: DealGoColors.primary,
      fontWeight: FontWeight.w800,
    );
    return DecoratedBox(
      key: const Key('ride-fare-control'),
      decoration: BoxDecoration(
        color: DealGoColors.subtlePurple,
        borderRadius: BorderRadius.circular(DealGoRadius.card),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DealGoSpacing.s16),
        child: Column(
          children: [
            Row(
              children: [
                _StepButton(
                  key: const Key('ride-fare-minus'),
                  icon: DealGoIcons.remove,
                  onTap: enabled ? onMinus : null,
                ),
                const SizedBox(width: DealGoSpacing.s16),
                Expanded(
                  child: Center(
                    child: Row(
                      key: const Key('ride-fare-amount'),
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Flexible(
                          child: IntrinsicWidth(
                            child: TextField(
                              key: const Key('ride-fare-field'),
                              controller: controller,
                              enabled: enabled,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              inputFormatters: const [
                                RideAmountInputFormatter(),
                              ],
                              style: amountStyle,
                              decoration: InputDecoration(
                                isDense: true,
                                filled: false,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: DealGoSpacing.s8,
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                hintText: hintText,
                                hintStyle: textTheme.titleSmall?.copyWith(
                                  color: DealGoColors.textSecondary,
                                ),
                              ),
                              onChanged: (_) => onChanged(),
                            ),
                          ),
                        ),
                        Text('đ', style: amountStyle),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: DealGoSpacing.s16),
                _StepButton(
                  key: const Key('ride-fare-plus'),
                  icon: DealGoIcons.add,
                  onTap: enabled ? onPlus : null,
                ),
              ],
            ),
            if (presets.isNotEmpty) ...[
              const SizedBox(height: DealGoSpacing.s12),
              RideFareRaiseChips(
                presets: presets,
                selectedVnd: selectedPreset,
                enabled: enabled,
                onPick: onPreset,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap, super.key});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: DealGoColors.card,
      shape: const CircleBorder(),
      elevation: 1,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, color: DealGoColors.primary, size: 22),
        ),
      ),
    );
  }
}

class _ClassTile extends StatelessWidget {
  const _ClassTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final RideQuote option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final code = option.vehicleClassCode;
    final title = option.vehicleClassName ?? rideVehicleClassLabel(l10n, code);
    final subtitle = option.seats == null || code == 'MOTORBIKE'
        ? l10n.rideVehicleBikeSubtitle
        : l10n.rideVehicleSeats(option.seats!);
    final photo = resolveMediaUrl(option.imageUrl);
    // The border marks the choice; screen readers get it from `selected`.
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? DealGoColors.subtlePurple : DealGoColors.card,
        borderRadius: BorderRadius.circular(DealGoRadius.input),
        child: InkWell(
          key: Key(
            code == 'MOTORBIKE'
                ? 'ride-vehicle-bike'
                : 'ride-vehicle-${code ?? 'unknown'}',
          ),
          borderRadius: BorderRadius.circular(DealGoRadius.input),
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(DealGoRadius.input),
              border: Border.all(
                color: selected ? DealGoColors.primary : DealGoColors.border,
                width: selected ? 1.8 : 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DealGoSpacing.s12,
                vertical: DealGoSpacing.s12,
              ),
              child: Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: DealGoColors.greenSurface,
                      borderRadius: BorderRadius.circular(DealGoRadius.input),
                    ),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: photo == null
                          ? Icon(
                              rideVehicleClassIcon(code),
                              color: DealGoColors.brandGreen,
                              size: 22,
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(
                                DealGoRadius.input,
                              ),
                              child: DealGoNetworkImage(
                                photo,
                                fit: BoxFit.cover,
                                fallback: Icon(
                                  rideVehicleClassIcon(code),
                                  color: DealGoColors.brandGreen,
                                  size: 22,
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: DealGoSpacing.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(subtitle, style: textTheme.bodySmall),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        l10n.rideSuggestedFareShort,
                        style: textTheme.labelSmall?.copyWith(
                          color: DealGoColors.textSecondary,
                        ),
                      ),
                      Text(
                        formatRideVnd(option.referenceFareVnd),
                        style: textTheme.titleSmall?.copyWith(
                          color: DealGoColors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

bool _sameStops(List<RidePoint> a, List<RidePoint> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i].lat != b[i].lat || a[i].lng != b[i].lng) return false;
  }
  return true;
}

/// Keeps the fare field grouped as the user types ("85000" → "85.000").
class RideAmountInputFormatter extends TextInputFormatter {
  const RideAmountInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue();
    final trimmed = digits.length > 9 ? digits.substring(0, 9) : digits;
    final text = formatRideAmount(int.parse(trimmed));
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
