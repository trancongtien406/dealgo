import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../motion/dealgo_motion.dart';
import '../../network/api_exception.dart';
import '../../network/request_failure.dart';
import '../icons/dealgo_icons.dart';
import '../tokens/dealgo_tokens.dart';
import 'dealgo_primary_button.dart';
import 'dealgo_secondary_button.dart';

/// t90u: driver KYC gate opened straight at the vehicle step to add car documents.
const carDocsFixRoute = '/driver/kyc?fix=car-docs';

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

enum _StateArtMood { brand, success, warning, danger, info }

class _StateArtSpec {
  const _StateArtSpec({
    required this.primaryIcon,
    required this.badgeIcon,
    required this.mood,
    this.radarWaves = false,
  });

  final IconData primaryIcon;
  final IconData badgeIcon;
  final _StateArtMood mood;
  final bool radarWaves;
}

/// Signature DealGo layered vector artwork for all 16 [DealGoStateArt] scenarios.
///
/// Adapts seamlessly to Light & Dark mode without baked-in white backgrounds,
/// using a custom-painted orbital backdrop, an elevated center plate, a
/// duotone semantic icon, and a floating corner badge.
class DealGoStateArtwork extends StatelessWidget {
  const DealGoStateArtwork({
    required this.art,
    this.size = 152,
    super.key,
  });

  final DealGoStateArt art;
  final double size;

  static _StateArtSpec _specFor(DealGoStateArt art) {
    return switch (art) {
      DealGoStateArt.noOrders => const _StateArtSpec(
        primaryIcon: DealGoIcons.shoppingBag,
        badgeIcon: DealGoIcons.stars,
        mood: _StateArtMood.brand,
      ),
      DealGoStateArt.noSearch => const _StateArtSpec(
        primaryIcon: DealGoIcons.search,
        badgeIcon: DealGoIcons.help,
        mood: _StateArtMood.brand,
      ),
      DealGoStateArt.noDriver => const _StateArtSpec(
        primaryIcon: DealGoIcons.car,
        badgeIcon: DealGoIcons.myLocation,
        mood: _StateArtMood.warning,
        radarWaves: true,
      ),
      DealGoStateArt.offline => const _StateArtSpec(
        primaryIcon: DealGoIcons.offline,
        badgeIcon: DealGoIcons.refresh,
        mood: _StateArtMood.danger,
        radarWaves: true,
      ),
      DealGoStateArt.paymentError => const _StateArtSpec(
        primaryIcon: DealGoIcons.card,
        badgeIcon: DealGoIcons.alert,
        mood: _StateArtMood.danger,
      ),
      DealGoStateArt.quoteExpired => const _StateArtSpec(
        primaryIcon: DealGoIcons.timer,
        badgeIcon: DealGoIcons.refresh,
        mood: _StateArtMood.warning,
      ),
      DealGoStateArt.success => const _StateArtSpec(
        primaryIcon: DealGoIcons.verified,
        badgeIcon: DealGoIcons.stars,
        mood: _StateArtMood.success,
      ),
      DealGoStateArt.security => const _StateArtSpec(
        primaryIcon: DealGoIcons.shield,
        badgeIcon: DealGoIcons.lock,
        mood: _StateArtMood.warning,
      ),
      DealGoStateArt.kycPending => const _StateArtSpec(
        primaryIcon: DealGoIcons.idCard,
        badgeIcon: DealGoIcons.hourglass,
        mood: _StateArtMood.info,
      ),
      DealGoStateArt.kycRejected => const _StateArtSpec(
        primaryIcon: DealGoIcons.idCard,
        badgeIcon: DealGoIcons.error,
        mood: _StateArtMood.danger,
      ),
      DealGoStateArt.noNotifications => const _StateArtSpec(
        primaryIcon: DealGoIcons.notifications,
        badgeIcon: DealGoIcons.stars,
        mood: _StateArtMood.brand,
      ),
      DealGoStateArt.noMessages => const _StateArtSpec(
        primaryIcon: DealGoIcons.chatBubbles,
        badgeIcon: DealGoIcons.send,
        mood: _StateArtMood.brand,
      ),
      DealGoStateArt.noAddresses => const _StateArtSpec(
        primaryIcon: DealGoIcons.pin,
        badgeIcon: DealGoIcons.add,
        mood: _StateArtMood.brand,
      ),
      DealGoStateArt.noVouchers => const _StateArtSpec(
        primaryIcon: DealGoIcons.voucher,
        badgeIcon: DealGoIcons.gift,
        mood: _StateArtMood.brand,
      ),
      DealGoStateArt.serverError => const _StateArtSpec(
        primaryIcon: DealGoIcons.warning,
        badgeIcon: DealGoIcons.refresh,
        mood: _StateArtMood.danger,
      ),
      DealGoStateArt.location => const _StateArtSpec(
        primaryIcon: DealGoIcons.myLocation,
        badgeIcon: DealGoIcons.navigation,
        mood: _StateArtMood.info,
        radarWaves: true,
      ),
    };
  }

