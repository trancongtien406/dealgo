import 'package:flutter/material.dart';

import '../tokens/dealgo_tokens.dart';

class DealGoCard extends StatelessWidget {
  const DealGoCard({
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(DealGoSpacing.s16),
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(DealGoRadius.card),
      side: const BorderSide(color: DealGoColors.border),
    );

    final content = Padding(padding: padding, child: child);

    return Material(
      color: DealGoColors.card,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? content
          : InkWell(onTap: onTap, customBorder: shape, child: content),
    );
  }
}
