import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/request_failure.dart';
import '../../../../core/design_system/components/dealgo_app_header.dart';
import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/components/dealgo_secondary_button.dart';
import '../../../../core/design_system/components/dealgo_state_view.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/ride_money.dart';
import '../../domain/entities/ride_models.dart';
import '../../domain/usecases/cancel_ride.dart';
import '../../domain/usecases/get_ride.dart';
import '../cubit/ride_matching_cubit.dart';
import '../utils/ride_routes.dart';
import '../utils/ride_vehicle_label.dart';
import '../cubit/ride_session.dart';
import '../../domain/ride_fare_presets.dart';
import '../widgets/ride_fare_raise_chips.dart';
import '../widgets/ride_widgets.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/maps/map_controls.dart';
import '../../../../core/maps/map_lat_lng.dart';
import '../../../../core/maps/map_port.dart';
import '../../../../core/realtime/snapshot_realtime.dart';
import '../../../../core/design_system/components/dealgo_haptics.dart';
import '../../../driver_card/domain/driver_card.dart';
import '../../../driver_card/presentation/driver_card_tile.dart';
import '../../domain/params/select_ride_offer_params.dart';
import '../../domain/ride_idempotency.dart';
import '../../domain/usecases/select_ride_offer.dart';
import '../widgets/ride_negotiation_ui.dart';
import '../widgets/ride_offer_countdown.dart';
import '../widgets/ride_search_status.dart';

class RideMatchingPage extends StatelessWidget {
  const RideMatchingPage({required this.rideId, this.clock, super.key});

  final String rideId;
  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => RideMatchingCubit(
        getRide: context.read<GetRide>(),
        cancelRide: context.read<CancelRide>(),
        realtime: _maybeRealtime(context),
      ),
      child: _RideMatchingView(rideId: rideId, clock: clock),
    );
  }
}

SnapshotRealtime? _maybeRealtime(BuildContext context) {
  try {
    return context.read<SnapshotRealtime>();
  } catch (_) {
    return null;
  }
}

class _RideMatchingView extends StatefulWidget {
  const _RideMatchingView({required this.rideId, this.clock});

  final String rideId;
  final DateTime Function()? clock;

  @override
  State<_RideMatchingView> createState() => _RideMatchingPageState();
}

class _RideMatchingPageState extends State<_RideMatchingView> {
  RideView? _ride;
  var _loading = true;
  var _busy = false;
  var _offline = false;
  Object? _failure;
  var _openedTracking = false;
  var _openedOffers = false;
  var _refreshing = false;
  var _watching = false;

