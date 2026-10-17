import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../domain/auth_redirect.dart';
import '../cubit/phone_auth_cubit.dart';
import '../widgets/otp_widgets.dart';

const _resendWait = Duration(seconds: 60);

enum _OtpPane { entry, invalid, cooldown }

class OtpPage extends StatefulWidget {
  const OtpPage({
    required this.challengeId,
    required this.phone,
    super.key,
  });

  final String challengeId;
  final String phone;

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  final TextEditingController _code = TextEditingController();
  late String _challengeId = widget.challengeId;
  late DateTime _resendAvailableAt = DateTime.now().add(_resendWait);
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
    _resendAvailableAt = DateTime.now().add(_resendWait);
    _ensureTicker();
  }

  void _confirm() {
    final phoneAuth = context.read<PhoneAuthCubit>().state;
    if (isPhoneAuthBusy(phoneAuth) || _code.text.length != otpCodeLength) {
      return;
    }
    unawaited(
      context.read<PhoneAuthCubit>().verifyOtp(
        challengeId: _challengeId,
        phone: widget.phone,
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
    unawaited(
      context.read<PhoneAuthCubit>().resendChallenge(
        phone: widget.phone,
        previousChallengeId: _challengeId,
      ),
    );
  }

  void _onPhoneAuth(PhoneAuthState state) {
    if (state is PhoneAuthChallengeReady) {
      setState(() {
        _challengeId = state.challengeId;
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
        if (state.phase == PhoneAuthPhase.verify &&
            isOtpCodeFailure(state.error)) {
          _pane = _OtpPane.invalid;
        } else if (state.phase == PhoneAuthPhase.resend &&
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

  void _pushDigit(String digit) {
    final busy = isPhoneAuthBusy(context.read<PhoneAuthCubit>().state);
    if (busy || _code.text.length >= otpCodeLength) {
      return;
    }
    _code.text = '${_code.text}$digit';
    setState(() {});
  }

  void _backspace() {
    final busy = isPhoneAuthBusy(context.read<PhoneAuthCubit>().state);
    if (busy || _code.text.isEmpty) {
      return;
    }
    _code.text = _code.text.substring(0, _code.text.length - 1);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PhoneAuthCubit, PhoneAuthState>(
      // ChallengeReady after resend only — login→OTP already used route args.
      listenWhen: (previous, next) =>
          (next is PhoneAuthChallengeReady &&
              previous is PhoneAuthResending) ||
          next is PhoneAuthError,
      listener: (context, state) => _onPhoneAuth(state),
      builder: (context, phoneAuth) {
        final submitting = phoneAuth is PhoneAuthVerifying;
        final resending = phoneAuth is PhoneAuthResending;
        final canConfirm =
            _code.text.length == otpCodeLength && !submitting && !resending;
        final displayError =
            isOtpCodeFailure(_error) ? null : _error;

        return Scaffold(
          body: SafeArea(
            child: switch (_pane) {
              _OtpPane.entry => OtpEntryPane(
                code: _code,
                phone: widget.phone,
                error: displayError,
                submitting: submitting,
                resending: resending,
                canConfirm: canConfirm,
                remaining: _remaining,
                onBack: _changePhone,
                onChanged: () => setState(() {}),
                onDigit: _pushDigit,
                onBackspace: _backspace,
                onResend: _resend,
                onConfirm: _confirm,
              ),
              _OtpPane.invalid => OtpInvalidPane(
                code: _code.text,
                error: _error,
                onBack: _changePhone,
                onChangePhone: _changePhone,
                onRetry: _retryEntry,
              ),
              _OtpPane.cooldown => OtpCooldownPane(
                phone: widget.phone,
                remaining: _remaining,
                onBack: _changePhone,
                onLeave: _changePhone,
                onContinue: _retryEntry,
              ),
            },
          ),
        );
      },
    );
  }
}
