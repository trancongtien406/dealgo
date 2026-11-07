import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/design_system/components/dealgo_card.dart';
import '../../../../core/design_system/components/dealgo_chip.dart';
import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/components/dealgo_refresh.dart';
import '../../../../core/design_system/components/dealgo_skeleton.dart';
import '../../../../core/design_system/components/dealgo_state_view.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/realtime/snapshot_realtime.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../food/domain/entities/food_money.dart';
import '../../../identity/domain/entities/auth_state.dart';
import '../../../identity/presentation/cubit/auth_cubit.dart';
import '../../domain/driver_credit.dart';
import '../driver_credit_cubit.dart';
import '../widgets/driver_credit_payment_sheet.dart';
import '../../../driver/presentation/widgets/driver_widgets.dart';

/// Driver prepaid credit (DEC-PROD-093): top up fees, see what is left and what
/// is still owed. The balance itself is only ever moved by the server.
class DriverCreditPage extends StatelessWidget {
  const DriverCreditPage({
    this.repository,
    this.accessToken,
    this.launcher = defaultDriverCreditLauncher,
    this.initialTopUpId,
    this.realtime,
    super.key,
  });

  final DriverCreditRepository? repository;
  final String? accessToken;
  final DriverCreditUrlLauncher launcher;

  /// Set when the PSP redirected back to `dealgo://payment-return?kind=driver-credit`.
  final String? initialTopUpId;
  final SnapshotRealtime? realtime;

  @override
  Widget build(BuildContext context) {
    String? token() {
      final fixed = accessToken;
      if (fixed != null) {
        return fixed;
      }
      final state = context.read<AuthCubit>().state;
      return state is AuthSignedIn ? state.tokens.accessToken : null;
    }

    return BlocProvider(
      create: (_) => DriverCreditCubit(
        repository: repository ?? context.read<DriverCreditRepository>(),
        accessToken: token,
      )..load(),
      child: _DriverCreditView(
        launcher: launcher,
        initialTopUpId: initialTopUpId,
        realtime: realtime,
      ),
    );
  }
}

class _DriverCreditView extends StatefulWidget {
  const _DriverCreditView({
    required this.launcher,
    this.initialTopUpId,
    this.realtime,
  });

  final DriverCreditUrlLauncher launcher;
  final String? initialTopUpId;
  final SnapshotRealtime? realtime;

  @override
  State<_DriverCreditView> createState() => _DriverCreditViewState();
}

