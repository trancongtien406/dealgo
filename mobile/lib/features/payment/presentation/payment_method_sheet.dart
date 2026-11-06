import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design_system/icons/dealgo_icons.dart';
import '../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../core/motion/dealgo_sheet.dart';
import '../../../core/di/injection.dart';
import '../../identity/domain/entities/auth_state.dart';
import '../../identity/presentation/cubit/auth_cubit.dart';
import '../data/payment_api.dart';
import '../domain/payment_models.dart';
import '../../../l10n/app_localizations.dart';

String? paymentAccessToken(BuildContext context) {
  final auth = context.read<AuthCubit>().state;
  return auth is AuthSignedIn ? auth.tokens.accessToken : null;
}

PaymentApi defaultPaymentApi() => DioPaymentApi(getIt<Dio>());

IconData paymentMethodIcon(String code) => switch (code) {
  'CASH' => DealGoIcons.cash,
  'INTERNATIONAL_CARD' || 'VNPAY_ATM' => DealGoIcons.card,
  _ => DealGoIcons.wallet,
};

/// Bottom sheet with the four DealGo sections. Returns the chosen code, or
/// null when dismissed. Unavailable rows stay visible with their reason.
Future<String?> showPaymentMethodSheet(
  BuildContext context, {
  required List<PaymentMethodOption> options,
  required String selected,
}) {
  return showDealGoSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: DealGoColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(DealGoRadius.sheet),
      ),
    ),
    builder: (context) =>
        PaymentMethodSheet(options: options, selected: selected),
  );
}

class PaymentMethodSheet extends StatefulWidget {
  const PaymentMethodSheet({
    required this.options,
    required this.selected,
    super.key,
  });

  final List<PaymentMethodOption> options;
  final String selected;

  @override
  State<PaymentMethodSheet> createState() => _PaymentMethodSheetState();
}

class _PaymentMethodSheetState extends State<PaymentMethodSheet> {
  late String _selected = widget.selected;

