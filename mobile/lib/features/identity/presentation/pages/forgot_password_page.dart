import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/components/dealgo_haptics.dart';
import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/components/dealgo_text_field.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/l10n/api_error_text.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/auth_redirect.dart';
import '../../domain/repositories/identity_repository.dart';
import '../widgets/auth_scaffold.dart';

enum _Step { email, code, done }

/// DEC-PROD-045 forgot password: email → 6-digit code + new password → done.
/// The server answers alike for every address, so the copy never says an account exists.
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key, this.initialEmail});

  final String? initialEmail;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  late final TextEditingController _email = TextEditingController(
    text: widget.initialEmail ?? '',
  );
  final TextEditingController _code = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  _Step _step = _Step.email;
  String? _challengeId;
  bool _busy = false;
  String? _error;
  String? _notice;
  bool _locked = false;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  IdentityRepository get _identity => context.read<IdentityRepository>();

  void _fail(String message) {
    DealGoHaptics.error();
    setState(() {
      _error = message;
      _notice = null;
    });
  }

  String _errorText(Object error) {
    final l10n = AppLocalizations.of(context);
    if (error is ApiException) {
      switch (error.errorCode) {
        case 'AUTH_CODE_INVALID':
          return l10n.otpInvalidShort;
        case 'AUTH_CODE_EXPIRED':
          return l10n.otpExpiredTitle;
        case 'AUTH_CODE_LOCKED':
          return l10n.otpEmailLockedBody;
        case 'AUTH_OTP_RATE_LIMITED':
          return l10n.emailErrorTooManyAttempts;
        case 'AUTH_OTP_RESEND_COOLDOWN':
          return l10n.forgotPasswordErrCooldown;
        case 'AUTH_OTP_RESEND_LIMIT':
          return l10n.forgotPasswordErrResendLimit;
      }
    }
    return apiErrorText(l10n, error);
  }

  Future<void> _sendCode() async {
    final l10n = AppLocalizations.of(context);
    final email = _email.text.trim();
    if (email.isEmpty) {
      return _fail(l10n.emailErrRequired);
    }
    if (!email.contains('@') || !email.contains('.')) {
      return _fail(l10n.emailErrInvalid);
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final challenge = await _identity.requestPasswordReset(email);
      if (!mounted) return;
      setState(() {
        _challengeId = challenge.challengeId;
        _step = _Step.code;
        _locked = false;
        _notice = l10n.forgotPasswordCodeSent(email);
      });
    } catch (error) {
      if (mounted) _fail(_errorText(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    final id = _challengeId;
    if (id == null) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _identity.resendPasswordReset(id);
      if (mounted) setState(() => _notice = l10n.forgotPasswordResent);
    } catch (error) {
      if (mounted) {
        _fail(_errorText(error));
        if (error is ApiException &&
            (error.errorCode == 'AUTH_CODE_LOCKED' ||
                error.errorCode == 'AUTH_OTP_RESEND_LIMIT')) {
          setState(() => _locked = true);
        }
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    final id = _challengeId;
    if (id == null) return;
    final l10n = AppLocalizations.of(context);
    final code = _code.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      return _fail(l10n.forgotPasswordErrCode);
    }
    if (_password.text.isEmpty) {
      return _fail(l10n.passwordErrRequired);
    }
    if (_password.text.length < 8) {
      return _fail(l10n.passwordErrTooShort);
    }
    if (_confirm.text.isEmpty) {
      return _fail(l10n.passwordErrConfirm);
    }
    if (_password.text != _confirm.text) {
      return _fail(l10n.passwordErrMismatch);
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _identity.confirmPasswordReset(
        challengeId: id,
        code: code,
        newPassword: _password.text,
      );
      if (!mounted) return;
      DealGoHaptics.success();
      setState(() {
        _step = _Step.done;
        _notice = null;
      });
    } catch (error) {
      if (mounted) {
        _fail(_errorText(error));
        if (error is ApiException && error.errorCode == 'AUTH_CODE_LOCKED') {
          setState(() => _locked = true);
        }
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _startOver() {
    setState(() {
      _step = _Step.email;
      _challengeId = null;
      _code.clear();
      _password.clear();
      _confirm.clear();
      _error = null;
      _notice = null;
      _locked = false;
    });
  }

  void _backToLogin() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AuthRoutes.emailLogin);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return AuthScaffold(
      onBack: _busy ? null : _backToLogin,
      backKey: const Key('forgot-back-btn'),
      centerLogo: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: DealGoSpacing.s20),
          Semantics(
            header: true,
            child: Text(
              l10n.forgotPasswordTitle,
              style: textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: DealGoSpacing.s8),
          if (_step == _Step.email)
            Text(
              l10n.forgotPasswordIntro,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: DealGoColors.textSecondary,
              ),
            ),
          const SizedBox(height: DealGoSpacing.s20),
          ...switch (_step) {
            _Step.email => _emailStep(l10n),
            _Step.code => _codeStep(l10n),
            _Step.done => _doneStep(l10n),
          },
          if (_notice != null) ...[
            const SizedBox(height: DealGoSpacing.s12),
            AuthNotice(message: _notice!, isError: false),
          ],
          if (_error != null) ...[
            const SizedBox(height: DealGoSpacing.s12),
            AuthNotice(key: const Key('forgot-error'), message: _error!),
          ],
          const SizedBox(height: DealGoSpacing.s20),
        ],
      ),
    );
  }

  List<Widget> _emailStep(AppLocalizations l10n) => [
    DealGoTextField(
      fieldKey: const Key('forgot-email-field'),
      label: l10n.authEmailLabel,
      showLabel: false,
      controller: _email,
      prefixIcon: DealGoIcons.mail,
      keyboardType: TextInputType.emailAddress,
      autofillHints: const [AutofillHints.email],
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => unawaited(_sendCode()),
      enabled: !_busy,
    ),
    const SizedBox(height: DealGoSpacing.s20),
    DealGoPrimaryButton(
      key: const Key('forgot-send-btn'),
      label: l10n.forgotPasswordSendCode,
      isLoading: _busy,
      onPressed: () => unawaited(_sendCode()),
    ),
  ];

  List<Widget> _codeStep(AppLocalizations l10n) => [
    DealGoTextField(
      fieldKey: const Key('forgot-code-field'),
      label: l10n.forgotPasswordCodeLabel,
      controller: _code,
      prefixIcon: DealGoIcons.shield,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(6),
      ],
      autofillHints: const [AutofillHints.oneTimeCode],
      textInputAction: TextInputAction.next,
      enabled: !_busy && !_locked,
    ),
    const SizedBox(height: DealGoSpacing.s12),
    DealGoTextField(
      fieldKey: const Key('forgot-password-field'),
      obscureToggleKey: const Key('forgot-toggle-password'),
      label: l10n.forgotPasswordNewLabel,
      controller: _password,
      prefixIcon: DealGoIcons.lock,
      obscure: true,
      autofillHints: const [AutofillHints.newPassword],
      textInputAction: TextInputAction.next,
      enabled: !_busy && !_locked,
    ),
    const SizedBox(height: DealGoSpacing.s12),
    DealGoTextField(
      fieldKey: const Key('forgot-confirm-field'),
      obscureToggleKey: const Key('forgot-toggle-confirm'),
      label: l10n.forgotPasswordConfirmLabel,
      controller: _confirm,
      prefixIcon: DealGoIcons.lock,
      obscure: true,
      autofillHints: const [AutofillHints.newPassword],
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => unawaited(_submit()),
      enabled: !_busy && !_locked,
    ),
    const SizedBox(height: DealGoSpacing.s20),
    if (_locked)
      DealGoPrimaryButton(
        key: const Key('forgot-start-over-btn'),
        label: l10n.forgotPasswordStartOver,
        onPressed: _startOver,
      )
    else
      DealGoPrimaryButton(
        key: const Key('forgot-submit-btn'),
        label: l10n.forgotPasswordSubmit,
        isLoading: _busy,
        onPressed: () => unawaited(_submit()),
      ),
    const SizedBox(height: DealGoSpacing.s8),
    if (!_locked)
      Center(
        child: TextButton(
          key: const Key('forgot-resend-btn'),
          onPressed: _busy ? null : () => unawaited(_resend()),
          child: Text(l10n.forgotPasswordResend),
        ),
      ),
  ];

  List<Widget> _doneStep(AppLocalizations l10n) => [
    AuthNotice(
      key: const Key('forgot-done'),
      message: l10n.forgotPasswordDone,
      isError: false,
    ),
    const SizedBox(height: DealGoSpacing.s20),
    DealGoPrimaryButton(
      key: const Key('forgot-back-to-login'),
      label: l10n.emailTabLogin,
      onPressed: _backToLogin,
    ),
  ];
}
