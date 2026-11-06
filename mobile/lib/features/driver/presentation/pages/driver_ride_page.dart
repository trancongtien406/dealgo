import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/api_base_url.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/components/dealgo_secondary_button.dart';
import '../../../../core/design_system/components/dealgo_text_field.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/network/api_exception.dart';
import '../../../parcel/presentation/widgets/parcel_labels.dart';
import '../../../ride/domain/entities/ride_models.dart';
import '../../../ride/presentation/utils/ride_vehicle_label.dart';
import '../../../ride/presentation/widgets/ride_negotiation_ui.dart';
import '../../../ride/domain/entities/ride_money.dart';
import '../../../ride/domain/params/submit_ride_offer_params.dart';
import '../../../ride/domain/usecases/get_ride.dart';
import '../../domain/usecases/submit_driver_ride_offer.dart';
import '../cubit/driver_offer_cubit.dart';

export '../cubit/driver_offer_cubit.dart'
    show DriverOfferSelection, driverOfferSelectionFor;
import '../utils/driver_routes.dart';
import '../widgets/driver_widgets.dart';
import '../widgets/ride_view_beacon.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../features/food/domain/entities/food_money.dart';
import '../../../../core/format/short_ref.dart';
import '../../../../core/l10n/api_error_text.dart';
import '../../../../core/realtime/snapshot_realtime.dart';
import '../cubit/driver_feed_cubit.dart';

class DriverRideDetailPage extends StatelessWidget {
  const DriverRideDetailPage({required this.ride, super.key});

  final OpenRide ride;

  @override
  Widget build(BuildContext context) {
    DriverFeedCubit? feed;
    try {
      feed = context.read<DriverFeedCubit>();
    } catch (_) {}
    if (feed == null) return _page(context, ride);
    // Follow the live feed so a customer fare raise shows (and quick-accept
    // sends the current price, not the one we were opened with).
    return BlocBuilder<DriverFeedCubit, DriverFeedState>(
      bloc: feed,
      builder: (context, state) => _page(
        context,
        state is DriverFeedReady
            ? state.rides.firstWhere((r) => r.id == ride.id, orElse: () => ride)
            : ride,
      ),
    );
  }

