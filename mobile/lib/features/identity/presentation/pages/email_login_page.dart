import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/components/dealgo_haptics.dart';
import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/components/dealgo_segmented_control.dart';
import '../../../../core/design_system/components/dealgo_text_field.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/motion/dealgo_motion.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/auth_redirect.dart';
import '../cubit/phone_auth_cubit.dart';
import '../widgets/auth_scaffold.dart';
import '../../../../core/l10n/api_error_text.dart';

enum _EmailAuthTab { login, register }

enum _EmailField { email, password, confirm }

/// Email sign-in / sign-up (two-step OTP on register and legacy activation).
class EmailLoginPage extends StatefulWidget {
  const EmailLoginPage({super.key});

  @override
  State<EmailLoginPage> createState() => _EmailLoginPageState();
}

class _EmailLoginPageState extends State<EmailLoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _displayNameController = TextEditingController();

  _EmailAuthTab _tab = _EmailAuthTab.login;

  /// First failing field (inline error) — validation stays sequential.
  _EmailField? _fieldError;
  String? _fieldErrorMessage;

  /// Server-side failure shown under the form.
  String? _serverError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  void _selectTab(_EmailAuthTab tab) {
    if (_tab == tab) {
      return;
    }
    DealGoHaptics.selection();
    setState(() {
      _tab = tab;
      _fieldError = null;
      _fieldErrorMessage = null;
      _serverError = null;
    });
  }

  void _setFieldError(_EmailField field, String message) {
    DealGoHaptics.error();
    setState(() {
      _fieldError = field;
      _fieldErrorMessage = message;
      _serverError = null;
    });
  }

  void _clearErrorFor(_EmailField field) {
    if (_fieldError == field || _serverError != null) {
      setState(() {
        if (_fieldError == field) {
          _fieldError = null;
          _fieldErrorMessage = null;
        }
        _serverError = null;
      });
    }
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;
    final displayName = _displayNameController.text.trim();

    if (email.isEmpty) {
      return _setFieldError(_EmailField.email, l10n.emailErrRequired);
    }
    // Mail servers reject accented/non-ASCII addresses (SMTP 555), e.g. "ái@gmail.com".
    if (!email.contains('@') ||
        !email.contains('.') ||
        email.runes.any((r) => r > 0x7e || r <= 0x20)) {
      return _setFieldError(_EmailField.email, l10n.emailErrInvalid);
    }
    if (password.isEmpty) {
      return _setFieldError(_EmailField.password, l10n.passwordErrRequired);
    }
    if (password.length < 6) {
      return _setFieldError(_EmailField.password, l10n.passwordErrTooShort);
    }
    if (_tab == _EmailAuthTab.register) {
      if (confirmPassword.isEmpty) {
        return _setFieldError(_EmailField.confirm, l10n.passwordErrConfirm);
      }
      if (password != confirmPassword) {
        return _setFieldError(_EmailField.confirm, l10n.passwordErrMismatch);
      }
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _fieldError = null;
      _fieldErrorMessage = null;
      _serverError = null;
    });
    final cubit = context.read<PhoneAuthCubit>();
    if (_tab == _EmailAuthTab.login) {
      await cubit.loginWithEmail(email: email, password: password);
    } else {
      await cubit.registerWithEmail(
        email: email,
        password: password,
        displayName: displayName.isEmpty ? null : displayName,
      );
    }
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AuthRoutes.login);
    }
  }

  String _friendlyEmailError(ApiException error) {
    final l10n = AppLocalizations.of(context);
    return switch (error.errorCode) {
      'AUTH_INVALID_CREDENTIALS' => l10n.emailErrWrongCredentials,
      'EMAIL_IN_USE' => l10n.emailErrInUse,
      'AUTH_EMAIL_NOT_VERIFIED' => l10n.emailErrorNotVerified,
      'AUTH_OTP_RATE_LIMITED' => l10n.emailErrorTooManyAttempts,
      'EMAIL_DELIVERY_FAILED' => l10n.emailErrorDeliveryFailed,
      'EMAIL_ADDRESS_REJECTED' => l10n.emailErrInvalid,
      _ => apiErrorText(AppLocalizations.of(context), error),
    };
  }

  bool _isEmailAuthError(PhoneAuthState state) {
    return state is PhoneAuthError &&
        (state.phase == PhoneAuthPhase.emailLogin ||
            state.phase == PhoneAuthPhase.emailRegister);
  }

  void _openEmailOtp(PhoneAuthEmailChallengeReady state) {
    final location = Uri(
      path: AuthRoutes.otp,
      queryParameters: {'challengeId': state.challengeId, 'email': state.email},
    ).toString();
    unawaited(context.push(location));
  }

  void _openForgotPassword() {
    final email = _emailController.text.trim();
    final location = Uri(
      path: AuthRoutes.forgotPassword,
      queryParameters: email.isEmpty ? null : {'email': email},
    ).toString();
    unawaited(context.push(location));
  }

  String? _errorFor(_EmailField field) =>
      _fieldError == field ? _fieldErrorMessage : null;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return BlocConsumer<PhoneAuthCubit, PhoneAuthState>(
      listenWhen: (previous, current) =>
          _isEmailAuthError(current) ||
          (current is PhoneAuthEmailChallengeReady &&
              previous is PhoneAuthEmailSigningIn),
      listener: (context, state) {
        if (state is PhoneAuthEmailChallengeReady) {
          _openEmailOtp(state);
          return;
        }
        if (state is PhoneAuthError) {
          DealGoHaptics.error();
          setState(() => _serverError = _friendlyEmailError(state.error));
          context.read<PhoneAuthCubit>().clearError();
        }
      },
      builder: (context, state) {
        final submitting = state is PhoneAuthEmailSigningIn;
        final isRegister = _tab == _EmailAuthTab.register;
        return AuthScaffold(
          onBack: submitting ? null : _goBack,
          centerLogo: true,
          body: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: DealGoSpacing.s20),
                Semantics(
                  header: true,
                  child: Text(
                    isRegister ? l10n.emailRegisterTitle : l10n.emailLoginTitle,
                    style: textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: DealGoSpacing.s20),
                DealGoSegmentedControl(
                  key: const Key('email-auth-tabs'),
                  value: _tab.name,
                  enabled: !submitting,
                  onChanged: (id) => _selectTab(
                    _EmailAuthTab.values.firstWhere((tab) => tab.name == id),
                  ),
                  items: [
                    DealGoSegmentItem(
                      id: _EmailAuthTab.login.name,
                      label: l10n.emailTabLogin,
                      key: const Key('email-tab-login'),
                    ),
                    DealGoSegmentItem(
                      id: _EmailAuthTab.register.name,
                      label: l10n.emailTabRegister,
                      key: const Key('email-tab-register'),
                    ),
                  ],
                ),
                const SizedBox(height: DealGoSpacing.s20),
                DealGoTextField(
                  fieldKey: const Key('email-field'),
                  label: l10n.authEmailLabel,
                  hint: 'Nhập địa chỉ email của bạn',
                  showLabel: true,
                  controller: _emailController,
                  prefixIcon: DealGoIcons.mail,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  enabled: !submitting,
                  errorText: _errorFor(_EmailField.email),
                  onChanged: (_) => _clearErrorFor(_EmailField.email),
                ),
                const SizedBox(height: DealGoSpacing.s12),
                DealGoTextField(
                  fieldKey: const Key('password-field'),
                  obscureToggleKey: const Key('toggle-password-visibility'),
                  label: l10n.emailFieldPassword,
                  hint: 'Nhập mật khẩu',
                  showLabel: true,
                  controller: _passwordController,
                  prefixIcon: DealGoIcons.lock,
                  obscure: true,
                  autofillHints: [
                    isRegister
                        ? AutofillHints.newPassword
                        : AutofillHints.password,
                  ],
                  textInputAction: isRegister
                      ? TextInputAction.next
                      : TextInputAction.done,
                  onSubmitted: isRegister ? null : (_) => unawaited(_submit()),
                  enabled: !submitting,
                  errorText: _errorFor(_EmailField.password),
                  onChanged: (_) => _clearErrorFor(_EmailField.password),
                ),
                if (!isRegister)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      key: const Key('email-forgot-password-btn'),
                      onPressed: submitting ? null : _openForgotPassword,
                      child: Text(l10n.forgotPasswordLink),
                    ),
                  ),
                AnimatedSize(
                  duration: DealGoMotion.durationFor(
                    context,
                    DealGoMotion.medium,
                  ),
                  curve: DealGoMotion.standard,
                  alignment: Alignment.topCenter,
                  child: isRegister
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: DealGoSpacing.s12),
                            DealGoTextField(
                              fieldKey: const Key('confirm-password-field'),
                              obscureToggleKey: const Key(
                                'toggle-confirm-password-visibility',
                              ),
                              label: l10n.emailFieldConfirmPassword,
                              hint: 'Nhập lại mật khẩu',
                              showLabel: true,
                              controller: _confirmPasswordController,
                              prefixIcon: DealGoIcons.lock,
                              obscure: true,
                              autofillHints: const [AutofillHints.newPassword],
                              textInputAction: TextInputAction.next,
                              enabled: !submitting,
                              errorText: _errorFor(_EmailField.confirm),
                              onChanged: (_) =>
                                  _clearErrorFor(_EmailField.confirm),
                            ),
                            const SizedBox(height: DealGoSpacing.s12),
                            DealGoTextField(
                              fieldKey: const Key('display-name-field'),
                              label: l10n.emailFieldDisplayName,
                              hint: 'Nhập tên hiển thị (tuỳ chọn)',
                              showLabel: true,
                              controller: _displayNameController,
                              prefixIcon: DealGoIcons.user,
                              autofillHints: const [AutofillHints.name],
                              textInputAction: TextInputAction.done,
                              textCapitalization: TextCapitalization.words,
                              onSubmitted: (_) => unawaited(_submit()),
                              enabled: !submitting,
                            ),
                          ],
                        )
                      : const SizedBox(width: double.infinity),
                ),
                if (_serverError != null) ...[
                  const SizedBox(height: DealGoSpacing.s12),
                  AuthNotice(message: _serverError!),
                ],
                const SizedBox(height: DealGoSpacing.s24),
                DealGoPrimaryButton(
                  key: const Key('email-submit-btn'),
                  label: isRegister
                      ? l10n.emailTabRegister
                      : l10n.emailTabLogin,
                  isLoading: submitting,
                  onPressed: () => unawaited(_submit()),
                ),
                const SizedBox(height: DealGoSpacing.s12),
                Center(
                  child: TextButton(
                    key: const Key('back-to-phone-login-btn'),
                    onPressed: submitting ? null : _goBack,
                    child: Text(l10n.authOtherMethods),
                  ),
                ),
                const AuthLegalFooter(),
              ],
            ),
          ),
        );
      },
    );
  }
}
