import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/components/dealgo_text_field.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/network/api_exception.dart';
import '../../../ride/domain/entities/ride_models.dart';
import '../../../ride/domain/entities/ride_money.dart';
import '../../../ride/domain/params/get_ride_params.dart';
import '../../../ride/domain/params/submit_ride_offer_params.dart';
import '../../../ride/domain/usecases/get_ride.dart';
import '../../domain/usecases/submit_driver_ride_offer.dart';
import '../cubit/driver_offer_cubit.dart';
import '../utils/driver_routes.dart';
import '../widgets/driver_widgets.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/format/short_ref.dart';
import '../../../../core/l10n/api_error_text.dart';
import '../../../../core/realtime/snapshot_binding.dart';
import '../../../../core/realtime/snapshot_realtime.dart';

class DriverRideDetailPage extends StatelessWidget {
  const DriverRideDetailPage({required this.ride, super.key});

  final OpenRide ride;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: DriverPageFrame(
        title: l10n.driverRideDetailTitle,
        insetBottom: true,
        onBack: () => driverBack(context),
        footer: DriverFooter(
          secondaryLabel: l10n.actionSkip,
          primaryLabel: l10n.driverMakeOffer,
          primaryKey: const Key('driver-open-offer'),
          onSecondary: () => driverBack(context),
          onPrimary: () =>
              context.push(DriverRoutes.offer(ride.id), extra: ride),
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
                  DriverChip(
                    label: l10n.driverRideChip,
                    tone: DriverChipTone.green,
                  ),
                  const SizedBox(height: DealGoSpacing.s12),
                  Text(AppLocalizations.of(context).rideRef(shortRef(ride.id))),
                  const SizedBox(height: DealGoSpacing.s12),
                  DriverStop(
                    color: DealGoColors.brandGreen,
                    label: l10n.driverPickupLabel,
                    value: ride.pickup.label,
                  ),
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
                ],
              ),
            ),
            const SizedBox(height: DealGoSpacing.s12),
            DriverNote(
              tone: DriverNoteTone.green,
              message: AppLocalizations.of(context).driverCounterNote,
            ),
          ],
        ),
      ),
    );
  }
}

class DriverOfferPage extends StatelessWidget {
  const DriverOfferPage({required this.ride, super.key});

  final OpenRide ride;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => DriverOfferCubit(
        submitDriverRideOffer: context.read<SubmitDriverRideOffer>(),
      ),
      child: _DriverOfferView(ride: ride),
    );
  }
}

class _DriverOfferView extends StatefulWidget {
  const _DriverOfferView({required this.ride});

  final OpenRide ride;

  @override
  State<_DriverOfferView> createState() => _DriverOfferPageState();
}

class _DriverOfferPageState extends State<_DriverOfferView> {
  late final TextEditingController _amount = TextEditingController(
    text: '${widget.ride.offeredFareVnd}',
  );
  var _submitting = false;
  String? _error;
  int? _sentAmount;
  var _selection = DriverOfferSelection.waiting;
  Timer? _poll;
  SnapshotBinding? _binding;

  @override
  void dispose() {
    _stopWatching();
    _amount.dispose();
    super.dispose();
  }

  /// After the offer is sent, follow the ride until the customer picks a driver:
  /// the server keeps a non-negotiating ride readable only for its assigned driver.
  /// DEC-PROD-025: the `ride:<id>` socket hint (ASSIGNED/CANCELLED/EXPIRED) triggers an
  /// immediate REST check; a slow poll stays as the safety net when the socket is down.
  void _startWatching() {
    _stopWatching();
    _poll = Timer.periodic(driverOfferPollInterval, (_) => _checkSelection());
    SnapshotRealtime? realtime;
    try {
      realtime = context.read<SnapshotRealtime>();
    } catch (_) {
      realtime = null;
    }
    if (realtime == null) {
      return;
    }
    final binding = SnapshotBinding(
      realtime: realtime,
      room: RideSnapshotRoom(widget.ride.id),
      onInvalidate: _checkSelection,
    );
    _binding = binding;
    binding.start(accessToken: driverAccessToken(context)).catchError((Object _) {});
  }

