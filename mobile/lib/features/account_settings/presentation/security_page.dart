import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/design_system/components/dealgo_app_header.dart';
import '../../../core/design_system/icons/dealgo_icons.dart';
import '../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../identity/domain/entities/auth_method_policy.dart';
import '../../legal/legal_document_page.dart';
import '../../legal/legal_documents.dart';
import '../../identity/domain/entities/auth_state.dart';
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
                  if (_passkeyEnabled) _PasskeyRow(shellPath: shellPath),
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
                  onTap: () => LegalDocumentPage.open(context, LegalSlug.terms),
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

/// Opens passkey management (list / add / remove). Sign-in with a passkey is
/// on the login screen; here the row only shows what is set up.
class _PasskeyRow extends StatefulWidget {
  const _PasskeyRow({required this.shellPath});

  final String shellPath;

  @override
  State<_PasskeyRow> createState() => _PasskeyRowState();
}

class _PasskeyRowState extends State<_PasskeyRow> {
  int? _count;

  @override
  void initState() {
    super.initState();
    unawaited(_loadCount());
  }

  Future<void> _loadCount() async {
    final auth = context.read<AuthCubit>().state;
    if (auth is! AuthSignedIn) return;
    try {
      final rows = await context.read<AccountSettingsRepository>().passkeys(
        accessToken: auth.tokens.accessToken,
      );
      if (mounted) setState(() => _count = rows.length);
    } catch (_) {
      // The page itself reports load failures; the row just omits the count.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final count = _count;
    return ListTile(
      key: const Key('security-passkey-row'),
      leading: const Icon(DealGoIcons.fingerprint, color: DealGoColors.primary),
      title: Text(l10n.securityPasskey),
      subtitle: count == null ? null : Text(l10n.securityPasskeysCount(count)),
      trailing: const Icon(DealGoIcons.chevronRight),
      onTap: () async {
        await context.push(AccountRoutes.passkeys(widget.shellPath));
        if (mounted) unawaited(_loadCount());
      },
    );
  }
}
