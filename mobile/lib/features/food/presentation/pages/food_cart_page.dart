import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../domain/entities/food_money.dart';
import '../cubit/food_cart_cubit.dart';
import '../utils/food_routes.dart';
import '../widgets/food_widgets.dart';

class FoodCartPage extends StatefulWidget {
  const FoodCartPage({super.key});

  @override
  State<FoodCartPage> createState() => _FoodCartPageState();
}

class _FoodCartPageState extends State<FoodCartPage> {
  late final TextEditingController _address;

  @override
  void initState() {
    super.initState();
    _address = TextEditingController(
      text: context.read<FoodCartCubit>().state.dropoffLabel,
    );
  }

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<FoodCartCubit>().state;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: DealGoColors.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const FoodScreenHeader(title: 'Giỏ hàng'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  DealGoDimensions.pageGutter,
                  DealGoSpacing.s8,
                  DealGoDimensions.pageGutter,
                  DealGoSpacing.s24,
                ),
                children: [
                  if (cart.lines.isEmpty)
                    const FoodPanel(child: Text('Giỏ hàng trống'))
                  else
                    FoodPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cart.storeName ?? '',
                            style: textTheme.titleMedium,
                          ),
                          const SizedBox(height: DealGoSpacing.s8),
                          for (final line in cart.lines)
                            FoodLineSummary(
                              name: line.name,
                              quantity: line.quantity,
                              unitPriceVnd: line.unitPriceVnd,
                              lineTotalVnd: line.lineTotalVnd,
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: DealGoSpacing.s16),
                  FoodPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dự tính thanh toán',
                          style: textTheme.titleMedium,
                        ),
                        const SizedBox(height: DealGoSpacing.s8),
                        FoodMoneyRow(
                          label: 'Tiền món',
                          amount: formatVnd(cart.subtotalVnd),
                        ),
                        _FareRow(fare: cart.deliveryFareVnd),
                        const FoodMoneyRow(label: 'Giảm giá', amount: '0đ'),
                        const Divider(height: 24),
                        FoodMoneyRow(
                          label: 'Tổng COD',
                          amount: formatVnd(cart.previewTotalVnd),
                          emphasize: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: DealGoSpacing.s16),
                  const FoodNote(
                    tone: FoodNoteTone.green,
                    message: 'Giỏ hàng đang ở trạng thái DRAFT. Chưa tạo đơn và chưa thu COD.',
                  ),
                  const SizedBox(height: DealGoSpacing.s16),
                  FoodPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Địa chỉ nhận', style: textTheme.titleMedium),
                        const SizedBox(height: DealGoSpacing.s8),
                        TextField(
                          controller: _address,
                          textInputAction: TextInputAction.done,
                          maxLength: 160,
                          onChanged: context
                              .read<FoodCartCubit>()
                              .setDropoffLabel,
                          decoration: const InputDecoration(
                            hintText: 'Số nhà, đường, quận',
                            counterText: '',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            DealGoDimensions.pageGutter,
            DealGoSpacing.s12,
            DealGoDimensions.pageGutter,
            DealGoSpacing.s12,
          ),
          child: DealGoPrimaryButton(
            label: 'Tiếp tục thanh toán',
            enabled: cart.canCheckout,
            onPressed: () => context.push(FoodRoutes.checkout),
          ),
        ),
      ),
    );
  }
}

class _FareRow extends StatelessWidget {
  const _FareRow({required this.fare});

  final int fare;

  @override
  Widget build(BuildContext context) {
    final cart = context.read<FoodCartCubit>();
    return Row(
      children: [
        Expanded(
          child: Text(
            'Phí giao',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        IconButton(
          tooltip: 'Giảm phí giao',
          onPressed: fare <= foodDeliveryFareMinVnd
              ? null
              : () => cart.setDeliveryFare(fare - 5000),
          icon: const Icon(Icons.remove),
        ),
        Text(
          formatVnd(fare),
          key: const Key('food-delivery-fare'),
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        IconButton(
          tooltip: 'Tăng phí giao',
          onPressed: fare >= foodDeliveryFareMaxVnd
              ? null
              : () => cart.setDeliveryFare(fare + 5000),
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}
