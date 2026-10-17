import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/components/dealgo_banner.dart';
import '../../../../core/design_system/components/dealgo_chip.dart';
import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/realtime/snapshot_realtime.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/food_money.dart';
import '../../domain/usecases/get_food_order.dart';
import '../cubit/food_tracking_cubit.dart';
import '../widgets/food_widgets.dart';

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
                  FoodScreenHeader(
                    title: l10n.foodInvoiceTitle,
                    onBack: () => _back(context),
                  ),
                  const Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ],
              );
            }
            final current = order;
            return Column(
              children: [
                FoodScreenHeader(
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
                      FoodPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.foodInvoiceDelivered,
                              style: textTheme.titleMedium,
                            ),
                            const SizedBox(height: DealGoSpacing.s8),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${l10n.foodInvoiceOrderId} #$orderId',
                                    style: textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                DealGoChip(
                                  label: l10n.foodInvoiceSyncChip,
                                  tone: DealGoChipTone.neutral,
                                ),
                              ],
                            ),
                            const SizedBox(height: DealGoSpacing.s8),
                            DealGoChip(
                              label: l10n.foodInvoiceDeliveredChip,
                              tone: DealGoChipTone.success,
                            ),
                            if (current != null) ...[
                              const SizedBox(height: DealGoSpacing.s12),
                              FoodMoneyRow(
                                label: l10n.foodInvoiceStore,
                                amount: current.lines.isEmpty
                                    ? '—'
                                    : current.lines.first.name,
                              ),
                              FoodMoneyRow(
                                label: l10n.foodInvoiceRecipient,
                                amount: l10n.foodInvoiceRecipientSample,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: DealGoSpacing.s12),
                      FoodPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.foodInvoiceItemsTitle,
                              style: textTheme.titleMedium,
                            ),
                            const SizedBox(height: DealGoSpacing.s12),
                            if (current == null || current.lines.isEmpty)
                              Text(
                                l10n.foodInvoiceItemsEmpty,
                                style: textTheme.bodySmall,
                              )
                            else
                              for (final line in current.lines) ...[
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const FoodThumb(size: 48),
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
                              amount: formatVnd(current?.subtotalVnd ?? 0),
                            ),
                            FoodMoneyRow(
                              label: l10n.foodInvoiceDelivery,
                              amount: formatVnd(current?.deliveryFareVnd ?? 0),
                            ),
                            FoodMoneyRow(
                              label: l10n.foodInvoiceDiscount,
                              amount: formatVnd(0),
                            ),
                            const Divider(height: DealGoSpacing.s24),
                            FoodMoneyRow(
                              label: l10n.foodInvoiceCodTotal,
                              amount: formatVnd(current?.totalVnd ?? 0),
                              emphasize: true,
                            ),
                            FoodMoneyRow(
                              label: l10n.foodInvoiceMethod,
                              amount: l10n.foodInvoiceMethodCollected,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: DealGoSpacing.s12),
                      DealGoBanner(
                        tone: DealGoBannerTone.info,
                        message: l10n.foodInvoiceCodNote(
                          formatVnd(current?.totalVnd ?? 0),
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
                    key: const Key('food-invoice-rate'),
                    label: l10n.foodInvoiceRateCta,
                    trailingIcon: Icons.arrow_forward,
                    onPressed: () {},
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
