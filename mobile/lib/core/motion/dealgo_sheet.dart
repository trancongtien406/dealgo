import 'package:flutter/material.dart';

import '../design_system/tokens/dealgo_tokens.dart';
import 'dealgo_motion.dart';

/// Shared modal sheet entry — one place for radius, barrier, and reduced-motion.
Future<T?> showDealGoSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  Color? backgroundColor,
}) {
  final reduce = DealGoMotion.prefersReducedMotion(context);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: backgroundColor ?? DealGoColors.card,
    barrierColor: Colors.black.withValues(alpha: reduce ? 0.45 : 0.32),
    sheetAnimationStyle: reduce
        ? AnimationStyle.noAnimation
        : AnimationStyle(
            duration: DealGoMotion.medium,
            reverseDuration: DealGoMotion.fast,
            curve: DealGoMotion.standard,
          ),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: builder,
  );
}
