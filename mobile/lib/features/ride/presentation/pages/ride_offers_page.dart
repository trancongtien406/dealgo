import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/components/dealgo_dialog.dart';
import '../../../../core/design_system/components/dealgo_haptics.dart';
import '../../../../core/network/api_error_l10n.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/request_failure.dart';
import '../../../../core/design_system/components/dealgo_state_view.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/ride_money.dart';
import '../../domain/entities/ride_models.dart';
import '../../domain/params/select_ride_offer_params.dart';
import '../../domain/ride_idempotency.dart';
import '../../domain/usecases/cancel_ride.dart';
import '../../domain/usecases/get_ride.dart';
import '../../domain/usecases/select_ride_offer.dart';
import '../cubit/ride_offers_cubit.dart';
import '../widgets/ride_offers_widgets.dart';
import '../utils/ride_routes.dart';
import '../cubit/ride_session.dart';
import '../widgets/ride_widgets.dart';
import '../widgets/ride_negotiation_ui.dart';
import '../widgets/ride_edit_stops_sheet.dart';
import '../../domain/stops/ride_stops_client.dart';
import '../../../../core/maps/map_lat_lng.dart';
import '../../../../core/l10n/api_error_text.dart';
import '../../../promotion/domain/entities/voucher_quote.dart';
import '../../../../core/design_system/components/dealgo_app_header.dart';
import '../../../../core/realtime/snapshot_realtime.dart';
import '../../../payment/domain/payment_models.dart';
import '../../../payment/presentation/payment_method_sheet.dart';

class RideOffersPage extends StatelessWidget {
  const RideOffersPage({required this.rideId, this.clock, super.key});

  final String rideId;
  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => RideOffersCubit(
        getRide: context.read<GetRide>(),
        selectRideOffer: context.read<SelectRideOffer>(),
        cancelRide: context.read<CancelRide>(),
        realtime: _maybeRealtime(context),
      ),
      child: _RideOffersView(rideId: rideId, clock: clock),
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

class _RideOffersView extends StatefulWidget {
  const _RideOffersView({required this.rideId, this.clock});

  final String rideId;
  final DateTime Function()? clock;

  @override
  State<_RideOffersView> createState() => _RideOffersPageState();
}

class _RideOffersPageState extends State<_RideOffersView> {
  RideView? _ride;
  MultiStopSettings _multiStop = MultiStopSettings.disabled;
  String? _selectedOfferId;
  OfferBlock? _block;
  var _loading = true;
  var _offline = false;
  var _busy = false;
  Object? _failure;
  String? _message;
  String? _selectKey;
  String? _voucherCode;
  var _voucherDiscountVnd = 0;
  var _voucherEpoch = 0;

  void _onVoucherQuote(VoucherQuote? quote) {
    final valid = quote != null && quote.valid;
    setState(() {
      _voucherCode = valid ? quote.code : null;
      _voucherDiscountVnd = valid ? quote.discountVnd : 0;
      // A different voucher is a different request; never replay the old key.
      _selectKey = null;
    });
  }

