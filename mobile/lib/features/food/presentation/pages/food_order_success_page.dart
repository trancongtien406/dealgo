import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/components/dealgo_success_mark.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../domain/entities/food_models.dart';
import '../../domain/entities/food_money.dart';
import '../../domain/usecases/get_food_order.dart';
import '../../../../core/realtime/snapshot_realtime.dart';
import '../cubit/food_tracking_cubit.dart';
import '../utils/food_routes.dart';
import '../widgets/food_widgets.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/format/short_ref.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/design_system/components/dealgo_app_header.dart';

class FoodOrderSuccessArgs {
  const FoodOrderSuccessArgs({
    required this.order,
    required this.storeName,
    this.storeAddress,
  });

  final PlacedFoodOrder order;
  final String storeName;
  final String? storeAddress;
}

/// Status after which the success page hands over to live tracking (driver
/// search, delivery offers, assignment and terminal states live there).
bool foodSuccessShouldOpenTracking(String status) =>
    !(status == 'PLACED' || status == 'PREPARING');

/// Polling fallback when the socket hint is missed (REST stays authoritative).
const foodSuccessPollInterval = Duration(seconds: 10);

class FoodOrderSuccessPage extends StatelessWidget {
  const FoodOrderSuccessPage({required this.args, super.key});

  final FoodOrderSuccessArgs args;

  @override
  Widget build(BuildContext context) {
    GetFoodOrder? getOrder;
    SnapshotRealtime? realtime;
    try {
      getOrder = context.read<GetFoodOrder>();
      realtime = context.read<SnapshotRealtime>();
    } on ProviderNotFoundException {
      // Static fallback (widget tests without the live providers).
    }
    if (getOrder == null || realtime == null) {
      return _FoodOrderSuccessView(args: args);
    }
    return BlocProvider(
      create: (context) =>
          FoodTrackingCubit(getFoodOrder: getOrder!, realtime: realtime!)
            ..start(
              orderId: args.order.id,
              accessToken: currentAccessToken(context),
            ),
      child: _LiveSuccess(args: args),
    );
  }
}

/// Live-updating wrapper: socket hints on `food:{id}` plus a poll fallback.
class _LiveSuccess extends StatefulWidget {
  const _LiveSuccess({required this.args});

  final FoodOrderSuccessArgs args;

  @override
  State<_LiveSuccess> createState() => _LiveSuccessState();
}

class _LiveSuccessState extends State<_LiveSuccess> {
  Timer? _poll;
  var _left = false;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(foodSuccessPollInterval, (_) {
      if (mounted) {
        context.read<FoodTrackingCubit>().refresh();
      }
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<FoodTrackingCubit, FoodTrackingState>(
      listener: (context, state) {
        final status = state.order?.status;
        if (!_left && status != null && foodSuccessShouldOpenTracking(status)) {
          _left = true;
          _poll?.cancel();
          context.pushReplacement(FoodRoutes.order(widget.args.order.id));
        }
      },
      builder: (context, state) => _FoodOrderSuccessView(
        args: widget.args,
        liveStatus: state.order?.status,
      ),
    );
  }
}

class _FoodOrderSuccessView extends StatelessWidget {
  const _FoodOrderSuccessView({required this.args, this.liveStatus});

  final FoodOrderSuccessArgs args;
  final String? liveStatus;

  void _track(BuildContext context) {
    context.pushReplacement(FoodRoutes.order(args.order.id));
  }

  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/customer/shop');
  }

  @override
  Widget build(BuildContext context) {
    final order = args.order;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: DealGoColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            DealGoAppHeader(
              title: AppLocalizations.of(context).foodOrderSentTitle,
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
                  const Center(child: DealGoSuccessMark()),
                  const SizedBox(height: DealGoSpacing.s16),
                  Text(
                    AppLocalizations.of(context).foodOrderPlaced,
                    key: const Key('food-order-success-title'),
                    textAlign: TextAlign.center,
                    style: textTheme.titleLarge,
                  ),
                  const SizedBox(height: DealGoSpacing.s4),
                  Text(
                    AppLocalizations.of(context).foodOrderPlacedSub,
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall,
                  ),
                  const SizedBox(height: DealGoSpacing.s16),
                  FoodPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context).merchantConflictOrder,
                          style: textTheme.titleMedium,
                        ),
                        const SizedBox(height: DealGoSpacing.s8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                AppLocalizations.of(context)
                                    .orderRef(shortRef(order.id)),
                                style: textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: DealGoSpacing.s12),
                        Row(
                          children: [
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: DealGoColors.subtlePurple,
                                borderRadius: BorderRadius.all(
                                  Radius.circular(8),
                                ),
                              ),
                              child: SizedBox(
                                width: 48,
                                height: 48,
                                child: Icon(
                                  DealGoIcons.store,
                                  color: DealGoColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: DealGoSpacing.s12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    args.storeName,
                                    style: textTheme.titleMedium,
                                  ),
                                  if ((args.storeAddress ?? '').isNotEmpty)
                                    Text(
                                      args.storeAddress!,
                                      style: textTheme.bodySmall,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: DealGoSpacing.s12),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                AppLocalizations.of(context).foodPayOnDelivery,
                                style: textTheme.bodyMedium,
                              ),
                            ),
                            Text(
                              formatVnd(order.totalVnd),
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: DealGoSpacing.s8),
                        FoodStatusChip(
                          label: AppLocalizations.of(context).foodCashNotPaid,
                          tone: FoodChipTone.warning,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: DealGoSpacing.s12),
                  FoodPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context).rideProgress,
                          style: textTheme.titleMedium,
                        ),
                        const SizedBox(height: DealGoSpacing.s12),
                        _ProgressRow(
                          label: AppLocalizations.of(context).foodStepSent,
                          tone: FoodChipTone.green,
                          done: true,
                        ),
                        const SizedBox(height: DealGoSpacing.s8),
                        _ProgressRow(
                          key: const Key('food-success-step-store'),
                          label: AppLocalizations.of(context)
                              .foodStepAwaitStore,
                          tone: liveStatus == 'PREPARING'
                              ? FoodChipTone.green
                              : FoodChipTone.warning,
                          done: liveStatus == 'PREPARING',
                        ),
                        const SizedBox(height: DealGoSpacing.s8),
                        _ProgressRow(
                          key: const Key('food-success-step-prep'),
                          label: liveStatus == 'PREPARING'
                              ? AppLocalizations.of(context)
                                    .merchantStatusPreparing
                              : AppLocalizations.of(context)
                                    .foodStepNotPreparing,
                          tone: liveStatus == 'PREPARING'
                              ? FoodChipTone.purple
                              : FoodChipTone.neutral,
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
              child: DealGoPrimaryButton(
                key: const Key('food-track-order'),
                label: AppLocalizations.of(context).foodTrackOrder,
                trailingIcon: DealGoIcons.arrowRight,
                onPressed: () => _track(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.label,
    super.key,
    required this.tone,
    this.done = false,
  });

  final String label;
  final FoodChipTone tone;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          done ? DealGoIcons.success : DealGoIcons.circle,
          size: 18,
          color: switch (tone) {
            FoodChipTone.green => DealGoColors.brandGreen,
            FoodChipTone.warning => DealGoColors.amber,
            FoodChipTone.neutral => DealGoColors.textSecondary,
            FoodChipTone.purple => DealGoColors.primary,
            FoodChipTone.danger => DealGoColors.danger,
          },
        ),
        const SizedBox(width: DealGoSpacing.s8),
        Expanded(
          child: FoodStatusChip(label: label, tone: tone),
        ),
      ],
    );
  }
}
