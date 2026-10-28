import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../design_system/components/dealgo_dialog.dart';
import '../design_system/components/dealgo_primary_button.dart';
import '../design_system/components/dealgo_secondary_button.dart';
import '../design_system/tokens/dealgo_tokens.dart';

/// "Tiếp tục hồ sơ đang làm?" — true: continue, false: start over,
/// null: dismissed (keep the draft, ask again next time).
Future<bool?> askResumeDraft(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => DealGoDialog(
      key: const Key('draft-resume-dialog'),
      title: l10n.draftResumeTitle,
      body: l10n.draftResumeBody,
      // Stacked so both labels stay on one line on small phones.
      content: Padding(
        padding: const EdgeInsets.only(top: DealGoSpacing.s8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DealGoPrimaryButton(
              key: const Key('draft-resume-continue'),
              label: l10n.draftResumeContinue,
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
            const SizedBox(height: DealGoSpacing.s12),
            DealGoSecondaryButton(
              key: const Key('draft-resume-discard'),
              label: l10n.draftResumeDiscard,
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Short confirmation after a draft was put back.
void showDraftRestoredNote(BuildContext context) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).draftRestoredNote)),
    );
}
