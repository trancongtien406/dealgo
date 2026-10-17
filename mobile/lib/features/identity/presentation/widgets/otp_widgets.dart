import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/design_system/components/dealgo_card.dart';
import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/components/dealgo_secondary_button.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/phone_input.dart';
import 'auth_widgets.dart';

const otpCodeLength = 6;

bool isOtpCodeFailure(ApiException? error) {
  if (error == null) {
    return false;
  }
  return error.errorCode == 'AUTH_CODE_INVALID' ||
      error.errorCode == 'AUTH_CODE_EXPIRED' ||
      error.errorCode == 'AUTH_CODE_LOCKED';
}

String _waitLabel(Duration duration) {
  final total = duration.inSeconds;
  final minutes = (total ~/ 60).toString().padLeft(2, '0');
  final seconds = (total % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

String _maskedPhone(String e164) {
  if (!e164.startsWith('+84') || e164.length < 6) {
    return e164;
  }
  final national = '0${e164.substring(3)}';
  if (national.length < 5) {
    return national;
  }
  final head = national.substring(0, 2);
  final tail = national.substring(national.length - 3);
  return '$head•• •••$tail';
}

class _OtpHeader extends StatelessWidget {
  const _OtpHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DealGoDimensions.pageGutter,
        vertical: DealGoSpacing.s8,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              AuthBackButton(onPressed: onBack),
              const SizedBox(width: DealGoSpacing.s8),
              const Text.rich(
                TextSpan(
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                  children: [
                    TextSpan(
                      text: 'Deal',
                      style: TextStyle(color: DealGoColors.primary),
                    ),
                    TextSpan(
                      text: 'Go',
                      style: TextStyle(color: DealGoColors.brandGreen),
                    ),
                  ],
                ),
              ),
            ],
          ),
          TextButton(
            onPressed: onBack,
            style: TextButton.styleFrom(
              foregroundColor: DealGoColors.primary,
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: const Text('Đổi số'),
          ),
        ],
      ),
    );
  }
}

class OtpEntryPane extends StatelessWidget {
  const OtpEntryPane({
    required this.code,
    required this.phone,
    required this.error,
    required this.submitting,
    required this.resending,
    required this.canConfirm,
    required this.remaining,
    required this.onBack,
    required this.onChanged,
    required this.onDigit,
    required this.onBackspace,
    required this.onResend,
    required this.onConfirm,
    super.key,
  });

