import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design_system/components/dealgo_banner.dart';
import '../../../core/design_system/components/dealgo_chip.dart';
import '../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../identity/presentation/widgets/auth_widgets.dart';

/// C046 — soft payment history shell (fixture rows; TEST_ONLY labels).
class PaymentHistoryPage extends StatefulWidget {
  const PaymentHistoryPage({super.key});

  @override
  State<PaymentHistoryPage> createState() => _PaymentHistoryPageState();
}

class _PaymentHistoryPageState extends State<PaymentHistoryPage> {
  var _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: DealGoColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DealGoSpacing.s8,
                DealGoSpacing.s8,
                DealGoDimensions.pageGutter,
                DealGoSpacing.s8,
              ),
              child: Row(
                children: [
                  AuthBackButton(
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      }
                    },
                  ),
                  const SizedBox(width: DealGoSpacing.s8),
                  Expanded(
                    child: Text(
                      l10n.paymentHistoryTitle,
                      style: textTheme.titleMedium,
                    ),
                  ),
                  const DealGoWordmark(),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  DealGoDimensions.pageGutter,
                  DealGoSpacing.s8,
                  DealGoDimensions.pageGutter,
                  DealGoSpacing.s24,
                ),
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: DealGoColors.primary,
                      borderRadius: BorderRadius.circular(DealGoRadius.card),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(DealGoSpacing.s20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.paymentHistoryMonthTotal,
                            style: textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                          const SizedBox(height: DealGoSpacing.s8),
                          Text(
                            '1.245.000đ',
                            style: textTheme.headlineMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: DealGoSpacing.s4),
                          Text(
                            l10n.paymentHistoryMonthMeta,
                            style: textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                          const SizedBox(height: DealGoSpacing.s8),
                          DealGoChip(
                            label: l10n.paymentHistoryTestOnly,
                            tone: DealGoChipTone.warning,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: DealGoSpacing.s16),
                  Row(
                    children: [
                      for (final entry in [
                        ('all', l10n.paymentHistoryFilterAll),
                        ('paid', l10n.paymentHistoryFilterPaid),
                        ('refund', l10n.paymentHistoryFilterRefund),
                      ]) ...[
                        DealGoChip(
                          label: entry.$2,
                          selected: _filter == entry.$1,
                          tone: DealGoChipTone.brand,
                          onTap: () => setState(() => _filter = entry.$1),
                        ),
                        const SizedBox(width: DealGoSpacing.s8),
                      ],
                    ],
                  ),
                  const SizedBox(height: DealGoSpacing.s20),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.paymentHistoryRecent,
                          style: textTheme.titleMedium,
                        ),
                      ),
                      Text(
                        l10n.paymentHistoryMonthPicker,
                        style: textTheme.labelSmall?.copyWith(
                          color: DealGoColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: DealGoSpacing.s12),
                  Text(
                    l10n.paymentHistoryTodayGroup,
                    style: textTheme.labelSmall?.copyWith(
                      color: DealGoColors.textSecondary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: DealGoSpacing.s8),
                  _TxRow(
                    icon: Icons.ramen_dining,
                    color: const Color(0xFFFFEDD5),
                    iconColor: const Color(0xFFEA580C),
                    title: l10n.paymentHistoryFoodSample,
                    subtitle: l10n.paymentHistoryFoodMeta,
                    amount: '-130.000đ',
                    amountColor: DealGoColors.text,
                  ),
                  _TxRow(
                    icon: Icons.directions_car_filled,
                    color: const Color(0xFFFEF3C7),
                    iconColor: const Color(0xFFD97706),
                    title: l10n.paymentHistoryRideSample,
                    subtitle: l10n.paymentHistoryRideMeta,
                    amount: '-42.000đ',
                    amountColor: DealGoColors.text,
                  ),
                  _TxRow(
                    icon: Icons.south_west,
                    color: DealGoColors.subtlePurple,
                    iconColor: DealGoColors.primary,
                    title: l10n.paymentHistoryRefundSample,
                    subtitle: l10n.paymentHistoryRefundMeta,
                    amount: '+35.000đ',
                    amountColor: DealGoColors.brandGreen,
                  ),
                  const SizedBox(height: DealGoSpacing.s16),
                  DealGoBanner(
                    tone: DealGoBannerTone.info,
                    message: l10n.paymentHistoryNote,
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

class _TxRow extends StatelessWidget {
  const _TxRow({
    required this.icon,
    required this.color,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.amountColor,
  });

  final IconData icon;
  final Color color;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String amount;
  final Color amountColor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DealGoSpacing.s8),
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(DealGoRadius.input),
            ),
            child: SizedBox(
              width: 40,
              height: 40,
              child: Icon(icon, color: iconColor, size: 20),
            ),
          ),
          const SizedBox(width: DealGoSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: textTheme.titleSmall),
                Text(subtitle, style: textTheme.bodySmall),
              ],
            ),
          ),
          Text(
            amount,
            style: textTheme.titleSmall?.copyWith(
              color: amountColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
