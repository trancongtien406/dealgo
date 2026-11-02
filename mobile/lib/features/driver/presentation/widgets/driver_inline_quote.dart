import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/l10n/api_error_text.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/realtime/snapshot_realtime.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../ride/domain/entities/ride_models.dart';
import '../../../ride/domain/entities/ride_money.dart';
import '../../../ride/domain/params/submit_ride_offer_params.dart';
import '../../../ride/domain/usecases/get_ride.dart';
import '../../../ride/domain/ride_fare_presets.dart';
import '../../../ride/presentation/widgets/ride_fare_raise_chips.dart';
import '../../../ride/presentation/widgets/ride_negotiation_ui.dart';
import '../../domain/usecases/submit_driver_ride_offer.dart';
import '../cubit/driver_offer_cubit.dart';
import '../utils/driver_routes.dart';
import 'driver_widgets.dart';
import 'ride_view_beacon.dart';

/// Quotes this driver sent in this app session (rideId → amount), shared by
/// the incoming-job card and the job list so both show the sent state.
final driverSentQuotes = ValueNotifier<Map<String, int>>(const {});

const driverQuoteStepVnd = 1000;

/// Counter chips on the customer's fare. [OpenRide.maxCounterVnd] is the cap
/// the server will store; the headroom is that cap split in three.
List<RideFarePreset> driverQuoteChips(OpenRide ride) {
  final max = ride.maxCounterVnd;
  return rideFareRaisePresets(
    suggestedVnd: ride.offeredFareVnd,
    maxBidVnd: max ?? ride.offeredFareVnd * 3,
    maxHeadroomPercent:
        ride.counterHeadroomPercent ?? (max == null ? 30 : null),
  );
}

/// inDrive-style inline quote: −/+ by fare step, +10/20/30% amount chips, one-tap accept of
/// the customer's price, send — no separate page. Server rules (min/max,
/// cap, edit limit, expiry) still apply and surface inline.
class DriverInlineQuote extends StatelessWidget {
  const DriverInlineQuote({required this.ride, this.onSent, super.key});

  final OpenRide ride;
  final ValueChanged<int>? onSent;

  /// Test hook: token used when no signed-in AuthCubit is in scope.
  @visibleForTesting
  static String? debugAccessToken;

  @override
  Widget build(BuildContext context) {
    SubmitDriverRideOffer? submit;
    try {
      submit = context.read<SubmitDriverRideOffer>();
    } catch (_) {
      return const SizedBox.shrink();
    }
    SnapshotRealtime? realtime;
    GetRide? getRide;
    try {
      realtime = context.read<SnapshotRealtime>();
    } catch (_) {}
    try {
      getRide = context.read<GetRide>();
    } catch (_) {}
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RideViewBeacon(rideId: ride.id),
        BlocProvider(
          create: (context) => DriverOfferCubit(
            submitDriverRideOffer: submit!,
            getRide: getRide,
            realtime: realtime,
          ),
          child: _InlineQuote(ride: ride, onSent: onSent),
        ),
      ],
    );
  }
}

class _InlineQuote extends StatefulWidget {
  const _InlineQuote({required this.ride, this.onSent});

  final OpenRide ride;
  final ValueChanged<int>? onSent;

  @override
  State<_InlineQuote> createState() => _InlineQuoteState();
}

