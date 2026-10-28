import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../motion/dealgo_motion.dart';
import '../../network/api_exception.dart';
import '../../network/request_failure.dart';
import '../icons/dealgo_icons.dart';
import '../tokens/dealgo_tokens.dart';
import 'dealgo_primary_button.dart';
import 'dealgo_secondary_button.dart';

/// Illustration set for empty / error / offline states (`/design` state_*).
enum DealGoStateArt {
  noOrders('state_no_orders'),
  noSearch('state_no_search'),
  noDriver('state_no_driver'),
  offline('state_offline'),
  paymentError('state_payment_error'),
  quoteExpired('state_quote_expired'),
  success('state_success'),
  security('state_security'),
  kycPending('state_kyc_pending'),
  kycRejected('state_kyc_rejected'),
  noNotifications('state_no_notifications'),
  noMessages('state_no_messages'),
  noAddresses('state_no_addresses'),
  noVouchers('state_no_vouchers'),
  serverError('state_server_error'),
  location('state_location');

  const DealGoStateArt(this.file);

  final String file;

  String get asset => 'assets/images/states/$file.webp';
}

/// Centered illustration + title + message + optional actions.
///
/// Use for empty lists, request failures (with retry) and offline. Announced
/// to screen readers as a live region so a state change is not silent.
class DealGoStateView extends StatelessWidget {
  const DealGoStateView({
    required this.art,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
    this.compact = false,
    super.key,
  });

  /// Request failed — generic copy and a retry button.
  factory DealGoStateView.error(
    BuildContext context, {
    required VoidCallback onRetry,
    String? message,
    bool compact = false,
    Key? key,
  }) {
    final l10n = AppLocalizations.of(context);
    return DealGoStateView(
      key: key,
      art: DealGoStateArt.serverError,
      title: l10n.stateErrorTitle,
      message: message ?? l10n.stateErrorBody,
      actionLabel: l10n.actionRetry,
      onAction: onRetry,
      compact: compact,
    );
  }

  /// Session expired or the role is not allowed to see this screen.
  factory DealGoStateView.permission(
    BuildContext context, {
    required VoidCallback onRetry,
    Object? cause,
    bool compact = false,
    Key? key,
  }) {
    final l10n = AppLocalizations.of(context);
    final expired =
        cause is ApiException &&
        (cause.statusCode == 401 || cause.errorCode == 'UNAUTHORIZED');
    return DealGoStateView(
      key: key,
      art: DealGoStateArt.security,
      title: expired ? l10n.errorSessionExpired : l10n.apiErrForbidden,
      message: expired ? l10n.errorUnauthorized : l10n.apiErrRoleNotActive,
      actionLabel: l10n.actionRetry,
      onAction: onRetry,
      compact: compact,
    );
  }

  /// Offline, permission, or a recoverable server error — picked from [cause].
  factory DealGoStateView.failure(
    BuildContext context, {
    required VoidCallback onRetry,
    Object? cause,
    String? message,
    bool compact = false,
    Key? key,
  }) {
    return switch (requestFailureKind(cause)) {
      RequestFailureKind.offline => DealGoStateView.offline(
        context,
        onRetry: onRetry,
        compact: compact,
        key: key,
      ),
      RequestFailureKind.permission => DealGoStateView.permission(
        context,
        onRetry: onRetry,
        cause: cause,
        compact: compact,
        key: key,
      ),
      RequestFailureKind.error => DealGoStateView.error(
        context,
        onRetry: onRetry,
        message: message,
        compact: compact,
        key: key,
      ),
    };
  }

  /// No connectivity — retry once back online.
  factory DealGoStateView.offline(
    BuildContext context, {
    required VoidCallback onRetry,
    bool compact = false,
    Key? key,
  }) {
    final l10n = AppLocalizations.of(context);
    return DealGoStateView(
      key: key,
      art: DealGoStateArt.offline,
      title: l10n.bannerOfflineTitle,
      message: l10n.errorOffline,
      actionLabel: l10n.actionRetry,
      onAction: onRetry,
      compact: compact,
    );
  }

  final DealGoStateArt art;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool compact;

  bool get _hasPrimary => actionLabel != null && onAction != null;
  bool get _hasSecondary => secondaryLabel != null && onSecondary != null;

  Widget _primaryButton() => DealGoPrimaryButton(
    key: const Key('state-view-action'),
    label: actionLabel!,
    onPressed: onAction!,
    leadingIcon:
        art == DealGoStateArt.serverError || art == DealGoStateArt.offline
        ? DealGoIcons.refresh
        : null,
  );

  Widget _secondaryButton() =>
      DealGoSecondaryButton(label: secondaryLabel!, onPressed: onSecondary!);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final artSize = compact ? 120.0 : 168.0;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          art.asset,
          width: artSize,
          height: artSize,
          excludeFromSemantics: true,
          errorBuilder: (context, error, stackTrace) => SizedBox(
            width: artSize,
            height: artSize,
            child: const Icon(
              DealGoIcons.inbox,
              size: 48,
              color: DealGoColors.primary,
            ),
          ),
        ),
        SizedBox(height: compact ? DealGoSpacing.s12 : DealGoSpacing.s20),
        Text(
          title,
          textAlign: TextAlign.center,
          style: compact ? textTheme.titleMedium : textTheme.headlineSmall,
        ),
        if (message != null) ...[
          const SizedBox(height: DealGoSpacing.s8),
          Text(
            message!,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: DealGoColors.textSecondary,
            ),
          ),
        ],
        if (_hasPrimary || _hasSecondary) ...[
          SizedBox(height: compact ? DealGoSpacing.s16 : DealGoSpacing.s24),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 180, maxWidth: 360),
            child: _hasPrimary && _hasSecondary
                // Side by side so two actions never stack into a column.
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(child: _secondaryButton()),
                      const SizedBox(width: DealGoSpacing.s8),
                      Flexible(child: _primaryButton()),
                    ],
                  )
                : _hasPrimary
                ? _primaryButton()
                : _secondaryButton(),
          ),
        ],
      ],
    );

    return Semantics(
      liveRegion: true,
      container: true,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: DealGoSpacing.s32,
            vertical: DealGoSpacing.s24,
          ),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: DealGoMotion.durationFor(context, DealGoMotion.medium),
            curve: DealGoMotion.standard,
            builder: (context, t, child) => Opacity(
              opacity: t,
              child: Transform.translate(
                offset: Offset(0, 12 * (1 - t)),
                child: child,
              ),
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}