  void _stopWatching() {
    _poll?.cancel();
    _poll = null;
    final binding = _binding;
    _binding = null;
    binding?.stop().catchError((Object _) {});
  }

  Future<void> _checkSelection() async {
    final token = driverAccessToken(context);
    if (token == null || token.isEmpty) {
      return;
    }
    DriverOfferSelection next;
    try {
      final view = await context.read<GetRide>()(
        GetRideParams(accessToken: token, rideId: widget.ride.id),
      );
      next = driverOfferSelectionFor(view.status);
    } on ApiException catch (error) {
      if (error.statusCode != 404) {
        return;
      }
      next = DriverOfferSelection.lost;
    } catch (_) {
      return;
    }
    if (!mounted) {
      return;
    }
    if (next != DriverOfferSelection.waiting) {
      _stopWatching();
    }
    setState(() => _selection = next);
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
          rideId: widget.ride.id,
          amountVnd: amount,
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
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    final ride = widget.ride;
    final amount = parseRideFareInput(_amount.text);
    final sent = _sentAmount;
    return Scaffold(
      body: DriverPageFrame(
        title: l10n.driverOfferTitle,
        subtitle: l10n.rideVehicleMotorbike,
        insetBottom: true,
        onBack: () => driverBack(context),
        footer: sent == null
            ? Padding(
                padding: const EdgeInsets.fromLTRB(
                  DealGoDimensions.pageGutter,
                  DealGoSpacing.s8,
                  DealGoDimensions.pageGutter,
                  DealGoSpacing.s16,
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
                  Text(l10n.driverCustomerRequest, style: textTheme.titleMedium),
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
                    value: l10n.rideVehicleMotorbike,
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
                      label: switch (_selection) {
                        DriverOfferSelection.waiting => sent == ride.offeredFareVnd
                            ? l10n.driverOfferWaitingAccept
                            : l10n.driverOfferWaitingCounter,
                        DriverOfferSelection.selected => l10n.driverOfferChosen,
                        DriverOfferSelection.lost => l10n.driverOfferLost,
                      },
                      tone: _selection == DriverOfferSelection.lost
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
                            _selection == DriverOfferSelection.selected
                                ? l10n.driverReadyToNavigate
                                : l10n.driverWaitingForCustomer,
                            style: textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            switch (_selection) {
                              DriverOfferSelection.waiting => l10n.driverWaitingForCustomerBody,
                              DriverOfferSelection.selected => l10n.driverReadyToNavigateBody,
                              DriverOfferSelection.lost => l10n.driverOfferLostBody,
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
              if (_selection == DriverOfferSelection.selected)
                DealGoPrimaryButton(
                  key: const Key('driver-open-active-ride'),
                  label: l10n.driverOpenPickupNavigation,
                  trailingIcon: DealGoIcons.arrowRight,
                  onPressed: () => context.pushReplacement(
                    DriverRoutes.active(ride.id),
                    extra: ride,
                  ),
                )
              else if (_selection == DriverOfferSelection.lost)
                DealGoPrimaryButton(
                  key: const Key('driver-offer-back-to-jobs'),
                  label: l10n.driverBackToJobs,
                  onPressed: () => context.go('/driver/jobs'),
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
              const SizedBox(height: DealGoSpacing.s12),
              DriverNote(
                tone: DriverNoteTone.green,
                message: l10n.driverOfferKindNote,
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

/// Safety-net poll while waiting for the customer's choice; the socket hint is the fast path.
const driverOfferPollInterval = Duration(seconds: 15);

enum DriverOfferSelection { waiting, selected, lost }

/// Still negotiating → wait; the ride moved on and is still readable → it is ours.
DriverOfferSelection driverOfferSelectionFor(RideStatus status) => switch (status) {
  RideStatus.negotiating => DriverOfferSelection.waiting,
  RideStatus.cancelled || RideStatus.expired => DriverOfferSelection.lost,
  _ => DriverOfferSelection.selected,
};