  DateTime get _now => (widget.clock ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _load();
      _watch();
    });
  }

  /// DEC-PROD-031 rev 2026-10-24: socket replaces the 4 s poll. REST snapshot at
  /// open (above) + after subscribe + after each hint / reconnect (in the cubit).
  void _watch() {
    if (!mounted || _watching) {
      return;
    }
    final token = rideAccessToken(context);
    if (token == null) {
      return;
    }
    _watching = true;
    context
        .read<RideMatchingCubit>()
        .watch(
          accessToken: token,
          rideId: widget.rideId,
          refresh: () async {
            final ride = _ride;
            if (!mounted) {
              return;
            }
            // Offers page (pushed on top) runs its own watcher; avoid double navigation.
            final current = ModalRoute.of(context)?.isCurrent ?? true;
            if (!current ||
                (ride != null && ride.status != RideStatus.negotiating)) {
              return;
            }
            await _load(silent: true);
          },
        )
        .catchError((Object _) {});
  }

  Future<void> _load({bool silent = false}) async {
    if (_busy || _refreshing) {
      return;
    }
    final token = rideAccessToken(context);
    if (token == null) {
      setState(() {
        _loading = false;
        _offline = false;
        _failure = sessionExpiredFailure;
      });
      return;
    }
    if (silent) {
      _refreshing = true;
    } else {
      setState(() {
        _busy = true;
      });
    }
    try {
      final ride = await context.read<RideMatchingCubit>().load(
        accessToken: token,
        rideId: widget.rideId,
      );
      _refreshing = false;
      if (!mounted) {
        return;
      }
      if (silent) {
        setState(() {
          _ride = ride;
          _autoAccept = ride.autoAcceptOfferedFare;
          _loading = false;
          _offline = false;
          _failure = null;
        });
      }
      final session = context.read<RideSessionCubit>();
      final waiting =
          ride.status == RideStatus.negotiating &&
          ride.selectedOfferId == null &&
          !rideNegotiationExpired(ride, _now);
      if (waiting) {
        session.remember(ride.id);
      } else {
        session.clear();
      }
      if (!silent) {
        setState(() {
          _ride = ride;
          _autoAccept = ride.autoAcceptOfferedFare;
          _loading = false;
          _busy = false;
          _offline = false;
          _failure = null;
        });
      }
      if (ride.status.hasDriver && !_openedTracking) {
        _openedTracking = true;
        unawaited(context.push(RideRoutes.tracking(ride.id)));
        return;
      }
      // inDrive-like: surface offer cards as soon as drivers respond.
      final canChoose =
          ride.status == RideStatus.negotiating &&
          ride.selectedOfferId == null &&
          ride.liveOffers.isNotEmpty &&
          !rideNegotiationExpired(ride, _now);
      // 2026-10-29: offers are answered inline on this sheet (no page push).
      if (canChoose && !_openedOffers) {
        _openedOffers = true;
        DealGoHaptics.success();
      }
    } catch (error) {
      _refreshing = false;
      if (!mounted || silent) {
        return;
      }
      setState(() {
        _loading = false;
        _busy = false;
        _failure = error;
        _offline = requestFailureIsOffline(error);
      });
    }
  }

  String? _actingOn;
  String? _inlineError;
  var _autoAccept = false;

  /// MOB-002: one Idempotency-Key per (ride, offer) selection attempt, reused when the
  /// customer retries after a timeout so the server replays instead of double-selecting.
  final Map<String, String> _selectKeys = {};

  /// One tap: take this driver's price (inDrive style) and go to tracking.
  Future<void> _accept(RideView ride, RideOffer offer) async {
    final token = rideAccessToken(context);
    if (_actingOn != null || token == null) return;
    setState(() {
      _actingOn = offer.id;
      _inlineError = null;
    });
    try {
      final updated = await context.read<SelectRideOffer>()(
        SelectRideOfferRequest(
          accessToken: token,
          idempotencyKey: _selectKeys.putIfAbsent(
            '${ride.id}:${offer.id}',
            createRideIdempotencyKey,
          ),
          rideId: ride.id,
          offerId: offer.id,
        ),
      );
      _selectKeys.remove('${ride.id}:${offer.id}');
      if (!mounted) return;
      context.read<RideSessionCubit>().clear();
      DealGoHaptics.success();
      setState(() {
        _actingOn = null;
        _ride = updated;
      });
      if (updated.status.hasDriver && !_openedTracking) {
        _openedTracking = true;
        context.pushReplacement(RideRoutes.tracking(updated.id));
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _actingOn = null;
        _inlineError = negotiationErrorText(context, error);
      });
      await _load(silent: true);
    }
  }

  Future<void> _decline(RideView ride, RideOffer offer) async {
    final client = maybeRideNegotiation(context);
    final token = rideAccessToken(context);
    if (_actingOn != null || client == null || token == null) return;
    setState(() {
      _actingOn = offer.id;
      _inlineError = null;
    });
    try {
      await client.declineOffer(
        accessToken: token,
        rideId: ride.id,
        offerId: offer.id,
      );
    } catch (error) {
      if (mounted) _inlineError = negotiationErrorText(context, error);
    }
    if (!mounted) return;
    setState(() => _actingOn = null);
    await _load(silent: true);
  }

  Future<void> _setAutoAccept(bool enabled) async {
    final client = maybeRideNegotiation(context);
    final token = rideAccessToken(context);
    final ride = _ride;
    if (_actingOn != null || client == null || token == null || ride == null) {
      return;
    }
    final previous = _autoAccept;
    setState(() {
      _autoAccept = enabled;
      _actingOn = 'auto';
      _inlineError = null;
    });
    try {
      await client.setAutoAccept(
        accessToken: token,
        rideId: ride.id,
        enabled: enabled,
      );
    } catch (error) {
      if (mounted) {
        _inlineError = negotiationErrorText(context, error);
        _autoAccept = previous;
      }
    }
    if (!mounted) return;
    setState(() => _actingOn = null);
    await _load(silent: true);
  }

  Future<void> _raise(RideView ride, int amountVnd) async {
    final client = maybeRideNegotiation(context);
    final token = rideAccessToken(context);
    if (_actingOn != null || client == null || token == null) return;
    setState(() {
      _actingOn = 'raise';
      _inlineError = null;
    });
    try {
      await client.raiseFare(
        accessToken: token,
        rideId: ride.id,
        amountVnd: amountVnd,
      );
    } catch (error) {
      if (mounted) _inlineError = negotiationErrorText(context, error);
    }
    if (!mounted) return;
    setState(() => _actingOn = null);
    await _load(silent: true);
  }

  void _editTrip(RideView ride) {
    context.push(
      RideRoutes.fare,
      extra: RidePlaces(
        pickup: ride.pickup,
        dropoff: ride.dropoff,
        stops: [for (final s in ride.stops) s.point],
      ),
    );
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
    final ride = _ride;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        backgroundColor: DealGoColors.canvas,
        // Map-first wait has its own insets; keep SafeArea only for form states.
        body:
            ride != null &&
                ride.status != RideStatus.cancelled &&
                !rideNegotiationExpired(ride, _now) &&
                !ride.status.hasDriver
            ? _body(ride)
            : SafeArea(child: _body(ride)),
      ),
    );
  }

  Widget _body(RideView? ride) {
    if (_loading && ride == null) {
      return Column(
        children: [
          DealGoAppHeader(
            title: AppLocalizations.of(context).rideMatchingReceiving,
            onBack: _back,
          ),
          const Expanded(child: Center(child: CircularProgressIndicator())),
        ],
      );
    }
    if (ride == null) {
      return Column(
        children: [
          DealGoAppHeader(
            title: AppLocalizations.of(context).rideMatchingSearching,
            onBack: _back,
          ),
          Expanded(
            child: DealGoStateView.failure(
              context,
              onRetry: _load,
              cause: _failure,
              message: AppLocalizations.of(context).rideMatchingLoadFailed,
            ),
          ),
        ],
      );
    }
    if (ride.status == RideStatus.cancelled) {
      return _CancelledMatch(
        onBack: _back,
        onHome: () => context.go('/customer'),
      );
    }
    if (rideNegotiationExpired(ride, _now)) {
      return _MatchingTimeout(
        ride: ride,
        busy: _busy,
        onBack: _back,
        onEdit: () => _editTrip(ride),
        onRetry: () => _editTrip(ride),
      );
    }
    if (ride.status.hasDriver) {
      return _AssignedHandoff(
        onBack: _back,
        onOpen: () => context.push(RideRoutes.tracking(ride.id)),
      );
    }
    return _MatchingWait(
      ride: ride,
      busy: _busy,
      offline: _offline,
      onBack: _back,
      onCancel: () => context.push(RideRoutes.cancel(ride.id)),
      onOpenOffers: ride.liveOffers.isEmpty
          ? null
          : () => context.push(RideRoutes.offers(ride.id)),
      offers: [
        for (final o in ride.liveOffers)
          if (rideOfferSelectable(o, _now)) o,
      ],
      actingOn: _actingOn,
      inlineError: _inlineError,
      onAccept: (o) => _accept(ride, o),
      onDecline: maybeRideNegotiation(context) == null
          ? null
          : (o) => _decline(ride, o),
      onRaise: maybeRideNegotiation(context) == null
          ? null
          : (amount) => _raise(ride, amount),
      autoAccept: _autoAccept,
      onAutoAccept: maybeRideNegotiation(context) == null
          ? null
          : _setAutoAccept,
    );
  }
}

