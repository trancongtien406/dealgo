import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/request_failure.dart';
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
import '../cubit/ride_session.dart';
import '../widgets/ride_widgets.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/components/dealgo_app_header.dart';

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
      ),
      child: _RideMatchingView(rideId: rideId, clock: clock),
    );
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

  DateTime get _now => (widget.clock ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (_busy) {
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
    setState(() {
      _busy = true;
    });
    try {
      final ride = await context.read<RideMatchingCubit>().load(
        accessToken: token,
        rideId: widget.rideId,
      );
      if (!mounted) {
        return;
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
      setState(() {
        _ride = ride;
        _loading = false;
        _busy = false;
        _offline = false;
        _failure = null;
      });
      if (ride.status.hasDriver && !_openedTracking) {
        _openedTracking = true;
        await context.push(RideRoutes.tracking(ride.id));
      }
    } catch (error) {
      if (!mounted) {
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

  void _editTrip(RideView ride) {
    context.push(
      RideRoutes.fare,
      extra: RidePlaces(pickup: ride.pickup, dropoff: ride.dropoff),
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
          DealGoAppHeader(title: AppLocalizations.of(context).rideMatchingReceiving, onBack: _back),
          const Expanded(child: Center(child: CircularProgressIndicator())),
        ],
      );
    }
    if (ride == null) {
      return Column(
        children: [
          DealGoAppHeader(title: AppLocalizations.of(context).rideMatchingSearching, onBack: _back),
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
      return _CancelledMatch(onBack: _back);
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
      onOpenOffers: ride.offers.isEmpty
          ? null
          : () => context.push(RideRoutes.offers(ride.id)),
    );
  }
}

class _MatchingWait extends StatelessWidget {
  const _MatchingWait({
    required this.ride,
    required this.busy,
    required this.offline,
    required this.onBack,
    required this.onCancel,
    required this.onOpenOffers,
  });

  final RideView ride;
  final bool busy;
  final bool offline;
  final VoidCallback onBack;
  final VoidCallback onCancel;
  final VoidCallback? onOpenOffers;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final offers = onOpenOffers;
    return Column(
      children: [
        DealGoAppHeader(title: AppLocalizations.of(context).rideMatchingReceiving, onBack: onBack),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              DealGoDimensions.pageGutter,
              DealGoSpacing.s8,
              DealGoDimensions.pageGutter,
              DealGoSpacing.s16,
            ),
            children: [
              RidePanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RideSectionTitle(AppLocalizations.of(context).driverOpenRequests),
                    const SizedBox(height: DealGoSpacing.s12),
                    RideStopList(
                      pickup: ride.pickup.label,
                      dropoff: ride.dropoff.label,
                    ),
                    const SizedBox(height: DealGoSpacing.s12),
                    Row(
                      children: [
                        RideStatusChip(
                          label: AppLocalizations.of(context).rideMatchingSent,
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
              const SizedBox(height: DealGoSpacing.s24),
              const _VehicleMark(),
              const SizedBox(height: DealGoSpacing.s16),
              Text(
                AppLocalizations.of(context).rideMatchingWaiting,
                textAlign: TextAlign.center,
                style: textTheme.titleMedium,
              ),
              const SizedBox(height: DealGoSpacing.s8),
              Text(
                AppLocalizations.of(context).rideMatchingWaitingHint,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: DealGoColors.textSecondary,
                ),
              ),
              const SizedBox(height: DealGoSpacing.s16),
              RidePanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RideMoneyLine(
                      label: AppLocalizations.of(context).rideStatusLabel,
                      amount: ride.status.wire,
                    ),
                    if (ride.offers.isEmpty) ...[
                      const SizedBox(height: DealGoSpacing.s8),
                      Text(
                        AppLocalizations.of(context).rideNoOffersTitle,
                        style: textTheme.titleMedium,
                      ),
                      const SizedBox(height: DealGoSpacing.s4),
                      Text(
                        AppLocalizations.of(context).rideNoOffersMessage,
                        style: textTheme.bodyMedium?.copyWith(
                          color: DealGoColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: DealGoSpacing.s16),
              RidePanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RideSectionTitle(AppLocalizations.of(context).rideProgress),
                    const SizedBox(height: DealGoSpacing.s12),
                    _MatchStep(
                      label: AppLocalizations.of(context).rideProgressSent,
                      tone: _StepTone.done,
                    ),
                    _MatchStep(
                      label: AppLocalizations.of(context).rideProgressReceiving,
                      tone: _StepTone.current,
                    ),
                    _MatchStep(
                      label: AppLocalizations.of(context).rideProgressChoose,
                      tone: _StepTone.pending,
                    ),
                  ],
                ),
              ),
              if (offline) ...[
                const SizedBox(height: DealGoSpacing.s12),
                RideOfflineNotice(
                  detail:
                      AppLocalizations.of(context).rideMatchingRefreshFailed,
                ),
              ],
              if (offers != null) ...[
                const SizedBox(height: DealGoSpacing.s12),
                DealGoSecondaryButton(label: AppLocalizations.of(context).rideViewOffers, onPressed: offers),
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
          child: DealGoSecondaryButton(
            key: const Key('ride-cancel-search'),
            label: AppLocalizations.of(context).rideCancelSearch,
            enabled: !busy,
            onPressed: onCancel,
          ),
        ),
      ],
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
        DealGoAppHeader(title: AppLocalizations.of(context).rideMatchingSearching, onBack: onBack),
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
                    RideSectionTitle(AppLocalizations.of(context).rideCurrentRoute),
                    const SizedBox(height: DealGoSpacing.s12),
                    RideStopList(
                      pickup: ride.pickup.label,
                      dropoff: ride.dropoff.label,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DealGoSpacing.s12),
              RidePanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RideSectionTitle(AppLocalizations.of(context).rideCurrentOfferedFare),
                    const SizedBox(height: DealGoSpacing.s8),
                    RideMoneyLine(
                      label: AppLocalizations.of(context).rideOfferedFare,
                      amount: formatRideVnd(ride.offeredFareVnd),
                      emphasize: true,
                    ),
                    RideMoneyLine(
                      label: AppLocalizations.of(context).kycStepVehicle,
                      amount: AppLocalizations.of(context).rideVehicleMotorbike,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DealGoSpacing.s12),
              RideNote(
                message: AppLocalizations.of(context).rideTimeoutNote,
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
        DealGoAppHeader(title: AppLocalizations.of(context).rideMatchingReceiving, onBack: onBack),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(DealGoDimensions.pageGutter),
            child: Text(
              AppLocalizations.of(context).rideAssignedNote,
            ),
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
  const _CancelledMatch({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DealGoAppHeader(title: AppLocalizations.of(context).rideMatchingReceiving, onBack: onBack),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(DealGoDimensions.pageGutter),
            child: Text(AppLocalizations.of(context).rideCancelledNote),
          ),
        ),
      ],
    );
  }
}

class _VehicleMark extends StatelessWidget {
  const _VehicleMark();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            color: DealGoColors.subtlePurple,
            shape: BoxShape.circle,
          ),
          child: SizedBox(
            width: 96,
            height: 96,
            child: Icon(
              DealGoIcons.motorbike,
              color: DealGoColors.primary,
              size: 42,
            ),
          ),
        ),
        const SizedBox(height: DealGoSpacing.s8),
        Text(
          AppLocalizations.of(context).rideVehicleMotorbike,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: DealGoColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

enum _StepTone { done, current, pending }

class _MatchStep extends StatelessWidget {
  const _MatchStep({required this.label, required this.tone});

  final String label;
  final _StepTone tone;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (tone) {
      _StepTone.done => (DealGoIcons.success, DealGoColors.brandGreen),
      _StepTone.current => (DealGoIcons.circle, DealGoColors.primary),
      _StepTone.pending => (DealGoIcons.radioOff, DealGoColors.textSecondary),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DealGoSpacing.s8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: DealGoSpacing.s12),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}
