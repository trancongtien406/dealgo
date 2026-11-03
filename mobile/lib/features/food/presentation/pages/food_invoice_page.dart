import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/components/dealgo_banner.dart';
import '../../../../core/design_system/components/dealgo_state_view.dart';
import '../../../../core/design_system/components/dealgo_chip.dart';
import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/realtime/snapshot_realtime.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../identity/domain/entities/auth_state.dart';
import '../../../identity/presentation/cubit/auth_cubit.dart';
import '../../domain/entities/food_models.dart';
import '../../domain/entities/food_money.dart';
import '../../domain/usecases/get_food_order.dart';
import '../cubit/food_tracking_cubit.dart';
import '../widgets/food_order_extras.dart';
import '../widgets/food_widgets.dart';
import '../utils/food_routes.dart';
import 'food_tracking_page.dart' show foodTrackingTitle;
import '../../../rating/domain/service_rating.dart';
import '../../../rating/presentation/rate_service_card.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/components/dealgo_app_header.dart';

/// C036 — food order invoice / receipt (separate from live tracking C033).
class FoodInvoicePage extends StatelessWidget {
  const FoodInvoicePage({required this.orderId, super.key});

  final String orderId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => FoodTrackingCubit(
        getFoodOrder: context.read<GetFoodOrder>(),
        realtime: context.read<SnapshotRealtime>(),
      )..start(orderId: orderId, accessToken: currentAccessToken(context)),
      child: _FoodInvoiceView(orderId: orderId),
    );
  }
}

class _FoodInvoiceView extends StatelessWidget {
  const _FoodInvoiceView({required this.orderId});