  Widget _page(BuildContext context, OpenRide ride) {
    final l10n = AppLocalizations.of(context);
    final classPhoto = resolveMediaUrl(ride.imageUrl);
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          DriverPageFrame(
            title: l10n.driverRideDetailTitle,
            subtitle: rideVehicleClassLabel(l10n, ride.vehicleClassCode),
            trailing: classPhoto == null
                ? null
                : RideVehicleClassPhoto(
                    imageUrl: ride.imageUrl,
                    code: ride.vehicleClassCode,
                    size: 36,
                  ),
            insetBottom: true,
            onBack: () => driverBack(context),
            footer: DriverFooter(
              // inDrive-style: one tap takes the customer's price; a counter
              // offer stays one step away.
              secondaryLabel: l10n.driverCounterOffer,
              secondaryKey: const Key('driver-open-offer'),
              primaryLabel: l10n.driverAcceptAtPrice(
                formatVnd(ride.offeredFareVnd),
              ),
              primaryKey: const Key('driver-quick-accept'),
              onSecondary: () =>
                  context.push(DriverRoutes.offer(ride.id), extra: ride),
              onPrimary: () => context.push(
                '${DriverRoutes.offer(ride.id)}?accept=1',
                extra: ride,
              ),
            ),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(
                DealGoDimensions.pageGutter,
                DealGoSpacing.s8,
                DealGoDimensions.pageGutter,
                DealGoSpacing.s16,
              ),
              children: [
                DriverPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // t73u: no green service badge; intercity is the one tag kept.
                      if (ride.intercity) ...[
                        DriverChip(
                          label: l10n.rideIntercity,
                          tone: DriverChipTone.warning,
                        ),
                        const SizedBox(height: DealGoSpacing.s12),
                      ],
                      Text(
                        AppLocalizations.of(context).rideRef(shortRef(ride.id)),
                      ),
                      const SizedBox(height: DealGoSpacing.s12),
                      DriverStop(
                        color: DealGoColors.brandGreen,
                        label: l10n.driverPickupLabel,
                        value: ride.pickup.label,
                      ),
                      for (final (i, stop) in ride.stops.indexed) ...[
                        const SizedBox(height: DealGoSpacing.s12),
                        DriverStop(
                          key: Key('driver-offer-stop-${i + 1}'),
                          color: DealGoColors.amber,
                          label: l10n.rideStopNumbered(i + 1),
                          value: stop.label,
                        ),
                      ],
                      const SizedBox(height: DealGoSpacing.s12),
                      DriverStop(
                        color: DealGoColors.danger,
                        label: l10n.driverDropoffLabel,
                        value: ride.dropoff.label,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: DealGoSpacing.s12),
                DriverPanel(
                  child: Column(
                    children: [
                      DriverMoneyRow(
                        label: l10n.driverCustomerFare,
                        value: formatRideVnd(ride.offeredFareVnd),
                        emphasize: true,
                      ),
                      DriverMoneyRow(
                        label: l10n.driverReferenceFare,
                        value: formatRideVnd(ride.referenceFareVnd),
                      ),
                      DriverMoneyRow(
                        label: l10n.driverOfferCount,
                        value: '${ride.offerCount}',
                      ),
                      // Drivers see the customer's rating first.
                      DriverMoneyRow(
                        key: const Key('driver-customer-rating'),
                        label: l10n.driverCustomerRating,
                        value: customerRatingText(l10n, ride.customerRating),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            width: 0,
            height: 0,
            child: RideViewBeacon(rideId: ride.id),
          ),
        ],
      ),
    );
  }
}

class DriverOfferPage extends StatelessWidget {
  const DriverOfferPage({
    required this.ride,
    this.quickAccept = false,
    super.key,
  });

  final OpenRide ride;

  /// Sends the customer's own price immediately (one-tap accept).
  final bool quickAccept;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => DriverOfferCubit(
        submitDriverRideOffer: context.read<SubmitDriverRideOffer>(),
        getRide: context.read<GetRide>(),
        realtime: _maybeRealtime(context),
      ),
      child: _DriverOfferView(ride: ride, quickAccept: quickAccept),
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

class _DriverOfferView extends StatefulWidget {
  const _DriverOfferView({required this.ride, this.quickAccept = false});

  final OpenRide ride;
  final bool quickAccept;

  @override
  State<_DriverOfferView> createState() => _DriverOfferPageState();
}

class _DriverOfferPageState extends State<_DriverOfferView> {
  late OpenRide _ride = widget.ride;
  late final TextEditingController _amount = TextEditingController(
    text: '${widget.ride.offeredFareVnd}',
  );
  StreamSubscription<DriverFeedState>? _feedSub;
  var _submitting = false;
  var _withdrawing = false;
  String? _error;
  int? _sentAmount;

  /// Take a pending offer back before the customer chooses.
  Future<void> _withdraw() async {
    final client = maybeRideNegotiation(context);
    final token = driverAccessToken(context);
    if (_withdrawing || client == null || token == null || token.isEmpty) {
      return;
    }
    // The withdraw button takes the submit button's place, so a double tap on
    // "send" used to pull the offer back a second later. Ask first.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final l10n = AppLocalizations.of(dialogContext);
        return AlertDialog(
          title: Text(l10n.driverWithdrawOffer),
          actions: [
            TextButton(
              key: const Key('driver-withdraw-cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                MaterialLocalizations.of(dialogContext).cancelButtonLabel,
              ),
            ),
            TextButton(
              key: const Key('driver-withdraw-confirm'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.driverWithdrawOffer),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() {
      _withdrawing = true;
      _error = null;
    });
    try {
      await client.withdrawOffer(accessToken: token, rideId: _ride.id);
      if (!mounted) {
        return;
      }
      showNegotiationSnack(
        context,
        AppLocalizations.of(context).driverWithdrawOfferDone,
      );
      context.go('/driver/jobs');
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _withdrawing = false;
        _error = negotiationErrorText(context, error);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    // The customer can raise the fare while we wait: the feed (re-synced on
    // the socket hint) carries the new price, and an ACCEPT offer follows it.
    try {
      _feedSub = context.read<DriverFeedCubit>().stream.listen(_onFeed);
    } catch (_) {}
    if (widget.quickAccept) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_submit());
        }
      });
    }
  }

  @override
  void dispose() {
    unawaited(_feedSub?.cancel());
    _amount.dispose();
    super.dispose();
  }

  void _onFeed(DriverFeedState feed) {
    if (!mounted || feed is! DriverFeedReady) return;
    for (final r in feed.rides) {
      if (r.id != _ride.id || r.offeredFareVnd == _ride.offeredFareVnd) {
        continue;
      }
      setState(() {
        if (_sentAmount == _ride.offeredFareVnd) _sentAmount = r.offeredFareVnd;
        if (_sentAmount == null &&
            parseRideFareInput(_amount.text) == _ride.offeredFareVnd) {
          _amount.text = '${r.offeredFareVnd}';
        }
        _ride = r;
      });
      return;
    }
  }

  /// After the offer is sent, follow the ride until the customer picks a driver.
  /// DEC-PROD-031 rev 2026-10-24: socket only (no poll) — see [DriverOfferCubit].
  void _startWatching() {
    final token = driverAccessToken(context);
    if (token == null || token.isEmpty) {
      return;
    }
    context
        .read<DriverOfferCubit>()
        .watchSelection(accessToken: token, rideId: _ride.id)
        .catchError((Object _) {});
  }

  Future<void> _submit() async {
    if (_submitting || _sentAmount != null) {
      return;
    }
    final amount = parseRideFareInput(_amount.text);
    // Fare bounds are admin settings checked by the server
    // (RIDE_FARE_OUT_OF_RANGE); the app only rejects non-amounts.
    if (amount == null || amount <= 0) {
      setState(() => _error = AppLocalizations.of(context).rideFareInvalid);
      return;
    }
    final token = driverAccessToken(context);
    if (token == null || token.isEmpty) {
      setState(() => _error = AppLocalizations.of(context).errorSessionExpired);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await context.read<DriverOfferCubit>().submit(
        SubmitRideOfferRequest(
          accessToken: token,
          rideId: _ride.id,
          amountVnd: amount,
          // Multi-stop: the server rejects an offer made on an older route.
          routeVersion: _ride.routeVersion,
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _submitting = false;
        _sentAmount = amount;
      });
      _startWatching();
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _submitting = false;
        _error = apiErrorText(AppLocalizations.of(context), error);
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _submitting = false;
        _error = AppLocalizations.of(context).driverOfferSendFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final selection = context.watch<DriverOfferCubit>().state;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    final ride = _ride;
    final amount = parseRideFareInput(_amount.text);
    final sent = _sentAmount;
    final classPhoto = resolveMediaUrl(ride.imageUrl);
    return Scaffold(
      body: DriverPageFrame(
        title: l10n.driverOfferTitle,
        subtitle: rideVehicleClassLabel(l10n, ride.vehicleClassCode),
        trailing: classPhoto == null
            ? null
            : RideVehicleClassPhoto(
                imageUrl: ride.imageUrl,
                code: ride.vehicleClassCode,
                size: 36,
              ),
        insetBottom: true,
        onBack: () => driverBack(context),
        footer: sent == null
            ? Padding(
                padding: const EdgeInsets.fromLTRB(
                  DealGoDimensions.pageGutter,
                  DealGoSpacing.s8,
                  DealGoDimensions.pageGutter,
                  DealGoSpacing.s12,
                ),
                child: DealGoPrimaryButton(
                  key: const Key('driver-submit-offer'),
                  label: l10n.driverSendOffer,
                  trailingIcon: DealGoIcons.arrowRight,
                  isLoading: _submitting,
                  enabled: !_submitting,
                  onPressed: _submit,
                ),
              )
            : null,
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            DealGoDimensions.pageGutter,
            DealGoSpacing.s8,
            DealGoDimensions.pageGutter,
            DealGoSpacing.s16,
          ),
          children: [
            DriverPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.driverCustomerRequest,
                    style: textTheme.titleMedium,
                  ),
                  const SizedBox(height: DealGoSpacing.s12),
                  Text(
                    AppLocalizations.of(context).rideRef(shortRef(ride.id)),
                    style: textTheme.bodySmall,
                  ),
                  DriverMoneyRow(
                    label: l10n.driverCustomerFare,
                    value: formatRideVnd(ride.offeredFareVnd),
                  ),
                  DriverMoneyRow(
                    label: l10n.driverVehicle,
                    value: rideVehicleClassLabel(l10n, ride.vehicleClassCode),
                  ),
                  if (ride.isParcel)
                    DriverMoneyRow(
                      key: const Key('driver-ride-parcel'),
                      label: l10n.parcelDriverBadge,
                      value: [
                        if (ride.parcelSizeClass != null)
                          parcelSizeLabel(l10n, ride.parcelSizeClass!),
                        if (ride.parcelWeightKg != null)
                          '${ride.parcelWeightKg!.toStringAsFixed(1)} kg',
                      ].join(' · '),
                    ),
                ],
              ),
            ),
            const SizedBox(height: DealGoSpacing.s12),
            if (sent != null) ...[
              DriverPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.driverOfferSent, style: textTheme.titleMedium),
                    const SizedBox(height: DealGoSpacing.s8),
                    Text(
                      formatRideVnd(sent),
                      style: textTheme.headlineSmall?.copyWith(
                        color: DealGoColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: DealGoSpacing.s8),
                    DriverChip(
                      label: switch (selection) {
                        DriverOfferSelection.waiting =>
                          sent == ride.offeredFareVnd
                              ? l10n.driverOfferWaitingAccept
                              : l10n.driverOfferWaitingCounter,
                        DriverOfferSelection.selected => l10n.driverOfferChosen,
                        DriverOfferSelection.lost => l10n.driverOfferLost,
                      },
                      tone: selection == DriverOfferSelection.lost
                          ? DriverChipTone.danger
                          : DriverChipTone.green,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DealGoSpacing.s12),
              DriverPanel(
                color: const Color(0xFF1E1B4B),
                child: Row(
                  children: [
                    const Icon(DealGoIcons.navigation, color: Colors.white),
                    const SizedBox(width: DealGoSpacing.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selection == DriverOfferSelection.selected
                                ? l10n.driverReadyToNavigate
                                : l10n.driverWaitingForCustomer,
                            style: textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            switch (selection) {
                              DriverOfferSelection.waiting =>
                                l10n.driverWaitingForCustomerBody,
                              DriverOfferSelection.selected =>
                                l10n.driverReadyToNavigateBody,
                              DriverOfferSelection.lost =>
                                l10n.driverOfferLostBody,
                            },
                            style: textTheme.bodySmall?.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DealGoSpacing.s12),
              if (selection == DriverOfferSelection.selected)
                DealGoPrimaryButton(
                  key: const Key('driver-open-active-ride'),
                  label: l10n.driverOpenPickupNavigation,
                  trailingIcon: DealGoIcons.arrowRight,
                  onPressed: () => context.pushReplacement(
                    DriverRoutes.active(ride.id),
                    extra: ride,
                  ),
                )
              else if (selection == DriverOfferSelection.lost)
                DealGoPrimaryButton(
                  key: const Key('driver-offer-back-to-jobs'),
                  label: l10n.driverBackToJobs,
                  onPressed: () => context.go('/driver/jobs'),
                )
              else if (maybeRideNegotiation(context) != null)
                DealGoSecondaryButton(
                  key: const Key('driver-withdraw-offer'),
                  label: l10n.driverWithdrawOffer,
                  enabled: !_withdrawing,
                  onPressed: _withdraw,
                ),
            ] else ...[
              DriverPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.driverYourOffer, style: textTheme.titleMedium),
                    const SizedBox(height: DealGoSpacing.s12),
                    DealGoTextField(
                      label: l10n.driverYourOffer,
                      showLabel: false,
                      controller: _amount,
                      fieldKey: const Key('driver-offer-amount'),
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      suffix: Text(l10n.currencySuffixVnd),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: DealGoSpacing.s8),
                    Text(
                      _hint(amount, ride.offeredFareVnd),
                      style: textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DealGoSpacing.s12),
              DriverPanel(
                child: Column(
                  children: [
                    DriverMoneyRow(
                      label: l10n.driverOfferAmount,
                      value: amount == null ? '—' : formatRideVnd(amount),
                      emphasize: true,
                    ),
                    DriverMoneyRow(
                      label: l10n.driverOfferKind,
                      value: amount == ride.offeredFareVnd
                          ? l10n.driverOfferKindAccept
                          : l10n.driverOfferKindCounter,
                    ),
                  ],
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: DealGoSpacing.s12),
              DriverNote(message: _error!),
            ],
          ],
        ),
      ),
    );
  }

  String _hint(int? amount, int offered) {
    if (amount == null || amount <= 0) {
      return AppLocalizations.of(context).rideFareInvalid;
    }
    if (amount == offered) {
      return AppLocalizations.of(context).driverOfferHintSame;
    }
    return AppLocalizations.of(context).driverOfferHintCounter;
  }
}
