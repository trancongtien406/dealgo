import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/components/dealgo_success_mark.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../domain/entities/food_models.dart';
import '../../domain/entities/food_money.dart';
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

class FoodOrderSuccessPage extends StatelessWidget {
  const FoodOrderSuccessPage({required this.args, super.key});

  final FoodOrderSuccessArgs args;

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
                            const DecoratedBox(
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
                          label: AppLocalizations.of(context)
                              .foodStepAwaitStore,
                          tone: FoodChipTone.warning,
                        ),
                        const SizedBox(height: DealGoSpacing.s8),
                        _ProgressRow(
                          label: AppLocalizations.of(context)
                              .foodStepNotPreparing,
                          tone: FoodChipTone.neutral,
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
