import 'package:flutter/material.dart';

import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../food/domain/entities/food_money.dart';
import '../../../food/presentation/widgets/food_order_extras.dart';
import '../utils/merchant_kitchen_lines.dart';

class MerchantKitchenLineRow extends StatelessWidget {
  const MerchantKitchenLineRow({required this.line, super.key});

  final MerchantKitchenLine line;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(DealGoRadius.small),
          child: Container(
            width: 44,
            height: 44,
            color: DealGoColors.amberSurface,
            child: Center(
              child: Icon(DealGoIcons.food, size: 20, color: DealGoColors.amber),
            ),
          ),
        ),
        const SizedBox(width: DealGoSpacing.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(line.name, style: textTheme.titleMedium),
              if (line.options.isNotEmpty)
                Text(
                  line.options,
                  key: const Key('merchant-line-options'),
                  style: textTheme.bodySmall?.copyWith(
                    color: DealGoColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if ((line.note ?? '').trim().isNotEmpty)
                FoodLineNoteText(line.note!),
              Text(
                l10n.merchantLineQty(line.qty, formatVnd(line.unitPriceVnd)),
                style: textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(width: DealGoSpacing.s8),
        Text(
          formatVnd(line.unitPriceVnd * line.qty),
          style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