  @override
  Widget build(BuildContext context) {
    final groups = groupPaymentMethods(widget.options);
    // top: false — isScrollControlled sheets keep the status-bar inset, so a
    // plain SafeArea pushed the title down by ~60pt of empty space.
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DealGoDimensions.pageGutter,
                DealGoSpacing.s12,
                DealGoSpacing.s8,
                DealGoSpacing.s8,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context).paymentSheetTitle,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: DealGoColors.text,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: AppLocalizations.of(context).paymentClose,
                    icon: const Icon(DealGoIcons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(
                  DealGoDimensions.pageGutter,
                  0,
                  DealGoDimensions.pageGutter,
                  DealGoSpacing.s16,
                ),
                children: [
                  for (final entry in groups.entries) ...[
                    Padding(
                      padding: const EdgeInsets.only(
                        top: DealGoSpacing.s12,
                        bottom: DealGoSpacing.s8,
                      ),
                      child: Text(
                        paymentGroupTitle(
                          AppLocalizations.of(context),
                          entry.key,
                        ),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: DealGoColors.textSecondary,
                        ),
                      ),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: DealGoColors.card,
                        border: Border.all(color: DealGoColors.border),
                        borderRadius: BorderRadius.circular(DealGoRadius.card),
                      ),
                      child: Column(
                        children: [
                          for (var i = 0; i < entry.value.length; i++) ...[
                            if (i > 0)
                              Divider(height: 1, color: DealGoColors.divider),
                            PaymentMethodRow(
                              option: entry.value[i],
                              selected: entry.value[i].code == _selected,
                              onTap: () {
                                setState(() => _selected = entry.value[i].code);
                                Navigator.of(context).pop(entry.value[i].code);
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PaymentMethodRow extends StatelessWidget {
  const PaymentMethodRow({
    required this.option,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final PaymentMethodOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = option.available;
    final fg = enabled ? DealGoColors.text : DealGoColors.textTertiary;
    final secondary = enabled
        ? paymentOptionSubtitle(AppLocalizations.of(context), option)
        : (option.reason ?? AppLocalizations.of(context).paymentUnavailable);
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      enabled: enabled,
      button: true,
      label: paymentOptionLabel(AppLocalizations.of(context), option),
      child: InkWell(
        key: Key('payment-method-${option.code}'),
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(DealGoRadius.card),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: DealGoDimensions.minTapTarget + 8,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DealGoSpacing.s12,
              vertical: DealGoSpacing.s12,
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: enabled
                        ? DealGoColors.subtlePurple
                        : DealGoColors.divider,
                    borderRadius: BorderRadius.circular(DealGoRadius.input),
                  ),
                  child: Icon(
                    paymentMethodIcon(option.code),
                    color: enabled
                        ? DealGoColors.primary
                        : DealGoColors.textTertiary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: DealGoSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        paymentOptionLabel(
                          AppLocalizations.of(context),
                          option,
                        ),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: fg,
                        ),
                      ),
                      if (secondary != null && secondary.isNotEmpty)
                        Text(
                          secondary,
                          style: TextStyle(
                            fontSize: 12,
                            color: enabled
                                ? DealGoColors.textSecondary
                                : DealGoColors.warning,
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: selected
                      ? DealGoColors.primary
                      : (enabled
                            ? DealGoColors.textSecondary
                            : DealGoColors.border),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Checkout row: shows the current method and opens the picker. Loads the
/// list from the server; on any error it silently stays on CASH.
class PaymentMethodTile extends StatefulWidget {
  const PaymentMethodTile({
    required this.service,
    required this.selected,
    required this.onChanged,
    this.api,
    this.accessToken,
    this.enabled = true,
    super.key,
  });

  final String service;
  final String selected;
  final ValueChanged<PaymentMethodOption> onChanged;
  final PaymentApi? api;
  final String? accessToken;
  final bool enabled;

  @override
  State<PaymentMethodTile> createState() => _PaymentMethodTileState();
}

class _PaymentMethodTileState extends State<PaymentMethodTile>
    with AutomaticKeepAliveClientMixin<PaymentMethodTile> {
  List<PaymentMethodOption> _options = const [PaymentMethodOption.cash];
  var _loading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = widget.accessToken ?? paymentAccessToken(context);
    if (token == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final list = await (widget.api ?? defaultPaymentApi()).listMethods(
        accessToken: token,
        service: widget.service,
      );
      if (!mounted) return;
      setState(() {
        _options = list.isEmpty ? const [PaymentMethodOption.cash] : list;
        _loading = false;
      });
      final effective = effectivePaymentSelection(_options, widget.selected);
      if (effective != widget.selected) {
        widget.onChanged(_find(effective));
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  PaymentMethodOption _find(String code) => _options.firstWhere(
    (o) => o.code == code,
    orElse: () => PaymentMethodOption.cash,
  );

  Future<void> _open() async {
    final code = await showPaymentMethodSheet(
      context,
      options: _options,
      selected: widget.selected,
    );
    if (code != null && code != widget.selected && mounted) {
      widget.onChanged(_find(code));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final current = _find(widget.selected);
    return InkWell(
      key: const Key('payment-method-tile'),
      onTap: widget.enabled && !_loading ? _open : null,
      borderRadius: BorderRadius.circular(DealGoRadius.input),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: DealGoSpacing.s4),
        child: Row(
          children: [
            Icon(
              paymentMethodIcon(current.code),
              color: DealGoColors.brandGreen,
            ),
            const SizedBox(width: DealGoSpacing.s8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    paymentOptionLabel(AppLocalizations.of(context), current),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (paymentOptionSubtitle(
                        AppLocalizations.of(context),
                        current,
                      ) !=
                      null)
                    Text(
                      paymentOptionSubtitle(
                        AppLocalizations.of(context),
                        current,
                      )!,
                      style: TextStyle(
                        fontSize: 12,
                        color: DealGoColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            if (_loading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Text(
                AppLocalizations.of(context).paymentChange,
                style: TextStyle(
                  color: DealGoColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            Icon(DealGoIcons.chevronRight, color: DealGoColors.textTertiary),
          ],
        ),
      ),
    );
  }
}
