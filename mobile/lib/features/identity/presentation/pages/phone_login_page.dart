import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_env.dart';
import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/components/dealgo_secondary_button.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/auth_redirect.dart';
import '../../domain/entities/auth_state.dart';
import '../../domain/phone_input.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/phone_auth_cubit.dart';
import '../widgets/auth_widgets.dart';

/// Screen S003: Nhập số điện thoại đăng nhập / đăng ký
/// Matches design/mockups/screens/shared/S003.png
class PhoneLoginPage extends StatefulWidget {
  const PhoneLoginPage({super.key});

  @override
  State<PhoneLoginPage> createState() => _PhoneLoginPageState();
}

class _PhoneLoginPageState extends State<PhoneLoginPage> {
  final TextEditingController _phone = TextEditingController();

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  bool get _phoneReady => e164FromNationalInput(_phone.text) != null;

  void _submit() {
    final phone = e164FromNationalInput(_phone.text);
    if (phone == null) {
      return;
    }
    unawaited(context.read<PhoneAuthCubit>().createPhoneChallenge(phone));
  }

  void _enterMockDemo() {
    if (!useMockData) {
      return;
    }
    unawaited(context.read<PhoneAuthCubit>().enterMockDemo());
  }

  @override
  Widget build(BuildContext context) {
    final restoring = context.watch<AuthCubit>().state is AuthRestoring;
    if (restoring) {
      return const SessionRestoringPage();
    }

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
          path: '/login/otp',
          queryParameters: {
            'challengeId': state.challengeId,
            'phone': state.phone,
          },
        ).toString();
        unawaited(context.push(location));
      },
      builder: (context, phoneAuth) {
        final submitting = isPhoneAuthBusy(phoneAuth);
        final error = phoneAuth is PhoneAuthError &&
                (phoneAuth.phase == PhoneAuthPhase.challenge ||
                    phoneAuth.phase == PhoneAuthPhase.mockDemo)
            ? phoneAuth.error
            : null;

        return Scaffold(
          backgroundColor: DealGoColors.canvas,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top App Bar: Back button and DealGo wordmark
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    DealGoSpacing.s8,
                    DealGoSpacing.s8,
                    DealGoDimensions.pageGutter,
                    0,
                  ),
                  child: Row(
                    children: [
                      AuthBackButton(
                        onPressed: () {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go(AuthRoutes.onboarding);
                          }
                        },
                      ),
                      const Spacer(),
                      const DealGoWordmark(),
                    ],
                  ),
                ),

                // Form Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(DealGoDimensions.pageGutter),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: DealGoSpacing.s8),
                        const _PhoneMark(),
                        const SizedBox(height: DealGoSpacing.s24),
                        Text.rich(
                          TextSpan(
                            style: textTheme.headlineMedium?.copyWith(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              height: 1.25,
                              color: DealGoColors.text,
                            ),
                            children: [
                              TextSpan(
                                text: AppLocalizations.of(context)
                                    .authWelcomePrefix,
                              ),
                              TextSpan(
                                text: AppLocalizations.of(context)
                                    .authWelcomeBrand,
                                style: const TextStyle(
                                  color: DealGoColors.primary,
                                ),
                              ),
                              TextSpan(
                                text: AppLocalizations.of(context)
                                    .authWelcomeSuffix,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: DealGoSpacing.s12),
                        Text(
                          AppLocalizations.of(context).authWelcomeBody,
                          style: textTheme.bodyMedium?.copyWith(
                            color: DealGoColors.textSecondary,
                            height: 1.45,
                            fontSize: 14.5,
                          ),
                        ),
                        const SizedBox(height: DealGoSpacing.s24),
                        ExcludeSemantics(
                          child: Text(
                            AppLocalizations.of(context).authPhoneLabel,
                            style: textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: DealGoColors.text,
                            ),
                          ),
                        ),
                        const SizedBox(height: DealGoSpacing.s8),
                        Semantics(
                          label: AppLocalizations.of(context).authPhoneLabel,
                          textField: true,
                          child: ExcludeSemantics(
                            child: TextField(
                              key: const Key('phone-field'),
                              controller: _phone,
                              enabled: !submitting,
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [
                                AutofillHints.telephoneNumber,
                              ],
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9+\s]'),
                                ),
                                LengthLimitingTextInputFormatter(16),
                              ],
                              onChanged: (_) => setState(() {}),
                              onSubmitted: (_) => _submit(),
                              style: textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: InputDecoration(
                                hintText: AppLocalizations.of(context)
                                    .authPhoneHint,
                                hintStyle: textTheme.bodyLarge?.copyWith(
                                  color: DealGoColors.textSecondary
                                      .withValues(alpha: 0.7),
                                  fontWeight: FontWeight.normal,
                                ),
                                filled: true,
                                fillColor: DealGoColors.card,
                                prefixIcon: const _DialCodePrefix(),
                                prefixIconConstraints: const BoxConstraints(
                                  minWidth: 0,
                                  minHeight: 0,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: DealGoSpacing.s16,
                                  vertical: DealGoSpacing.s16,
                                ),
                                enabledBorder: _fieldBorder(DealGoColors.border),
                                disabledBorder: _fieldBorder(
                                  DealGoColors.border,
                                ),
                                focusedBorder: _fieldBorder(
                                  DealGoColors.primary,
                                  width: 1.6,
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (error != null) ...[
                          const SizedBox(height: DealGoSpacing.s12),
                          AuthErrorText(error: error),
                        ],
                        const SizedBox(height: DealGoSpacing.s16),
                        AuthInfoBanner(
                          message: AppLocalizations.of(context).authOtpInfo,
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom Area: Terms and Action Button
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    DealGoDimensions.pageGutter,
                    DealGoSpacing.s8,
                    DealGoDimensions.pageGutter,
                    DealGoSpacing.s16,
                  ),
                  child: Column(
                    children: [
                      Text.rich(
                        TextSpan(
                          style: textTheme.bodySmall?.copyWith(
                            height: 1.4,
                            fontSize: 12,
                          ),
                          children: [
                            TextSpan(
                              text: AppLocalizations.of(context)
                                  .authTermsPrefix,
                            ),
                            TextSpan(
                              text: AppLocalizations.of(context).authTermsOfUse,
                              style: const TextStyle(
                                color: DealGoColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            TextSpan(
                              text: AppLocalizations.of(context).authTermsAnd,
                            ),
                            TextSpan(
                              text: AppLocalizations.of(context)
                                  .authPrivacyPolicy,
                              style: const TextStyle(
                                color: DealGoColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            TextSpan(
                              text: AppLocalizations.of(context)
                                  .authTermsSuffix,
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: DealGoSpacing.s12),
                      SizedBox(
                        width: double.infinity,
                        child: DealGoPrimaryButton(
                          label: AppLocalizations.of(context).actionContinue,
                          trailingIcon: Icons.arrow_forward,
                          isLoading: submitting,
                          enabled: _phoneReady && !submitting,
                          onPressed: _submit,
                        ),
                      ),
                      if (useMockData) ...[
                        const SizedBox(height: DealGoSpacing.s8),
                        SizedBox(
                          width: double.infinity,
                          child: DealGoSecondaryButton(
                            key: const Key('mock-demo-enter'),
                            label: AppLocalizations.of(context).authMockDemo,
                            enabled: !submitting,
                            onPressed: _enterMockDemo,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

OutlineInputBorder _fieldBorder(Color color, {double width = 1}) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(DealGoRadius.input),
    borderSide: BorderSide(color: color, width: width),
  );
}

class _PhoneMark extends StatelessWidget {
  const _PhoneMark();

  static const _appColors = <Color>[
    Color(0xFF6D28D9),
    Color(0xFF16A34A),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFF0EA5E9),
    Color(0xFF8B5CF6),
  ];

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        color: DealGoColors.subtlePurple,
        borderRadius: BorderRadius.all(Radius.circular(DealGoRadius.card)),
      ),
      child: SizedBox(
        width: 72,
        height: 72,
        child: Center(child: _PhoneGlyph()),
      ),
    );
  }
}

class _PhoneGlyph extends StatelessWidget {
  const _PhoneGlyph();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 48,
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2230),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Wrap(
        spacing: 3,
        runSpacing: 3,
        children: [
          for (final color in _PhoneMark._appColors)
            DecoratedBox(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
              child: const SizedBox(width: 7, height: 7),
            ),
        ],
      ),
    );
  }
}

class _DialCodePrefix extends StatelessWidget {
  const _DialCodePrefix();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: DealGoSpacing.s12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _VietnamFlag(),
          const SizedBox(width: DealGoSpacing.s8),
          Text(
            '+84',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: DealGoSpacing.s12),
          const SizedBox(
            width: 1,
            height: 22,
            child: ColoredBox(color: DealGoColors.border),
          ),
        ],
      ),
    );
  }
}

class _VietnamFlag extends StatelessWidget {
  const _VietnamFlag();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 22,
      height: 16,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Color(0xFFDA251D),
          borderRadius: BorderRadius.all(Radius.circular(2)),
        ),
        child: Icon(Icons.star_rounded, color: Color(0xFFFFE14A), size: 11),
      ),
    );
  }
}
