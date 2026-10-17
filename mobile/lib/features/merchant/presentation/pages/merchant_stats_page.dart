import 'package:flutter/material.dart';

import '../../../../core/design_system/components/dealgo_card.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../widgets/merchant_widgets.dart';

class MerchantStatsPage extends StatelessWidget {
  const MerchantStatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return MerchantPageFrame(
      title: 'Thống kê',
      onBack: () => merchantBack(context),
      body: ListView(
        padding: merchantPagePadding,
        children: [
          Text('Hôm nay', style: textTheme.titleMedium),
          const SizedBox(height: DealGoSpacing.s12),
          const Row(
            children: [
              Expanded(
                child: _KpiCard(
                  label: 'Doanh thu',
                  value: '2,45 triệu',
                  tone: DealGoColors.primary,
                ),
              ),
              SizedBox(width: DealGoSpacing.s12),
              Expanded(
                child: _KpiCard(
                  label: 'Đơn hoàn thành',
                  value: '28',
                  tone: DealGoColors.brandGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: DealGoSpacing.s12),
          const Row(
            children: [
              Expanded(
                child: _KpiCard(
                  label: 'Đơn đang xử lý',
                  value: '3',
                  tone: DealGoColors.amber,
                ),
              ),
              SizedBox(width: DealGoSpacing.s12),
              Expanded(
                child: _KpiCard(
                  label: 'Đánh giá TB',
                  value: '4.8',
                  tone: Color(0xFFEA580C),
                ),
              ),
            ],
          ),
          const SizedBox(height: DealGoSpacing.s20),
          Text('7 ngày gần đây', style: textTheme.titleMedium),
          const SizedBox(height: DealGoSpacing.s12),
          DealGoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Đơn theo ngày', style: textTheme.titleMedium),
                const SizedBox(height: DealGoSpacing.s16),
                const _MiniBars(
                  values: [0.45, 0.6, 0.52, 0.78, 0.7, 0.88, 0.65],
                  labels: ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'],
                ),
                const SizedBox(height: DealGoSpacing.s12),
                Text(
                  'Tổng 186 đơn · doanh thu ước tính 14,2 triệu đồng',
                  style: textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: DealGoSpacing.s16),
          DealGoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Món bán chạy', style: textTheme.titleMedium),
                const SizedBox(height: DealGoSpacing.s12),
                const _RankRow(rank: '1', name: 'Bún bò đặc biệt', count: '96'),
                const SizedBox(height: DealGoSpacing.s8),
                const _RankRow(rank: '2', name: 'Trà đá', count: '71'),
                const SizedBox(height: DealGoSpacing.s8),
                const _RankRow(rank: '3', name: 'Bún bò thường', count: '48'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.tone,
  });

  final String label;
  final String value;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return DealGoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: textTheme.bodySmall),
          const SizedBox(height: DealGoSpacing.s8),
          Text(
            value,
            style: textTheme.titleLarge?.copyWith(
              color: tone,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniBars extends StatelessWidget {
  const _MiniBars({required this.values, required this.labels});

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

class _RankRow extends StatelessWidget {
  const _RankRow({required this.rank, required this.name, required this.count});

  final String rank;
  final String name;
  final String count;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: DealGoColors.subtlePurple,
            borderRadius: BorderRadius.circular(999),
          ),
          child: SizedBox(
            width: 28,
            height: 28,
            child: Center(
              child: Text(
                rank,
                style: textTheme.labelSmall?.copyWith(
                  color: DealGoColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: DealGoSpacing.s12),
        Expanded(child: Text(name, style: textTheme.bodyMedium)),
        Text(
          '$count phần',
          style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
