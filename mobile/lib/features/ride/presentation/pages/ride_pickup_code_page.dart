import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/components/dealgo_banner.dart';
import '../../../../core/design_system/components/dealgo_chip.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/realtime/snapshot_realtime.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/ride_vehicle.dart';
import '../../domain/usecases/get_ride.dart';
import '../utils/ride_routes.dart';
import '../cubit/ride_tracking_cubit.dart';
import '../widgets/ride_widgets.dart';

/// C012 — customer view of pickup verification code.
class RidePickupCodePage extends StatelessWidget {
  const RidePickupCodePage({required this.rideId, super.key});

  final String rideId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => RideTrackingCubit(
        getRide: context.read<GetRide>(),
        realtime: context.read<SnapshotRealtime>(),
      )..start(rideId: rideId, accessToken: rideAccessToken(context)),
      child: _RidePickupCodeView(rideId: rideId),
    );
  }
}

class _RidePickupCodeView extends StatelessWidget {
  const _RidePickupCodeView({required this.rideId});

  final String rideId;

  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(RideRoutes.tracking(rideId));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final state = context.watch<RideTrackingCubit>().state;
    final ride = state.ride;
    final code = ride == null ? '7294' : ridePickupCode(ride.id);

    return Scaffold(
      backgroundColor: DealGoColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            RideScreenHeader(
              title: l10n.ridePickupCodeTitle,
              onBack: () => _back(context),
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
                  RidePanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DealGoChip(
                          label: l10n.ridePickupCodeChip,
                          tone: DealGoChipTone.brand,
                        ),
                        const SizedBox(height: DealGoSpacing.s16),
                        Text(
                          l10n.ridePickupCodeHeadline,
                          style: textTheme.titleMedium,
                        ),
                        const SizedBox(height: DealGoSpacing.s8),
                        Text(
                          l10n.ridePickupCodeBody,
                          style: textTheme.bodyMedium?.copyWith(
                            color: DealGoColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: DealGoSpacing.s24),
                        Center(
                          child: Text(
                            code.split('').join('  '),
                            key: const Key('ride-pickup-code-full'),
                            style: textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 4,
                            ),
                          ),
                        ),
                        const SizedBox(height: DealGoSpacing.s16),
                        Center(
                          child: Text(
                            'ID · $rideId',
                            style: textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: DealGoSpacing.s12),
                  DealGoBanner(
                    tone: DealGoBannerTone.warning,
                    title: l10n.ridePickupCodeSafetyTitle,
                    message: l10n.ridePickupCodeSafetyBody,
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
