import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/design_system/components/dealgo_app_header.dart';
import '../../../core/design_system/components/dealgo_primary_button.dart';
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
      final rows = await context.read<AccountSettingsRepository>().sessions(
        accessToken: token,
      );
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
      backgroundColor: DealGoColors.card,
      appBar: DealGoAppHeader(title: l10n.sessionsHeader, applySafeArea: true),
      body: SafeArea(
        top: false,
        child: _loading
            ? const DealGoSkeletonList(itemCount: 3)
            : _loadFailure != null && _sessions.isEmpty
            ? DealGoStateView.failure(
                context,
                onRetry: _load,
                cause: _loadFailure,
                compact: true,
              )
            : Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(
                        DealGoDimensions.pageGutter,
                      ),
                      children: [
                        Text(
                          l10n.sessionsTitle,
                          style: textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.sessionsSubtitle,
                          style: textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 12),
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
                            when: fmt.format(s.lastSeenAt.toLocal()),
                          ),
                        const SizedBox(height: 20),
                        Text(l10n.sessionsOthers, style: textTheme.titleMedium),
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
                              when: fmt.format(s.lastSeenAt.toLocal()),
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
                  if (others.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(
                        DealGoDimensions.pageGutter,
                      ),
                      child: DealGoPrimaryButton(
                        label: l10n.sessionsLogoutOthers,
                        isLoading: _busy,
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
    required this.when,
    this.badge,
    this.actionLabel,
    this.onAction,
  });

  final AccountSession session;
  final String when;
  final String? badge;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(DealGoIcons.devices, color: DealGoColors.primary),
        title: Text(session.deviceLabel ?? 'DealGo'),
        subtitle: Text(when, style: textTheme.bodySmall),
        trailing: badge != null
            ? Text(
                badge!,
                style: textTheme.labelSmall?.copyWith(
                  color: DealGoColors.primary,
                ),
              )
            : (actionLabel == null
                  ? null
                  : TextButton(onPressed: onAction, child: Text(actionLabel!))),
      ),
    );
  }
}
