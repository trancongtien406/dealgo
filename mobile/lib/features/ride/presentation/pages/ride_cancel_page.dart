import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/components/dealgo_banner.dart';
import '../../../../core/design_system/components/dealgo_chip.dart';
import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/components/dealgo_secondary_button.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/ride_models.dart';
import '../../domain/usecases/cancel_ride.dart';
import '../../domain/usecases/get_ride.dart';
import '../../domain/usecases/select_ride_offer.dart';
import '../cubit/ride_offers_cubit.dart';
import '../utils/ride_routes.dart';
import '../cubit/ride_session.dart';
import '../widgets/ride_widgets.dart';

/// C016 — cancel ride reason picker. Does not invent fee/penalty policies.
class RideCancelPage extends StatelessWidget {
  const RideCancelPage({required this.rideId, super.key});

  final String rideId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => RideOffersCubit(
        getRide: context.read<GetRide>(),
        selectRideOffer: context.read<SelectRideOffer>(),
        cancelRide: context.read<CancelRide>(),
      ),
      child: _RideCancelView(rideId: rideId),
    );
  }
}

class _RideCancelView extends StatefulWidget {
  const _RideCancelView({required this.rideId});

  final String rideId;

  @override
  State<_RideCancelView> createState() => _RideCancelViewState();
}

class _RideCancelViewState extends State<_RideCancelView> {
  String? _reasonId;
  var _busy = false;
  String? _message;
  var _done = false;

  List<_CancelReason> _reasons(AppLocalizations l10n) {
    return [
      _CancelReason(id: 'wait_too_long', label: l10n.rideCancelReasonWait),
      _CancelReason(id: 'changed_plans', label: l10n.rideCancelReasonPlans),
      _CancelReason(id: 'wrong_address', label: l10n.rideCancelReasonAddress),
      _CancelReason(id: 'driver_issue', label: l10n.rideCancelReasonDriver),
      _CancelReason(id: 'other', label: l10n.rideCancelReasonOther),
    ];
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(RideRoutes.matching(widget.rideId));
  }

  Future<void> _confirm() async {
    if (_busy || _reasonId == null) {
      return;
    }
    final token = rideAccessToken(context);
    final l10n = AppLocalizations.of(context);
    if (token == null) {
      setState(() => _message = l10n.errorUnauthorized);
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final updated = await context.read<RideOffersCubit>().cancel(
        accessToken: token,
        rideId: widget.rideId,
      );
      if (!mounted) {
        return;
      }
      context.read<RideSessionCubit>().clear();
      setState(() {
        _busy = false;
        _done = true;
        _message = updated.status == RideStatus.cancelled
            ? l10n.rideCancelSuccess
            : l10n.rideCancelSubmitted;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _message = error is ApiException
            ? error.message
            : l10n.rideCancelSoftFail;
        _done = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final reasons = _reasons(l10n);

    return Scaffold(
      backgroundColor: DealGoColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            RideScreenHeader(title: l10n.rideCancelTitle, onBack: _back),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  DealGoDimensions.pageGutter,
                  DealGoSpacing.s8,
                  DealGoDimensions.pageGutter,
                  DealGoSpacing.s16,
                ),
                children: [
                  DealGoBanner(
                    tone: DealGoBannerTone.warning,
                    message: l10n.rideCancelPolicyHint,
                  ),
                  const SizedBox(height: DealGoSpacing.s16),
                  Text(l10n.rideCancelPickReason, style: textTheme.titleMedium),
                  const SizedBox(height: DealGoSpacing.s12),
                  for (final reason in reasons) ...[
                    _ReasonTile(
                      reason: reason,
                      selected: _reasonId == reason.id,
                      enabled: !_busy && !_done,
                      onTap: () => setState(() => _reasonId = reason.id),
                    ),
                    const SizedBox(height: DealGoSpacing.s8),
                  ],
                  if (_message != null) ...[
                    const SizedBox(height: DealGoSpacing.s12),
                    DealGoBanner(
                      tone: _done
                          ? DealGoBannerTone.info
                          : DealGoBannerTone.warning,
                      message: _message!,
                    ),
                  ],
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!_done)
                    DealGoPrimaryButton(
                      key: const Key('ride-cancel-confirm'),
                      label: l10n.rideCancelConfirm,
                      isLoading: _busy,
                      enabled: _reasonId != null,
                      onPressed: _confirm,
                    ),
                  if (_done) ...[
                    DealGoPrimaryButton(
                      key: const Key('ride-cancel-done'),
                      label: l10n.actionBack,
                      onPressed: () => context.go('/customer'),
                    ),
                  ],
                  const SizedBox(height: DealGoSpacing.s8),
                  DealGoSecondaryButton(
                    label: l10n.rideCancelKeep,
                    enabled: !_busy,
                    onPressed: _back,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CancelReason {
  const _CancelReason({required this.id, required this.label});

  final String id;
  final String label;
}

class _ReasonTile extends StatelessWidget {
  const _ReasonTile({
    required this.reason,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final _CancelReason reason;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: DealGoColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DealGoRadius.card),
        side: BorderSide(
          color: selected ? DealGoColors.primary : DealGoColors.border,
          width: selected ? 1.6 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('ride-cancel-reason-${reason.id}'),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(DealGoSpacing.s16),
          child: Row(
            children: [
              Expanded(child: Text(reason.label)),
              if (selected)
                const DealGoChip(
                  label: '✓',
                  tone: DealGoChipTone.brand,
                  selected: true,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
