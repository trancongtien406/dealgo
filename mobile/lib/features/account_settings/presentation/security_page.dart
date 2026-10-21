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
import '../../identity/domain/entities/auth_state.dart';
import '../../identity/domain/passkey_platform.dart';
import '../../identity/presentation/cubit/auth_cubit.dart';
import '../domain/account_settings.dart';
import '../../shell/presentation/account_routes.dart';

class SecurityPage extends StatelessWidget {
  const SecurityPage({super.key, required this.shellPath});

  final String shellPath;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = context.watch<AuthCubit>().state;
    final phone = auth is AuthSignedIn ? (auth.profile.phone ?? '') : '';
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
            const SizedBox(height: 8),
            Text(l10n.securitySubtitle, style: textTheme.bodyMedium),
            const SizedBox(height: 16),
            _Banner(
              icon: DealGoIcons.shield,
              title: l10n.securityProtected,
              body: l10n.securityProtectedBody,
            ),
            const SizedBox(height: 20),
            Text(l10n.securityLoginSection, style: textTheme.titleMedium),
            const SizedBox(height: 8),
            _Group(
              children: [
                _Row(
                  icon: DealGoIcons.phone,
                  title: l10n.securityPhone,
                  body: phone.isEmpty ? '—' : phone,
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: DealGoColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      l10n.securityVerified,
                      style: textTheme.labelSmall?.copyWith(
                        color: DealGoColors.primary,
                      ),
                    ),
                  ),
                ),
                _Row(
                  icon: DealGoIcons.lock,
                  title: l10n.securityChangePassword,
                  body: l10n.securityChangePasswordBody,
                  onTap: () =>
                      context.push(AccountRoutes.changePassword(shellPath)),
                ),
                _PasskeyRow(hasPhone: phone.isNotEmpty),
                _Row(
                  icon: DealGoIcons.devices,
                  title: l10n.securitySessions,
                  body: l10n.securitySessionsBody,
                  onTap: () => context.push(AccountRoutes.sessions(shellPath)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(l10n.securityPrivacySection, style: textTheme.titleMedium),
            const SizedBox(height: 8),
            _Group(
              children: [
                _Row(
                  icon: DealGoIcons.lock,
                  title: l10n.securityPermissions,
                  body: l10n.securityPermissionsBody,
                  onTap: () => openAppSettings(),
                ),
                _Row(
                  icon: DealGoIcons.document,
                  title: l10n.securityTerms,
                  body: l10n.securityTermsBody,
                  onTap: () => launchUrl(
                    Uri.parse('https://dealgo.vn/terms'),
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
                  body: l10n.securityDeleteBody,
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
  const _Banner({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;
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
        subtitle: Text(body),
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
    required this.body,
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
      subtitle: Text(body),
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
  const _PasskeyRow({required this.hasPhone});

  final bool hasPhone;

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
    if (!widget.hasPhone) {
      _say(l10n.securityPasskeyNeedsPhone);
      return;
    }
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
        'AUTH_METHOD_DISABLED' => l10n.securityPasskeyDisabled,
        'WEBAUTHN_NOT_CONFIGURED' => l10n.securityPasskeyUnsupported,
        'AUTH_PASSKEY_EXISTS' => l10n.securityPasskeyExists,
        'FORBIDDEN' => l10n.securityPasskeyNeedsPhone,
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
      subtitle: Text(l10n.securityPasskeyBody),
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