  static ({Color accent, Color softSurface, Color halo}) _colorsFor(
    _StateArtMood mood,
  ) {
    return switch (mood) {
      _StateArtMood.brand => (
        accent: DealGoColors.primary,
        softSurface: DealGoColors.subtlePurple,
        halo: DealGoColors.lavender,
      ),
      _StateArtMood.success => (
        accent: DealGoColors.brandGreen,
        softSurface: DealGoColors.greenSurface,
        halo: DealGoColors.greenSurface,
      ),
      _StateArtMood.warning => (
        accent: DealGoColors.amber,
        softSurface: DealGoColors.amberSurface,
        halo: DealGoColors.warningSurface,
      ),
      _StateArtMood.danger => (
        accent: DealGoColors.danger,
        softSurface: DealGoColors.dangerSurface,
        halo: DealGoColors.dangerSurface,
      ),
      _StateArtMood.info => (
        accent: DealGoColors.info,
        softSurface: DealGoColors.infoSurface,
        halo: DealGoColors.infoSurface,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final spec = _specFor(art);
    final palette = _colorsFor(spec.mood);
    final plateSize = size * 0.56;
    final badgeSize = size * 0.25;
    final primaryIconSize = size * 0.27;
    final badgeIconSize = size * 0.125;

    return ExcludeSemantics(
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size.square(size),
              painter: _DealGoStateBackdropPainter(
                accent: palette.accent,
                softSurface: palette.softSurface,
                halo: palette.halo,
                radarWaves: spec.radarWaves,
              ),
            ),
            // Floating decorative pill Behind plate for depth
            Transform.translate(
              offset: Offset(-size * 0.08, -size * 0.07),
              child: Transform.rotate(
                angle: -0.14,
                child: Container(
                  width: plateSize * 0.92,
                  height: plateSize * 0.92,
                  decoration: BoxDecoration(
                    color: palette.softSurface.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(size * 0.18),
                    border: Border.all(
                      color: palette.accent.withValues(alpha: 0.16),
                    ),
                  ),
                ),
              ),
            ),
            // Main elevated center card plate
            Container(
              width: plateSize,
              height: plateSize,
              decoration: BoxDecoration(
                color: DealGoColors.card,
                borderRadius: BorderRadius.circular(size * 0.19),
                border: Border.all(
                  color: palette.accent.withValues(alpha: 0.22),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: palette.accent.withValues(alpha: 0.14),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: plateSize * 0.64,
                    height: plateSize * 0.64,
                    decoration: BoxDecoration(
                      color: palette.softSurface,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Icon(
                    spec.primaryIcon,
                    size: primaryIconSize,
                    color: palette.accent,
                  ),
                ],
              ),
            ),
            // Floating bottom-right accent badge
            Positioned(
              right: size * 0.15,
              bottom: size * 0.14,
              child: Container(
                width: badgeSize,
                height: badgeSize,
                decoration: BoxDecoration(
                  color: palette.accent,
                  shape: BoxShape.circle,
                  border: Border.all(color: DealGoColors.card, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: palette.accent.withValues(alpha: 0.32),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  spec.badgeIcon,
                  size: badgeIconSize,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DealGoStateBackdropPainter extends CustomPainter {
  const _DealGoStateBackdropPainter({
    required this.accent,
    required this.softSurface,
    required this.halo,
    required this.radarWaves,
  });

  final Color accent;
  final Color softSurface;
  final Color halo;
  final bool radarWaves;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.width / 2;

    // Soft outer glow disc
    final outerPaint = Paint()
      ..color = halo.withValues(alpha: 0.55)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, maxR * 0.88, outerPaint);

    // Inner tonal disc
    final innerPaint = Paint()
      ..color = softSurface.withValues(alpha: 0.75)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, maxR * 0.66, innerPaint);

    // Dashed or concentric orbital ring
    final ringPaint = Paint()
      ..color = accent.withValues(alpha: radarWaves ? 0.22 : 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25;

    if (radarWaves) {
      const dashCount = 24;
      const sweep = (2 * math.pi) / dashCount;
      final rect = Rect.fromCircle(center: center, radius: maxR * 0.78);
      for (var i = 0; i < dashCount; i += 2) {
        canvas.drawArc(rect, i * sweep, sweep * 0.65, false, ringPaint);
      }
    } else {
      canvas.drawCircle(center, maxR * 0.78, ringPaint);
    }

    // Decorative floating dots & sparkles around the orbit
    final dotPaint = Paint()
      ..color = accent.withValues(alpha: 0.28)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(size.width * 0.18, size.height * 0.26),
      size.width * 0.028,
      dotPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.82, size.height * 0.24),
      size.width * 0.022,
      dotPaint..color = accent.withValues(alpha: 0.38),
    );
    canvas.drawCircle(
      Offset(size.width * 0.20, size.height * 0.76),
      size.width * 0.018,
      dotPaint..color = accent.withValues(alpha: 0.22),
    );

    // Four-point sparkle at top-right
    _drawSparkle(
      canvas,
      Offset(size.width * 0.78, size.height * 0.20),
      size.width * 0.045,
      accent.withValues(alpha: 0.45),
    );
  }

  void _drawSparkle(Canvas canvas, Offset c, double r, Color color) {
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _DealGoStateBackdropPainter oldDelegate) {
    return oldDelegate.accent != accent ||
        oldDelegate.softSurface != softSurface ||
        oldDelegate.halo != halo ||
        oldDelegate.radarWaves != radarWaves;
  }
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
    if (isCarDocsRequired(cause)) {
      return DealGoStateView(
        key: key ?? const Key('state-car-docs-required'),
        art: DealGoStateArt.kycPending,
        title: l10n.apiErrCarDocsTitle,
        message: l10n.apiErrCarDocsBody,
        actionLabel: l10n.actionCompleteDocuments,
        onAction: () => GoRouter.of(context).push(carDocsFixRoute),
        secondaryLabel: l10n.actionRetry,
        onSecondary: onRetry,
        compact: compact,
      );
    }
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
    final artSize = compact ? 116.0 : 156.0;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DealGoStateArtwork(art: art, size: artSize),
        SizedBox(height: compact ? DealGoSpacing.s12 : DealGoSpacing.s20),
        Text(
          title,
          textAlign: TextAlign.center,
          style: compact ? textTheme.titleMedium : textTheme.headlineSmall,
        ),
        if (message != null) ...[
          const SizedBox(height: DealGoSpacing.s8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Text(
              message!,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: DealGoColors.textSecondary,
                height: 1.45,
              ),
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

    final animated = Padding(
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
    );

    return Semantics(
      liveRegion: true,
      container: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Already inside a vertical Scrollable (ListView / CustomScrollView):
          // avoid a nested vertical SingleChildScrollView that would steal
          // pull-to-refresh drag gestures on iOS BouncingScrollPhysics.
          if (!constraints.hasBoundedHeight) {
            return Center(child: animated);
          }
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(child: animated),
            ),
          );
        },
      ),
    );
  }
}
