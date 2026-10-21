import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/design_system/components/dealgo_text_field.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';

/// DEC-PROD-036: asks the driver for the 4-digit delivery code (from the customer) or
/// handover code (from the store). Returns the code, or null when dismissed.
Future<String?> showDriverFoodCodeSheet(
  BuildContext context, {
  required bool delivery,
  String? error,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _DriverFoodCodeSheet(delivery: delivery, error: error),
  );
}

class _DriverFoodCodeSheet extends StatefulWidget {
  const _DriverFoodCodeSheet({required this.delivery, this.error});

  final bool delivery;
  final String? error;

  @override
  State<_DriverFoodCodeSheet> createState() => _DriverFoodCodeSheetState();
}

class _DriverFoodCodeSheetState extends State<_DriverFoodCodeSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _complete => RegExp(r'^\d{4}$').hasMatch(_controller.text);

  void _submit() {
    if (_complete) {
      Navigator.of(context).pop(_controller.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final error = widget.error;
    return Padding(
      key: const Key('driver-food-code-sheet'),
      padding: EdgeInsets.fromLTRB(
        DealGoDimensions.pageGutter,
        0,
        DealGoDimensions.pageGutter,
        MediaQuery.viewInsetsOf(context).bottom + DealGoSpacing.s16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.delivery
                ? l10n.driverFoodDeliveryCodeTitle
                : l10n.driverFoodHandoverCodeTitle,
            style: textTheme.titleLarge,
          ),
          const SizedBox(height: DealGoSpacing.s8),
          Text(
            widget.delivery
                ? l10n.driverFoodDeliveryCodeBody
                : l10n.driverFoodHandoverCodeBody,
            style: textTheme.bodyMedium?.copyWith(
              color: DealGoColors.textSecondary,
            ),
          ),
          const SizedBox(height: DealGoSpacing.s16),
          DealGoTextField(
            label: widget.delivery
                ? l10n.driverFoodDeliveryCodeTitle
                : l10n.driverFoodHandoverCodeTitle,
            showLabel: false,
            controller: _controller,
            fieldKey: const Key('driver-food-code-input'),
            autofocus: true,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            errorText: error,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: DealGoSpacing.s16),
          FilledButton(
            key: const Key('driver-food-code-submit'),
            onPressed: _complete ? _submit : null,
            child: Text(l10n.driverFoodCodeSubmit),
          ),
        ],
      ),
    );
  }
}
