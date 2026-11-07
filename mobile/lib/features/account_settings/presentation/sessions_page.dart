import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/design_system/components/dealgo_app_header.dart';
import '../../../core/design_system/components/dealgo_dialog.dart';
import '../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../core/design_system/components/dealgo_refresh.dart';
import '../../../core/design_system/components/dealgo_skeleton.dart';
import '../../../core/design_system/components/dealgo_state_view.dart';
import '../../../core/network/request_failure.dart';
import '../../../core/design_system/icons/dealgo_icons.dart';
import '../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../core/l10n/api_error_text.dart';
import '../../../core/network/api_exception.dart';
import '../../../l10n/app_localizations.dart';
import '../../identity/domain/entities/auth_state.dart';
import '../../identity/presentation/cubit/auth_cubit.dart';
import '../domain/account_settings.dart';
import 'session_device.dart';

class SessionsPage extends StatefulWidget {
  const SessionsPage({super.key});

  @override
  State<SessionsPage> createState() => _SessionsPageState();
}

class _SessionsPageState extends State<SessionsPage> {
  List<AccountSession> _sessions = const [];
  var _loading = true;
  var _busy = false;
  String? _message;
  Object? _loadFailure;

  String? get _token {
    final s = context.read<AuthCubit>().state;
    return s is AuthSignedIn ? s.tokens.accessToken : null;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = _token;
    if (token == null) {
      setState(() {
        _loading = false;
        _loadFailure = sessionExpiredFailure;
      });
      return;
    }
    try {
      final repo = context.read<AccountSettingsRepository>();
      // Name this device first, so the list says which phone is which.
      try {
        await repo.touchCurrentDevice(
          accessToken: token,
          deviceLabel: await currentDeviceLabel(),
        );
      } catch (_) {
        // Best effort: the list still loads with the server-side details.
      }
      final rows = await repo.sessions(accessToken: token);
      if (mounted) {
        setState(() {
          _sessions = rows;
          _loading = false;
          _loadFailure = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadFailure = error;
        });
      }
    }
  }

