import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/components/dealgo_nav_insets.dart';
import '../../../../core/design_system/components/dealgo_bottom_bar.dart';
import '../../../../core/design_system/components/dealgo_state_view.dart';
import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/food_money.dart';
import '../cubit/food_cart_cubit.dart';
import '../utils/food_routes.dart';
import '../widgets/food_dropoff_tile.dart';
import '../widgets/food_widgets.dart';
import '../widgets/food_badges.dart';
import '../../../../core/design_system/components/dealgo_app_header.dart';

class FoodCartPage extends StatelessWidget {
  const FoodCartPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cart = context.watch<FoodCartCubit>().state;
    final textTheme = Theme.of(context).textTheme;
    final fare = cart.deliveryFareVnd;
    return Scaffold(
      backgroundColor: DealGoColors.canvas,
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            DealGoAppHeader(title: l10n.foodCartTitle),
            Expanded(
              // extendBody hands the real bottom-bar height (2-line labels,
              // large text, home indicator) down as padding.bottom.
              // Builder: this context sits under the Scaffold body's MediaQuery.
              child: Builder(
                builder: (bodyContext) => ListView(
                  padding: dealGoScrollPadding(
                    bodyContext,
                    const EdgeInsets.fromLTRB(
                      DealGoDimensions.pageGutter,
                      DealGoSpacing.s8,
                      DealGoDimensions.pageGutter,
                      DealGoSpacing.s24,
                    ),
                  ),
                  children: [
                    if (cart.lines.isEmpty)
                      DealGoStateView(
                        key: const Key('food-cart-empty'),
                        art: DealGoStateArt.noOrders,
                        title: l10n.foodCartEmpty,
                        message: l10n.checkoutEmptyBody,
                        actionLabel: l10n.checkoutBackToMenu,
                        onAction: () {
                          final storeId = cart.storeId;
                          if (storeId != null && storeId.isNotEmpty) {
                            context.go(FoodRoutes.store(storeId));
                            return;
                          }
                          context.go('/customer/shop');
                        },
                        compact: true,
                      )
                    else
                      FoodPanel(
                        elevated: true,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  DealGoIcons.store,
                                  size: 18,
                                  color: DealGoColors.primary,
                                ),
                                const SizedBox(width: DealGoSpacing.s8),
                                Expanded(
                                  child: Text(
                                    cart.storeName ?? '',
                                    style: textTheme.titleMedium,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: DealGoSpacing.s8),
                            for (final line in cart.lines)
                              FoodLineSummary(
                                imageUrl: line.imageUrl,
                                name: line.name,
                                quantity: line.quantity,
                                unitPriceVnd: line.unitPriceVnd,
                                lineTotalVnd: line.lineTotalVnd,
                              ),
                            if (cart.minOrderShortVnd > 0) ...[
                              const SizedBox(height: DealGoSpacing.s8),
                              FoodNote(
                                key: const Key('food-cart-min-order'),
                                message: l10n.foodCartMinOrderMissing(
                                  formatVnd(cart.minOrderShortVnd),
                                ),
                                tone: FoodNoteTone.amber,
                              ),
                            ],
                          ],
                        ),
                      ),
                    if (cart.lines.isNotEmpty && cart.etaMinutes != null) ...[
                      const SizedBox(height: DealGoSpacing.s12),
                      FoodEtaLine(minutes: cart.etaMinutes!),
                    ],
                    const SizedBox(height: DealGoSpacing.s16),
                    FoodPanel(
                      elevated: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.foodDropoffTitle,
                            style: textTheme.titleMedium,
                          ),
                          const SizedBox(height: DealGoSpacing.s4),
                          const FoodDropoffTile(),
                        ],
                      ),
                    ),
                    const SizedBox(height: DealGoSpacing.s16),
                    FoodPanel(
                      elevated: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.foodCartEstimate,
                            style: textTheme.titleMedium,
                          ),
                          const SizedBox(height: DealGoSpacing.s8),
                          FoodMoneyRow(
                            label: l10n.checkoutSubtotal,
                            amount: formatVnd(cart.subtotalVnd),
                          ),
                          FoodMoneyRow(
                            key: const Key('food-delivery-fare'),
                            label: l10n.checkoutDeliveryFee,
                            amount: fare == null
                                ? l10n.foodFareNeedAddress
                                : formatVnd(fare),
                          ),
                          if (cart.voucherDiscountVnd > 0)
                            FoodMoneyRow(
                              label: l10n.checkoutDiscount,
                              amount: '-${formatVnd(cart.voucherDiscountVnd)}',
                            ),
                          const Divider(height: 24),
                          FoodMoneyRow(
                            label: l10n.checkoutCodTotal,
                            amount: formatVnd(cart.previewTotalVnd),
                            emphasize: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: DealGoBottomBar(
        child: cart.lines.isEmpty
            ? DealGoPrimaryButton(
                key: const Key('food-cart-back-to-menu'),
                label: l10n.checkoutBackToMenu,
                trailingIcon: DealGoIcons.arrowRight,
                onPressed: () {
                  final storeId = cart.storeId;
                  if (storeId != null && storeId.isNotEmpty) {
                    context.go(FoodRoutes.store(storeId));
                    return;
                  }
                  context.go('/customer/shop');
                },
              )
            : DealGoPrimaryButton(
                label: l10n.foodCartContinue,
                trailingIcon: DealGoIcons.arrowRight,
                enabled: cart.canCheckout,
                onPressed: () => context.push(FoodRoutes.checkout),
              ),
      ),
    );
  }
}
