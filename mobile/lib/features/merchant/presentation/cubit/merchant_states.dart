import 'package:flutter/material.dart';

import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/network/request_failure.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../food/domain/entities/food_models.dart';
import '../widgets/merchant_widgets.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/format/short_ref.dart';

class MerchantQueueLoadingView extends StatelessWidget {
  const MerchantQueueLoadingView({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return MerchantPageFrame(
      title: title,
      onBack: () => merchantBack(context),
      body: Center(child: Text(AppLocalizations.of(context).merchantLoadingOrders)),
    );
  }
}

class MerchantIneligibleView extends StatelessWidget {
  const MerchantIneligibleView({
    required this.title,
    required this.onRetry,
    super.key,
  });

  final String title;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return MerchantPageFrame(
      title: title,
      onBack: () => merchantBack(context),
      footer: MerchantPrimaryBar(
        buttonKey: const Key('merchant-retry-queue'),
        label: AppLocalizations.of(context).actionRetry,
        onPressed: onRetry,
      ),
      body: ListView(
        padding: merchantPagePadding,
        children: [
          MerchantHero(
            icon: DealGoIcons.alert,
            iconColor: DealGoColors.danger,
            background: DealGoColors.dangerSurface,
            title: l10n.merchantIneligibleTitle,
            message: l10n.merchantIneligibleMessage,
          ),
          const SizedBox(height: DealGoSpacing.s16),
          MerchantNote(message: l10n.merchantIneligibleNote),
        ],
      ),
    );
  }
}

class MerchantQueueEmptyView extends StatelessWidget {
  const MerchantQueueEmptyView({required this.onCheck, super.key});

  final VoidCallback onCheck;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return MerchantPageFrame(
      title: l10n.merchantQueueTitle,
      onBack: () => merchantBack(context),
      footer: MerchantPrimaryBar(
        buttonKey: const Key('merchant-check-orders'),
        label: l10n.merchantReloadOrders,
        onPressed: onCheck,
      ),
      body: ListView(
        padding: merchantPagePadding,
        children: [
          MerchantHero(
            icon: DealGoIcons.square,
            iconColor: DealGoColors.brandGreen,
            background: DealGoColors.greenSurface,
            title: l10n.merchantNoNewOrders,
            message: l10n.merchantNoNewOrdersBody,
          ),
          const SizedBox(height: DealGoSpacing.s12),
          MerchantNote(message: l10n.merchantNoNewOrdersNote),
        ],
      ),
    );
  }
}

class MerchantQueueErrorView extends StatefulWidget {
  const MerchantQueueErrorView({
    required this.saved,
    required this.syncedAt,
    required this.onRetry,
    this.cause,
    super.key,
  });

  final List<MerchantQueueOrder> saved;
  final DateTime? syncedAt;
  final VoidCallback onRetry;
  final Object? cause;

  @override
  State<MerchantQueueErrorView> createState() => _MerchantQueueErrorViewState();
}

class _MerchantQueueErrorViewState extends State<MerchantQueueErrorView> {
  var _showSaved = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    final kind = requestFailureKind(widget.cause);
    final title = switch (kind) {
      RequestFailureKind.offline => l10n.merchantOrdersLoadFailed,
      RequestFailureKind.permission => l10n.apiErrForbidden,
      RequestFailureKind.error => l10n.stateErrorTitle,
    };
    final message = switch (kind) {
      RequestFailureKind.offline => l10n.merchantOrdersLoadFailedBody,
      RequestFailureKind.permission => l10n.apiErrRoleNotActive,
      RequestFailureKind.error => l10n.stateErrorBody,
    };
    return MerchantPageFrame(
      title: l10n.merchantQueueTitle,
      onBack: () => merchantBack(context),
      footer: MerchantFooter(
        secondaryLabel: l10n.merchantViewSavedOrders,
        primaryLabel: AppLocalizations.of(context).actionRetry,
        primaryKey: const Key('merchant-retry-queue'),
        onSecondary: () => setState(() => _showSaved = true),
        onPrimary: widget.onRetry,
      ),
      body: ListView(
        padding: merchantPagePadding,
        children: [
          MerchantHero(
            icon: DealGoIcons.alert,
            iconColor: DealGoColors.danger,
            background: DealGoColors.dangerSurface,
            title: title,
            message: message,
          ),
          const SizedBox(height: DealGoSpacing.s24),
          MerchantPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.merchantConnection, style: textTheme.titleMedium),
                const SizedBox(height: DealGoSpacing.s12),
                MerchantChip(
                  label: l10n.merchantLoadFailedChip,
                  tone: MerchantChipTone.warning,
                ),
                const SizedBox(height: DealGoSpacing.s16),
                MerchantMoneyRow(
                  label: l10n.merchantLastSynced,
                  value: formatSyncClock(l10n, widget.syncedAt),
                ),
              ],
            ),
          ),
          const SizedBox(height: DealGoSpacing.s12),
          MerchantNote(message: l10n.merchantLoadFailedNote),
          if (_showSaved) ...[
            const SizedBox(height: DealGoSpacing.s16),
            if (widget.saved.isEmpty)
              Text(l10n.merchantNoSavedOrders, style: textTheme.bodyMedium)
            else ...[
              Text(l10n.merchantSavedOrders, style: textTheme.titleMedium),
              const SizedBox(height: DealGoSpacing.s8),
              for (final order in widget.saved) ...[
                MerchantPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.orderRef(shortRef(order.id)),
                        style: textTheme.titleMedium,
                      ),
                      const SizedBox(height: DealGoSpacing.s4),
                      Text(
                        merchantStatusLabel(l10n, order.status),
                        style: textTheme.bodySmall,
                      ),
                      Text(order.dropoff.label, style: textTheme.bodyMedium),
                    ],
                  ),
                ),
                const SizedBox(height: DealGoSpacing.s8),
              ],
            ],
          ],
        ],
      ),
    );
  }
}
