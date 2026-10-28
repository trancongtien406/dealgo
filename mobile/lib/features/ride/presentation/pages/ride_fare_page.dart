import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_error_l10n.dart';
import '../../../../core/network/api_exception.dart';
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
import '../../domain/ride_idempotency.dart';
import '../../domain/usecases/create_ride.dart';
import '../cubit/ride_fare_cubit.dart';
import '../utils/ride_routes.dart';
import '../utils/ride_vehicle_label.dart';
import '../cubit/ride_session.dart';
import '../widgets/ride_widgets.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/l10n/api_error_text.dart';
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
  static const _fareStepVnd = 1000;

  late RidePlaces _places;
  late List<RideQuote> _options;
  late final TextEditingController _fare;
  CreateRideRequest? _attempt;
  String? _openRideId;
  var _busy = false;
  var _offline = false;
  var _quoting = false;
  var _quoteFailed = false;
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
        _fare.text = '$initial';
        _quoting = false;
        _quoteFailed = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _quoting = false;
        _quoteFailed = true;
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
      _fare.text = '${option.referenceFareVnd}';
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
    final next = (current + delta).clamp(_quote.minFareVnd, _quote.maxFareVnd);
    _fare.text = '$next';
    setState(() => _message = null);
  }

  String _rangeLabel(BuildContext context) => AppLocalizations.of(context)
      .rideFareRange(
        formatRideVnd(_quote.minFareVnd),
        formatRideVnd(_quote.maxFareVnd),
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
    final expired =
        ride.status == RideStatus.expired ||
        rideNegotiationExpired(ride, DateTime.now());
    final waiting =
        ride.status == RideStatus.negotiating &&
        ride.selectedOfferId == null &&
        ride.offers.isEmpty &&
        !expired;
    if (ride.status.hasDriver) {
      await context.push(RideRoutes.tracking(ride.id));
      return;
    }
    if (waiting || expired) {
      await context.push(RideRoutes.matching(ride.id));
      return;
    }
    await context.push(RideRoutes.offers(ride.id));
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
              minChildSize: 0.32,
              maxChildSize: 0.92,
              snapSizes: const [0.32, 0.56, 0.78],
                        children: [
                          const RideSheetHandle(),
                          const SizedBox(height: DealGoSpacing.s8),
                          RideStopList(
                            pickup: _places.pickup.label,
                            dropoff: _places.dropoff.label,
                            stops: [for (final s in _places.stops) s.label],
                          ),
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
                            DealGoBanner(
                              key: const Key('ride-quote-error'),
                              tone: DealGoBannerTone.warning,
                              message: l10n.rideQuoteError,
                              actionLabel: l10n.actionRetry,
                              onAction: () => unawaited(_loadQuote()),
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
                          if (quote != null) ...[
                            const SizedBox(height: DealGoSpacing.s16),
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
                            const SizedBox(height: DealGoSpacing.s12),
                            // C10: one control — the amount itself is editable
                            // between −/+, with the presets underneath.
                            _FareControl(
                              controller: _fare,
                              presets: quote.presetsVnd,
                              selectedPreset: amount,
                              hintText: l10n.rideEnterAmount,
                              enabled: !_busy,
                              onMinus: () => _nudgeFare(-_fareStepVnd),
                              onPlus: () => _nudgeFare(_fareStepVnd),
                              onPreset: (preset) {
                                _fare.text = '$preset';
                                setState(() => _message = null);
                              },
                              onChanged: () => setState(() => _message = null),
                            ),
                          ],
                          if (_offline) ...[
                            const SizedBox(height: DealGoSpacing.s12),
                            RideOfflineNotice(detail: l10n.rideFareOffline),
                          ],
                          if (_message != null) ...[
                            const SizedBox(height: DealGoSpacing.s12),
                            RideNote(message: _message!),
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
                        key: const Key('ride-submit-fare'),
                        label: viewExisting
                            ? l10n.rideSeeDriverOffers
                            : amount == null
                            ? l10n.rideFindDriverPlain
                            : l10n.rideFindDriverCta(formatRideVnd(amount)),
                        trailingIcon: DealGoIcons.arrowRight,
                        compact: true,
                        isLoading: _busy,
                        enabled: viewExisting || allowed,
                        onPressed: _submit,
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
    required this.hintText,
    required this.enabled,
    required this.onMinus,
    required this.onPlus,
    required this.onPreset,
    required this.onChanged,
  });

  final TextEditingController controller;
  final List<int> presets;
  final int? selectedPreset;
  final String hintText;
  final bool enabled;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final ValueChanged<int> onPreset;
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
        padding: const EdgeInsets.fromLTRB(
          DealGoSpacing.s8,
          DealGoSpacing.s12,
          DealGoSpacing.s8,
          DealGoSpacing.s12,
        ),
        child: Column(
          children: [
            Row(
              children: [
                _StepButton(
                  key: const Key('ride-fare-minus'),
                  icon: DealGoIcons.remove,
                  onTap: enabled ? onMinus : null,
                ),
                Expanded(
                  child: TextField(
                    key: const Key('ride-fare-field'),
                    controller: controller,
                    enabled: enabled,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: amountStyle,
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: hintText,
                      hintStyle: textTheme.titleSmall?.copyWith(
                        color: DealGoColors.textSecondary,
                      ),
                      suffixText: 'đ',
                      suffixStyle: amountStyle,
                    ),
                    onChanged: (_) => onChanged(),
                  ),
                ),
                _StepButton(
                  key: const Key('ride-fare-plus'),
                  icon: DealGoIcons.add,
                  onTap: enabled ? onPlus : null,
                ),
              ],
            ),
            if (presets.isNotEmpty) ...[
              const SizedBox(height: DealGoSpacing.s12),
              Row(
                children: [
                  for (var i = 0; i < presets.length; i++) ...[
                    if (i > 0) const SizedBox(width: DealGoSpacing.s8),
                    Expanded(
                      child: _FarePreset(
                        amount: presets[i],
                        selected: selectedPreset == presets[i],
                        onTap: enabled ? () => onPreset(presets[i]) : null,
                      ),
                    ),
                  ],
                ],
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

class _FarePreset extends StatelessWidget {
  const _FarePreset({
    required this.amount,
    required this.selected,
    required this.onTap,
  });

  final int amount;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // The border marks the choice; screen readers get it from `selected`.
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? DealGoColors.card : DealGoColors.canvas,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: BorderSide(
            color: selected ? DealGoColors.primary : DealGoColors.border,
            width: selected ? 1.4 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: DealGoSpacing.s8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    formatRideVnd(amount),
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: selected
                          ? DealGoColors.primary
                          : DealGoColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
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