class _InlineQuoteState extends State<_InlineQuote> {
  late int _amount = widget.ride.offeredFareVnd;
  int? _sent;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _sent = driverSentQuotes.value[widget.ride.id];
    if (_sent != null) _watch();
  }

  @override
  void didUpdateWidget(covariant _InlineQuote old) {
    super.didUpdateWidget(old);
    // Customer raised their fare: follow it unless the driver set a higher one.
    final fare = widget.ride.offeredFareVnd;
    if (fare != old.ride.offeredFareVnd && _amount < fare) {
      setState(() => _amount = fare);
    }
  }

  String? _token() {
    try {
      return driverAccessToken(context) ?? DriverInlineQuote.debugAccessToken;
    } catch (_) {
      return DriverInlineQuote.debugAccessToken;
    }
  }

  void _watch() {
    final token = _token();
    if (token == null || token.isEmpty) return;
    unawaited(
      context
          .read<DriverOfferCubit>()
          .watchSelection(accessToken: token, rideId: widget.ride.id)
          .catchError((Object _) {}),
    );
  }

  void _nudge(int delta) {
    final floor = widget.ride.offeredFareVnd;
    final cap = widget.ride.maxCounterVnd;
    var next = _amount + delta;
    if (next < floor) return;
    if (cap != null && next > cap) {
      if (delta > 0 && _amount < cap) {
        next = cap;
      } else {
        return;
      }
    }
    setState(() {
      _amount = next;
      _error = null;
    });
  }

  Future<void> _send(int amount) async {
    final token = _token();
    if (_busy || token == null || token.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<DriverOfferCubit>().submit(
        SubmitRideOfferRequest(
          accessToken: token,
          rideId: widget.ride.id,
          amountVnd: amount,
          routeVersion: widget.ride.routeVersion,
        ),
      );
      if (!mounted) return;
      driverSentQuotes.value = {
        ...driverSentQuotes.value,
        widget.ride.id: amount,
      };
      setState(() {
        _busy = false;
        _sent = amount;
      });
      _watch();
      widget.onSent?.call(amount);
    } catch (error) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      setState(() {
        _busy = false;
        _error = error is ApiException
            ? apiErrorText(l10n, error)
            : l10n.driverOfferSendFailed;
      });
    }
  }

  Future<void> _withdraw() async {
    final client = maybeRideNegotiation(context);
    final token = _token();
    if (_busy || client == null || token == null || token.isEmpty) return;
    setState(() => _busy = true);
    try {
      await client.withdrawOffer(accessToken: token, rideId: widget.ride.id);
      if (!mounted) return;
      driverSentQuotes.value = {...driverSentQuotes.value}
        ..remove(widget.ride.id);
      await context.read<DriverOfferCubit>().stopWatching();
      setState(() {
        _busy = false;
        _sent = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = negotiationErrorText(context, error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final id = widget.ride.id;
    final fare = widget.ride.offeredFareVnd;
    return BlocListener<DriverOfferCubit, DriverOfferSelection>(
      listener: (context, selection) {
        if (selection == DriverOfferSelection.selected) {
          driverSentQuotes.value = {...driverSentQuotes.value}..remove(id);
          context.push(DriverRoutes.active(id), extra: widget.ride);
        }
      },
      child: Column(
        key: Key('driver-inline-quote-$id'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_sent case final sent?) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${l10n.driverOfferSent} · ${formatRideVnd(sent)}',
                    key: Key('driver-inline-sent-$id'),
                    style: text.titleSmall?.copyWith(
                      color: DealGoColors.primary,
                    ),
                  ),
                ),
                if (maybeRideNegotiation(context) != null)
                  TextButton(
                    key: Key('driver-inline-withdraw-$id'),
                    onPressed: _busy ? null : _withdraw,
                    child: Text(l10n.driverWithdrawOfferShort),
                  ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                _StepButton(
                  key: Key('driver-inline-minus-$id'),
                  icon: Icons.remove,
                  onPressed: _amount > fare
                      ? () => _nudge(-driverQuoteStepVnd)
                      : null,
                ),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      formatRideVnd(_amount),
                      key: Key('driver-inline-amount-$id'),
                      textAlign: TextAlign.center,
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                _StepButton(
                  key: Key('driver-inline-plus-$id'),
                  icon: Icons.add,
                  onPressed:
                      widget.ride.maxCounterVnd != null &&
                          _amount >= widget.ride.maxCounterVnd!
                      ? null
                      : () => _nudge(driverQuoteStepVnd),
                ),
              ],
            ),
            const SizedBox(height: DealGoSpacing.s4),
            RideFareRaiseChips(
              keyPrefix: 'driver-inline-chip',
              keySuffix: '-$id',
              presets: driverQuoteChips(widget.ride),
              selectedVnd: _amount,
              onPick: (amount) => setState(() {
                _amount = amount;
                _error = null;
              }),
            ),
            const SizedBox(height: DealGoSpacing.s8),
            Row(
              children: [
                if (_amount != fare) ...[
                  Expanded(
                    child: OutlinedButton(
                      key: Key('driver-inline-accept-$id'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 40),
                        padding: const EdgeInsets.symmetric(
                          horizontal: DealGoSpacing.s8,
                        ),
                      ),
                      onPressed: _busy ? null : () => _send(fare),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          l10n.rideAcceptAmount(formatRideVnd(fare)),
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: DealGoSpacing.s8),
                ],
                Expanded(
                  child: DealGoPrimaryButton(
                    key: Key('driver-inline-send-$id'),
                    label: _amount == fare
                        ? l10n.rideAcceptAmount(formatRideVnd(fare))
                        : l10n.driverSendQuoteAmount(formatRideVnd(_amount)),
                    compact: true,
                    isLoading: _busy,
                    enabled: !_busy,
                    onPressed: () => _send(_amount),
                  ),
                ),
              ],
            ),
          ],
          if (_error case final err?)
            Padding(
              padding: const EdgeInsets.only(top: DealGoSpacing.s8),
              child: Text(
                err,
                key: Key('driver-inline-error-$id'),
                style: text.bodySmall?.copyWith(color: DealGoColors.danger),
              ),
            ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onPressed, super.key});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.outlined(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 36, height: 36),
      padding: EdgeInsets.zero,
    );
  }
}
