import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design_system/components/dealgo_app_header.dart';
import '../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../core/design_system/components/dealgo_text_field.dart';
import '../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../core/l10n/api_error_text.dart';
import '../../../core/network/api_exception.dart';
import '../../../l10n/app_localizations.dart';
import '../../identity/domain/entities/auth_state.dart';
import '../../identity/presentation/cubit/auth_cubit.dart';
import '../../identity/presentation/widgets/auth_scaffold.dart';
import '../domain/account_settings.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  var _busy = false;
  String? _error;
  String? _ok;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    if (_next.text != _confirm.text) {
      setState(() => _error = l10n.changePasswordMismatch);
      return;
    }
    final auth = context.read<AuthCubit>().state;
    if (auth is! AuthSignedIn || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _ok = null;
    });
    try {
      await context.read<AccountSettingsRepository>().changePassword(
        accessToken: auth.tokens.accessToken,
        currentPassword: _current.text,
        newPassword: _next.text,
      );
      if (mounted) {
        setState(() => _ok = l10n.changePasswordDone);
        _current.clear();
        _next.clear();
        _confirm.clear();
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = apiErrorText(l10n, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: DealGoColors.card,
      appBar: DealGoAppHeader(
        title: l10n.changePasswordHeader,
        applySafeArea: true,
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: AuthBackdrop()),
          SafeArea(
            top: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: ListView(
                  padding: const EdgeInsets.all(DealGoDimensions.pageGutter),
                  children: [
                    DealGoTextField(
                      label: l10n.changePasswordCurrent,
                      hint: 'Nhập mật khẩu hiện tại',
                      controller: _current,
                      obscure: true,
                    ),
                    const SizedBox(height: 12),
                    DealGoTextField(
                      label: l10n.changePasswordNew,
                      hint: 'Nhập mật khẩu mới (tối thiểu 6 ký tự)',
                      controller: _next,
                      obscure: true,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    DealGoTextField(
                      label: l10n.changePasswordConfirm,
                      hint: 'Nhập lại mật khẩu mới',
                      controller: _confirm,
                      obscure: true,
                      onChanged: (_) => setState(() {}),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: TextStyle(color: DealGoColors.danger)),
                    ],
                    if (_ok != null) ...[
                      const SizedBox(height: 12),
                      Text(_ok!, style: TextStyle(color: DealGoColors.primary)),
                    ],
                    const SizedBox(height: 20),
                    DealGoPrimaryButton(
                      label: l10n.changePasswordSave,
                      isLoading: _busy,
                      enabled: _current.text.isNotEmpty && _next.text.length >= 6,
                      onPressed: _save,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