  final String orderId;

  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/customer/shop');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: DealGoColors.canvas,
      body: SafeArea(
        child: BlocBuilder<FoodTrackingCubit, FoodTrackingState>(
          builder: (context, state) {
            final order = state.order;
            if (order == null && state is FoodTrackingLoading) {
              return Column(
                children: [
                  DealGoAppHeader(
                    title: l10n.foodInvoiceTitle,
                    onBack: () => _back(context),
                  ),
                  const Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ],
              );
            }
            if (order == null) {
              return Column(
                children: [
                  DealGoAppHeader(
                    title: l10n.foodInvoiceTitle,
                    onBack: () => _back(context),
                  ),
                  Expanded(
                    child: DealGoStateView.failure(
                      context,
                      onRetry: () =>
                          context.read<FoodTrackingCubit>().refresh(),
                      cause: state is FoodTrackingOffline ? state.cause : null,
                    ),
                  ),
                ],
              );
            }
            final current = order;
            final stage = foodTrackingStage(current.status);
            final delivered = stage == FoodTrackingStage.delivered;
            final statusTitle = foodTrackingTitle(l10n, stage);
            final statusChip = _invoiceStatusChip(l10n, stage);
            final statusTone = _invoiceStatusTone(stage);
            return Column(
              children: [
                DealGoAppHeader(
                  title: l10n.foodInvoiceTitle,
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
                      if (delivered)
                        RateServiceCard(
                          type: RatingSubjectType.foodOrder,
                          subjectId: current.id,
                        ),
                      FoodPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              statusTitle,
                              key: const Key('food-invoice-status-title'),
                              style: textTheme.titleMedium,
                            ),
                            const SizedBox(height: DealGoSpacing.s8),
                            Text(
                              '${l10n.foodInvoiceOrderId} #$orderId',
                              style: textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: DealGoSpacing.s8),
                            DealGoChip(
                              key: const Key('food-invoice-status-chip'),
                              label: statusChip,
                              tone: statusTone,
                            ),
                            const SizedBox(height: DealGoSpacing.s12),
                            FoodMoneyRow(
                              label: l10n.foodInvoiceStore,
                              amount: current.storeName ?? '—',
                            ),
                            FoodMoneyRow(
                              label: l10n.foodInvoiceRecipient,
                              amount: _recipient(context, current),
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
                              delivered
                                  ? l10n.foodInvoiceItemsTitle
                                  : l10n.foodInvoiceItemsTitleOpen,
                              style: textTheme.titleMedium,
                            ),
                            const SizedBox(height: DealGoSpacing.s12),
                            if (current.lines.isEmpty)
                              Text(
                                l10n.foodInvoiceItemsEmpty,
                                style: textTheme.bodySmall,
                              )
                            else
                              for (final line in current.lines) ...[
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    FoodThumb(
                                      size: 48,
                                      imageUrl: line.imageUrl,
                                    ),
                                    const SizedBox(width: DealGoSpacing.s12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            line.name,
                                            style: textTheme.titleSmall,
                                          ),
                                          if (line.options.isNotEmpty)
                                            Text(
                                              line.optionsSummary,
                                              key: const Key(
                                                'food-invoice-line-options',
                                              ),
                                              style: textTheme.bodySmall
                                                  ?.copyWith(
                                                    color: DealGoColors
                                                        .textSecondary,
                                                  ),
                                            ),
                                          if ((line.note ?? '')
                                              .trim()
                                              .isNotEmpty)
                                            FoodLineNoteText(line.note!),
                                          Text(
                                            'x${line.quantity} · ${formatVnd(line.unitPriceVnd)}',
                                            style: textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      formatVnd(line.lineTotalVnd),
                                      style: textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: DealGoSpacing.s12),
                              ],
                          ],
                        ),
                      ),
                      if ((current.note ?? '').trim().isNotEmpty ||
                          !current.utensils)
                        Padding(
                          padding: const EdgeInsets.only(
                            top: DealGoSpacing.s12,
                          ),
                          child: FoodPanel(
                            child: FoodOrderExtrasBlock(
                              note: current.note,
                              utensils: current.utensils,
                            ),
                          ),
                        ),
                      const SizedBox(height: DealGoSpacing.s12),
                      FoodPanel(
                        color: DealGoColors.subtlePurple,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.foodInvoiceReceiptTitle,
                              style: textTheme.titleMedium,
                            ),
                            const SizedBox(height: DealGoSpacing.s12),
                            FoodMoneyRow(
                              label: l10n.foodInvoiceSubtotal,
                              amount: formatVnd(current.subtotalVnd),
                            ),
                            FoodMoneyRow(
                              label: l10n.foodInvoiceDelivery,
                              amount: formatVnd(current.deliveryFareVnd),
                            ),
                            FoodMoneyRow(
                              label: l10n.foodInvoiceDiscount,
                              amount: formatVnd(0),
                            ),
                            const Divider(height: DealGoSpacing.s24),
                            FoodMoneyRow(
                              label: delivered
                                  ? l10n.foodInvoiceCodTotal
                                  : l10n.foodInvoiceCodDue,
                              amount: formatVnd(current.totalVnd),
                              emphasize: true,
                            ),
                            FoodMoneyRow(
                              label: l10n.foodInvoiceMethod,
                              amount: delivered
                                  ? l10n.foodInvoiceMethodCollected
                                  : l10n.checkoutCodUncollected,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: DealGoSpacing.s12),
                      DealGoBanner(
                        tone: DealGoBannerTone.info,
                        message: delivered
                            ? l10n.foodInvoiceCodNote(
                                formatVnd(current.totalVnd),
                              )
                            : l10n.foodTrackingCodHint,
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
                    key: Key(
                      delivered ? 'food-invoice-rate' : 'food-invoice-track',
                    ),
                    label: delivered
                        ? l10n.foodInvoiceRateCta
                        : l10n.foodInvoiceTrackCta,
                    trailingIcon: DealGoIcons.arrowRight,
                    onPressed: delivered
                        ? () {}
                        : () => context.push(FoodRoutes.order(current.id)),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The signed-in customer's name, else the delivery address label.
String _recipient(BuildContext context, FoodOrderDetail order) {
  final auth = context.read<AuthCubit>().state;
  final name = auth is AuthSignedIn ? auth.profile.displayName.trim() : '';
  return name.isNotEmpty ? name : order.dropoff.label;
}

String _invoiceStatusChip(AppLocalizations l10n, FoodTrackingStage stage) {
  return switch (stage) {
    FoodTrackingStage.preparing => l10n.foodStagePreparing,
    FoodTrackingStage.onTheWay => l10n.foodStageOnTheWay,
    FoodTrackingStage.delivered => l10n.foodInvoiceDeliveredChip,
    FoodTrackingStage.failed => l10n.foodStageFailed,
    FoodTrackingStage.cancelled => l10n.foodStageCancelled,
    FoodTrackingStage.unknown => l10n.foodStageUnknown,
  };
}

DealGoChipTone _invoiceStatusTone(FoodTrackingStage stage) {
  return switch (stage) {
    FoodTrackingStage.preparing ||
    FoodTrackingStage.onTheWay => DealGoChipTone.brand,
    FoodTrackingStage.delivered => DealGoChipTone.success,
    FoodTrackingStage.failed ||
    FoodTrackingStage.cancelled => DealGoChipTone.danger,
    FoodTrackingStage.unknown => DealGoChipTone.neutral,
  };
}
