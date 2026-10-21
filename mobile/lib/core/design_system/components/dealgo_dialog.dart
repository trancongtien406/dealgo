import 'package:flutter/material.dart';

import '../tokens/dealgo_tokens.dart';
import 'dealgo_primary_button.dart';
import 'dealgo_secondary_button.dart';

/// Rounded DealGo confirm/info dialog card.
class DealGoDialog extends StatelessWidget {
  const DealGoDialog({
    required this.title,
    this.body,
    this.content,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.primaryTone = DealGoDialogPrimaryTone.brand,
    this.primaryKey,
    super.key,
  });

  final String title;
  final String? body;
  final Widget? content;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final DealGoDialogPrimaryTone primaryTone;
  final Key? primaryKey;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Dialog(
      backgroundColor: DealGoColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DealGoRadius.card),
      ),
      insetPadding: const EdgeInsets.symmetric(
        horizontal: DealGoDimensions.pageGutter * 1.5,
        vertical: DealGoSpacing.s24,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          DealGoSpacing.s20,
          DealGoSpacing.s20,
          DealGoSpacing.s20,
          DealGoSpacing.s16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: textTheme.titleLarge),
            if (body != null) ...[
              const SizedBox(height: DealGoSpacing.s12),
              Text(body!, style: textTheme.bodyMedium),
            ],
            if (content != null) ...[
              const SizedBox(height: DealGoSpacing.s12),
              content!,
            ],
            if (primaryLabel != null || secondaryLabel != null) ...[
              const SizedBox(height: DealGoSpacing.s20),
              if (secondaryLabel != null && primaryLabel != null)
                Row(
                  children: [
                    Expanded(
                      child: DealGoSecondaryButton(
                        label: secondaryLabel!,
                        onPressed:
                            onSecondary ?? () => Navigator.of(context).pop(),
                      ),
                    ),
                    const SizedBox(width: DealGoSpacing.s12),
                    Expanded(
                      child: primaryTone == DealGoDialogPrimaryTone.danger
                          ? DealGoSecondaryButton(
                              key: primaryKey,
                              label: primaryLabel!,
                              tone: DealGoSecondaryTone.danger,
                              onPressed:
                                  onPrimary ??
                                  () => Navigator.of(context).pop(true),
                            )
                          : DealGoPrimaryButton(
                              key: primaryKey,
                              label: primaryLabel!,
                              onPressed:
                                  onPrimary ??
                                  () => Navigator.of(context).pop(true),
                            ),
                    ),
                  ],
                )
              else if (primaryLabel != null)
                DealGoPrimaryButton(
                  key: primaryKey,
                  label: primaryLabel!,
                  onPressed: onPrimary ?? () => Navigator.of(context).pop(true),
                )
              else
                DealGoSecondaryButton(
                  label: secondaryLabel!,
                  onPressed: onSecondary ?? () => Navigator.of(context).pop(),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

enum DealGoDialogPrimaryTone { brand, danger }

Future<T?> showDealGoDialog<T>({
  required BuildContext context,
  required String title,
  String? body,
  Widget? content,
  String? primaryLabel,
  VoidCallback? onPrimary,
  String? secondaryLabel,
  VoidCallback? onSecondary,
  DealGoDialogPrimaryTone primaryTone = DealGoDialogPrimaryTone.brand,
  Key? primaryKey,
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (dialogContext) => DealGoDialog(
      title: title,
      body: body,
      content: content,
      primaryLabel: primaryLabel,
      onPrimary: onPrimary,
      secondaryLabel: secondaryLabel,
      onSecondary: onSecondary,
      primaryTone: primaryTone,
      primaryKey: primaryKey,
    ),
  );
}

Future<bool> showDealGoConfirmDialog({
  required BuildContext context,
  required String title,
  String? body,
  required String confirmLabel,
  required String cancelLabel,
  DealGoDialogPrimaryTone confirmTone = DealGoDialogPrimaryTone.brand,
  Key? confirmKey,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => DealGoDialog(
      title: title,
      body: body,
      primaryLabel: confirmLabel,
      secondaryLabel: cancelLabel,
      primaryTone: confirmTone,
      primaryKey: confirmKey,
      onPrimary: () => Navigator.of(dialogContext).pop(true),
      onSecondary: () => Navigator.of(dialogContext).pop(false),
    ),
  );
  return result == true;
}
