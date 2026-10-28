import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/components/dealgo_haptics.dart';
import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/auth_redirect.dart';
import '../../domain/entities/auth_state.dart';
import '../../domain/phone_input.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/phone_auth_cubit.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/auth_widgets.dart';

/// S003b — phone number entry; on challenge success pushes the OTP screen.
class PhoneInputPage extends StatefulWidget {
  const PhoneInputPage({super.key});

  @override
  State<PhoneInputPage> createState() => _PhoneInputPageState();
}

class _PhoneInputPageState extends State<PhoneInputPage> {
  final TextEditingController _phone = TextEditingController();
  String? _localValidationError;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  void _submit() {
    final l10n = AppLocalizations.of(context);
    final raw = _phone.text.trim();
    if (raw.isEmpty) {
      DealGoHaptics.error();
      setState(() => _localValidationError = l10n.authPhoneRequired);
      return;
    }
    final phone = e164FromNationalInput(raw);
    if (phone == null) {
      DealGoHaptics.error();
      setState(() => _localValidationError = l10n.authPhoneInvalid);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _localValidationError = null);
    unawaited(context.read<PhoneAuthCubit>().createPhoneChallenge(phone));
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AuthRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final restoring = context.watch<AuthCubit>().state is AuthRestoring;
    if (restoring) {
      return const SessionRestoringPage();
    }
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;

    return BlocConsumer<PhoneAuthCubit, PhoneAuthState>(
      listenWhen: (previous, next) =>
          next is PhoneAuthChallengeReady &&
          previous is PhoneAuthSubmittingChallenge,
      listener: (context, state) {
        if (state is! PhoneAuthChallengeReady) {
          return;
        }
        final location = Uri(
          path: AuthRoutes.otp,
          queryParameters: {
            'challengeId': state.challengeId,
            'phone': state.phone,
          },
        ).toString();
        unawaited(context.push(location));
      },
      builder: (context, phoneAuth) {
        final submitting = isPhoneAuthBusy(phoneAuth);
        final error =
            phoneAuth is PhoneAuthError &&
                phoneAuth.phase == PhoneAuthPhase.challenge
            ? phoneAuth.error
            : null;

        return AuthScaffold(
          onBack: _goBack,
          centerLogo: true,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: DealGoSpacing.s32),
              Semantics(
                header: true,
                child: Text(
                  l10n.authPhoneTitle,
                  style: textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: DealGoSpacing.s24),
              AuthPhoneField(
                controller: _phone,
                enabled: !submitting,
                autofocus: true,
                errorText: _localValidationError,
                onSubmitted: _submit,
                onChanged: (_) {
                  if (_localValidationError != null) {
                    setState(() => _localValidationError = null);
                  }
                },
              ),
              if (error != null) ...[
                const SizedBox(height: DealGoSpacing.s8),
                AuthErrorText(error: error),
              ],
              const SizedBox(height: DealGoSpacing.s20),
              DealGoPrimaryButton(
                key: const Key('phone-submit-btn'),
                label: l10n.actionContinue,
                trailingIcon: DealGoIcons.arrowRight,
                isLoading: submitting,
                onPressed: _submit,
              ),
              const SizedBox(height: DealGoSpacing.s12),
              Center(
                child: TextButton(
                  onPressed: _goBack,
                  child: Text(l10n.authOtherMethods),
                ),
              ),
              const AuthLegalFooter(),
            ],
          ),
        );
      },
    );
  }
}
