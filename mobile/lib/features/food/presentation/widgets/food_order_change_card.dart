import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design_system/components/dealgo_banner.dart';
import '../../../../core/design_system/components/dealgo_card.dart';
import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/components/dealgo_secondary_button.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/l10n/api_error_text.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/datasources/food_remote_datasource.dart';
import '../../domain/entities/food_models.dart';
import '../../domain/entities/food_money.dart';

/// The store edited the order (sold out / fewer portions). The customer
/// accepts the new total or cancels for free — GrabFood/ShopeeFood "món hết" flow.
class FoodOrderChangeCard extends StatefulWidget {
  const FoodOrderChangeCard({
    required this.orderId,
    required this.change,
    required this.onAnswered,
    required this.accessToken,
    super.key,
  });

  final String orderId;
  final FoodOrderChange change;
  final String? accessToken;

  /// Called after the server accepted the answer (the page reloads the order).
  final VoidCallback onAnswered;

  @override
  State<FoodOrderChangeCard> createState() => _FoodOrderChangeCardState();
}

class _FoodOrderChangeCardState extends State<FoodOrderChangeCard> {
  bool? _sending;
  String? _error;

  Future<void> _answer(bool accept) async {
    if (_sending != null) return;
    final l10n = AppLocalizations.of(context);
    if (!accept) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.foodChangeRejectConfirmTitle),
          content: Text(l10n.foodChangeRejectConfirmBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.actionBack),
            ),
            TextButton(
              key: const Key('food-change-reject-confirm'),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.foodChangeReject),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() {
      _sending = accept;
      _error = null;
    });
    try {
      await context.read<FoodClient>().answerOrderChange(
        accessToken: widget.accessToken ?? '',
        orderId: widget.orderId,
        changeId: widget.change.id,
        accept: accept,
      );
      if (!mounted) return;
      setState(() => _sending = null);
      widget.onAnswered();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _sending = null;
        _error = apiErrorText(l10n, error);
      });
      // The change may have expired/been answered elsewhere — reload either way.
      widget.onAnswered();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final change = widget.change;
    final until = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(change.expiresAt.toLocal()),
      alwaysUse24HourFormat: true,
    );
    final reason = switch (change.reason) {
      FoodOrderChangeReason.outOfStock => l10n.foodChangeReasonOutOfStock,
      FoodOrderChangeReason.notEnoughPortions => l10n.foodChangeReasonNotEnough,
      FoodOrderChangeReason.other => l10n.foodChangeReasonOther,
    };
    final note = change.note;
    return DealGoCard(
      key: const Key('food-order-change-card'),
      borderColor: DealGoColors.warning,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.foodChangeTitle, style: textTheme.titleMedium),
          const SizedBox(height: DealGoSpacing.s4),
          Text(
            note == null ? reason : '$reason — $note',
            style: textTheme.bodySmall,
          ),
          const SizedBox(height: DealGoSpacing.s12),
          for (final line in change.lines)
            Padding(
              padding: const EdgeInsets.only(bottom: DealGoSpacing.s4),
              child: Row(
                children: [
                  Expanded(child: Text(line.name, style: textTheme.bodyMedium)),
                  Text(
                    line.removed
                        ? l10n.foodChangeLineRemoved
                        : '${line.fromQuantity} → ${line.toQuantity}',
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: line.removed ? DealGoColors.danger : null,
                    ),
                  ),
                ],
              ),
            ),
          const Divider(height: DealGoSpacing.s16),
          Row(
            children: [
              Expanded(child: Text(l10n.foodChangeNewTotal)),
              Text(
                formatVnd(change.newTotalVnd),
                key: const Key('food-change-new-total'),
                style: textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: DealGoSpacing.s4),
          Text(
            l10n.foodChangeAnswerBy(until),
            style: textTheme.bodySmall?.copyWith(
              color: DealGoColors.textSecondary,
            ),
          ),
          if (_error case final error?) ...[
            const SizedBox(height: DealGoSpacing.s8),
            DealGoBanner(tone: DealGoBannerTone.warning, message: error),
          ],
          const SizedBox(height: DealGoSpacing.s12),
          Row(
            children: [
              Expanded(
                child: DealGoSecondaryButton(
                  key: const Key('food-change-reject'),
                  label: l10n.foodChangeReject,
                  tone: DealGoSecondaryTone.danger,
                  enabled: _sending == null,
                  onPressed: () => _answer(false),
                ),
              ),
              const SizedBox(width: DealGoSpacing.s8),
              Expanded(
                child: DealGoPrimaryButton(
                  key: const Key('food-change-accept'),
                  label: l10n.foodChangeAccept,
                  isLoading: _sending == true,
                  enabled: _sending == null,
                  onPressed: () => _answer(true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
