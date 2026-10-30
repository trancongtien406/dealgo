import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/api_base_url.dart';
import '../../../rating/domain/service_rating.dart';
import '../../../rating/presentation/rate_service_card.dart';
import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/components/dealgo_secondary_button.dart';
import '../utils/ride_routes.dart';
import '../../../../core/design_system/components/dealgo_state_view.dart';
import '../../../../core/network/request_failure.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/format/date_time_format.dart';
import '../../../shell/presentation/account_routes.dart';
import '../../domain/entities/ride_money.dart';
import '../../../parcel/domain/parcel_client.dart';
import '../../../parcel/domain/parcel_models.dart';
import '../../domain/entities/ride_models.dart';
import '../../domain/entities/ride_vehicle.dart';
import '../../domain/usecases/get_ride.dart';
import '../cubit/ride_receipt_cubit.dart';
import '../utils/ride_vehicle_label.dart';
import '../widgets/ride_widgets.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/components/dealgo_app_header.dart';

class RideReceiptPage extends StatelessWidget {
  const RideReceiptPage({required this.rideId, super.key});

  final String rideId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => RideReceiptCubit(getRide: context.read<GetRide>()),
      child: _RideReceiptView(rideId: rideId),
    );
  }
}

class _RideReceiptView extends StatefulWidget {
  const _RideReceiptView({required this.rideId});

  final String rideId;

  @override
  State<_RideReceiptView> createState() => _RideReceiptPageState();
}