  Future<void> _revoke(String id) async {
    final token = _token;
    if (token == null || _busy) return;
    final l10n = AppLocalizations.of(context);
    final ok = await showDealGoConfirmDialog(
      context: context,
      title: l10n.sessionsLogoutTitle,
      body: l10n.sessionsLogoutBody,
      confirmLabel: l10n.sessionsLogout,
      cancelLabel: l10n.actionCancel,
      confirmTone: DealGoDialogPrimaryTone.danger,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await context.read<AccountSettingsRepository>().revokeSession(
        accessToken: token,
        sessionId: id,
      );
      if (mounted) {
        setState(() => _message = AppLocalizations.of(context).sessionsRevoked);
        await _load();
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(
          () => _message = apiErrorText(AppLocalizations.of(context), e),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _revokeOthers() async {
    final token = _token;
    if (token == null || _busy) return;
    final l10n = AppLocalizations.of(context);
    final ok = await showDealGoConfirmDialog(
      context: context,
      title: l10n.sessionsLogoutOthersTitle,
      body: l10n.sessionsLogoutBody,
      confirmLabel: l10n.sessionsLogoutOthers,
      cancelLabel: l10n.actionCancel,
      confirmTone: DealGoDialogPrimaryTone.danger,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await context.read<AccountSettingsRepository>().revokeOtherSessions(
        accessToken: token,
      );
      if (mounted) {
        setState(() => _message = AppLocalizations.of(context).sessionsRevoked);
        await _load();
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(
          () => _message = apiErrorText(AppLocalizations.of(context), e),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final current = _sessions.where((s) => s.current).toList();
    final others = _sessions.where((s) => !s.current).toList();
    final fmt = DateFormat('HH:mm, dd/MM/yyyy');
    return Scaffold(
      backgroundColor: DealGoColors.canvas,
      appBar: DealGoAppHeader(title: l10n.sessionsHeader, applySafeArea: true),
      body: SafeArea(
        top: false,
        child: _loading
            ? const DealGoSkeletonList(itemCount: 3)
            : _loadFailure != null && _sessions.isEmpty
            ? DealGoRefresh(
                onRefresh: _load,
                child: DealGoStateView.failure(
                  context,
                  onRetry: _load,
                  cause: _loadFailure,
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: DealGoRefresh(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(
                          DealGoDimensions.pageGutter,
                          DealGoSpacing.s16,
                          DealGoDimensions.pageGutter,
                          DealGoSpacing.s16,
                        ),
                        children: [
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F7EE),
                              borderRadius: BorderRadius.circular(
                                DealGoRadius.card,
                              ),
                            ),
                            child: ListTile(
                              leading: const Icon(
                                DealGoIcons.shield,
                                color: Color(0xFF1B7A3D),
                              ),
                              title: Text(
                                l10n.sessionsWarn,
                                style: textTheme.bodySmall,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            l10n.sessionsCurrent,
                            style: textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          for (final s in current)
                            _SessionCard(
                              session: s,
                              badge: l10n.sessionsThisDevice,
                              lastActive: l10n.sessionsActiveNow,
                              signedIn: l10n.sessionsSignedInAt(
                                fmt.format(s.createdAt.toLocal()),
                              ),
                            ),
                          const SizedBox(height: 20),
                          Text(
                            others.isEmpty
                                ? l10n.sessionsOthers
                                : '${l10n.sessionsOthers} (${others.length})',
                            style: textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          if (others.isEmpty)
                            Text(
                              l10n.sessionsEmptyOthers,
                              style: textTheme.bodyMedium,
                            )
                          else
                            for (final s in others)
                              _SessionCard(
                                session: s,
                                lastActive: l10n.sessionsLastActive(
                                  fmt.format(s.lastSeenAt.toLocal()),
                                ),
                                signedIn: l10n.sessionsSignedInAt(
                                  fmt.format(s.createdAt.toLocal()),
                                ),
                                actionLabel: l10n.sessionsLogout,
                                onAction: () => _revoke(s.id),
                              ),
                          if (_message != null) ...[
                            const SizedBox(height: 12),
                            Text(_message!),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (others.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        DealGoDimensions.pageGutter,
                        DealGoSpacing.s8,
                        DealGoDimensions.pageGutter,
                        DealGoSpacing.s12,
                      ),
                      child: DealGoPrimaryButton(
                        label: l10n.sessionsLogoutOthers,
                        isLoading: _busy,
                        fullWidth: true,
                        onPressed: _revokeOthers,
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.lastActive,
    required this.signedIn,
    this.badge,
    this.actionLabel,
    this.onAction,
  });

  final AccountSession session;
  final String lastActive;
  final String signedIn;
  final String? badge;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final isCurrent = badge != null;
    final location = formatSessionLocation(session.ipAddress);

    return Card(
      key: Key('session-${session.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DealGoRadius.card),
        side: BorderSide(
          color: isCurrent
              ? DealGoColors.primary.withValues(alpha: 0.35)
              : DealGoColors.border,
          width: isCurrent ? 1.5 : 1,
        ),
      ),
      elevation: 0,
      color: DealGoColors.card,
      child: Padding(
        padding: const EdgeInsets.all(DealGoSpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? DealGoColors.primary.withValues(alpha: 0.12)
                        : DealGoColors.canvas,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    sessionIcon(session),
                    color: isCurrent
                        ? DealGoColors.primary
                        : DealGoColors.textSecondary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: DealGoSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sessionTitle(l10n, session),
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (isCurrent)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: const BoxDecoration(
                                color: Color(0xFF1B7A3D),
                                shape: BoxShape.circle,
                              ),
                            ),
                          Flexible(
                            child: Text(
                              lastActive,
                              style: textTheme.bodySmall?.copyWith(
                                color: isCurrent
                                    ? const Color(0xFF1B7A3D)
                                    : DealGoColors.textSecondary,
                                fontWeight: isCurrent ? FontWeight.w600 : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F7EE),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      badge!,
                      style: textTheme.labelSmall?.copyWith(
                        color: const Color(0xFF1B7A3D),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: DealGoSpacing.s8),
              child: Divider(height: 1, color: DealGoColors.border),
            ),
            if (location.isNotEmpty) ...[
              Row(
                children: [
                  Icon(
                    DealGoIcons.pin,
                    size: 14,
                    color: DealGoColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      location,
                      style: textTheme.bodySmall?.copyWith(
                        color: DealGoColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],
            Row(
              children: [
                Icon(
                  DealGoIcons.clock,
                  size: 14,
                  color: DealGoColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    signedIn,
                    style: textTheme.bodySmall?.copyWith(
                      color: DealGoColors.textSecondary,
                    ),
                  ),
                ),
                if (actionLabel != null)
                  TextButton(
                    onPressed: onAction,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: DealGoColors.danger,
                    ),
                    child: Text(
                      actionLabel!,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