  final TextEditingController code;
  final String phone;
  final ApiException? error;
  final bool submitting;
  final bool resending;
  final bool canConfirm;
  final Duration remaining;
  final VoidCallback onBack;
  final VoidCallback onChanged;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onResend;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final displayPhone = formatDisplayPhone(phone);
    final waiting = remaining > Duration.zero;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _OtpHeader(onBack: onBack),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              DealGoDimensions.pageGutter,
              DealGoSpacing.s16,
              DealGoDimensions.pageGutter,
              DealGoSpacing.s8,
            ),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(DealGoRadius.card),
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 160),
                    child: Image.asset(
                      'assets/images/hero_otp_shield.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          const _LockMark(),
                    ),
                  ),
                ),
                const SizedBox(height: DealGoSpacing.s16),
                Text(
                  AppLocalizations.of(context).otpHeading,
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: DealGoSpacing.s8),
                Text.rich(
                  TextSpan(
                    style: textTheme.bodyMedium?.copyWith(
                      color: DealGoColors.textSecondary,
                    ),
                    children: [
                      TextSpan(
                        text: AppLocalizations.of(context).otpBodyPrefix,
                      ),
                      TextSpan(
                        text: displayPhone,
                        style: const TextStyle(
                          color: DealGoColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: DealGoSpacing.s24),
                _OtpBoxes(controller: code, onChanged: onChanged),
                if (error != null) ...[
                  const SizedBox(height: DealGoSpacing.s12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: AuthErrorText(error: error!),
                  ),
                ],
                const SizedBox(height: DealGoSpacing.s8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context).otpNotReceived,
                        style: textTheme.bodySmall,
                      ),
                    ),
                    TextButton(
                      onPressed: submitting || resending ? null : onResend,
                      style: TextButton.styleFrom(
                        foregroundColor: waiting
                            ? DealGoColors.brandGreen
                            : DealGoColors.primary,
                        minimumSize: const Size(
                          DealGoDimensions.minTapTarget,
                          DealGoDimensions.minTapTarget,
                        ),
                      ),
                      child: Text(
                        resending
                            ? AppLocalizations.of(context).otpSending
                            : waiting
                            ? AppLocalizations.of(context).otpResendAfter(
                                _waitLabel(remaining),
                              )
                            : AppLocalizations.of(context).actionResend,
                      ),
                    ),
                  ],
                ),
                AuthInfoBanner(
                  title: AppLocalizations.of(context).otpProtectTitle,
                  message: AppLocalizations.of(context).otpProtectBody,
                ),
                const SizedBox(height: DealGoSpacing.s16),
                DealGoCard(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.smartphone_outlined,
                        color: DealGoColors.primary,
                      ),
                      const SizedBox(width: DealGoSpacing.s12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppLocalizations.of(context).authPhoneLabel,
                              style: textTheme.bodySmall,
                            ),
                            const SizedBox(height: DealGoSpacing.s4),
                            Text(displayPhone, style: textTheme.titleMedium),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: onBack,
                        style: TextButton.styleFrom(
                          foregroundColor: DealGoColors.primary,
                          minimumSize: const Size(
                            DealGoDimensions.minTapTarget,
                            DealGoDimensions.minTapTarget,
                          ),
                        ),
                        child: Text(AppLocalizations.of(context).actionChange),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: DealGoSpacing.s16),
                _Keypad(
                  enabled: !submitting,
                  onDigit: onDigit,
                  onBackspace: onBackspace,
                  onSubmit: onConfirm,
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
            DealGoSpacing.s16,
          ),
          child: DealGoPrimaryButton(
            label: AppLocalizations.of(context).actionVerifyContinue,
            trailingIcon: Icons.arrow_forward,
            isLoading: submitting,
            enabled: canConfirm,
            onPressed: onConfirm,
          ),
        ),
      ],
    );
  }
}

class OtpInvalidPane extends StatelessWidget {
  const OtpInvalidPane({
    required this.code,
    required this.error,
    required this.onBack,
    required this.onChangePhone,
    required this.onRetry,
    super.key,
  });

