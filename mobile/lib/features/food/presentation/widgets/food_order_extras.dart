import 'package:flutter/material.dart';

import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/design_system/tokens/dealgo_type_scale.dart';
import '../../../../l10n/app_localizations.dart';

/// Customer note quoted under a dish on receipts, kitchen tickets and cards.
class FoodLineNoteText extends StatelessWidget {
  const FoodLineNoteText(this.note, {super.key});

  final String note;

  @override
  Widget build(BuildContext context) {
    final text = note.trim();
    if (text.isEmpty) {
      return const SizedBox.shrink();
    }
    return Text(
      '"$text"',
      style: DealGoType.meta(Theme.of(context).textTheme).copyWith(
        color: DealGoColors.textSecondary,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}

/// Read-only order note and cutlery answer, shared by the invoice, the
/// merchant kitchen ticket, the driver job card and customer tracking.
class FoodOrderExtrasBlock extends StatelessWidget {
  const FoodOrderExtrasBlock({
    required this.note,
    required this.utensils,
    this.showUtensils = true,
    this.title,
    super.key,
  });

  final String? note;
  final bool utensils;
  final bool showUtensils;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final trimmed = (note ?? '').trim();
    final rows = <Widget>[
      if (trimmed.isNotEmpty)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(DealGoIcons.note, size: 18, color: DealGoColors.textSecondary),
            const SizedBox(width: DealGoSpacing.s8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.foodOrderNoteLabel,
                    style: DealGoType.meta(textTheme)
                        .copyWith(color: DealGoColors.textSecondary),
                  ),
                  const SizedBox(height: DealGoSpacing.s4),
                  Text(
                    trimmed,
                    key: const Key('food-order-note-read'),
                    style: DealGoType.body(textTheme)
                        .copyWith(color: DealGoColors.text),
                  ),
                ],
              ),
            ),
          ],
        ),
      if (showUtensils)
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.foodUtensilsLabel,
                style: DealGoType.meta(textTheme)
                    .copyWith(color: DealGoColors.textSecondary),
              ),
            ),
            Text(
              utensils ? l10n.foodUtensilsYes : l10n.foodUtensilsNo,
              key: const Key('food-order-utensils-read'),
              style: DealGoType.body(
                textTheme,
              ).copyWith(fontWeight: FontWeight.w700, color: DealGoColors.text),
            ),
          ],
        ),
    ];
    if (rows.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Text(title!, style: textTheme.titleMedium),
          const SizedBox(height: DealGoSpacing.s8),
        ],
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: DealGoSpacing.s8),
          rows[i],
        ],
      ],
    );
  }
}
