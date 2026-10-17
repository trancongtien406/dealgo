import 'package:flutter/material.dart';

import '../../../../core/design_system/components/dealgo_card.dart';
import '../../../../core/design_system/components/dealgo_segmented_control.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../widgets/driver_widgets.dart';

enum _EarnRange { today, week, month, custom }

class DriverEarningsPage extends StatefulWidget {
  const DriverEarningsPage({super.key});

  @override
  State<DriverEarningsPage> createState() => _DriverEarningsPageState();
}

class _DriverEarningsPageState extends State<DriverEarningsPage> {
  var _range = _EarnRange.today;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return DriverPageFrame(
      title: 'Tổng quan thu nhập',
      subtitle: 'Thu nhập tài xế',
      onBack: () => driverBack(context),
      footer: DriverFooter(
        secondaryLabel: 'Đối soát COD',
        primaryLabel: 'Xem ví tài xế',
        onSecondary: () {},
        onPrimary: () {},
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          DealGoDimensions.pageGutter,
          DealGoSpacing.s12,
          DealGoDimensions.pageGutter,
          DealGoSpacing.s16,
        ),
        children: [
          DealGoSegmentedControl(
            value: _range.name,
            onChanged: (id) => setState(
              () => _range = _EarnRange.values.firstWhere((e) => e.name == id),
            ),
            items: const [
              DealGoSegmentItem(id: 'today', label: 'Hôm nay'),
              DealGoSegmentItem(id: 'week', label: '7 ngày'),
              DealGoSegmentItem(id: 'month', label: '30 ngày'),
              DealGoSegmentItem(id: 'custom', label: 'Tùy chọn'),
            ],
          ),
          const SizedBox(height: DealGoSpacing.s16),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6D28D9), Color(0xFF8B5CF6)],
              ),
              borderRadius: BorderRadius.circular(DealGoRadius.card),
            ),
            child: Padding(
              padding: const EdgeInsets.all(DealGoSpacing.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Thu nhập thực nhận hôm nay',
                          style: textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: DealGoSpacing.s8,
                            vertical: 4,
                          ),
                          child: Text(
                            '+ 2 công việc',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: DealGoSpacing.s8),
                  Text(
                    '60.000đ',
                    style: textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: DealGoSpacing.s4),
                  Text(
                    'Sau phí nền tảng · không bao gồm COD thu hộ',
                    style: textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: DealGoSpacing.s12),
          const Row(
            children: [
              Expanded(
                child: _SplitCard(
                  title: 'Chuyên chở khách',
                  amount: '40.000đ',
                  meta: '1 chuyến · sau phí',
                ),
              ),
              SizedBox(width: DealGoSpacing.s12),
              Expanded(
                child: _SplitCard(
                  title: 'Giao đồ ăn',
                  amount: '20.000đ',
                  meta: '1 đơn · sau phí',
                ),
              ),
            ],
          ),
          const SizedBox(height: DealGoSpacing.s20),
          DealGoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Thu nhập 7 ngày',
                        style: textTheme.titleMedium,
                      ),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: DealGoColors.subtlePurple,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: DealGoSpacing.s8,
                          vertical: 4,
                        ),
                        child: Text(
                          '1,25 triệu đồng',
                          style: textTheme.labelSmall?.copyWith(
                            color: DealGoColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: DealGoSpacing.s16),
                const _WeekBars(
                  values: [0.55, 0.7, 0.48, 0.82, 0.66, 0.9, 0.42],
                  labels: ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'],
                ),
              ],
            ),
          ),
          const SizedBox(height: DealGoSpacing.s16),
          Row(
            children: [
              Expanded(
                child: Text('Các khoản gần đây', style: textTheme.titleMedium),
              ),
              TextButton(onPressed: () {}, child: const Text('Chi tiết')),
            ],
          ),
          const SizedBox(height: DealGoSpacing.s8),
          const _TxnRow(
            icon: Icons.two_wheeler,
            title: 'Chở khách · DG-R26001',
            meta: '10:45 · Sau phí 5.000đ',
            amount: '+40.000đ',
          ),
          const SizedBox(height: DealGoSpacing.s12),
          const _TxnRow(
            icon: Icons.shopping_bag_outlined,
            title: 'Giao đồ ăn · DG-123456',
            meta: '11:05 · Sau phí 5.000đ',
            amount: '+20.000đ',
          ),
        ],
      ),
    );
  }
}

class _SplitCard extends StatelessWidget {
  const _SplitCard({
    required this.title,
    required this.amount,
    required this.meta,
  });

  final String title;
  final String amount;
  final String meta;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return DealGoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: textTheme.bodySmall),
          const SizedBox(height: DealGoSpacing.s8),
          Text(amount, style: textTheme.titleMedium),
          Text(meta, style: textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _WeekBars extends StatelessWidget {
  const _WeekBars({required this.values, required this.labels});

  final List<double> values;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var index = 0; index < values.length; index++) ...[
            if (index > 0) const SizedBox(width: DealGoSpacing.s8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: FractionallySizedBox(
                      heightFactor: values[index],
                      widthFactor: 1,
                      alignment: Alignment.bottomCenter,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: index == values.length - 1
                              ? DealGoColors.brandGreen
                              : DealGoColors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: DealGoSpacing.s8),
                  Text(
                    labels[index],
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TxnRow extends StatelessWidget {
  const _TxnRow({
    required this.icon,
    required this.title,
    required this.meta,
    required this.amount,
  });

  final IconData icon;
  final String title;
  final String meta;
  final String amount;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return DealGoCard(
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: DealGoColors.subtlePurple,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(icon, color: DealGoColors.primary),
            ),
          ),
          const SizedBox(width: DealGoSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.titleMedium?.copyWith(fontSize: 14),
                ),
                Text(meta, style: textTheme.bodySmall),
              ],
            ),
          ),
          Text(
            amount,
            style: textTheme.titleMedium?.copyWith(
              color: DealGoColors.brandGreen,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}
