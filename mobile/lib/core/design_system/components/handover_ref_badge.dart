import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../icons/dealgo_icons.dart';
import '../tokens/dealgo_tokens.dart';

/// OPEN-011 / DEC-PROD-047: last 4 letters/digits of the order id, shown big
/// to both merchant and driver so they can match the bag at handover
/// (Grab/ShopeeFood style; no OTP).
String handoverRef(String id) {
  final compact = id.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
  if (compact.isEmpty) {
    return '#—';
  }
  return '#${compact.length <= 4 ? compact : compact.substring(compact.length - 4)}';
}

class HandoverRefBadge extends StatelessWidget {
  const HandoverRefBadge({
    required this.orderId,
    this.dense = false,
    super.key,
  });

  final String orderId;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ref = handoverRef(orderId);
    return Semantics(
      label: l10n.handoverRefSemantics(ref),
      child: Container(
        key: const Key('handover-ref'),
        padding: EdgeInsets.symmetric(
          horizontal: dense ? 8 : 12,
          vertical: dense ? 4 : 8,
        ),
        decoration: BoxDecoration(
          color: DealGoColors.brandGreen.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: DealGoColors.brandGreen.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              DealGoIcons.package,
              size: dense ? 14 : 18,
              color: DealGoColors.brandGreen,
            ),
            const SizedBox(width: 6),
            if (!dense) ...[
              Text(
                l10n.handoverRefLabel,
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              ref,
              style: TextStyle(
                fontSize: dense ? 14 : 22,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
                color: DealGoColors.brandGreen,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
