import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/design_system/components/dealgo_card.dart';
import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/components/dealgo_secondary_button.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/motion/dealgo_sheet.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../food/domain/entities/food_money.dart';
import '../../domain/driver_credit.dart';
import '../driver_credit_cubit.dart';

typedef DriverCreditUrlLauncher = Future<bool> Function(Uri uri);

Future<bool> defaultDriverCreditLauncher(Uri uri) async {
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

/// Shows the payment QR / detail sheet for one top-up. Closing it never
/// decides the outcome: the PSP callback (or ops reconcile) credits the driver.
Future<void> showDriverTopUpSheet(
  BuildContext context, {
  required DriverCreditCubit cubit,
  required String topUpId,
  required DriverCreditUrlLauncher launcher,
}) {
  return showDealGoSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: _DriverTopUpSheet(topUpId: topUpId, launcher: launcher),
    ),
  );
}

class _DriverTopUpSheet extends StatefulWidget {
  const _DriverTopUpSheet({required this.topUpId, required this.launcher});

  final String topUpId;
  final DriverCreditUrlLauncher launcher;

  @override
  State<_DriverTopUpSheet> createState() => _DriverTopUpSheetState();
}

class _DriverTopUpSheetState extends State<_DriverTopUpSheet> {
  static const _pollInterval = Duration(seconds: 5);

