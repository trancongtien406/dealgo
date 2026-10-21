import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/design_system/components/dealgo_card.dart';
import '../../../../core/design_system/components/dealgo_logo.dart';
import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/components/dealgo_secondary_button.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/phone_input.dart';
import '../../../../core/design_system/components/dealgo_icon_badge.dart';
import 'auth_scaffold.dart';
import 'auth_widgets.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';

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
  const _OtpHeader({required this.onBack, this.isEmail = false});

  final VoidCallback onBack;
  final bool isEmail;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      height: DealGoDimensions.headerHeight,
      child: Padding(
        padding: const EdgeInsets.only(
          left: DealGoDimensions.pageGutter,
          right: DealGoSpacing.s4,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const DealGoLogo.wordmark(size: 24),
            TextButton(
              onPressed: onBack,
              child: Text(
                isEmail ? l10n.actionChangeEmail : l10n.otpChangePhone,
              ),
            ),
          ],
        ),
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
    this.isEmail = false,
    super.key,
  });

  final TextEditingController code;

  /// E.164 phone, or the email address when [isEmail] is true.
  final String phone;
  final bool isEmail;
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
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final displayPhone = isEmail ? phone : formatDisplayPhone(phone);
    final waiting = remaining > Duration.zero;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _OtpHeader(onBack: onBack, isEmail: isEmail),
        Expanded(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.symmetric(horizontal: DealGoSpacing.s20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: Image.asset(
                    'assets/images/hero_otp_shield.png',
                    fit: BoxFit.contain,
                    excludeFromSemantics: true,
                    errorBuilder: (context, error, stackTrace) =>
                        const _LockMark(),
                  ),
                ),
                const SizedBox(height: DealGoSpacing.s12),
                Semantics(
                  header: true,
                  child: Text.rich(
                    TextSpan(
                      style: textTheme.headlineMedium,
                      children: [
                        TextSpan(
                          text: isEmail
                              ? l10n.otpEmailHeadingPrefix
                              : l10n.otpPhoneHeadingPrefix,
                        ),
                        TextSpan(
                          text: isEmail
                              ? l10n.otpEmailHeadingAccent
                              : l10n.otpPhoneHeadingAccent,
                          style: const TextStyle(color: DealGoColors.primary),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: DealGoSpacing.s6),
                Text.rich(
                  TextSpan(
                    style: textTheme.bodyMedium?.copyWith(
                      color: DealGoColors.textSecondary,
                    ),
                    children: [
                      TextSpan(text: l10n.otpEmailBodyPrefix),
                      TextSpan(
                        text: displayPhone,
                        style: const TextStyle(
                          color: DealGoColors.text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: DealGoSpacing.s20),
                _OtpBoxes(controller: code, onChanged: onChanged),
                if (error != null) ...[
                  const SizedBox(height: DealGoSpacing.s12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: AuthErrorText(error: error!),
                  ),
                ],
                const SizedBox(height: DealGoSpacing.s16),
                Semantics(
                  liveRegion: true,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(DealGoIcons.clock, size: 16),
                      const SizedBox(width: DealGoSpacing.s6),
                      Text.rich(
                        TextSpan(
                          style: textTheme.labelMedium,
                          children: [
                            TextSpan(text: '${l10n.otpResendIn} '),
                            TextSpan(
                              text: l10n.otpSeconds(
                                waiting ? remaining.inSeconds : 0,
                              ),
                              style: const TextStyle(
                                color: DealGoColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: DealGoSpacing.s16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DealGoSpacing.s12,
                    vertical: DealGoSpacing.s12,
                  ),
                  decoration: BoxDecoration(
                    color: DealGoColors.lavender,
                    borderRadius: BorderRadius.circular(DealGoRadius.button),
                  ),
                  child: Row(
                    children: [
                      const DealGoIconBadge(
                        DealGoIcons.lock,
                        size: 30,
                        circle: true,
                      ),
                      const SizedBox(width: DealGoSpacing.s12),
                      Expanded(
                        child: Text(
                          l10n.otpShieldNote,
                          style: textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: DealGoSpacing.s20),
                DealGoPrimaryButton(
                  label: l10n.otpConfirm,
                  trailingIcon: DealGoIcons.arrowRight,
                  enabled: canConfirm,
                  isLoading: submitting,
                  onPressed: onConfirm,
                ),
                const SizedBox(height: DealGoSpacing.s12),
                SizedBox(
                  width: double.infinity,
                  child: DealGoSecondaryButton(
                    label: resending ? l10n.otpSending : l10n.otpResendLabel,
                    leadingIcon: DealGoIcons.sync,
                    enabled: !submitting && !resending,
                    onPressed: onResend,
                  ),
                ),
                const AuthLegalFooter(),
                Offstage(
                  offstage: true,
                  child: _Keypad(
                    enabled: !submitting,
                    onDigit: onDigit,
                    onBackspace: onBackspace,
                    onSubmit: onConfirm,
                  ),
                ),
              ],
            ),
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
    this.isEmail = false,
    super.key,
  });

  final String code;
  final bool isEmail;
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
    // Email challenges cannot be resent once locked; the user starts over.
    final emailLocked = isEmail && locked;
    final detail = emailLocked
        ? l10n.otpEmailLockedBody
        : (locked ? l10n.otpLockedBody : l10n.otpInvalidBody);

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
                  icon: DealGoIcons.close,
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
                  label: isEmail
                      ? l10n.actionChangeEmail
                      : l10n.actionChangePhone,
                  onPressed: onChangePhone,
                ),
              ),
              if (!emailLocked) ...[
                const SizedBox(width: DealGoSpacing.s12),
                Expanded(
                  child: DealGoPrimaryButton(
                    label: AppLocalizations.of(context).actionRetry,
                    onPressed: onRetry,
                  ),
                ),
              ],
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
    this.isEmail = false,
    super.key,
  });

  /// E.164 phone, or the email address when [isEmail] is true.
  final String phone;
  final bool isEmail;
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
                  icon: DealGoIcons.chartPie,
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
                              isEmail
                                  ? l10n.authEmailLabel
                                  : l10n.authPhoneLabel,
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
                            isEmail ? phone : _maskedPhone(phone),
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
            Icon(DealGoIcons.lock, color: Color(0xFFF5B942), size: 40),
            Positioned(
              right: 18,
              top: 22,
              child: Icon(DealGoIcons.key, color: Color(0xFFE8A317), size: 18),
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
    final activeIndex = code.length >= otpCodeLength
        ? otpCodeLength - 1
        : code.length;

    return Semantics(
      label: AppLocalizations.of(context).otpFieldLabel,
      textField: true,
      child: SizedBox(
        height: 60,
        child: Stack(
          alignment: Alignment.center,
          children: [
            IgnorePointer(
              child: Row(
                children: [
                  for (var index = 0; index < otpCodeLength; index++) ...[
                    if (index > 0) const SizedBox(width: 8),
                    Expanded(
                      child: _OtpBox(
                        digit: index < code.length ? code[index] : '',
                        highlighted: index == activeIndex,
                        style: Theme.of(context).textTheme.titleLarge,
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
                autofocus: true,
                showCursor: false,
                style: const TextStyle(color: Colors.transparent),
                cursorColor: Colors.transparent,
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
    final hasDigit = digit.isNotEmpty;
    return Container(
      height: 58,
      decoration: BoxDecoration(
        color: hasDigit
            ? Colors.white
            : (highlighted ? Colors.white : const Color(0xFFF8FAFC)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlighted
              ? const Color(0xFF6D28D9)
              : (hasDigit ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0)),
          width: highlighted ? 1.8 : 1.2,
        ),
        boxShadow: highlighted
            ? [
                BoxShadow(
                  color: const Color(0xFF6D28D9).withValues(alpha: 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Center(
        child: hasDigit
            ? Text(
                digit,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              )
            : (highlighted
                  ? Container(
                      width: 2,
                      height: 24,
                      decoration: BoxDecoration(
                        color: const Color(0xFF6D28D9),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    )
                  : const SizedBox.shrink()),
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
                icon: DealGoIcons.backspace,
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
                icon: DealGoIcons.check,
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
