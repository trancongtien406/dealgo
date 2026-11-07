import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/design_system/components/dealgo_card.dart';
import '../../../../core/design_system/components/dealgo_logo.dart';
import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/components/dealgo_secondary_button.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/phone_input.dart';
import 'auth_widgets.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';

const otpCodeLength = 6;

final _sixDigits = RegExp(r'(?<!\d)(\d{6})(?!\d)');

/// First standalone 6-digit code in [text] (e.g. from an email or SMS), or null.
String? extractOtpCode(String? text) {
  if (text == null || text.isEmpty) {
    return null;
  }
  return _sixDigits.firstMatch(text)?.group(1);
}

/// Keeps the field to digits; a multi-character insert (paste, autofill) that
/// contains a standalone 6-digit code becomes exactly that code.
class OtpCodeInputFormatter extends TextInputFormatter {
  const OtpCodeInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final inserted = newValue.text.length - oldValue.text.length;
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (inserted > 1 || newValue.text.length > otpCodeLength) {
      digits = extractOtpCode(newValue.text) ?? digits;
    }
    if (digits.length > otpCodeLength) {
      digits = digits.substring(0, otpCodeLength);
    }
    return TextEditingValue(
      text: digits,
      selection: TextSelection.collapsed(offset: digits.length),
    );
  }
}

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
        padding: const EdgeInsets.symmetric(horizontal: DealGoSpacing.s4),
        child: Row(
          children: [
            AuthBackButton(key: const Key('otp-back'), onPressed: onBack),
            const Spacer(),
            const DealGoLogo.wordmark(size: 24),
            const Spacer(),
            if (!isEmail)
              TextButton(
                key: const Key('otp-change-phone'),
                onPressed: onBack,
                child: Text(
                  l10n.otpChangePhone,
                  style: const TextStyle(
                    color: DealGoColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              )
            else
              const SizedBox(width: DealGoDimensions.minTapTarget),
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
    required this.onResend,
    required this.onConfirm,
    this.onCompleted,
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
  final VoidCallback onResend;
  final VoidCallback onConfirm;

  /// Called once all 6 digits are present (typed, pasted, autofilled).
  final VoidCallback? onCompleted;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final displayPhone = isEmail ? phone : formatDisplayPhone(phone);
    final waiting = remaining > Duration.zero;
    final screenHeight = MediaQuery.sizeOf(context).height;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _OtpHeader(onBack: onBack, isEmail: isEmail),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // The Scaffold shrinks the body when the keyboard opens; shrink or
              // drop the hero so heading + code boxes stay above the keyboard.
              final room = constraints.maxHeight - 232;
              final fitted = (screenHeight * 0.2).clamp(0.0, 168.0);
              final heroHeight = room < 96
                  ? 0.0
                  : (room < fitted ? room : fitted);
              final compact = heroHeight == 0;
              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.symmetric(
                  horizontal: DealGoSpacing.s20,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          height: heroHeight,
                          width: double.infinity,
                          child: heroHeight == 0
                              ? null
                              : Image.asset(
                                  'assets/images/hero_otp_shield.png',
                                  fit: BoxFit.contain,
                                  excludeFromSemantics: true,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const _LockMark(),
                                ),
                        ),
                        SizedBox(
                          height: compact
                              ? DealGoSpacing.s8
                              : DealGoSpacing.s12,
                        ),
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
                                  style: const TextStyle(
                                    color: DealGoColors.primary,
                                  ),
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
                                style: TextStyle(
                                  color: DealGoColors.text,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: DealGoSpacing.s20),
                        OtpCodeField(
                          controller: code,
                          enabled: !submitting,
                          onChanged: onChanged,
                          onCompleted: onCompleted,
                        ),
                        if (error != null) ...[
                          const SizedBox(height: DealGoSpacing.s12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: AuthErrorText(error: error!),
                          ),
                        ],
                        const SizedBox(height: DealGoSpacing.s8),
                        Semantics(
                          liveRegion: true,
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text.rich(
                                TextSpan(
                                  style: textTheme.labelMedium?.copyWith(
                                    color: DealGoColors.textSecondary,
                                  ),
                                  children: waiting
                                      ? [
                                          TextSpan(
                                            text: '${l10n.otpResendIn} ',
                                          ),
                                          TextSpan(
                                            text: l10n.otpSeconds(
                                              remaining.inSeconds,
                                            ),
                                            style: const TextStyle(
                                              color: DealGoColors.primary,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ]
                                      : [TextSpan(text: l10n.otpNoCodeYet)],
                                ),
                              ),
                              TextButton(
                                key: const Key('otp-resend'),
                                style: TextButton.styleFrom(
                                  minimumSize: const Size(
                                    DealGoDimensions.minTapTarget,
                                    DealGoDimensions.minTapTarget,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: DealGoSpacing.s8,
                                  ),
                                ),
                                onPressed: submitting || resending
                                    ? null
                                    : onResend,
                                child: Text(
                                  resending
                                      ? l10n.otpSending
                                      : l10n.otpResendLabel,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: DealGoSpacing.s8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: DealGoSpacing.s16,
                            vertical: DealGoSpacing.s8,
                          ),
                          decoration: BoxDecoration(
                            color: DealGoColors.subtlePurple,
                            borderRadius: BorderRadius.circular(
                              DealGoRadius.input,
                            ),
                            border: Border.all(
                              color: DealGoColors.border.withValues(alpha: 0.6),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF8B5CF6),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: const Icon(
                                  DealGoIcons.shield,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: DealGoSpacing.s8),
                              Expanded(
                                child: Text(
                                  'Mã OTP giúp bảo vệ tài khoản của bạn.',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: DealGoColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: DealGoSpacing.s12),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        // Pinned under the scroll view: with the keyboard open the Scaffold
        // resizes, so the button sits right above the keyboard.
        Padding(
          padding: const EdgeInsets.fromLTRB(
            DealGoSpacing.s20,
            DealGoSpacing.s8,
            DealGoSpacing.s20,
            DealGoSpacing.s12,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: DealGoPrimaryButton(
                key: const Key('otp-confirm'),
                label: l10n.otpConfirm,
                trailingIcon: DealGoIcons.arrowRight,
                enabled: canConfirm,
                isLoading: submitting,
                onPressed: onConfirm,
              ),
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
        _OtpHeader(onBack: onBack, isEmail: isEmail),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(DealGoDimensions.pageGutter),
            child: Column(
              children: [
                _StatusMark(
                  icon: DealGoIcons.close,
                  color: DealGoColors.danger,
                  background: DealGoColors.dangerSurface,
                ),
                const SizedBox(height: DealGoSpacing.s20),
                Text(
                  title,
                  key: const Key('auth-error'),
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
                        isEmail
                            ? '${l10n.otpEmailHeadingPrefix}'
                                  '${l10n.otpEmailHeadingAccent}'
                            : l10n.otpHeading,
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
                    ],
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
            DealGoSpacing.s16,
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
        _OtpHeader(onBack: onBack, isEmail: isEmail),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(DealGoDimensions.pageGutter),
            child: Column(
              children: [
                _StatusMark(
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
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
                              ],
                            ),
                          ),
                          const SizedBox(width: DealGoSpacing.s12),
                          Text(
                            _waitLabel(remaining),
                            style: textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: DealGoColors.primary,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: DealGoSpacing.s12,
                        ),
                        child: Divider(height: 1),
                      ),
                      Row(
                        children: [
                          Text(
                            isEmail ? l10n.authEmailLabel : l10n.authPhoneLabel,
                            style: textTheme.bodySmall,
                          ),
                          const SizedBox(width: DealGoSpacing.s12),
                          Expanded(
                            child: Text(
                              isEmail ? phone : _maskedPhone(phone),
                              textAlign: TextAlign.end,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.titleSmall,
                            ),
                          ),
                        ],
                      ),
                    ],
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
            DealGoSpacing.s16,
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
        ),
      ],
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
    return DecoratedBox(
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

/// Six-box OTP input backed by one real (transparent) [TextField], so system
/// one-time-code autofill, paste and hardware keyboards all work:
/// - iOS: `AutofillHints.oneTimeCode` maps to `UITextContentType.oneTimeCode`
///   (QuickType bar suggests codes from Messages and, on iOS 17+, Mail).
/// - Android: the hint maps to `AUTOFILL_HINT_SMS_OTP`; Google autofill / keyboards
///   can offer the code. When the app resumes with a 6-digit code on the
///   clipboard (copied from the email), a one-tap "Dán mã" chip appears.
/// Pasting any text that contains a 6-digit code fills exactly that code.
class OtpCodeField extends StatefulWidget {
  const OtpCodeField({
    required this.controller,
    required this.onChanged,
    this.onCompleted,
    this.enabled = true,
    super.key,
  });

  final TextEditingController controller;
  final VoidCallback onChanged;
  final VoidCallback? onCompleted;
  final bool enabled;

  @override
  State<OtpCodeField> createState() => _OtpCodeFieldState();
}

class _OtpCodeFieldState extends State<OtpCodeField>
    with WidgetsBindingObserver {
  final FocusNode _focus = FocusNode(debugLabel: 'otp-field');
  String? _clipboardCode;
  String? _offeredCode;
  String _lastCompleted = '';

  bool get _clipboardChipSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_onText);
    _focus.addListener(_onFocus);
    unawaited(_checkClipboard());
  }

  @override
  void didUpdateWidget(OtpCodeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onText);
      widget.controller.addListener(_onText);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_onText);
    _focus.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_checkClipboard());
    }
  }

  void _onFocus() => setState(() {});

  void _onText() {
    final text = widget.controller.text;
    if (text.length < otpCodeLength) {
      _lastCompleted = '';
    }
    if (_clipboardCode != null && text == _clipboardCode) {
      setState(() => _clipboardCode = null);
    }
  }

  Future<void> _checkClipboard() async {
    if (!_clipboardChipSupported) {
      return;
    }
    try {
      if (!await Clipboard.hasStrings()) {
        return;
      }
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final code = extractOtpCode(data?.text);
      if (!mounted ||
          code == null ||
          code == _offeredCode ||
          code == widget.controller.text) {
        return;
      }
      setState(() => _clipboardCode = code);
    } on PlatformException {
      // Clipboard unavailable (e.g. restricted profile): no chip.
    }
  }

  void _applyCode(String code) {
    _offeredCode = code;
    widget.controller.value = TextEditingValue(
      text: code,
      selection: TextSelection.collapsed(offset: code.length),
    );
    setState(() => _clipboardCode = null);
    _handleChanged();
  }

  void _handleChanged() {
    widget.onChanged();
    final text = widget.controller.text;
    if (text.length == otpCodeLength && text != _lastCompleted) {
      _lastCompleted = text;
      TextInput.finishAutofillContext();
      widget.onCompleted?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final code = widget.controller.text;
    final focused = _focus.hasFocus;
    final activeIndex = code.length >= otpCodeLength
        ? otpCodeLength - 1
        : code.length;
    final chipCode = _clipboardCode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label: l10n.otpFieldLabel,
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
                            highlighted: focused && index == activeIndex,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Positioned.fill(
                  child: AutofillGroup(
                    child: TextField(
                      key: const Key('otp-field'),
                      controller: widget.controller,
                      focusNode: _focus,
                      // readOnly (not disabled) keeps focus + keyboard while verifying.
                      readOnly: !widget.enabled,
                      autofocus: true,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      autocorrect: false,
                      enableSuggestions: false,
                      enableIMEPersonalizedLearning: false,
                      showCursor: false,
                      cursorColor: Colors.transparent,
                      // Invisible text; the boxes draw the digits. No fill so the
                      // theme's input background never covers the boxes.
                      style: const TextStyle(color: Colors.transparent),
                      textAlign: TextAlign.center,
                      inputFormatters: const [OtpCodeInputFormatter()],
                      onChanged: (_) => _handleChanged(),
                      onSubmitted: (_) => _handleChanged(),
                      decoration: const InputDecoration(
                        isCollapsed: true,
                        filled: false,
                        fillColor: Colors.transparent,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        counterText: '',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (chipCode != null && widget.enabled) ...[
          const SizedBox(height: DealGoSpacing.s12),
          Center(
            child: ActionChip(
              key: const Key('otp-paste-chip'),
              avatar: const Icon(
                LucideIcons.clipboardPaste,
                size: 18,
                color: DealGoColors.primary,
              ),
              label: Text(l10n.otpPasteChip(chipCode)),
              labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: DealGoColors.primary,
                fontWeight: FontWeight.w700,
              ),
              backgroundColor: DealGoColors.lavender,
              side: const BorderSide(color: Color(0xFFDDD6FE)),
              shape: const StadiumBorder(),
              onPressed: () => _applyCode(chipCode),
            ),
          ),
        ],
      ],
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