  Timer? _ticker;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final cubit = context.read<DriverCreditCubit>();
      cubit.selectTopUp(widget.topUpId);
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() {});
        }
      });
      _poll = Timer.periodic(_pollInterval, (_) {
        final selected = context.read<DriverCreditCubit>().state.selected;
        if (selected?.isPayable ?? false) {
          unawaited(context.read<DriverCreditCubit>().refreshSelected());
        }
      });
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
      ),
      decoration: BoxDecoration(
        color: DealGoColors.canvas,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(DealGoRadius.sheet),
        ),
      ),
      child: SafeArea(
        top: false,
        child: BlocConsumer<DriverCreditCubit, DriverCreditState>(
          listenWhen: (previous, next) =>
              previous.selected?.status != next.selected?.status,
          listener: (context, state) {
            final status = state.selected?.status;
            if (status != null && status != DriverTopUpStatus.pending) {
              _poll?.cancel();
            }
          },
          builder: (context, state) {
            final topUp = state.selected;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      DealGoDimensions.pageGutter,
                      DealGoSpacing.s8,
                      DealGoDimensions.pageGutter,
                      DealGoSpacing.s16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: DealGoColors.border,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: DealGoSpacing.s16),
                        Text(
                          topUp == null ||
                                  topUp.status == DriverTopUpStatus.pending
                              ? l10n.driverCreditPending
                              : l10n.driverCreditDetailTitle,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: DealGoSpacing.s4),
                        if (topUp == null)
                          const Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: DealGoSpacing.s32,
                            ),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else
                          _content(context, topUp),
                      ],
                    ),
                  ),
                ),
                if (topUp != null) _actions(context, topUp),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _content(BuildContext context, DriverTopUp topUp) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          formatVnd(topUp.amountVnd),
          key: const Key('driver-credit-sheet-amount'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.w800, color: DealGoColors.text),
        ),
        const SizedBox(height: DealGoSpacing.s16),
        switch (topUp.status) {
          DriverTopUpStatus.pending => _pendingBody(context, topUp),
          DriverTopUpStatus.paid => _paidBody(context, topUp),
          DriverTopUpStatus.refundPending ||
          DriverTopUpStatus.refunded => _refundedBody(context, topUp),
          _ => _closedBody(context, topUp),
        },
      ],
    );
  }

  Widget _pendingBody(BuildContext context, DriverTopUp topUp) {
    final l10n = AppLocalizations.of(context);
    final qrCode = topUp.qrCode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (qrCode != null) ...[
          Center(
            child: Container(
              key: const Key('driver-credit-qr'),
              padding: const EdgeInsets.all(DealGoSpacing.s16),
              decoration: BoxDecoration(
                color: DealGoColors.card,
                borderRadius: BorderRadius.circular(DealGoRadius.card),
                border: Border.all(color: DealGoColors.border),
              ),
              child: QrImageView(
                data: qrCode,
                version: QrVersions.auto,
                size: 208,
                backgroundColor: DealGoColors.card,
                eyeStyle: QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: DealGoColors.text,
                ),
                dataModuleStyle: QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: DealGoColors.text,
                ),
              ),
            ),
          ),
          const SizedBox(height: DealGoSpacing.s12),
          Text(
            l10n.driverCreditScanHint,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: DealGoColors.textSecondary),
          ),
        ] else
          _Notice(
            icon: DealGoIcons.card,
            message: l10n.driverCreditOpenCheckout,
          ),
        const SizedBox(height: DealGoSpacing.s16),
        _OrderCodeRow(topUp: topUp),
        if (topUp.expiresAt case final expiresAt?) ...[
          const SizedBox(height: DealGoSpacing.s8),
          _Countdown(expiresAt: expiresAt),
        ],
        const SizedBox(height: DealGoSpacing.s12),
        _DetailRows(topUp: topUp),
      ],
    );
  }

  Widget _paidBody(BuildContext context, DriverTopUp topUp) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          key: const Key('driver-credit-sheet-paid'),
          padding: const EdgeInsets.all(DealGoSpacing.s16),
          decoration: BoxDecoration(
            color: DealGoColors.greenSurface,
            borderRadius: BorderRadius.circular(DealGoRadius.card),
          ),
          child: Column(
            children: [
              const Icon(
                DealGoIcons.check,
                color: DealGoColors.brandGreen,
                size: 36,
              ),
              const SizedBox(height: DealGoSpacing.s8),
              Text(
                l10n.driverCreditPaymentReceived,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: DealGoSpacing.s4),
              Text(
                l10n.driverCreditPaymentReceivedBody(
                  formatVnd(topUp.amountVnd),
                ),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: DealGoColors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: DealGoSpacing.s16),
        _DetailRows(topUp: topUp),
      ],
    );
  }

  Widget _refundedBody(BuildContext context, DriverTopUp topUp) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Notice(
          icon: DealGoIcons.refresh,
          message: AppLocalizations.of(context).driverCreditStatusRefunded,
        ),
        const SizedBox(height: DealGoSpacing.s16),
        _DetailRows(topUp: topUp),
      ],
    );
  }

  Widget _closedBody(BuildContext context, DriverTopUp topUp) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Notice(icon: DealGoIcons.clock, message: l10n.driverCreditLinkExpired),
        const SizedBox(height: DealGoSpacing.s16),
        _DetailRows(topUp: topUp),
      ],
    );
  }

  Widget _actions(BuildContext context, DriverTopUp topUp) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<DriverCreditCubit>();
    final Widget body = switch (topUp.status) {
      DriverTopUpStatus.pending => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DealGoPrimaryButton(
            key: const Key('driver-credit-sheet-open'),
            label: l10n.driverCreditOpenCheckout,
            onPressed: () => _openCheckout(topUp),
          ),
          const SizedBox(height: DealGoSpacing.s8),
          DealGoSecondaryButton(
            key: const Key('driver-credit-sheet-cancel'),
            label: l10n.driverCreditCancelTopUp,
            tone: DealGoSecondaryTone.danger,
            enabled: !cubit.state.cancelling,
            onPressed: () async {
              final navigator = Navigator.of(context);
              await cubit.cancelPending();
              navigator.maybePop();
            },
          ),
          const SizedBox(height: DealGoSpacing.s8),
          Text(
            l10n.driverCreditWaitingBank,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: DealGoColors.textTertiary),
          ),
        ],
      ),
      DriverTopUpStatus.paid ||
      DriverTopUpStatus.refundPending ||
      DriverTopUpStatus.refunded => DealGoPrimaryButton(
        key: const Key('driver-credit-sheet-close'),
        label: l10n.driverCreditClose,
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      _ =>
        cubit.state.credit?.enabled == true && cubit.state.pending == null
            ? DealGoPrimaryButton(
                key: const Key('driver-credit-sheet-new'),
                label: l10n.driverCreditCreateNew,
                enabled: !cubit.state.busy,
                isLoading: cubit.state.submitting,
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  final created = await cubit.createTopUp(
                    idempotencyKey:
                        'topup-${DateTime.now().microsecondsSinceEpoch}',
                  );
                  if (created != null) {
                    navigator.maybePop();
                  }
                },
              )
            : DealGoPrimaryButton(
                label: l10n.driverCreditClose,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(
        DealGoDimensions.pageGutter,
        DealGoSpacing.s12,
        DealGoDimensions.pageGutter,
        DealGoSpacing.s12,
      ),
      decoration: BoxDecoration(
        color: DealGoColors.canvas,
        border: Border(top: BorderSide(color: DealGoColors.border)),
      ),
      child: body,
    );
  }

  Future<void> _openCheckout(DriverTopUp topUp) async {
    final url = topUp.checkoutUrl;
    if (url == null) {
      return;
    }
    await widget.launcher(Uri.parse(url));
  }
}

