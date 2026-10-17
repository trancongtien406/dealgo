import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_env.dart';
import '../../../../core/design_system/components/dealgo_logo.dart';
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

/// Screen S003: Welcome & Phone Login
/// Corresponding to Mockup design/mockups/new/S003.png
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
              children: [
                // Top Bar: DealGo Wordmark & Help button
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DealGoDimensions.pageGutter,
                    vertical: DealGoSpacing.s8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const DealGoLogo.wordmark(size: 26),
                      TextButton(
                        onPressed: () {
                          // Opens help center or displays quick modal
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Trung tâm trợ giúp DealGo: 1900 xxxx'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: DealGoColors.primary,
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: const Text('Trợ giúp'),
                      ),
                    ],
                  ),
                ),

                // Main Form Content
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: DealGoDimensions.pageGutter,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Hero Visual (Da Nang scenic graphic)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(DealGoRadius.card),
                          child: Container(
                            constraints: const BoxConstraints(maxHeight: 200),
                            child: Image.asset(
                              'assets/images/hero_dealgo_danang.png',
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) => Container(
                                height: 160,
                                decoration: BoxDecoration(
                                  color: DealGoColors.subtlePurple,
                                  borderRadius: BorderRadius.circular(DealGoRadius.card),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.travel_explore_rounded,
                                    size: 64,
                                    color: DealGoColors.primary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: DealGoSpacing.s16),

                        // Headline
                        Text.rich(
                          const TextSpan(
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: DealGoColors.text,
                              height: 1.25,
                              letterSpacing: -0.5,
                            ),
                            children: [
                              TextSpan(text: 'Chào mừng bạn\nđến với '),
                              TextSpan(
                                text: 'DealGo!',
                                style: TextStyle(color: DealGoColors.primary),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: DealGoSpacing.s8),

                        const Text(
                          'Nhập số điện thoại để tiếp tục đặt xe,\ngọi đồ ăn và mua sắm.',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w400,
                            color: DealGoColors.textSecondary,
                            height: 1.45,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: DealGoSpacing.s20),

                        // Phone label
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Số điện thoại',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: DealGoColors.text,
                            ),
                          ),
                        ),

                        const SizedBox(height: DealGoSpacing.s8),

                        // Phone Input Field with VN Flag & +84
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(DealGoRadius.button),
                            border: Border.all(
                              color: DealGoColors.border,
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Row(
                            children: [
                              const _VietnamFlagBadge(),
                              const SizedBox(width: 8),
                              const Text(
                                '+84',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: DealGoColors.text,
                                ),
                              ),
                              const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 18,
                                color: DealGoColors.textSecondary,
                              ),
                              const SizedBox(width: 10),
                              Container(
                                width: 1,
                                height: 24,
                                color: DealGoColors.border,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  key: const Key('phone-field'),
                                  controller: _phone,
                                  enabled: !submitting,
                                  keyboardType: TextInputType.phone,
                                  textInputAction: TextInputAction.done,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(RegExp(r'[0-9\s]')),
                                    LengthLimitingTextInputFormatter(14),
                                  ],
                                  onChanged: (_) => setState(() {}),
                                  onSubmitted: (_) => _submit(),
                                  style: const TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w600,
                                    color: DealGoColors.text,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Nhập số điện thoại',
                                    hintStyle: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w400,
                                      color: DealGoColors.textSecondary.withValues(alpha: 0.7),
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        if (error != null) ...[
                          const SizedBox(height: DealGoSpacing.s12),
                          AuthErrorText(error: error),
                        ],

                        const SizedBox(height: DealGoSpacing.s12),

                        // Security lock hint
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.lock_outline_rounded,
                              size: 16,
                              color: DealGoColors.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Mã OTP sẽ được gửi để xác minh và bảo vệ tài khoản của bạn.',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  color: DealGoColors.textSecondary.withValues(alpha: 0.85),
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: DealGoSpacing.s20),

                        // Primary Action Button: Tiếp tục
                        DealGoPrimaryButton(
                          label: 'Tiếp tục',
                          trailingIcon: Icons.arrow_forward_rounded,
                          isLoading: submitting,
                          enabled: _phoneReady && !submitting,
                          onPressed: _submit,
                        ),

                        const SizedBox(height: DealGoSpacing.s12),

                        // Alternate login buttons (Email, Passkey)
                        _AlternateAuthButton(
                          icon: Icons.mail_outline_rounded,
                          label: 'Đăng nhập bằng Email',
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Đăng nhập bằng Email sẽ hỗ trợ ở bản tới'),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: DealGoSpacing.s8),

                        _AlternateAuthButton(
                          icon: Icons.key_rounded,
                          label: 'Dùng Passkey',
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Đăng nhập bằng Passkey sẽ hỗ trợ ở bản tới'),
                              ),
                            );
                          },
                        ),

                        if (useMockData) ...[
                          const SizedBox(height: DealGoSpacing.s8),
                          DealGoSecondaryButton(
                            key: const Key('mock-demo-enter'),
                            label: 'Vào nhanh chế độ Demo (Mock)',
                            enabled: !submitting,
                            onPressed: _enterMockDemo,
                          ),
                        ],

                        const SizedBox(height: DealGoSpacing.s16),

                        // Legal Terms Notice
                        Text.rich(
                          const TextSpan(
                            style: TextStyle(
                              fontSize: 11.5,
                              color: DealGoColors.textSecondary,
                              height: 1.45,
                            ),
                            children: [
                              TextSpan(text: 'Bằng việc tiếp tục, bạn đồng ý với '),
                              TextSpan(
                                text: 'Điều khoản',
                                style: TextStyle(
                                  color: DealGoColors.primary,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                              TextSpan(text: '\nvà '),
                              TextSpan(
                                text: 'Chính sách quyền riêng tư',
                                style: TextStyle(
                                  color: DealGoColors.primary,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                              TextSpan(text: '.'),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: DealGoSpacing.s16),
                      ],
                    ),
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

class _VietnamFlagBadge extends StatelessWidget {
  const _VietnamFlagBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: const BoxDecoration(
        color: Color(0xFFDA251D),
        shape: BoxShape.circle,
      ),
      child: const Center(
        child: Icon(Icons.star_rounded, color: Color(0xFFFFE14A), size: 14),
      ),
    );
  }
}

class _AlternateAuthButton extends StatelessWidget {
  const _AlternateAuthButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: DealGoColors.border, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DealGoRadius.button),
          ),
          backgroundColor: Colors.white,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: DealGoColors.primary),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: DealGoColors.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