class _DriverCreditViewState extends State<_DriverCreditView>
    with WidgetsBindingObserver {
  static const _padding = EdgeInsets.fromLTRB(
    DealGoDimensions.pageGutter,
    DealGoSpacing.s12,
    DealGoDimensions.pageGutter,
    DealGoSpacing.s16,
  );

  StreamSubscription<DriverCreditStatusHint>? _statusSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _listenStatusHints();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final topUpId = widget.initialTopUpId;
      if (!mounted || topUpId == null || topUpId.isEmpty) {
        return;
      }
      _showSheet(topUpId);
    });
  }

  void _listenStatusHints() {
    SnapshotRealtime? realtime = widget.realtime;
    if (realtime == null) {
      try {
        realtime = context.read<SnapshotRealtime>();
      } catch (_) {
        return; // No socket in this tree: the sheet polls and resume refreshes.
      }
    }
    _statusSub = realtime.driverCreditStatuses.listen((hint) {
      if (!mounted) {
        return;
      }
      unawaited(context.read<DriverCreditCubit>().onStatusHint(hint.topUpId));
    });
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(context.read<DriverCreditCubit>().load());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<DriverCreditCubit>().state;
    return DriverPageFrame(
      title: l10n.driverCreditTitle,
      subtitle: l10n.driverCreditSubtitle,
      body: _body(context, state),
    );
  }

  Widget _body(BuildContext context, DriverCreditState state) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<DriverCreditCubit>();
    if (state.status == DriverCreditStatus.failed && state.credit == null) {
      return DealGoRefresh(
        onRefresh: cubit.load,
        child: DealGoStateView.failure(
          context,
          onRetry: cubit.load,
          cause: state.cause,
        ),
      );
    }
    final credit = state.credit;
    if (credit == null) {
      return DealGoSkeletonList(
        padding: _padding,
        thumbSize: 44,
        semanticLabel: l10n.driverCreditLoading,
      );
    }
    return DealGoRefresh(
      onRefresh: cubit.load,
      child: ListView(
        key: const Key('driver-credit-list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: _padding,
        children: [
          _BalanceCard(credit: credit),
          if (state.actionError case final code?) ...[
            const SizedBox(height: DealGoSpacing.s12),
            _ErrorLine(l10n: l10n, code: code),
          ],
          if (credit.blocked) ...[
            const SizedBox(height: DealGoSpacing.s12),
            _Notice(
              icon: Icons.warning_amber_rounded,
              message: l10n.driverCreditBlocked,
              tone: DealGoColors.danger,
            ),
          ],
          const SizedBox(height: DealGoSpacing.s16),
          if (!credit.enabled)
            _Notice(
              icon: Icons.info_outline_rounded,
              message: l10n.driverCreditDisabled,
              tone: DealGoColors.textSecondary,
            )
          else ...[
            _AmountPicker(credit: credit, state: state),
            const SizedBox(height: DealGoSpacing.s12),
            DealGoPrimaryButton(
              key: const Key('driver-credit-top-up'),
              label: state.submitting
                  ? l10n.driverCreditChecking
                  : l10n.driverCreditTopUp,
              enabled: !state.busy && state.pending == null,
              isLoading: state.submitting,
              onPressed: () => _topUp(context),
            ),
          ],
          if (state.pending case final pending?) ...[
            const SizedBox(height: DealGoSpacing.s16),
            _PendingCard(
              pending: pending,
              busy: state.busy,
              refreshing: state.refreshingPending,
              onOpen: () => _showSheet(pending.id),
              onCancel: cubit.cancelPending,
            ),
          ],
          const SizedBox(height: DealGoSpacing.s20),
          Text(
            l10n.driverCreditRecent,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: DealGoSpacing.s8),
          if (credit.recentTopUps.isEmpty)
            DealGoCard(child: Text(l10n.driverCreditEmpty))
          else
            for (final topUp in credit.recentTopUps) ...[
              _TopUpRow(topUp: topUp, onTap: () => _showSheet(topUp.id)),
              const SizedBox(height: DealGoSpacing.s8),
            ],
        ],
      ),
    );
  }

  Future<void> _topUp(BuildContext context) async {
    final cubit = context.read<DriverCreditCubit>();
    final key = 'topup-${DateTime.now().microsecondsSinceEpoch}';
    final created = await cubit.createTopUp(idempotencyKey: key);
    if (!mounted || created == null) {
      return;
    }
    await _showSheet(created.id);
  }

  Future<void> _showSheet(String topUpId) async {
    final cubit = context.read<DriverCreditCubit>();
    await showDriverTopUpSheet(
      context,
      cubit: cubit,
      topUpId: topUpId,
      launcher: widget.launcher,
    );
    if (mounted) {
      await cubit.load();
    }
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.credit});

  final DriverCredit credit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DealGoColors.primary,
        borderRadius: BorderRadius.circular(DealGoRadius.card),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DealGoSpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.driverCreditBalance,
              style: textTheme.bodyMedium?.copyWith(
                color: DealGoColors.card.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: DealGoSpacing.s4),
            Text(
              formatVnd(credit.creditVnd),
              key: const Key('driver-credit-balance'),
              style: textTheme.headlineMedium?.copyWith(
                color: DealGoColors.card,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: DealGoSpacing.s8),
            Text(
              '${l10n.driverCreditOwes}: ${formatVnd(credit.owesVnd)}',
              key: const Key('driver-credit-owes'),
              style: textTheme.bodyMedium?.copyWith(
                color: DealGoColors.card,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AmountPicker extends StatelessWidget {
  const _AmountPicker({required this.credit, required this.state});

  final DriverCredit credit;
  final DriverCreditState state;

  List<int> get _options {
    const quick = [50_000, 100_000, 200_000, 500_000, 1_000_000, 2_000_000];
    final min = credit.minVnd > 0 ? credit.minVnd : 10_000;
    final max = credit.maxVnd > 0 ? credit.maxVnd : min;
    final values = <int>{
      min,
      if (min <= max) ...quick.where((v) => v >= min && v <= max),
    };
    return values.toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<DriverCreditCubit>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.driverCreditAmount,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: DealGoSpacing.s8),
        Wrap(
          spacing: DealGoSpacing.s8,
          runSpacing: DealGoSpacing.s8,
          children: [
            for (final amount in _options)
              DealGoChip(
                key: Key('driver-credit-amount-$amount'),
                label: formatVnd(amount),
                selected: state.amountVnd == amount,
                onTap: () => cubit.selectAmount(amount),
              ),
          ],
        ),
        const SizedBox(height: DealGoSpacing.s4),
        Text(
          l10n.driverCreditAmountRange(
            formatVnd(credit.minVnd),
            formatVnd(credit.maxVnd),
          ),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _PendingCard extends StatelessWidget {
  const _PendingCard({
    required this.pending,
    required this.busy,
    required this.refreshing,
    required this.onOpen,
    required this.onCancel,
  });

  final DriverTopUp pending;
  final bool busy;
  final bool refreshing;
  final VoidCallback onOpen;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final expiresAt = pending.expiresAt;
    final expires = expiresAt == null
        ? null
        : DateFormat.Hm(Localizations.localeOf(context).toLanguageTag())
              .format(expiresAt);
    return DealGoCard(
      key: const Key('driver-credit-pending'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.driverCreditPending, style: textTheme.titleMedium),
          const SizedBox(height: DealGoSpacing.s4),
          Text(
            formatVnd(pending.amountVnd),
            style: textTheme.headlineSmall?.copyWith(
              color: DealGoColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (expires != null) Text(expires, style: textTheme.bodySmall),
          const SizedBox(height: DealGoSpacing.s8),
          if (refreshing)
            Text(l10n.driverCreditChecking, style: textTheme.bodySmall),
          Wrap(
            spacing: DealGoSpacing.s8,
            children: [
              TextButton(
                key: const Key('driver-credit-open-checkout'),
                onPressed: busy ? null : onOpen,
                child: Text(l10n.driverCreditOpenCheckout),
              ),
              TextButton(
                key: const Key('driver-credit-cancel'),
                onPressed: busy ? null : onCancel,
                child: Text(l10n.driverCreditCancelTopUp),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TopUpRow extends StatelessWidget {
  const _TopUpRow({required this.topUp, required this.onTap});

  final DriverTopUp topUp;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final meta = [
      DateFormat('dd/MM · HH:mm', locale).format(topUp.createdAt),
      _statusLabel(l10n, topUp.status),
      if (topUp.status == DriverTopUpStatus.paid && topUp.remainingVnd > 0)
        l10n.driverCreditRemaining(formatVnd(topUp.remainingVnd)),
    ].join(' · ');
    return DealGoCard(
      key: Key('driver-credit-top-up-${topUp.id}'),
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(formatVnd(topUp.amountVnd), style: textTheme.titleMedium),
                Text(meta, style: textTheme.bodySmall),
              ],
            ),
          ),
          Icon(
            topUp.status == DriverTopUpStatus.paid
                ? Icons.check_circle_outline
                : Icons.schedule,
            color: topUp.status == DriverTopUpStatus.paid
                ? DealGoColors.brandGreen
                : DealGoColors.textTertiary,
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.message,
    required this.tone,
  });

  final IconData icon;
  final String message;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: tone),
        const SizedBox(width: DealGoSpacing.s8),
        Expanded(
          child: Text(
            message,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: tone),
          ),
        ),
      ],
    );
  }
}

class _ErrorLine extends StatelessWidget {
  const _ErrorLine({required this.l10n, required this.code});

  final AppLocalizations l10n;
  final String code;

  @override
  Widget build(BuildContext context) {
    final message = switch (code) {
      'DRIVER_TOP_UP_PENDING' => l10n.driverCreditErrorPending,
      'DRIVER_TOP_UP_DAILY_LIMIT' => l10n.driverCreditErrorDailyLimit,
      'DRIVER_CREDIT_LIMIT' => l10n.driverCreditErrorCreditLimit,
      'DRIVER_TOP_UP_AMOUNT_INVALID' => l10n.driverCreditErrorAmount,
      'DRIVER_KYC_REQUIRED' => l10n.driverCreditErrorKyc,
      'DRIVER_TOP_UP_DISABLED' => l10n.driverCreditErrorDisabled,
      'DRIVER_TOP_UP_PROVIDER_NOT_CONFIGURED' ||
      'DRIVER_TOP_UP_PROVIDER_ERROR' => l10n.driverCreditErrorProvider,
      _ => l10n.driverCreditErrorGeneric,
    };
    return _Notice(
      icon: Icons.error_outline,
      message: message,
      tone: DealGoColors.danger,
    );
  }
}

String _statusLabel(AppLocalizations l10n, DriverTopUpStatus status) {
  return switch (status) {
    DriverTopUpStatus.pending => l10n.driverCreditStatusPending,
    DriverTopUpStatus.paid => l10n.driverCreditStatusPaid,
    DriverTopUpStatus.expired => l10n.driverCreditStatusExpired,
    DriverTopUpStatus.cancelled => l10n.driverCreditStatusCancelled,
    DriverTopUpStatus.refundPending => l10n.driverCreditStatusRefundPending,
    DriverTopUpStatus.refunded => l10n.driverCreditStatusRefunded,
    DriverTopUpStatus.failed => l10n.driverCreditStatusFailed,
  };
}