class _RideReceiptPageState extends State<_RideReceiptView> {
  RideView? _ride;
  ParcelInfo? _parcel;
  var _loading = true;
  Object? _failure;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final token = rideAccessToken(context);
    if (token == null) {
      setState(() {
        _loading = false;
        _failure = sessionExpiredFailure;
      });
      return;
    }
    try {
      final ride = await context.read<RideReceiptCubit>().load(
        accessToken: token,
        rideId: widget.rideId,
      );
      final parcel = ride.isParcel ? await _loadParcel(token) : null;
      if (!mounted) {
        return;
      }
      setState(() {
        _ride = ride;
        _parcel = parcel;
        _loading = false;
        _failure = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _failure = error;
      });
    }
  }

  /// Parcel fee breakdown; the receipt still renders if it can't load.
  Future<ParcelInfo?> _loadParcel(String token) async {
    ParcelClient client;
    try {
      client = context.read<ParcelClient>();
    } catch (_) {
      return null;
    }
    try {
      return (await client.get(
        accessToken: token,
        rideId: widget.rideId,
      )).parcel;
    } catch (_) {
      return null;
    }
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
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: DealGoColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            DealGoAppHeader(
              title: l10n.rideReceiptTitle,
              onBack: _back,
              trailing: Text(
                'DealGo',
                style: textTheme.titleMedium?.copyWith(
                  color: DealGoColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Expanded(child: _body(ride, textTheme)),
            if (ride != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  DealGoDimensions.pageGutter,
                  DealGoSpacing.s8,
                  DealGoDimensions.pageGutter,
                  DealGoSpacing.s12,
                ),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (ride.agreedFareVnd != null) ...[
                        Expanded(
                          child: DealGoSecondaryButton(
                            key: const Key('ride-receipt-help'),
                            label: l10n.rideReceiptHelp,
                            onPressed: () => context.push(
                              AccountRoutes.help('/customer/account'),
                            ),
                          ),
                        ),
                        const SizedBox(width: DealGoSpacing.s8),
                      ],
                      // "Đặt lại": same A→B and class; the fare page asks the
                      // server for a fresh quote (no old price is reused).
                      Expanded(
                        child: DealGoPrimaryButton(
                          key: const Key('ride-receipt-reorder'),
                          label: l10n.rideRebookAction,
                          onPressed: () => context.push(
                            RideRoutes.fare,
                            extra: RidePlaces(
                              pickup: ride.pickup,
                              dropoff: ride.dropoff,
                              stops: [for (final s in ride.stops) s.point],
                              vehicleClassCode: ride.vehicleClassCode.isEmpty
                                  ? null
                                  : ride.vehicleClassCode,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _body(RideView? ride, TextTheme textTheme) {
    final l10n = AppLocalizations.of(context);
    if (_loading && ride == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_failure != null && ride == null) {
      return DealGoStateView.failure(
        context,
        onRetry: _load,
        cause: _failure,
        message: l10n.rideReceiptOffline,
      );
    }
    if (ride == null) {
      return const SizedBox.shrink();
    }
    final agreed = ride.agreedFareVnd;
    final finishedAt = formatLocalDateTime(ride.updatedAt);
    final completed = ride.status == RideStatus.completed;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        DealGoDimensions.pageGutter,
        DealGoSpacing.s8,
        DealGoDimensions.pageGutter,
        DealGoSpacing.s24,
      ),
      children: [
        if (ride.status == RideStatus.completed)
          RateServiceCard(
            type: RatingSubjectType.ride,
            subjectId: ride.id,
            hasDriver: ride.assignedDriverId != null,
          ),
        const Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: DealGoColors.greenSurface,
              shape: BoxShape.circle,
            ),
            child: SizedBox(
              width: 72,
              height: 72,
              child: Icon(
                DealGoIcons.check,
                color: DealGoColors.brandGreen,
                size: 36,
              ),
            ),
          ),
        ),
        const SizedBox(height: DealGoSpacing.s16),
        Text(
          completed ? l10n.rideReceiptDone : l10n.rideReceiptTitle,
          textAlign: TextAlign.center,
          style: textTheme.titleLarge,
        ),
        const SizedBox(height: DealGoSpacing.s4),
        Text(
          l10n.rideReceiptThanks,
          textAlign: TextAlign.center,
          style: textTheme.bodySmall,
        ),
        const SizedBox(height: DealGoSpacing.s12),
        if (agreed == null)
          RideNote(message: l10n.rideReceiptNoFare)
        else
          Text(
            formatRideVnd(
              rideCashAfterVoucher(agreed + ride.waitFeeVnd, ride.discountVnd),
            ),
            key: const Key('ride-receipt-fare'),
            textAlign: TextAlign.center,
            style: textTheme.headlineSmall?.copyWith(
              color: DealGoColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        if (agreed != null) ...[
          const SizedBox(height: DealGoSpacing.s4),
          Text(
            l10n.rideReceiptCash,
            textAlign: TextAlign.center,
            style: textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: DealGoSpacing.s16),
        RidePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.rideReceiptRef(rideShortRef(ride.id)),
                      style: textTheme.titleMedium,
                    ),
                  ),
                  if (completed)
                    RideStatusChip(
                      label: l10n.statusCompleted,
                      tone: RideChipTone.green,
                    ),
                ],
              ),
              const SizedBox(height: DealGoSpacing.s12),
              RideStopList(
                pickup: ride.pickup.label,
                dropoff: ride.dropoff.label,
                stops: [for (final s in ride.stops) s.point.label],
                stopStates: [for (final s in ride.stops) s.state],
              ),
              const SizedBox(height: DealGoSpacing.s12),
              if (finishedAt != null)
                RideMoneyLine(
                  label: l10n.rideReceiptFinishedAt,
                  amount: finishedAt,
                ),
              if (resolveMediaUrl(ride.imageUrl) != null) ...[
                RideVehicleClassPhoto(
                  imageUrl: ride.imageUrl,
                  code: ride.vehicleClassCode,
                  size: 48,
                ),
                const SizedBox(height: DealGoSpacing.s8),
              ],
              RideMoneyLine(
                label: l10n.rideVehicleLabel,
                amount: rideVehicleClassLabel(l10n, ride.vehicleClassCode),
              ),
            ],
          ),
        ),
        const SizedBox(height: DealGoSpacing.s12),
        RidePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RideSectionTitle(l10n.rideReceiptPayment),
              const SizedBox(height: DealGoSpacing.s8),
              if (agreed != null) ...[
                RideMoneyLine(
                  label: l10n.rideAgreedFare,
                  amount: formatRideVnd(agreed),
                ),
                if (ride.waitFeeVnd > 0)
                  RideMoneyLine(
                    key: const Key('ride-receipt-wait-fee'),
                    label: l10n.rideWaitFeeLine,
                    amount: formatRideVnd(ride.waitFeeVnd),
                  ),
                if ((_parcel?.serviceFeeVnd ?? 0) > 0)
                  RideMoneyLine(
                    key: const Key('ride-receipt-parcel-service-fee'),
                    label: l10n.parcelReceiptServiceFee,
                    amount: formatRideVnd(_parcel!.serviceFeeVnd),
                  ),
                if (_parcel?.outcome == ParcelOutcome.returned &&
                    _parcel!.returnFeeVnd > 0)
                  RideMoneyLine(
                    key: const Key('ride-receipt-parcel-return-fee'),
                    label: l10n.parcelReceiptReturnFee,
                    amount: formatRideVnd(_parcel!.returnFeeVnd),
                  ),
                if (ride.discountVnd > 0)
                  RideMoneyLine(
                    label: l10n.rideVoucherLine(ride.voucherCode ?? ''),
                    amount: formatRideVnd(-ride.discountVnd),
                  ),
                RideMoneyLine(
                  key: const Key('ride-receipt-total'),
                  label: l10n.checkoutTotalSection,
                  amount: formatRideVnd(
                    rideCashAfterVoucher(
                          agreed + ride.waitFeeVnd,
                          ride.discountVnd,
                        ) +
                        (_parcel?.outcome == ParcelOutcome.returned
                            ? _parcel!.returnFeeVnd
                            : 0),
                  ),
                  emphasize: true,
                ),
              ] else
                RideNote(message: l10n.rideReceiptNoFare),
            ],
          ),
        ),
      ],
    );
  }
}
