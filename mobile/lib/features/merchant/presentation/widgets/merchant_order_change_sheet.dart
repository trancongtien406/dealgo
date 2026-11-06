import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design_system/components/dealgo_banner.dart';
import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/components/dealgo_text_field.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/motion/dealgo_sheet.dart';
import '../../../../core/l10n/api_error_text.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../food/data/datasources/food_remote_datasource.dart';
import '../../../food/domain/entities/food_models.dart';
import '../../../food/domain/entities/food_money.dart';
import '../utils/merchant_kitchen_lines.dart';
import 'merchant_widgets.dart';

/// Store reports sold-out items — lower quantities or remove lines.
/// The customer must accept the new total (GrabFood/ShopeeFood "hết món" flow).
/// Returns the pending change once the server stored it.
Future<FoodOrderChange?> showMerchantOrderChangeSheet(
  BuildContext context, {
  required String orderId,
  required List<MerchantKitchenLine> lines,
}) {
  return showDealGoSheet<FoodOrderChange>(
    context: context,
    isScrollControlled: true,
    builder: (_) => MerchantOrderChangeSheet(
      orderId: orderId,
      lines: [
        for (final line in lines)
          if (line.id != null) line,
      ],
      client: context.read<FoodClient>(),
      accessToken: merchantAccessToken(context) ?? '',
    ),
  );
}

class MerchantOrderChangeSheet extends StatefulWidget {
  const MerchantOrderChangeSheet({
    required this.orderId,
    required this.lines,
    required this.client,
    required this.accessToken,
    super.key,
  });

  final String orderId;
  final List<MerchantKitchenLine> lines;
  final FoodClient client;
  final String accessToken;

  @override
  State<MerchantOrderChangeSheet> createState() =>
      _MerchantOrderChangeSheetState();
}

class _MerchantOrderChangeSheetState extends State<MerchantOrderChangeSheet> {
  late final Map<String, int> _qty = {
    for (final line in widget.lines) line.id!: line.qty,
  };
  var _reason = FoodOrderChangeReason.outOfStock;
  final _note = TextEditingController();
  var _sending = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Map<String, int> get _edits => {
    for (final line in widget.lines)
      if (_qty[line.id!]! < line.qty) line.id!: _qty[line.id!]!,
  };

  int get _newSubtotal {
    var total = 0;
    for (final line in widget.lines) {
      total += line.unitPriceVnd * _qty[line.id!]!;
    }
    return total;
  }

  bool get _valid {
    if (_edits.isEmpty) return false;
    // Removing every line is a reject, not an edit.
    if (_qty.values.every((q) => q == 0)) return false;
    if (_reason == FoodOrderChangeReason.other && _note.text.trim().isEmpty) {
      return false;
    }
    return true;
  }

  Future<void> _submit() async {
    if (!_valid || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final change = await widget.client.proposeOrderChange(
        accessToken: widget.accessToken,
        orderId: widget.orderId,
        reason: _reason,
        quantities: _edits,
        note: _note.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(change);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = apiErrorText(AppLocalizations.of(context), error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final allRemoved = _qty.values.every((q) => q == 0);
    return Padding(
      padding: EdgeInsets.only(
        left: DealGoSpacing.s16,
        right: DealGoSpacing.s16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + DealGoSpacing.s16,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.merchantEditOrder, style: textTheme.titleLarge),
            const SizedBox(height: DealGoSpacing.s4),
            Text(l10n.merchantEditOrderHint, style: textTheme.bodySmall),
            const SizedBox(height: DealGoSpacing.s12),
            for (final line in widget.lines)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      line.name,
                      style: textTheme.bodyMedium?.copyWith(
                        decoration: _qty[line.id!] == 0
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ),
                  IconButton(
                    key: Key('merchant-change-minus-${line.id}'),
                    onPressed: _sending || _qty[line.id!] == 0
                        ? null
                        : () => setState(
                            () => _qty[line.id!] = _qty[line.id!]! - 1,
                          ),
                    icon: const Icon(DealGoIcons.remove),
                  ),
                  Text('${_qty[line.id!]}/${line.qty}'),
                  IconButton(
                    key: Key('merchant-change-plus-${line.id}'),
                    onPressed: _sending || _qty[line.id!] == line.qty
                        ? null
                        : () => setState(
                            () => _qty[line.id!] = _qty[line.id!]! + 1,
                          ),
                    icon: const Icon(DealGoIcons.add),
                  ),
                ],
              ),
            const SizedBox(height: DealGoSpacing.s8),
            Wrap(
              spacing: DealGoSpacing.s8,
              children: [
                for (final reason in FoodOrderChangeReason.values)
                  ChoiceChip(
                    key: Key('merchant-change-reason-${reason.wire}'),
                    selected: _reason == reason,
                    onSelected: _sending
                        ? null
                        : (_) => setState(() => _reason = reason),
                    label: Text(switch (reason) {
                      FoodOrderChangeReason.outOfStock =>
                        l10n.foodChangeReasonOutOfStock,
                      FoodOrderChangeReason.notEnoughPortions =>
                        l10n.foodChangeReasonNotEnough,
                      FoodOrderChangeReason.other => l10n.foodChangeReasonOther,
                    }),
                  ),
              ],
            ),
            const SizedBox(height: DealGoSpacing.s8),
            DealGoTextField(
              key: const Key('merchant-change-note'),
              label: l10n.merchantEditOrderNote,
              controller: _note,
              maxLength: 300,
              enabled: !_sending,
              onChanged: (_) => setState(() {}),
            ),
            if (allRemoved)
              DealGoBanner(
                tone: DealGoBannerTone.warning,
                message: l10n.merchantEditOrderAllRemoved,
              ),
            if (_error case final error?)
              DealGoBanner(tone: DealGoBannerTone.warning, message: error),
            const SizedBox(height: DealGoSpacing.s8),
            Text(
              l10n.merchantEditOrderNewSubtotal(formatVnd(_newSubtotal)),
              style: textTheme.titleMedium,
            ),
            const SizedBox(height: DealGoSpacing.s12),
            DealGoPrimaryButton(
              key: const Key('merchant-change-submit'),
              label: l10n.merchantEditOrderSend,
              isLoading: _sending,
              enabled: _valid && !_sending,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
