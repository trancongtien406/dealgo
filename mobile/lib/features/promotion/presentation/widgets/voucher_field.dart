import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design_system/components/dealgo_haptics.dart';
import '../../../../core/design_system/components/dealgo_text_field.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/l10n/api_error_text.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/voucher_quote.dart';
import '../../domain/usecases/validate_voucher.dart';

/// Voucher entry that checks the code against `POST /v1/promotions/validate`.
class VoucherField extends StatefulWidget {
  const VoucherField({
    required this.service,
    required this.orderAmountVnd,
    required this.accessToken,
    required this.formatAmount,
    this.deliveryFeeVnd,
    this.storeId,
    this.onQuote,
    this.initialCode,
    this.seededCode,
    this.seededCodeVersion = 0,
    super.key,
  });

  final VoucherService service;
  final int orderAmountVnd;
  final int? deliveryFeeVnd;
  final String? storeId;
  final String? Function() accessToken;
  final String Function(int amountVnd) formatAmount;
  final ValueChanged<VoucherQuote?>? onQuote;

  /// Code already held by the caller (e.g. the cart); re-quoted on mount.
  final String? initialCode;

  /// Code chosen outside the field (voucher list). [seededCodeVersion] changes
  /// on every pick so the same code is quoted again after the customer clears it.
  final String? seededCode;
  final int seededCodeVersion;

  @override
  State<VoucherField> createState() => _VoucherFieldState();
}

class _VoucherFieldState extends State<VoucherField> {
  final _controller = TextEditingController();
  var _busy = false;
  String? _error;
  VoucherQuote? _quote;

  @override
  void initState() {
    super.initState();
    final code = widget.initialCode;
    if (code != null && code.isNotEmpty) {
      _controller.text = code;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _apply(silent: true);
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant VoucherField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final amountsChanged =
        oldWidget.orderAmountVnd != widget.orderAmountVnd ||
        oldWidget.deliveryFeeVnd != widget.deliveryFeeVnd;
    if (amountsChanged && _quote != null && !_busy) {
      // The quote was for another basket; ask the server again.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _apply(silent: true);
        }
      });
    }
    final seeded = widget.seededCode?.trim() ?? '';
    if (widget.seededCodeVersion != oldWidget.seededCodeVersion &&
        seeded.isNotEmpty) {
      _controller.text = seeded;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _apply();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _apply({bool silent = false}) async {
    final l10n = AppLocalizations.of(context);
    final code = _controller.text.trim();
    if (!silent) {
      FocusScope.of(context).unfocus();
    }
    if (code.isEmpty) {
      setState(() => _error = l10n.voucherErrEmpty);
      return;
    }
    final token = widget.accessToken();
    if (token == null || token.isEmpty) {
      setState(() => _error = l10n.errorSessionExpired);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    VoucherQuote? quote;
    String? failure;
    try {
      quote = await context.read<ValidateVoucher>()(
        accessToken: token,
        code: code,
        service: widget.service,
        orderAmountVnd: widget.orderAmountVnd,
        deliveryFeeVnd: widget.deliveryFeeVnd,
        storeId: widget.storeId,
      );
      if (!quote.valid) {
        // Server reasons are developer copy; the rejection code is localized.
        final code = quote.rejectCode;
        failure = code == null
            ? l10n.voucherErrInvalid
            : apiErrorText(
                l10n,
                ApiException(statusCode: 422, message: '', errorCode: code),
                fallback: l10n.voucherErrInvalid,
              );
        quote = null;
      }
    } on ApiException catch (error) {
      failure = error.statusCode <= 0
          ? l10n.errorNetwork
          : l10n.voucherErrFailed;
    } catch (_) {
      failure = l10n.voucherErrFailed;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
      _error = failure;
      _quote = quote;
    });
    widget.onQuote?.call(quote);
    if (silent) {
      return;
    }
    if (quote != null) {
      DealGoHaptics.success();
    } else {
      DealGoHaptics.error();
    }
  }

  void _clear() {
    setState(() {
      _quote = null;
      _error = null;
      _controller.clear();
    });
    widget.onQuote?.call(null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final quote = _quote;
    if (quote != null) {
      return Semantics(
        liveRegion: true,
        child: Container(
          key: const Key('voucher-applied'),
          padding: const EdgeInsets.all(DealGoSpacing.s12),
          decoration: BoxDecoration(
            color: DealGoColors.greenSurface,
            borderRadius: BorderRadius.circular(DealGoRadius.card),
          ),
          child: Row(
            children: [
              const Icon(DealGoIcons.success, color: DealGoColors.brandGreen),
              const SizedBox(width: DealGoSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.voucherValid(
                        quote.code,
                        widget.formatAmount(quote.discountVnd),
                      ),
                      style: textTheme.titleSmall,
                    ),
                    Text(l10n.voucherPreviewNote, style: textTheme.bodySmall),
                  ],
                ),
              ),
              IconButton(
                key: const Key('voucher-clear'),
                tooltip: l10n.voucherRemove,
                onPressed: _clear,
                icon: const Icon(DealGoIcons.close),
              ),
            ],
          ),
        ),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: DealGoTextField(
            fieldKey: const Key('voucher-field'),
            label: l10n.voucherLabel,
            hint: l10n.voucherHint,
            showLabel: false,
            controller: _controller,
            enabled: !_busy,
            errorText: _error,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.done,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9_-]')),
              LengthLimitingTextInputFormatter(32),
            ],
            onChanged: (_) {
              if (_error != null) {
                setState(() => _error = null);
              }
            },
            onSubmitted: (_) => _apply(),
          ),
        ),
        const SizedBox(width: DealGoSpacing.s8),
        SizedBox(
          height: DealGoDimensions.inputHeight,
          child: FilledButton.tonal(
            key: const Key('voucher-apply'),
            onPressed: _busy ? null : _apply,
            child: _busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.voucherApply),
          ),
        ),
      ],
    );
  }
}