class _MatchingWait extends StatefulWidget {
  const _MatchingWait({
    required this.ride,
    required this.busy,
    required this.offline,
    required this.onBack,
    required this.onCancel,
    required this.onOpenOffers,
    this.offers = const [],
    this.actingOn,
    this.inlineError,
    this.onAccept,
    this.onDecline,
    this.onRaise,
    this.autoAccept = false,
    this.onAutoAccept,
  });

  final List<RideOffer> offers;
  final String? actingOn;
  final String? inlineError;
  final ValueChanged<RideOffer>? onAccept;
  final ValueChanged<RideOffer>? onDecline;
  final ValueChanged<int>? onRaise;
  final bool autoAccept;
  final ValueChanged<bool>? onAutoAccept;

  final RideView ride;
  final bool busy;
  final bool offline;

  /// Leaves the page; the search keeps running and is reopened from the fare
  /// or map screen.
  final VoidCallback onBack;
  final VoidCallback onCancel;
  final VoidCallback? onOpenOffers;

  @override
  State<_MatchingWait> createState() => _MatchingWaitState();
}

/// Receiving offers: the sheet opens near full height (animated) so offers are
/// visible without a swipe, and re-expands when a new offer arrives.
class _MatchingWaitState extends State<_MatchingWait> {
  final _sheet = DraggableScrollableController();
  final _offersKey = GlobalKey();
  double _max = 0.86;