  final String code;
  final ApiException? error;
  final VoidCallback onBack;
  final VoidCallback onChangePhone;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    final locked = error?.errorCode == 'AUTH_CODE_LOCKED';
    final expired = error?.errorCode == 'AUTH_CODE_EXPIRED';
    final title = expired ? l10n.otpExpiredTitle : l10n.otpInvalidTitle;
    final detail = locked ? l10n.otpLockedBody : l10n.otpInvalidBody;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _OtpHeader(onBack: onBack),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(DealGoDimensions.pageGutter),
            child: Column(
              children: [
                const _StatusMark(
                  icon: Icons.close_rounded,
                  color: DealGoColors.danger,
                  background: DealGoColors.dangerSurface,
                ),
                const SizedBox(height: DealGoSpacing.s20),
                Text(
                  title,
                  style: textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: DealGoSpacing.s8),
                Text(
                  detail,
                  style: textTheme.bodyMedium?.copyWith(
                    color: DealGoColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: DealGoSpacing.s20),
                DealGoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.otpHeading,
                        style: textTheme.labelLarge?.copyWith(fontSize: 14),
                      ),
                      const SizedBox(height: DealGoSpacing.s12),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: DealGoColors.dangerSurface,
                          borderRadius: BorderRadius.circular(
                            DealGoRadius.input,
                          ),
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: DealGoSpacing.s16,
                            ),
                            child: Text(
                              _spacedCode(code),
                              textAlign: TextAlign.center,
                              style: textTheme.titleLarge?.copyWith(
                                color: DealGoColors.danger,
                                letterSpacing: 4,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: DealGoSpacing.s8),
                      Text(
                        l10n.otpInvalidShort,
                        key: const Key('auth-error'),
                        style: textTheme.bodyMedium?.copyWith(
                          color: DealGoColors.danger,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: DealGoSpacing.s16),
                _NoticeBanner(message: l10n.otpPrivacyNote),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            DealGoDimensions.pageGutter,
            DealGoSpacing.s8,
            DealGoDimensions.pageGutter,
            DealGoSpacing.s16,
          ),
          child: Row(
            children: [
              Expanded(
                child: DealGoSecondaryButton(
                  label: l10n.actionChangePhone,
                  onPressed: onChangePhone,
                ),
              ),
              const SizedBox(width: DealGoSpacing.s12),
              Expanded(
                child: DealGoPrimaryButton(
                  label: AppLocalizations.of(context).actionRetry,
                  onPressed: onRetry,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _spacedCode(String code) {
  if (code.isEmpty) {
    return '______';
  }
  return code.split('').join(' ');
}

class OtpCooldownPane extends StatelessWidget {
  const OtpCooldownPane({
    required this.phone,
    required this.remaining,
    required this.onBack,
    required this.onLeave,
    required this.onContinue,
    super.key,
  });

  final String phone;
  final Duration remaining;
  final VoidCallback onBack;
  final VoidCallback onLeave;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _OtpHeader(onBack: onBack),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(DealGoDimensions.pageGutter),
            child: Column(
              children: [
                const _StatusMark(
                  icon: Icons.pie_chart_outline,
                  color: DealGoColors.amber,
                  background: DealGoColors.amberSurface,
                ),
                const SizedBox(height: DealGoSpacing.s20),
                Text(
                  l10n.otpCannotResendTitle,
                  style: textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: DealGoSpacing.s8),
                Text(
                  l10n.otpCannotResendBody,
                  style: textTheme.bodyMedium?.copyWith(
                    color: DealGoColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: DealGoSpacing.s20),
                DealGoCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.otpResendLabel,
                              style: textTheme.labelLarge?.copyWith(
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: DealGoSpacing.s12),
                            Text(
                              l10n.otpResendCooldown,
                              style: textTheme.bodySmall,
                            ),
                            const SizedBox(height: DealGoSpacing.s8),
                            Text(
                              l10n.authPhoneLabel,
                              style: textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const SizedBox(height: DealGoSpacing.s32),
                          Text(
                            _waitLabel(remaining),
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: DealGoSpacing.s8),
                          Text(
                            _maskedPhone(phone),
                            style: textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: DealGoSpacing.s16),
                _NoticeBanner(message: l10n.otpServerGateHint),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            DealGoDimensions.pageGutter,
            DealGoSpacing.s8,
            DealGoDimensions.pageGutter,
            DealGoSpacing.s16,
          ),
          child: Row(
            children: [
              Expanded(
                child: DealGoSecondaryButton(
                  label: l10n.actionBack,
                  onPressed: onLeave,
                ),
              ),
              const SizedBox(width: DealGoSpacing.s12),
              Expanded(
                child: DealGoPrimaryButton(
                  label: l10n.actionKeepEnteringCode,
                  onPressed: onContinue,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NoticeBanner extends StatelessWidget {
  const _NoticeBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DealGoColors.warningSurface,
        borderRadius: BorderRadius.circular(DealGoRadius.input),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DealGoSpacing.s12),
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: DealGoColors.warning, height: 1.4),
        ),
      ),
    );
  }
}

class _StatusMark extends StatelessWidget {
  const _StatusMark({
    required this.icon,
    required this.color,
    required this.background,
  });

  final IconData icon;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: const BorderRadius.all(Radius.circular(18)),
      ),
      child: SizedBox(
        width: 72,
        height: 72,
        child: Icon(icon, color: color, size: 32),
      ),
    );
  }
}

class _LockMark extends StatelessWidget {
  const _LockMark();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        color: DealGoColors.subtlePurple,
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      child: SizedBox(
        width: 84,
        height: 84,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(Icons.lock_rounded, color: Color(0xFFF5B942), size: 40),
            Positioned(
              right: 18,
              top: 22,
              child: Icon(
                Icons.key_rounded,
                color: Color(0xFFE8A317),
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OtpBoxes extends StatelessWidget {
  const _OtpBoxes({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final code = controller.text;
    final textTheme = Theme.of(context).textTheme;
    final activeIndex = code.length >= otpCodeLength
        ? otpCodeLength - 1
        : code.length;

    return Semantics(
      label: AppLocalizations.of(context).otpFieldLabel,
      textField: true,
      child: ExcludeSemantics(
        child: SizedBox(
          height: 56,
          child: Stack(
            alignment: Alignment.center,
            children: [
              IgnorePointer(
                child: Row(
                  children: [
                    for (var index = 0; index < otpCodeLength; index++) ...[
                      if (index > 0) const SizedBox(width: DealGoSpacing.s8),
                      Expanded(
                        child: _OtpBox(
                          digit: index < code.length ? code[index] : '',
                          highlighted: index == activeIndex,
                          style: textTheme.titleLarge,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Positioned.fill(
                child: TextField(
                  key: const Key('otp-field'),
                  controller: controller,
                  readOnly: true,
                  enableInteractiveSelection: false,
                  showCursor: false,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(otpCodeLength),
                  ],
                  onChanged: (_) => onChanged(),
                  decoration: const InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    counterText: '',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OtpBox extends StatelessWidget {
  const _OtpBox({
    required this.digit,
    required this.highlighted,
    required this.style,
  });

  final String digit;
  final bool highlighted;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: highlighted ? Colors.white : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(DealGoRadius.input),
        border: Border.all(
          color: highlighted ? DealGoColors.primary : DealGoColors.border,
          width: highlighted ? 2.0 : 1.2,
        ),
        boxShadow: highlighted
            ? [
                BoxShadow(
                  color: DealGoColors.primary.withValues(alpha: 0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Center(
        child: Text(
          digit,
          style: (style ?? const TextStyle()).copyWith(
            color: DealGoColors.primary,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({
    required this.enabled,
    required this.onDigit,
    required this.onBackspace,
    required this.onSubmit,
  });

  final bool enabled;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    const rows = <List<String>>[
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
    ];

    return Column(
      children: [
        for (final row in rows) ...[
          Row(
            children: [
              for (var index = 0; index < row.length; index++) ...[
                if (index > 0) const SizedBox(width: DealGoSpacing.s8),
                Expanded(
                  child: _KeypadKey(
                    label: row[index],
                    enabled: enabled,
                    onPressed: () => onDigit(row[index]),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: DealGoSpacing.s8),
        ],
        Row(
          children: [
            Expanded(
              child: _KeypadKey(
                icon: Icons.backspace_outlined,
                keyName: 'backspace',
                enabled: enabled,
                onPressed: onBackspace,
              ),
            ),
            const SizedBox(width: DealGoSpacing.s8),
            Expanded(
              child: _KeypadKey(
                label: '0',
                enabled: enabled,
                onPressed: () => onDigit('0'),
              ),
            ),
            const SizedBox(width: DealGoSpacing.s8),
            Expanded(
              child: _KeypadKey(
                icon: Icons.check_rounded,
                keyName: 'submit',
                enabled: enabled,
                onPressed: onSubmit,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _KeypadKey extends StatelessWidget {
  const _KeypadKey({
    required this.enabled,
    required this.onPressed,
    this.label,
    this.icon,
    this.keyName,
  });

  final String? label;
  final IconData? icon;
  final String? keyName;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final name = keyName ?? label ?? 'key';
    return Material(
      color: DealGoColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DealGoRadius.input),
        side: const BorderSide(color: DealGoColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('otp-key-$name'),
        onTap: enabled ? onPressed : null,
        child: SizedBox(
          height: 52,
          child: Center(
            child: icon != null
                ? Icon(icon, color: DealGoColors.text)
                : Text(
                    label ?? '',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
          ),
        ),
      ),
    );
  }
}