  DateTime get _now => (widget.clock ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _load();
      _watch();
    });
    unawaited(Future<void>.microtask(_loadMultiStop));
  }

  var _watching = false;

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
        .read<RideOffersCubit>()
        .watch(
          accessToken: token,
          rideId: widget.rideId,
          refresh: () async {
            final ride = _ride;
            if (!mounted ||
                _busy ||
                (ride != null && ride.status != RideStatus.negotiating)) {
              return;
            }
            await _load(silent: true);
          },
        )
        .catchError((Object _) {});
  }

  Future<void> _load({bool silent = false}) async {
    final token = rideAccessToken(context);
    if (token == null) {
      setState(() {
        _loading = false;
        _offline = false;
        _failure = sessionExpiredFailure;
        _message = null;
      });
      return;
    }
    if (!silent) {
      setState(() {
        _loading = true;
        _offline = false;
        _message = null;
        _block = null;
      });
    }
    try {
      final ride = await context.read<RideOffersCubit>().load(
        accessToken: token,
        rideId: widget.rideId,
      );
      if (!mounted) {
        return;
      }
      final session = context.read<RideSessionCubit>();
      if (ride.status == RideStatus.negotiating &&
          !rideNegotiationExpired(ride, _now)) {
        session.remember(ride.id);
      } else {
        session.clear();
      }
      if (ride.status.hasDriver) {
        session.clear();
        setState(() {
          _ride = ride;
          _loading = false;
          _selectedOfferId = null;
        });
        if (!mounted) {
          return;
        }
        // Replace: back from tracking must not land on this stale offers screen.
        context.pushReplacement(RideRoutes.tracking(ride.id));
        return;
      }
      final selectable = _selectable(ride);
      setState(() {
        _ride = ride;
        _loading = false;
        _selectedOfferId = _keepSelection(selectable);
      });
    } catch (error) {
      if (!mounted || silent) {
        return;
      }
      setState(() {
        _loading = false;
        _failure = error;
        _offline = rideFailureIsOffline(error);
        _message = _offline
            ? null
            : (error is ApiException
                  ? apiErrorText(AppLocalizations.of(context), error)
                  : AppLocalizations.of(context).errorLoadFailed);
      });
    }
  }

  List<RideOffer> _selectable(RideView ride) {
    final offers = ride.offers.where(
      (offer) => rideOfferSelectable(offer, _now),
    );
    final sorted = offers.toList()
      ..sort((a, b) => a.amountVnd.compareTo(b.amountVnd));
    return sorted;
  }

  String? _keepSelection(List<RideOffer> offers) {
    final current = _selectedOfferId;
    if (current != null && offers.any((offer) => offer.id == current)) {
      return current;
    }
    if (offers.isEmpty) {
      return null;
    }
    return offers.first.id;
  }

  /// True when an online payment method is enabled for this ride's service (else cash-only).
  Future<bool> _onlinePaymentAvailable(
    String token,
    String? vehicleClassCode,
  ) async {
    try {
      final methods = await defaultPaymentApi()
          .listMethods(
            accessToken: token,
            service: paymentServiceForVehicleClass(vehicleClassCode),
          )
          .timeout(const Duration(seconds: 4));
      return methods.any((m) => !m.isCash);
    } catch (_) {
      return false;
    }
  }

  Future<void> _select() async {
    if (_busy) {
      return;
    }
    final ride = _ride;
    final offerId = _selectedOfferId;
    if (ride == null || offerId == null) {
      return;
    }
    if (rideNegotiationExpired(ride, _now)) {
      setState(() => _block = const OfferBlock.expired());
      return;
    }
    RideOffer? offer;
    for (final candidate in ride.offers) {
      if (candidate.id == offerId) {
        offer = candidate;
      }
    }
    if (offer == null || !rideOfferSelectable(offer, _now)) {
      setState(() => _block = const OfferBlock.expired());
      return;
    }
    final chosen = offer;
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDealGoConfirmDialog(
      context: context,
      title: l10n.rideOfferConfirmTitle,
      body: l10n.rideOfferConfirmBody(
        formatRideVnd(
          rideCashAfterVoucher(chosen.amountVnd, _voucherDiscountVnd),
        ),
      ),
      confirmLabel: l10n.rideOfferConfirmAction,
      cancelLabel: l10n.rideOfferConfirmCancel,
      confirmKey: const Key('ride-offer-confirm'),
    );
    if (!confirmed || !mounted || _busy) {
      return;
    }
    if (!rideOfferSelectable(chosen, _now)) {
      setState(() => _block = const OfferBlock.expired());
      return;
    }
    final token = rideAccessToken(context);
    if (token == null) {
      setState(() => _message = sessionExpiredMessage(context));
      return;
    }
    final key = _selectKey ?? createRideIdempotencyKey();
    _selectKey = key;
    final request = SelectRideOfferRequest(
      accessToken: token,
      idempotencyKey: key,
      rideId: ride.id,
      offerId: chosen.id,
      voucherCode: _voucherCode,
    );
    setState(() {
      _busy = true;
      _offline = false;
      _message = null;
    });
    try {
      final updated = await context.read<RideOffersCubit>().select(request);
      if (!mounted) {
        return;
      }
      final agreed = updated.agreedFareVnd;
      if (!updated.status.hasDriver || agreed == null) {
        setState(() {
          _busy = false;
          _ride = updated;
          _message = AppLocalizations.of(context).rideNoAgreedYet;
        });
        return;
      }
      context.read<RideSessionCubit>().clear();
      DealGoHaptics.success();
      setState(() {
        _busy = false;
        _ride = updated;
        _selectKey = null;
      });
      if (agreed == chosen.amountVnd &&
          updated.discountVnd == 0 &&
          !await _onlinePaymentAvailable(token, updated.vehicleClassCode)) {
        // Price unchanged, no voucher to read back and cash is the only method: the separate
        // "confirmed" screen was a dead-end extra tap before tracking. Go straight to tracking.
        // When an online method is enabled the confirm screen hosts the payment picker.
        if (!mounted) {
          return;
        }
        context.pushReplacement(RideRoutes.tracking(updated.id));
        return;
      }
      if (!mounted) {
        return;
      }
      await context.push(
        RideRoutes.confirm(updated.id),
        extra: RideConfirmArgs(
          ride: updated,
          tappedAmountVnd: chosen.amountVnd,
        ),
      );
      if (mounted) {
        await _load();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      _selectKey = null;
      if (error is ApiException && error.errorCode == 'RIDE_OFFER_EXPIRED') {
        setState(() {
          _busy = false;
          _block = OfferBlock.expired(amountVnd: chosen.amountVnd);
        });
        return;
      }
      if (error is ApiException && error.errorCode.startsWith('VOUCHER_')) {
        // The selection rolled back with the voucher; drop the code so the next tap is plain.
        final l10n = AppLocalizations.of(context);
        setState(() {
          _busy = false;
          _voucherCode = null;
          _voucherDiscountVnd = 0;
          _voucherEpoch += 1;
          _message = l10n.rideVoucherDropped(apiErrorText(l10n, error));
        });
        return;
      }
      // RIDE-003: a driver assigned elsewhere answers RIDE_OFFER_DRIVER_UNAVAILABLE;
      // same outcome for the customer as a taken offer: pick another one.
      if (error is ApiException &&
          (error.errorCode == 'RIDE_OFFER_UNAVAILABLE' ||
              error.errorCode == 'RIDE_OFFER_DRIVER_UNAVAILABLE')) {
        setState(() {
          _busy = false;
          _block = OfferBlock.taken(amountVnd: chosen.amountVnd);
        });
        return;
      }
      setState(() {
        _busy = false;
        if (rideFailureIsOffline(error)) {
          _offline = true;
        } else {
          _message = error is ApiException
              ? apiErrorText(AppLocalizations.of(context), error)
              : AppLocalizations.of(context).rideSelectFailed;
        }
      });
    }
  }

  Future<void> _cancel() async {
    if (_busy) {
      return;
    }
    final ride = _ride;
    if (ride == null || ride.status != RideStatus.negotiating) {
      return;
    }
    final token = rideAccessToken(context);
    if (token == null) {
      return;
    }
    setState(() => _busy = true);
    try {
      final updated = await context.read<RideOffersCubit>().cancel(
        accessToken: token,
        rideId: ride.id,
      );
      if (!mounted) {
        return;
      }
      context.read<RideSessionCubit>().clear();
      setState(() {
        _busy = false;
        _ride = updated;
        _block = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        if (rideFailureIsOffline(error)) {
          _offline = true;
        } else {
          _message = error is ApiException
              ? apiErrorText(AppLocalizations.of(context), error)
              : AppLocalizations.of(context).rideCancelFailed;
        }
      });
    }
  }

  RideStopsClient? get _stopsClient {
    try {
      return context.read<RideStopsClient>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  /// Admin multi-stop flags; failure keeps the edit button hidden.
  Future<void> _loadMultiStop() async {
    final client = _stopsClient;
    final token = rideAccessToken(context);
    if (client == null || token == null) {
      return;
    }
    try {
      final settings = await client.config(accessToken: token);
      if (mounted) {
        setState(() => _multiStop = settings);
      }
    } catch (_) {
      // Keep disabled.
    }
  }

  bool _canEditStops(RideView ride) =>
      ride.status == RideStatus.negotiating &&
      (_maxStopsFor(ride) > 0 || ride.stops.isNotEmpty);

  int _maxStopsFor(RideView ride) =>
      _multiStop.forVehicleClass(ride.vehicleClassCode).maxStops;

  /// Customer replaces the stops while NEGOTIATING. Pending offers are dropped
  /// by the server, so we ask first when any exist.
  Future<void> _editStops(RideView ride) async {
    final client = _stopsClient;
    final token = rideAccessToken(context);
    if (_busy || client == null || token == null) {
      return;
    }
    final max = _maxStopsFor(ride);
    final next = await showRideEditStopsSheet(
      context: context,
      current: [for (final s in ride.stops) s.point],
      maxStops: max < ride.stops.length ? ride.stops.length : max,
      pick: (ctx) => defaultRideStopPicker(
        ctx,
        near: MapLatLng(lat: ride.pickup.lat, lng: ride.pickup.lng),
      ),
    );
    if (next == null || !mounted) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final hasOffers = ride.offers.any(
      (o) => o.status == RideOfferStatus.pending,
    );
    if (hasOffers) {
      final ok = await showDealGoConfirmDialog(
        context: context,
        title: l10n.rideEditStopsConfirmTitle,
        body: l10n.rideEditStopsConfirmBody,
        confirmLabel: l10n.rideEditStopsConfirmAction,
        cancelLabel: l10n.rideOfferConfirmCancel,
        confirmKey: const Key('ride-edit-stops-confirm'),
      );
      if (!ok || !mounted) {
        return;
      }
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final updated = await client.updateStops(
        accessToken: token,
        rideId: ride.id,
        stops: next,
        routeVersion: ride.routeVersion,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _ride = updated;
        _selectedOfferId = null;
      });
      showNegotiationSnack(context, l10n.rideEditStopsDone);
      await _load(silent: true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _message = negotiationErrorText(context, error);
      });
    }
  }

  /// Raise the fare in place; drivers see it over the socket.
  Future<void> _raiseFare(RideView ride) async {
    final client = maybeRideNegotiation(context);
    final token = rideAccessToken(context);
    if (_busy || client == null || token == null) {
      return;
    }
    final amount = await showRaiseFareSheet(
      context: context,
      currentFareVnd: ride.offeredFareVnd,
      formatVnd: formatRideVnd,
      maxFareVnd: ride.maxOfferedFareVnd,
      referenceFareVnd: ride.referenceFareVnd,
    );
    if (amount == null || !mounted) {
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await client.raiseFare(
        accessToken: token,
        rideId: ride.id,
        amountVnd: amount,
      );
      if (!mounted) {
        return;
      }
      setState(() => _busy = false);
      showNegotiationSnack(
        context,
        AppLocalizations.of(context).rideRaiseFareDone(formatRideVnd(amount)),
      );
      await _load(silent: true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _message = negotiationErrorText(context, error);
      });
    }
  }

  /// Decline the selected offer without cancelling the ride.
  Future<void> _declineSelected(RideView ride) async {
    final client = maybeRideNegotiation(context);
    final token = rideAccessToken(context);
    final offerId = _selectedOfferId;
    if (_busy || client == null || token == null || offerId == null) {
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await client.declineOffer(
        accessToken: token,
        rideId: ride.id,
        offerId: offerId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _selectedOfferId = null;
      });
      showNegotiationSnack(
        context,
        AppLocalizations.of(context).rideDeclineOfferDone,
      );
      await _load(silent: true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _message = negotiationErrorText(context, error);
      });
    }
  }

  void _changeFare(RideView ride) {
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
        body: SafeArea(child: _body(ride)),
      ),
    );
  }

  Widget _body(RideView? ride) {
    if (_loading && ride == null) {
      return Column(
        children: [
          DealGoAppHeader(
            title: AppLocalizations.of(context).rideDriverOffers,
            onBack: _back,
          ),
          const Expanded(child: Center(child: CircularProgressIndicator())),
        ],
      );
    }
    if (ride == null) {
      final l10n = AppLocalizations.of(context);
      return Column(
        children: [
          DealGoAppHeader(title: l10n.rideDriverOffers, onBack: _back),
          Expanded(
            child: DealGoStateView.failure(
              context,
              onRetry: _load,
              cause: _failure,
              message: _message ?? l10n.rideOffersLoadFailed,
            ),
          ),
        ],
      );
    }
    final block = _block;
    if (block != null) {
      return BlockedOffers(
        ride: ride,
        block: block,
        onBack: _back,
        onChangeFare: () => _changeFare(ride),
        onRefresh: _load,
      );
    }
    if (rideNegotiationExpired(ride, _now) ||
        ride.status == RideStatus.expired) {
      return ExpiredRide(
        ride: ride,
        onBack: _back,
        onChangeFare: () => _changeFare(ride),
        onRefresh: _load,
      );
    }
    if (ride.status == RideStatus.cancelled) {
      return TerminalRide(
        title: AppLocalizations.of(context).rideRequestCancelled,
        status: ride.status.wire,
        message: AppLocalizations.of(context).rideOfferInvalid,
        onBack: _back,
      );
    }
    if (ride.status.hasDriver) {
      final agreed = ride.agreedFareVnd;
      return TerminalRide(
        title: AppLocalizations.of(context).rideAgreedTitle,
        status: ride.status.wire,
        message: agreed == null
            ? AppLocalizations.of(context).rideAgreedMissing
            : AppLocalizations.of(context).rideCustomerPaysAmount(
                formatRideVnd(rideCashAfterVoucher(agreed, ride.discountVnd)),
              ),
        onBack: _back,
        actionLabel: agreed == null
            ? null
            : AppLocalizations.of(context).rideTrack,
        onAction: agreed == null
            ? null
            : () => context.push(RideRoutes.tracking(ride.id)),
      );
    }
    final offers = _selectable(ride);
    final negotiation = maybeRideNegotiation(context);
    if (offers.isEmpty) {
      return EmptyOffers(
        ride: ride,
        busy: _busy,
        offline: _offline,
        message: _message,
        onBack: _back,
        onRetry: _load,
        onChangeFare: () => _changeFare(ride),
        onCancel: _cancel,
        onRaiseFare: negotiation == null ? null : () => _raiseFare(ride),
        onEditStops: _canEditStops(ride) ? () => _editStops(ride) : null,
      );
    }
    return OfferList(
      ride: ride,
      offers: offers,
      selectedOfferId: _selectedOfferId,
      busy: _busy,
      offline: _offline,
      message: _message,
      onBack: _back,
      onSelectOffer: (id) => setState(() => _selectedOfferId = id),
      onConfirm: _select,
      onAcceptOffer: (id) {
        setState(() => _selectedOfferId = id);
        unawaited(_select());
      },
      onCancel: _cancel,
      onRaiseFare: negotiation == null ? null : () => _raiseFare(ride),
      onEditStops: _canEditStops(ride) ? () => _editStops(ride) : null,
      onDeclineSelected: negotiation == null
          ? null
          : () => _declineSelected(ride),
      onVoucherQuote: _onVoucherQuote,
      voucherCode: _voucherCode,
      voucherDiscountVnd: _voucherDiscountVnd,
      voucherEpoch: _voucherEpoch,
    );
  }
}
