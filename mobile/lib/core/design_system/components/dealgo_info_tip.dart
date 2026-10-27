import 'package:flutter/material.dart';

import '../tokens/dealgo_tokens.dart';

/// Small info icon that reveals [message] on tap/long-press instead of a
/// permanent hint line (keeps screens short; text stays in arb).
class DealGoInfoTip extends StatelessWidget {
  const DealGoInfoTip({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: message,
      triggerMode: TooltipTriggerMode.tap,
      showDuration: const Duration(seconds: 4),
      child: Semantics(
        button: true,
        label: message,
        child: const Padding(
          padding: EdgeInsets.all(DealGoSpacing.s4),
          child: Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: DealGoColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
