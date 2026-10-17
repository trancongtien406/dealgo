import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../domain/entities/food_models.dart';
import '../../domain/entities/food_money.dart';
import '../utils/food_routes.dart';
import '../widgets/food_widgets.dart';

class FoodOrderSuccessArgs {
  const FoodOrderSuccessArgs({
    required this.order,
    required this.storeName,
    required this.storeAddress,
  });

  final PlacedFoodOrder order;
  final String storeName;
  final String storeAddress;
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
            FoodScreenHeader(
              title: 'Đã gửi đơn hàng',
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
                          Icons.check,
                          color: DealGoColors.brandGreen,
                          size: 36,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: DealGoSpacing.s16),
                  Text(
                    'Đặt hàng thành công',
                    key: const Key('food-order-success-title'),
                    textAlign: TextAlign.center,
                    style: textTheme.titleLarge,
                  ),
                  const SizedBox(height: DealGoSpacing.s4),
                  Text(
                    'Đơn đã được tạo; quán chưa xác nhận',
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall,
                  ),
                  const SizedBox(height: DealGoSpacing.s16),
                  FoodPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Đơn hàng', style: textTheme.titleMedium),
                        const SizedBox(height: DealGoSpacing.s8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Đơn #${order.id}',
                                style: textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            FoodStatusChip(
                              label: 'v1 · Dữ liệu đồng bộ',
                              tone: FoodChipTone.neutral,
                            ),
                          ],
                        ),
                        const SizedBox(height: DealGoSpacing.s12),
                        Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.asset(
                                'assets/images/food_bun_bo_hue.png',
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: ColoredBox(
                                    color: DealGoColors.subtlePurple,
                                  ),
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
                                  Text(
                                    args.storeAddress,
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
                                'Khách thanh toán COD',
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
                        const FoodStatusChip(
                          label: 'COD · Chưa thu tiền',
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
                        Text('Tiến trình', style: textTheme.titleMedium),
                        const SizedBox(height: DealGoSpacing.s12),
                        const _ProgressRow(
                          label: 'Đơn đã gửi',
                          time: '13:24',
                          tone: FoodChipTone.green,
                          done: true,
                        ),
                        const SizedBox(height: DealGoSpacing.s8),
                        const _ProgressRow(
                          label: 'Chờ Shop xác nhận',
                          tone: FoodChipTone.warning,
                        ),
                        const SizedBox(height: DealGoSpacing.s8),
                        const _ProgressRow(
                          label: 'Chưa chuẩn bị',
                          tone: FoodChipTone.neutral,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: DealGoSpacing.s12),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: DealGoColors.greenSurface,
                      borderRadius: BorderRadius.circular(DealGoRadius.input),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(DealGoSpacing.s12),
                      child: Text(
                        '“Đặt hàng thành công” là tạo đơn thành công, KHÔNG phải giao hàng hoặc thanh toán thành công.',
                        style: textTheme.bodySmall?.copyWith(
                          color: DealGoColors.brandGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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
                label: 'Theo dõi đơn hàng',
                trailingIcon: Icons.arrow_forward,
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
    this.time,
    this.done = false,
  });

  final String label;
  final FoodChipTone tone;
  final String? time;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          done ? Icons.check_circle : Icons.circle,
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
        if (time != null)
          Text(time!, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
