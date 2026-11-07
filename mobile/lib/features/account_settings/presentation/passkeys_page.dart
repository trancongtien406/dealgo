import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/design_system/components/dealgo_app_header.dart';
import '../../../core/design_system/components/dealgo_dialog.dart';
import '../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../core/design_system/components/dealgo_refresh.dart';
import '../../../core/design_system/components/dealgo_skeleton.dart';
import '../../../core/design_system/components/dealgo_state_view.dart';
import '../../../core/design_system/icons/dealgo_icons.dart';
import '../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../core/l10n/api_error_text.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/request_failure.dart';
import '../../../l10n/app_localizations.dart';
import '../../identity/domain/entities/auth_state.dart';
import '../../identity/domain/passkey_platform.dart';
import '../../identity/presentation/cubit/auth_cubit.dart';
import '../domain/account_settings.dart';

/// Passkey management: what is bound to the account, add one on this device,
/// remove one. Signing in with a passkey lives on the login screen.
class PasskeysPage extends StatefulWidget {
  const PasskeysPage({super.key});

  @override
  State<PasskeysPage> createState() => _PasskeysPageState();
}

class _PasskeysPageState extends State<PasskeysPage> {
  List<AccountPasskey> _items = const [];
  var _loading = true;
  var _busy = false;
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

  void _say(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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
      final rows = await context.read<AccountSettingsRepository>().passkeys(
        accessToken: token,
      );
      if (!mounted) return;
      setState(() {
        _items = rows;
        _loading = false;
        _loadFailure = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailure = error;
      });
    }
  }

  Future<void> _add() async {
    final l10n = AppLocalizations.of(context);
    final token = _token;
    if (token == null || _busy) return;
    final settings = context.read<AccountSettingsRepository>();
    final platform = context.read<PasskeyPlatform>();
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
      if (!mounted) return;
      _say(l10n.securityPasskeyAdded);
      await _load();
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
        case PasskeyFailureKind.noCredentials:
          _say(l10n.securityPasskeyFailed);
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      _say(_apiMessage(l10n, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _apiMessage(AppLocalizations l10n, ApiException error) {
    return switch (error.errorCode) {
      'WEBAUTHN_NOT_CONFIGURED' => l10n.securityPasskeyUnsupported,
      'AUTH_PASSKEY_EXISTS' => l10n.securityPasskeyExists,
      'FORBIDDEN' => l10n.securityPasskeyNeedsVerifiedLogin,
      'AUTH_PASSKEY_INVALID' => l10n.securityPasskeyFailed,
      'AUTH_PASSKEY_LAST_CREDENTIAL' => l10n.passkeysLastCredential,
      _ => apiErrorText(l10n, error),
    };
  }

  Future<void> _remove(AccountPasskey passkey) async {
    final l10n = AppLocalizations.of(context);
    final token = _token;
    if (token == null || _busy) return;
    final ok = await showDealGoConfirmDialog(
      context: context,
      title: l10n.passkeysRemoveTitle,
      body: l10n.passkeysRemoveBody,
      confirmLabel: l10n.passkeysRemove,
      cancelLabel: l10n.actionCancel,
      confirmTone: DealGoDialogPrimaryTone.danger,
    );
    if (!ok || !mounted) return;
    final settings = context.read<AccountSettingsRepository>();
    setState(() => _busy = true);
    try {
      await settings.deletePasskey(accessToken: token, passkeyId: passkey.id);
      if (!mounted) return;
      _say(l10n.passkeysRemoved);
      await _load();
    } on ApiException catch (error) {
      if (mounted) _say(_apiMessage(l10n, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final fmt = DateFormat('HH:mm, dd/MM/yyyy');
    return Scaffold(
      backgroundColor: DealGoColors.canvas,
      appBar: DealGoAppHeader(title: l10n.passkeysHeader, applySafeArea: true),
      body: SafeArea(
        top: false,
        child: _loading
            ? const DealGoSkeletonList(itemCount: 2)
            : _loadFailure != null && _items.isEmpty
            ? DealGoRefresh(
                onRefresh: _load,
                child: DealGoStateView.failure(
                  context,
                  onRetry: _load,
                  cause: _loadFailure,
                ),
              )
            : Column(
                children: [
                  Expanded(
                    child: DealGoRefresh(
                      onRefresh: _load,
                      child: ListView(
                        key: const Key('passkeys-list'),
                        padding: const EdgeInsets.all(
                          DealGoDimensions.pageGutter,
                        ),
                        children: [
                          Text(l10n.passkeysIntro, style: textTheme.bodyMedium),
                          const SizedBox(height: 16),
                          if (_items.isEmpty)
                            Text(
                              l10n.passkeysEmpty,
                              style: textTheme.bodyMedium,
                            )
                          else
                            for (final p in _items)
                              Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  key: Key('passkey-${p.id}'),
                                  leading: const Icon(
                                    DealGoIcons.fingerprint,
                                    color: DealGoColors.primary,
                                  ),
                                  title: Text(l10n.passkeysItemTitle),
                                  subtitle: Text(
                                    '${l10n.passkeysAddedOn(fmt.format(p.createdAt.toLocal()))}\n'
                                    '${p.backedUp ? l10n.passkeysSynced : l10n.passkeysThisDeviceOnly}',
                                  ),
                                  isThreeLine: true,
                                  trailing: IconButton(
                                    tooltip: l10n.passkeysRemove,
                                    icon: const Icon(
                                      DealGoIcons.trash,
                                      color: DealGoColors.danger,
                                    ),
                                    onPressed: _busy ? null : () => _remove(p),
                                  ),
                                ),
                              ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      DealGoDimensions.pageGutter,
                      DealGoSpacing.s8,
                      DealGoDimensions.pageGutter,
                      DealGoSpacing.s12,
                    ),
                    child: DealGoPrimaryButton(
                      key: const Key('passkeys-add'),
                      label: l10n.passkeysAdd,
                      fullWidth: true,
                      isLoading: _busy,
                      onPressed: _add,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
