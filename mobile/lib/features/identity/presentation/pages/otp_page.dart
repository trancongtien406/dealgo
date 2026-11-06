import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/network/api_exception.dart';
import '../../domain/auth_redirect.dart';
import '../cubit/phone_auth_cubit.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/otp_widgets.dart';

const _resendWait = Duration(seconds: 30);
// Matches the server cooldown for email sign-up resends (EMAIL_SIGNUP_RESEND_COOLDOWN_MS).
const _emailResendWait = Duration(seconds: 60);

enum _OtpPane { entry, invalid, cooldown }

class OtpPage extends StatefulWidget {
  const OtpPage({required this.challengeId, required String phone, super.key})
    : destination = phone,
      isEmail = false;

  /// Email sign-up: the account is created only when this code is verified.
  const OtpPage.email({
    required this.challengeId,
    required String email,
    super.key,
  }) : destination = email,
       isEmail = true;

  final String challengeId;

  /// E.164 phone or email address the code was sent to.
  final String destination;
  final bool isEmail;

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  final TextEditingController _code = TextEditingController();
  late String _challengeId = widget.challengeId;
  late DateTime _resendAvailableAt = DateTime.now().add(_wait);
  ApiException? _error;
  Timer? _ticker;
  var _pane = _OtpPane.entry;

  @override
  void initState() {
    super.initState();
    _ensureTicker();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _code.dispose();
    super.dispose();
  }

  Duration get _wait => widget.isEmail ? _emailResendWait : _resendWait;

  bool get _cooldownActive =>
      _resendAvailableAt.difference(DateTime.now()) > Duration.zero;

  Duration get _remaining {
    final diff = _resendAvailableAt.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  void _ensureTicker() {
    if (_ticker != null) {
      return;
    }
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      if (!_cooldownActive) {
        _ticker?.cancel();
        _ticker = null;
      }
      setState(() {});
    });
  }

  void _armCooldown() {
    _resendAvailableAt = DateTime.now().add(_wait);
    _ensureTicker();
  }

  void _confirm() {
    final phoneAuth = context.read<PhoneAuthCubit>().state;
    if (isPhoneAuthBusy(phoneAuth) || _code.text.length != otpCodeLength) {
      return;
    }
    final cubit = context.read<PhoneAuthCubit>();
    unawaited(
      widget.isEmail
          ? cubit.verifyEmailRegistration(
              challengeId: _challengeId,
              email: widget.destination,
              code: _code.text,
            )
          : cubit.verifyOtp(
              challengeId: _challengeId,
              phone: widget.destination,
              code: _code.text,
            ),
    );
  }

  void _resend() {
    final phoneAuth = context.read<PhoneAuthCubit>().state;
    if (isPhoneAuthBusy(phoneAuth)) {
      return;
    }
    if (_cooldownActive) {
      setState(() => _pane = _OtpPane.cooldown);
      return;
    }
    final cubit = context.read<PhoneAuthCubit>();
    unawaited(
      widget.isEmail
          ? cubit.resendEmailRegistration(
              email: widget.destination,
              challengeId: _challengeId,
            )
          : cubit.resendChallenge(
              phone: widget.destination,
              previousChallengeId: _challengeId,
            ),
    );
  }

  void _onPhoneAuth(PhoneAuthState state) {
    final reissuedId = switch (state) {
      PhoneAuthChallengeReady(:final challengeId) => challengeId,
      PhoneAuthEmailChallengeReady(:final challengeId) => challengeId,
      _ => null,
    };
    if (reissuedId != null) {
      setState(() {
        _challengeId = reissuedId;
        _error = null;
        _code.clear();
        _pane = _OtpPane.entry;
      });
      _armCooldown();
      return;
    }
    if (state is PhoneAuthError) {
      setState(() {
        _error = state.error;
        final verifyPhase = widget.isEmail
            ? PhoneAuthPhase.emailVerify
            : PhoneAuthPhase.verify;
        final resendPhase = widget.isEmail
            ? PhoneAuthPhase.emailResend
            : PhoneAuthPhase.resend;
        final lockedOnResend =
            state.phase == resendPhase &&
            state.error.errorCode == 'AUTH_CODE_LOCKED';
        if ((state.phase == verifyPhase && isOtpCodeFailure(state.error)) ||
            lockedOnResend) {
          _pane = _OtpPane.invalid;
        } else if (state.phase == resendPhase &&
            state.error.statusCode == 429) {
          _pane = _OtpPane.cooldown;
          _armCooldown();
        }
      });
    }
  }

  void _changePhone() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AuthRoutes.login);
  }

  void _retryEntry() {
    setState(() {
      _pane = _OtpPane.entry;
      _error = null;
      _code.clear();
    });
  }

  /// Back from the cooldown notice: keep whatever was already typed.
  void _continueEntry() {
    setState(() => _pane = _OtpPane.entry);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PhoneAuthCubit, PhoneAuthState>(
      listenWhen: (previous, next) =>
          (next is PhoneAuthChallengeReady && previous is PhoneAuthResending) ||
          (next is PhoneAuthEmailChallengeReady &&
              previous is PhoneAuthEmailResending) ||
          next is PhoneAuthError,
      listener: (context, state) => _onPhoneAuth(state),
      builder: (context, phoneAuth) {
        final submitting =
            phoneAuth is PhoneAuthVerifying ||
            phoneAuth is PhoneAuthEmailVerifying;
        final resending =
            phoneAuth is PhoneAuthResending ||
            phoneAuth is PhoneAuthEmailResending;
        final canConfirm =
            _code.text.length == otpCodeLength && !submitting && !resending;
        final displayError = isOtpCodeFailure(_error) ? null : _error;

        return Scaffold(
          backgroundColor: DealGoColors.card,
          body: Stack(
            children: [
              const Positioned.fill(child: AuthBackdrop()),
              SafeArea(
                child: switch (_pane) {
                  _OtpPane.entry => OtpEntryPane(
                    code: _code,
                    phone: widget.destination,
                    isEmail: widget.isEmail,
                    error: displayError,
                    submitting: submitting,
                    resending: resending,
                    canConfirm: canConfirm,
                    remaining: _remaining,
                    onBack: _changePhone,
                    onChanged: () => setState(() {}),
                    // Autofilled / pasted / fully typed codes submit themselves.
                    onCompleted: _confirm,
                    onResend: _resend,
                    onConfirm: _confirm,
                  ),
                  _OtpPane.invalid => OtpInvalidPane(
                    code: _code.text,
                    isEmail: widget.isEmail,
                    error: _error,
                    onBack: _changePhone,
                    onChangePhone: _changePhone,
                    onRetry: _retryEntry,
                  ),
                  _OtpPane.cooldown => OtpCooldownPane(
                    phone: widget.destination,
                    isEmail: widget.isEmail,
                    remaining: _remaining,
                    onBack: _changePhone,
                    onLeave: _changePhone,
                    onContinue: _continueEntry,
                  ),
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
