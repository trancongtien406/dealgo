import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../driver_card/domain/driver_card.dart';
import '../../../driver_card/presentation/driver_card_tile.dart';

import '../../../../core/design_system/components/dealgo_banner.dart';
import '../../../../core/design_system/components/dealgo_state_view.dart';
import '../../../../core/network/request_failure.dart';
import '../../../../core/design_system/components/dealgo_chip.dart';
import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/ride_money.dart';
import '../../domain/entities/ride_models.dart';
import '../../domain/usecases/cancel_ride.dart';
import '../../domain/usecases/get_ride.dart';
import '../../domain/usecases/select_ride_offer.dart';
import '../cubit/ride_offers_cubit.dart';
import '../utils/ride_routes.dart';
import '../widgets/ride_widgets.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/components/dealgo_app_header.dart';

class RideOfferDetailArgs {
  const RideOfferDetailArgs({required this.ride, required this.offer});

  final RideView ride;
  final RideOffer offer;
}

class RideOfferDetailPage extends StatelessWidget {
  const RideOfferDetailPage({
    required this.rideId,
    this.offerId,
    this.args,
    super.key,
  });

  final String rideId;
  final String? offerId;
  final RideOfferDetailArgs? args;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => RideOffersCubit(
        getRide: context.read<GetRide>(),
        selectRideOffer: context.read<SelectRideOffer>(),
        cancelRide: context.read<CancelRide>(),
      ),
      child: _RideOfferDetailView(rideId: rideId, offerId: offerId, seed: args),
    );
  }
}

class _RideOfferDetailView extends StatefulWidget {
  const _RideOfferDetailView({required this.rideId, this.offerId, this.seed});

  final String rideId;
  final String? offerId;
  final RideOfferDetailArgs? seed;

  @override
  State<_RideOfferDetailView> createState() => _RideOfferDetailViewState();
}

class _RideOfferDetailViewState extends State<_RideOfferDetailView> {
  RideView? _ride;
  RideOffer? _offer;
  var _loading = true;
  Object? _failure;
  String? _error;

  @override
  void initState() {
    super.initState();
    final seed = widget.seed;
    if (seed != null) {
      _ride = seed.ride;
      _offer = seed.offer;
      _loading = false;
      return;
    }
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
    setState(() {
      _loading = true;
      _failure = null;
      _error = null;
    });
    try {
      final ride = await context.read<RideOffersCubit>().load(
        accessToken: token,
        rideId: widget.rideId,
      );
      if (!mounted) {
        return;
      }
      final offerId = widget.offerId;
      RideOffer? offer;
      if (offerId != null && offerId.isNotEmpty) {
        for (final candidate in ride.offers) {
          if (candidate.id == offerId) {
            offer = candidate;
            break;
          }
        }
      }
      offer ??= ride.offers.isEmpty ? null : ride.offers.first;
      setState(() {
        _loading = false;
        _ride = ride;
        _offer = offer;
        if (offer == null) {
          _error = AppLocalizations.of(context).emptyOffers;
        }
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

  void _back() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(RideRoutes.offers(widget.rideId));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ride = _ride;
    final offer = _offer;

    return Scaffold(
      backgroundColor: DealGoColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            DealGoAppHeader(title: l10n.rideOfferDetailTitle, onBack: _back),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _failure != null && offer == null
                  ? DealGoStateView.failure(
                      context,
                      onRetry: _load,
                      cause: _failure,
                      message: l10n.errorLoadFailed,
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(
                        DealGoDimensions.pageGutter,
                        DealGoSpacing.s8,
                        DealGoDimensions.pageGutter,
                        DealGoSpacing.s16,
                      ),
                      children: [
                        if (_error != null)
                          DealGoBanner(
                            tone: DealGoBannerTone.warning,
                            message: _error!,
                            actionLabel: l10n.actionRetry,
                            onAction: _load,
                          ),
                        if (offer != null && ride != null) ...[
                          RidePanel(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                DriverCardTile(
                                  job: DriverCardJob.rideOffer,
                                  jobId: ride.id,
                                  offerId: offer.id,
                                  accessToken: rideAccessToken(context) ?? '',
                                ),
                                const SizedBox(height: DealGoSpacing.s12),
                                DealGoChip(
                                  label: rideOfferKindLabel(
                                    AppLocalizations.of(context),
                                    offer.kind,
                                  ),
                                  tone: offer.kind == RideOfferKind.accept
                                      ? DealGoChipTone.success
                                      : DealGoChipTone.neutral,
                                ),
                                const SizedBox(height: DealGoSpacing.s12),
                                RideMoneyLine(
                                  label: l10n.rideOfferAmountLabel,
                                  amount: formatRideVnd(offer.amountVnd),
                                  emphasize: true,
                                ),
                                RideMoneyLine(
                                  label: l10n.rideYourBidLabel,
                                  amount: formatRideVnd(ride.offeredFareVnd),
                                ),
                                RideMoneyLine(
                                  label: l10n.statusPending,
                                  amount: offer.status.wire,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: DealGoSpacing.s12),
                          RidePanel(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                RideSectionTitle(l10n.rideTripInfoTitle),
                                const SizedBox(height: DealGoSpacing.s12),
                                RideStopList(
                                  pickup: ride.pickup.label,
                                  dropoff: ride.dropoff.label,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
            if (offer != null && ride != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  DealGoDimensions.pageGutter,
                  DealGoSpacing.s8,
                  DealGoDimensions.pageGutter,
                  DealGoSpacing.s12,
                ),
                child: DealGoPrimaryButton(
                  key: const Key('ride-offer-detail-select'),
                  label: l10n.rideSelectOfferCta,
                  trailingIcon: DealGoIcons.arrowRight,
                  onPressed: () => context.push(
                    RideRoutes.confirm(ride.id),
                    extra: RideConfirmArgs(
                      ride: ride,
                      tappedAmountVnd: offer.amountVnd,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