class _OrderCodeRow extends StatelessWidget {
  const _OrderCodeRow({required this.topUp});

  final DriverTopUp topUp;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final code = topUp.orderCode > 0 ? '${topUp.orderCode}' : topUp.id;
    return DealGoCard(
      elevated: false,
      padding: const EdgeInsets.symmetric(
        horizontal: DealGoSpacing.s12,
        vertical: DealGoSpacing.s8,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.driverCreditOrderCode,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: DealGoColors.textSecondary),
                ),
                Text(
                  code,
                  key: const Key('driver-credit-order-code'),
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          IconButton(
            key: const Key('driver-credit-copy-code'),
            tooltip: l10n.driverCreditCopyCode,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: code));
              if (!context.mounted) {
                return;
              }
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(l10n.driverCreditCopied)));
            },
            icon: const Icon(DealGoIcons.copy, size: 18),
          ),
        ],
      ),
    );
  }
}

class _DetailRows extends StatelessWidget {
  const _DetailRows({required this.topUp});

  final DriverTopUp topUp;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final created = DateFormat(
      'dd/MM/yyyy HH:mm',
      locale,
    ).format(topUp.createdAt);
    final paidAt = topUp.paidAt;
    return DealGoCard(
      elevated: false,
      child: Column(
        children: [
          _DetailLine(
            label: l10n.driverCreditOrderCode,
            value: topUp.orderCode > 0 ? '${topUp.orderCode}' : topUp.id,
          ),
          _DetailLine(
            label: l10n.driverCreditMethod,
            value: topUp.provider.toUpperCase(),
          ),
          _DetailLine(label: l10n.driverCreditCreatedAt, value: created),
          if (paidAt != null)
            _DetailLine(
              label: l10n.driverCreditPaidAt,
              value: DateFormat('dd/MM/yyyy HH:mm', locale).format(paidAt),
            ),
          if (topUp.consumedVnd > 0)
            _DetailLine(
              label: l10n.driverCreditAppliedFees,
              value: formatVnd(topUp.consumedVnd),
            ),
          if (topUp.refundedVnd > 0)
            _DetailLine(
              label: l10n.driverCreditRefundedAmount,
              value: formatVnd(topUp.refundedVnd),
            ),
          if (topUp.remainingVnd > 0)
            _DetailLine(
              label: l10n.driverCreditBalance,
              value: formatVnd(topUp.remainingVnd),
              strong: true,
            ),
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.label,
    required this.value,
    this.strong = false,
  });

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium
        ?.copyWith(fontWeight: strong ? FontWeight.w700 : FontWeight.w500);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DealGoSpacing.s4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: style?.copyWith(color: DealGoColors.textSecondary),
            ),
          ),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class _Countdown extends StatelessWidget {
  const _Countdown({required this.expiresAt});

  final DateTime expiresAt;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final left = expiresAt.difference(DateTime.now());
    if (left.isNegative) {
      return _Notice(
        icon: DealGoIcons.clock,
        message: l10n.driverCreditLinkExpired,
      );
    }
    final minutes = left.inMinutes.toString().padLeft(2, '0');
    final seconds = (left.inSeconds % 60).toString().padLeft(2, '0');
    return Text(
      l10n.driverCreditExpiresIn('$minutes:$seconds'),
      key: const Key('driver-credit-countdown'),
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodySmall
          ?.copyWith(color: DealGoColors.warning, fontWeight: FontWeight.w600),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: DealGoColors.textSecondary),
        const SizedBox(width: DealGoSpacing.s8),
        Expanded(
          child: Text(
            message,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: DealGoColors.textSecondary),
          ),
        ),
      ],
    );
  }
}