  RideView get ride => widget.ride;
  bool get busy => widget.busy;
  bool get offline => widget.offline;
  VoidCallback get onBack => widget.onBack;
  VoidCallback get onCancel => widget.onCancel;
  VoidCallback? get onOpenOffers => widget.onOpenOffers;
  List<RideOffer> get offers => widget.offers;
  String? get actingOn => widget.actingOn;
  String? get inlineError => widget.inlineError;
  ValueChanged<RideOffer>? get onAccept => widget.onAccept;
  ValueChanged<RideOffer>? get onDecline => widget.onDecline;
  ValueChanged<int>? get onRaise => widget.onRaise;
  bool get autoAccept => widget.autoAccept;
  ValueChanged<bool>? get onAutoAccept => widget.onAutoAccept;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _expand());
  }

  @override
  void didUpdateWidget(covariant _MatchingWait oldWidget) {
    super.didUpdateWidget(oldWidget);
    final added = widget.offers.any(
      (o) => !oldWidget.offers.any((old) => old.id == o.id),
    );
    if (added) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _expand());
    }
  }

  @override
  void dispose() {
    _sheet.dispose();
    super.dispose();
  }

  Future<void> _expand() async {
    if (!mounted || !_sheet.isAttached) return;
    if (_sheet.size < _max - 0.005) {
      await _sheet.animateTo(
        _max,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
    final target = _offersKey.currentContext;
    if (mounted && target != null && target.mounted) {
      await Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    final openOffers = onOpenOffers;
    final route = ride.route.polylineOr([
      MapLatLng(lat: ride.pickup.lat, lng: ride.pickup.lng),
      MapLatLng(lat: ride.dropoff.lat, lng: ride.dropoff.lng),
    ]);
    final media = MediaQuery.of(context);
    final fitPadding = EdgeInsets.fromLTRB(
      40,
      // Status bar + the full stop pin (chip above the tip) + margin.
      media.padding.top + 80,
      40,
      media.size.height * 0.48,
    );
    return Stack(
      children: [
        Positioned.fill(
          child: context.watch<MapPort>().buildMap(
            center: MapLatLng(lat: ride.pickup.lat, lng: ride.pickup.lng),
            markers: [
              MapLatLng(lat: ride.pickup.lat, lng: ride.pickup.lng),
              MapLatLng(lat: ride.dropoff.lat, lng: ride.dropoff.lng),
            ],
            route: route,
            pulseRoute: true,
            fitPadding: fitPadding,
          ),
        ),
        RideDraggableSheet(
          key: const Key('ride-matching-sheet'),
          controller: _sheet,
          // Owner: searching opens tall (~80%) so offers/raise are in view.
          initialChildSize: math.min(
            0.8,
            rideSheetMaxSize(MediaQuery.of(context)),
          ),
          minChildSize: 0.4,
          // Max + snaps together keep the sheet under the back button.
          maxChildSize: _max = rideSheetMaxSize(MediaQuery.of(context)),
          snapSizes: rideSheetSnapSizes(const [
            0.4,
            0.46,
            0.72,
            0.8,
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
                      Text(
                        l10n.rideMatchingReceiving,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: DealGoSpacing.s12),
                      RideViewerBanner(count: ride.viewingDriverCount),
                      const SizedBox(height: DealGoSpacing.s12),
                      RidePanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RideStopList(
                              pickup: ride.pickup.label,
                              dropoff: ride.dropoff.label,
                              stops: [
                                for (final s in ride.stops) s.point.label,
                              ],
                            ),
                            const SizedBox(height: DealGoSpacing.s12),
                            Row(
                              children: [
                                RideStatusChip(
                                  label: l10n.rideMatchingSent,
                                  tone: RideChipTone.green,
                                ),
                                const Spacer(),
                                Text(
                                  formatRideVnd(ride.offeredFareVnd),
                                  style: textTheme.titleMedium?.copyWith(
                                    color: DealGoColors.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (onAutoAccept case final toggle?) ...[
                        const SizedBox(height: DealGoSpacing.s12),
                        RideAutoAcceptSwitch(
                          priceVnd: ride.offeredFareVnd,
                          enabled: autoAccept,
                          busy: actingOn != null,
                          onChanged: toggle,
                        ),
                      ],
                      if (onRaise case final raise?) ...[
                        const SizedBox(height: DealGoSpacing.s8),
                        Column(
                          key: const Key('ride-inline-raise'),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.rideRaiseFare,
                              style: textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: DealGoSpacing.s4),
                            // t73u (owner): amount only, one compact row.
                            RideFareRaiseChips(
                              keyPrefix: 'ride-inline-raise',
                              presets:
                                  rideRaiseFareOptions(
                                        ride.offeredFareVnd,
                                        maxFareVnd: ride.maxOfferedFareVnd,
                                        referenceFareVnd: ride.referenceFareVnd,
                                      )
                                      .map(
                                        (o) => RideFarePreset(
                                          percent: o.percent,
                                          amountVnd: o.amountVnd,
                                          enabled: true,
                                        ),
                                      )
                                      .toList(),
                              selectedVnd: null,
                              enabled: actingOn == null,
                              onPick: raise,
                            ),
                          ],
                        ),
                      ],
                      if (inlineError case final err?) ...[
                        const SizedBox(height: DealGoSpacing.s8),
                        Text(
                          err,
                          key: const Key('ride-inline-error'),
                          style: textTheme.bodySmall?.copyWith(
                            color: DealGoColors.danger,
                          ),
                        ),
                      ],
                      if (offers.isNotEmpty) ...[
                        const SizedBox(height: DealGoSpacing.s12),
                        Text(
                          l10n.rideOffersCount(offers.length),
                          key: _offersKey,
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: DealGoSpacing.s8),
                        for (final offer in offers) ...[
                          RideOfferCountdown(
                            key: ValueKey('offer-cd-${offer.id}'),
                            expiresAt: offer.expiresAt,
                            builder: (context, progress, seconds) =>
                                _InlineOfferCard(
                                  rideId: ride.id,
                                  offer: offer,
                                  progress: progress,
                                  seconds: seconds,
                                  busy: actingOn == offer.id,
                                  enabled: actingOn == null,
                                  onAccept: onAccept == null
                                      ? null
                                      : () => onAccept!(offer),
                                  onDecline: onDecline == null
                                      ? null
                                      : () => onDecline!(offer),
                                ),
                          ),
                          const SizedBox(height: DealGoSpacing.s8),
                        ],
                      ] else ...[
                        const SizedBox(height: DealGoSpacing.s12),
                        RidePanel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              RideMoneyLine(
                                label: l10n.rideStatusLabel,
                                amount: rideStatusText(l10n, ride.status),
                              ),
                              const SizedBox(height: DealGoSpacing.s8),
                              Text(
                                l10n.rideNoOffersTitle,
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: DealGoSpacing.s4),
                              Text(
                                l10n.rideNoOffersMessage,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: DealGoColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (offline) ...[
                        const SizedBox(height: DealGoSpacing.s12),
                        RideOfflineNotice(
                          detail: l10n.rideMatchingRefreshFailed,
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
                    rideSheetFooterBottom(context),
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: DealGoSecondaryButton(
                            key: const Key('ride-cancel-search'),
                            label: l10n.rideCancelSearch,
                            compact: true,
                            enabled: !busy,
                            onPressed: onCancel,
                          ),
                        ),
                        if (openOffers != null) ...[
                          const SizedBox(width: DealGoSpacing.s8),
                          Expanded(
                            // Voucher / offer details stay one tap away;
                            // accepting no longer needs it.
                            child: DealGoSecondaryButton(
                              key: const Key('ride-open-offers-from-wait'),
                              label: l10n.rideViewOffers,
                              compact: true,
                              onPressed: openOffers,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        MapBackOverlay(
          buttonKey: const Key('ride-matching-back'),
          enabled: !busy,
          onPressed: onBack,
        ),
      ],
    );
  }
}

/// inDrive-style quote: driver, price, and Từ chối / Chấp nhận on the card.
class _InlineOfferCard extends StatelessWidget {
  const _InlineOfferCard({
    required this.rideId,
    required this.offer,
    required this.busy,
    required this.enabled,
    required this.onAccept,
    required this.onDecline,
    this.progress = 1,
    this.seconds = 20,
  });

  final String rideId;
  final RideOffer offer;

  /// t81u: countdown shown inside the Accept button only.
  final double progress;
  final int seconds;
  final bool busy;
  final bool enabled;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return RidePanel(
      key: Key('ride-inline-offer-${offer.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: DriverCardTile(
                  job: DriverCardJob.rideOffer,
                  jobId: rideId,
                  offerId: offer.id,
                  accessToken: rideAccessToken(context) ?? '',
                ),
              ),
              const SizedBox(width: DealGoSpacing.s8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatRideVnd(offer.amountVnd),
                    style: textTheme.titleMedium?.copyWith(
                      color: DealGoColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    rideOfferKindLabel(l10n, offer.kind),
                    style: textTheme.labelSmall?.copyWith(
                      color: DealGoColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: DealGoSpacing.s12),
          Row(
            children: [
              if (onDecline != null) ...[
                Expanded(
                  child: DealGoSecondaryButton(
                    key: Key('ride-inline-decline-${offer.id}'),
                    label: l10n.rideOfferDeclineShort,
                    compact: true,
                    enabled: enabled,
                    onPressed: onDecline!,
                  ),
                ),
                const SizedBox(width: DealGoSpacing.s8),
              ],
              Expanded(
                child: RideOfferAcceptButton(
                  key: Key('ride-inline-accept-${offer.id}'),
                  label: l10n.rideOfferAcceptShort,
                  progress: progress,
                  seconds: seconds,
                  busy: busy,
                  enabled: enabled && onAccept != null,
                  onPressed: onAccept,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MatchingTimeout extends StatelessWidget {
  const _MatchingTimeout({
    required this.ride,
    required this.busy,
    required this.onBack,
    required this.onEdit,
    required this.onRetry,
  });

  final RideView ride;
  final bool busy;
  final VoidCallback onBack;
  final VoidCallback onEdit;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DealGoAppHeader(
          title: AppLocalizations.of(context).rideMatchingSearching,
          onBack: onBack,
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              DealGoDimensions.pageGutter,
              DealGoSpacing.s8,
              DealGoDimensions.pageGutter,
              DealGoSpacing.s16,
            ),
            children: [
              RideStateHero(
                icon: DealGoIcons.timer,
                iconColor: DealGoColors.warning,
                background: DealGoColors.amberSurface,
                title: AppLocalizations.of(context).rideTimeoutTitle,
                message: AppLocalizations.of(context).rideTimeoutMessage,
              ),
              const SizedBox(height: DealGoSpacing.s16),
              RidePanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RideSectionTitle(
                      AppLocalizations.of(context).rideCurrentRoute,
                    ),
                    const SizedBox(height: DealGoSpacing.s12),
                    RideStopList(
                      pickup: ride.pickup.label,
                      dropoff: ride.dropoff.label,
                      stops: [for (final s in ride.stops) s.point.label],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DealGoSpacing.s12),
              RidePanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RideSectionTitle(
                      AppLocalizations.of(context).rideCurrentOfferedFare,
                    ),
                    const SizedBox(height: DealGoSpacing.s8),
                    RideMoneyLine(
                      label: AppLocalizations.of(context).rideOfferedFare,
                      amount: formatRideVnd(ride.offeredFareVnd),
                      emphasize: true,
                    ),
                    RideMoneyLine(
                      label: AppLocalizations.of(context).kycStepVehicle,
                      amount: rideVehicleClassLabel(
                        AppLocalizations.of(context),
                        ride.vehicleClassCode,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            DealGoDimensions.pageGutter,
            DealGoSpacing.s8,
            DealGoDimensions.pageGutter,
            DealGoSpacing.s12,
          ),
          child: RideDualActions(
            secondaryLabel: AppLocalizations.of(context).rideEditRoute,
            primaryLabel: AppLocalizations.of(context).rideFindAgain,
            enabled: !busy,
            onSecondary: onEdit,
            onPrimary: onRetry,
          ),
        ),
      ],
    );
  }
}

class _AssignedHandoff extends StatelessWidget {
  const _AssignedHandoff({required this.onBack, required this.onOpen});

  final VoidCallback onBack;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DealGoAppHeader(
          title: AppLocalizations.of(context).rideMatchingReceiving,
          onBack: onBack,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(DealGoDimensions.pageGutter),
            child: Text(AppLocalizations.of(context).rideAssignedNote),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(DealGoDimensions.pageGutter),
          child: DealGoSecondaryButton(
            label: AppLocalizations.of(context).rideTrack,
            onPressed: onOpen,
          ),
        ),
      ],
    );
  }
}

class _CancelledMatch extends StatelessWidget {
  const _CancelledMatch({required this.onBack, required this.onHome});

  final VoidCallback onBack;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        DealGoAppHeader(title: l10n.rideRequestCancelled, onBack: onBack),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              DealGoDimensions.pageGutter,
              DealGoSpacing.s8,
              DealGoDimensions.pageGutter,
              DealGoSpacing.s16,
            ),
            children: [
              RideStateHero(
                icon: DealGoIcons.close,
                iconColor: DealGoColors.danger,
                background: DealGoColors.dangerSurface,
                title: l10n.rideRequestCancelled,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            DealGoDimensions.pageGutter,
            DealGoSpacing.s8,
            DealGoDimensions.pageGutter,
            DealGoSpacing.s12,
          ),
          child: DealGoPrimaryButton(
            key: const Key('ride-cancelled-home'),
            label: l10n.rideBookTitle,
            onPressed: onHome,
          ),
        ),
      ],
    );
  }
}
