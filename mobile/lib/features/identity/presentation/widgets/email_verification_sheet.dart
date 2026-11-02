import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/l10n/api_error_text.dart';
import '../../../../core/motion/dealgo_sheet.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/email_verification.dart';
import '../../domain/repositories/identity_repository.dart';
import '../cubit/auth_cubit.dart';
import 'otp_widgets.dart';

/// Asks for the 6-digit code mailed for a profile email. Resolves to true once
/// the server accepted the code and the refreshed profile was applied.
Future<bool> showEmailVerificationSheet({
  required BuildContext context,
  required EmailVerification verification,
  required IdentityRepository repository,
  required AuthCubit auth,
  required String accessToken,
}) async {
  final verified = await showDealGoSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => EmailVerificationSheet(
      verification: verification,
      repository: repository,
      auth: auth,
      accessToken: accessToken,
    ),
  );
  return verified ?? false;
}

/// After a profile save: when [submittedEmail] is not yet the account email the
/// server mailed a code, so ask for it. Returns null when nothing was pending,
/// otherwise whether the address got verified.
Future<bool?> verifySubmittedProfileEmail({
  required BuildContext context,
  required String? submittedEmail,
  required String? accountEmail,
  required IdentityRepository repository,
  required AuthCubit auth,
  required String accessToken,
}) async {
  final email = submittedEmail?.trim().toLowerCase() ?? '';
  if (email.isEmpty || email == accountEmail?.toLowerCase()) return null;
  final verification = await repository.requestEmailVerification(
    accessToken: accessToken,
    email: email,
  );
  if (!context.mounted) return false;
  return showEmailVerificationSheet(
    context: context,
    verification: verification,
    repository: repository,
    auth: auth,
    accessToken: accessToken,
  );
}

class EmailVerificationSheet extends StatefulWidget {
  const EmailVerificationSheet({
    required this.verification,
    required this.repository,
    required this.auth,
    required this.accessToken,
    super.key,
  });

  final EmailVerification verification;
  final IdentityRepository repository;
  final AuthCubit auth;
  final String accessToken;

  @override
  State<EmailVerificationSheet> createState() => _EmailVerificationSheetState();
}

class _EmailVerificationSheetState extends State<EmailVerificationSheet> {
  final _code = TextEditingController();
  late EmailVerification _verification = widget.verification;
  Timer? _ticker;
  Duration _resendIn = Duration.zero;
  bool _submitting = false;
  bool _resending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startTicker();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _code.dispose();
    super.dispose();
  }

  void _startTicker() {
    _ticker?.cancel();
    _tick();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final left = _verification.resendAvailableAt.difference(DateTime.now());
    final next = left.isNegative ? Duration.zero : left;
    if (next == Duration.zero) _ticker?.cancel();
    if (mounted) setState(() => _resendIn = next);
  }

  String _errorText(AppLocalizations l10n, Object error) {
    if (error is ApiException) {
      switch (error.errorCode) {
        case 'AUTH_CODE_INVALID':
          return l10n.otpInvalidShort;
        case 'AUTH_CODE_EXPIRED':
          return l10n.otpExpiredTitle;
        case 'AUTH_CODE_LOCKED':
          return l10n.emailVerifyLocked;
        case 'AUTH_OTP_RATE_LIMITED':
          return l10n.emailErrorTooManyAttempts;
        case 'EMAIL_IN_USE':
          return l10n.emailErrInUse;
      }
    }
    return apiErrorText(l10n, error);
  }

  Future<void> _confirm() async {
    final code = _code.text;
    if (_submitting || code.length != otpCodeLength) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.repository.confirmEmailVerification(
        verificationId: _verification.verificationId,
        code: code,
      );
      final profile = await widget.repository.fetchMe(widget.accessToken);
      await widget.auth.applyUpdatedProfile(profile);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = _errorText(l10n, error);
      });
    }
  }

  Future<void> _resend() async {
    if (_resending || _submitting || _resendIn > Duration.zero) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _resending = true;
      _error = null;
    });
    try {
      final next = await widget.repository.requestEmailVerification(
        accessToken: widget.accessToken,
        email: _verification.email,
      );
      if (!mounted) return;
      _code.clear();
      setState(() {
        _verification = next;
        _resending = false;
      });
      _startTicker();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _resending = false;
        _error = _errorText(l10n, error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final waiting = _resendIn > Duration.zero;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            DealGoSpacing.s20,
            DealGoSpacing.s20,
            DealGoSpacing.s20,
            DealGoSpacing.s12,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text.rich(
                  TextSpan(
                    style: textTheme.titleLarge,
                    children: [
                      TextSpan(text: l10n.otpEmailHeadingPrefix),
                      TextSpan(
                        text: l10n.otpEmailHeadingAccent,
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
                      text: _verification.email,
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
                key: const Key('email-verify-code'),
                controller: _code,
                enabled: !_submitting,
                onChanged: () => setState(() => _error = null),
                onCompleted: () => unawaited(_confirm()),
              ),
              if (_error != null) ...[
                const SizedBox(height: DealGoSpacing.s12),
                Text(
                  _error!,
                  key: const Key('email-verify-error'),
                  style: textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: DealGoSpacing.s8),
              Text(
                l10n.otpEmailSpamHint,
                textAlign: TextAlign.center,
                style: textTheme.labelMedium?.copyWith(
                  color: DealGoColors.textSecondary,
                ),
              ),
              Semantics(
                liveRegion: true,
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      waiting
                          ? '${l10n.otpResendIn} ${l10n.otpSeconds(_resendIn.inSeconds)}'
                          : l10n.otpNoCodeYet,
                      style: textTheme.labelMedium?.copyWith(
                        color: DealGoColors.textSecondary,
                      ),
                    ),
                    TextButton(
                      key: const Key('email-verify-resend'),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(
                          DealGoDimensions.minTapTarget,
                          DealGoDimensions.minTapTarget,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: DealGoSpacing.s8,
                        ),
                      ),
                      onPressed: waiting || _submitting || _resending
                          ? null
                          : () => unawaited(_resend()),
                      child: Text(
                        _resending ? l10n.otpSending : l10n.otpResendLabel,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DealGoSpacing.s8),
              ListenableBuilder(
                listenable: _code,
                builder: (context, _) => DealGoPrimaryButton(
                  key: const Key('email-verify-confirm'),
                  label: l10n.otpConfirm,
                  enabled: _code.text.length == otpCodeLength && !_submitting,
                  isLoading: _submitting,
                  onPressed: _confirm,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
