import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/design_system/components/dealgo_app_header.dart';
import '../../../core/l10n/api_error_text.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/design_system/icons/dealgo_icons.dart';
import '../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/config/app_env.dart';
import '../../identity/domain/entities/auth_method_policy.dart';
import '../../identity/domain/entities/auth_state.dart';
import '../../identity/domain/passkey_platform.dart';
import '../../identity/presentation/auth_methods_store.dart';
import '../../identity/presentation/cubit/auth_cubit.dart';
import '../domain/account_settings.dart';
import '../../shell/presentation/account_routes.dart';

class SecurityPage extends StatefulWidget {
  const SecurityPage({super.key, required this.shellPath});

  final String shellPath;

  @override
  State<SecurityPage> createState() => _SecurityPageState();
}

class _SecurityPageState extends State<SecurityPage> {
  /// Passkey enrolment follows the admin auth-method switch (DEC-PROD-052).
  late final AuthMethodsStore _methods = context.read<AuthMethodsStore>();

  /// Shown only once the switch is known to be on: never while loading or
  /// when the lookup failed, so a switched-off method is never advertised.
  bool get _passkeyEnabled => _methods.isEnabled(AuthMethodPolicy.passkey);

  /// The password is the email sign-in credential; it follows that switch.
  bool get _emailEnabled => _methods.isEnabled(AuthMethodPolicy.email);

  @override
  void initState() {
    super.initState();
    _methods.addListener(_onMethods);
    unawaited(_methods.load());
  }

  void _onMethods() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _methods.removeListener(_onMethods);
    super.dispose();
  }

  String get shellPath => widget.shellPath;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = context.watch<AuthCubit>().state;
    final profile = auth is AuthSignedIn ? auth.profile : null;
    final phone = profile?.phone ?? '';
    final email = profile?.email ?? '';
    final verifiedChip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: DealGoColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        l10n.securityVerified,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: DealGoColors.primary),
      ),
    );
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: DealGoColors.card,
      appBar: DealGoAppHeader(title: l10n.securityHeader, applySafeArea: true),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(DealGoDimensions.pageGutter),
          children: [
            Text(
              l10n.securityTitle,
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            _Banner(icon: DealGoIcons.shield, title: l10n.securityProtected),
            const SizedBox(height: 20),
            Text(l10n.securityLoginSection, style: textTheme.titleMedium),
            const SizedBox(height: 8),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _Group(
                children: [
                  if (phone.isNotEmpty)
                    _Row(
                      icon: DealGoIcons.phone,
                      title: l10n.securityPhone,
                      body: phone,
                      trailing: (profile?.phoneVerifiedAt ?? '').isNotEmpty
                          ? verifiedChip
                          : null,
                    ),
                  if (email.isNotEmpty)
                    _Row(
                      icon: DealGoIcons.mail,
                      title: l10n.securityEmail,
                      body: email,
                      trailing: (profile?.emailVerifiedAt ?? '').isNotEmpty
                          ? verifiedChip
                          : null,
                    ),
                  if (_emailEnabled)
                    _Row(
                      icon: DealGoIcons.lock,
                      title: l10n.securityChangePassword,
                      onTap: () =>
                          context.push(AccountRoutes.changePassword(shellPath)),
                    ),
                  if (_passkeyEnabled) const _PasskeyRow(),
                  _Row(
                    icon: DealGoIcons.devices,
                    title: l10n.securitySessions,
                    onTap: () =>
                        context.push(AccountRoutes.sessions(shellPath)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(l10n.securityPrivacySection, style: textTheme.titleMedium),
            const SizedBox(height: 8),
            _Group(
              children: [
                _Row(
                  icon: DealGoIcons.lock,
                  title: l10n.securityPermissions,
                  onTap: () => openAppSettings(),
                ),
                _Row(
                  icon: DealGoIcons.document,
                  title: l10n.securityTerms,
                  onTap: () => launchUrl(
                    Uri.parse('https://$appLinkHost/terms'),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(l10n.securityAccountSection, style: textTheme.titleMedium),
            const SizedBox(height: 8),
            _Group(
              children: [
                _Row(
                  icon: DealGoIcons.deleteAccount,
                  title: l10n.securityDelete,
                  danger: true,
                  onTap: () =>
                      context.push(AccountRoutes.deleteAccount(shellPath)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.title});
  final IconData icon;
  final String title;
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DealGoColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(DealGoRadius.card),
      ),
      child: ListTile(
        leading: Icon(icon, color: DealGoColors.primary),
        title: Text(title),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: DealGoColors.border),
        borderRadius: BorderRadius.circular(DealGoRadius.card),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    this.body = '',
    this.onTap,
    this.trailing,
    this.danger = false,
  });
  final IconData icon;
  final String title;
  final String body;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool danger;
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: danger ? DealGoColors.danger : DealGoColors.primary,
      ),
      title: Text(title),
      subtitle: body.isEmpty ? null : Text(body),
      trailing:
          trailing ??
          (onTap == null ? null : const Icon(DealGoIcons.chevronRight)),
      onTap: onTap,
    );
  }
}

/// S025 passkey enrolment (DEC-PROD-045). Wired to the existing registration endpoints;
/// devices or builds that cannot create passkeys get a calm explanation, never a crash.
class _PasskeyRow extends StatefulWidget {
  const _PasskeyRow();

  @override
  State<_PasskeyRow> createState() => _PasskeyRowState();
}

class _PasskeyRowState extends State<_PasskeyRow> {
  bool _busy = false;

  void _say(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _enroll() async {
    final l10n = AppLocalizations.of(context);
    final auth = context.read<AuthCubit>().state;
    if (auth is! AuthSignedIn || _busy) return;
    final settings = context.read<AccountSettingsRepository>();
    final platform = context.read<PasskeyPlatform>();
    final token = auth.tokens.accessToken;
    setState(() => _busy = true);
    try {
      final options = await settings.passkeyRegistrationOptions(
        accessToken: token,
      );
      final response = await platform.register(options);
      await settings.verifyPasskeyRegistration(
        accessToken: token,
        response: response,
      );
      if (mounted) _say(l10n.securityPasskeyAdded);
    } on PasskeyPlatformException catch (error) {
      if (!mounted) return;
      switch (error.kind) {
        case PasskeyFailureKind.cancelled:
          break;
        case PasskeyFailureKind.unsupported:
          _say(l10n.securityPasskeyUnsupported);
        case PasskeyFailureKind.alreadyRegistered:
          _say(l10n.securityPasskeyExists);
        case PasskeyFailureKind.failed:
          _say(l10n.securityPasskeyFailed);
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      _say(switch (error.errorCode) {
        'WEBAUTHN_NOT_CONFIGURED' => l10n.securityPasskeyUnsupported,
        'AUTH_PASSKEY_EXISTS' => l10n.securityPasskeyExists,
        'FORBIDDEN' => l10n.securityPasskeyNeedsVerifiedLogin,
        'AUTH_PASSKEY_INVALID' => l10n.securityPasskeyFailed,
        _ => apiErrorText(l10n, error),
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      key: const Key('security-passkey-row'),
      leading: const Icon(DealGoIcons.shieldPlain, color: DealGoColors.primary),
      title: Text(l10n.securityPasskey),
      trailing: _busy
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(DealGoIcons.chevronRight),
      onTap: _busy ? null : _enroll,
    );
  }
}
