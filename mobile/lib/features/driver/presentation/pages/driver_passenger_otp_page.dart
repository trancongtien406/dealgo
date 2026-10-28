import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../ride/domain/entities/ride_models.dart';
import '../../../ride/domain/entities/ride_money.dart';
import '../../../ride/domain/params/ride_driver_action.dart';
import '../../domain/usecases/advance_driver_ride.dart';
import '../cubit/driver_duty_cubit.dart';
import '../utils/driver_action_runner.dart';
import '../utils/driver_routes.dart';
import '../widgets/driver_contact_actions.dart';
import '../widgets/driver_widgets.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/format/short_ref.dart';

/// D023 — passenger OTP entry for driver before trip start.
class DriverPassengerOtpPage extends StatefulWidget {
  const DriverPassengerOtpPage({required this.rideId, this.ride, super.key});

  final String rideId;
  final OpenRide? ride;

  @override
  State<DriverPassengerOtpPage> createState() => _DriverPassengerOtpPageState();
}

class _DriverPassengerOtpPageState extends State<DriverPassengerOtpPage>
    with DriverActionRunner {
  final TextEditingController _code = TextEditingController();
  var _wrong = false;
  var _confirmed = false;

  static const _otpLength = 4;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ensureDriverOnDuty(context);
      }
    });
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() {
      _wrong = false;
      _confirmed = false;
    });
  }

  /// The code is checked by the backend only (DEC-PROD-017); the app never
  /// knows the expected value.
  Future<void> _confirm() async {
    final code = _code.text;
    if (code.length != _otpLength) {
      setState(() {
        _wrong = true;
        _confirmed = false;
      });
      return;
    }
    setState(() => _wrong = false);
    final advance = context.read<AdvanceDriverRide>();
    final ok = await runDriverAction(
      (token) => advance(
        accessToken: token,
        rideId: widget.rideId,
        action: RideDriverAction.start,
        pickupCode: code,
      ),
    );
    if (!mounted) {
      return;
    }
    if (!ok) {
      setState(() => _confirmed = false);
      return;
    }
    setState(() => _confirmed = true);
    context.pushReplacement(
      DriverRoutes.active(widget.rideId),
      extra: {'ride': widget.ride, 'phase': 'onTrip'},
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final ride = widget.ride;
    final digits = _code.text.padRight(_otpLength).substring(0, _otpLength);

    return DriverPageFrame(
      title: l10n.driverOtpTitle,
      insetBottom: true,
      onBack: () => driverBack(context),
      footer: DriverFooter(
        secondaryLabel: l10n.actionBack,
        primaryLabel: l10n.driverOtpConfirm,
        primaryKey: const Key('driver-otp-confirm'),
        primaryEnabled: _code.text.length == _otpLength && !actionBusy,
        primaryLoading: actionBusy,
        onSecondary: () => driverBack(context),
        onPrimary: _confirm,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          DealGoDimensions.pageGutter,
          DealGoSpacing.s8,
          DealGoDimensions.pageGutter,
          DealGoSpacing.s16,
        ),
        children: [
          Row(
            children: [
              Text(
                l10n.rideRef(shortRef(widget.rideId)),
                style: textTheme.labelSmall?.copyWith(
                  color: DealGoColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                l10n.driverOtpWaitingChip,
                style: textTheme.labelSmall?.copyWith(
                  color: DealGoColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: DealGoSpacing.s12),
          Text(l10n.driverOtpHeadline, style: textTheme.titleLarge),
          const SizedBox(height: DealGoSpacing.s8),
          Text(
            l10n.driverOtpBody,
            style: textTheme.bodyMedium?.copyWith(
              color: DealGoColors.textSecondary,
            ),
          ),
          const SizedBox(height: DealGoSpacing.s16),
          DriverPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      DealGoIcons.shield,
                      color: DealGoColors.brandGreen,
                    ),
                    const SizedBox(width: DealGoSpacing.s8),
                    Text(
                      l10n.driverOtpVerifyTitle,
                      style: textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: DealGoSpacing.s8),
                Text(
                  l10n.driverOtpValidFor(shortRef(widget.rideId)),
                  style: textTheme.bodySmall,
                ),
                const SizedBox(height: DealGoSpacing.s16),
                Stack(
                  children: [
                    Row(
                      children: [
                        for (var i = 0; i < _otpLength; i++) ...[
                          if (i > 0) const SizedBox(width: DealGoSpacing.s8),
                          Expanded(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: DealGoColors.subtlePurple,
                                borderRadius: BorderRadius.circular(
                                  DealGoRadius.input,
                                ),
                                border: Border.all(
                                  color: _wrong
                                      ? DealGoColors.danger
                                      : DealGoColors.border,
                                ),
                              ),
                              child: SizedBox(
                                height: 56,
                                child: Center(
                                  child: Text(
                                    digits[i].trim().isEmpty ? '' : digits[i],
                                    style: textTheme.headlineSmall?.copyWith(
                                      color: DealGoColors.primary,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    TextField(
                      key: const Key('driver-passenger-otp'),
                      controller: _code,
                      keyboardType: TextInputType.number,
                      maxLength: _otpLength,
                      autofocus: true,
                      style: const TextStyle(color: Colors.transparent),
                      cursorColor: Colors.transparent,
                      decoration: const InputDecoration(
                        counterText: '',
                        border: InputBorder.none,
                        filled: true,
                        fillColor: Colors.transparent,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(_otpLength),
                      ],
                      onChanged: _onChanged,
                    ),
                  ],
                ),
                const SizedBox(height: DealGoSpacing.s8),
                Text(l10n.driverOtpWaitingHint, style: textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(height: DealGoSpacing.s12),
          DriverPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: DealGoColors.subtlePurple,
                      child: Icon(
                        DealGoIcons.user,
                        color: DealGoColors.primary,
                      ),
                    ),
                    const SizedBox(width: DealGoSpacing.s12),
                    Expanded(
                      child: Text(
                        l10n.driverPassenger,
                        style: textTheme.titleMedium,
                      ),
                    ),
                    DriverContactActions(resourceId: widget.rideId),
                  ],
                ),
                const SizedBox(height: DealGoSpacing.s16),
                DriverStop(
                  color: DealGoColors.brandGreen,
                  label: l10n.driverPickupLabel,
                  value: ride?.pickup.label ?? '—',
                ),
                const SizedBox(height: DealGoSpacing.s12),
                DriverStop(
                  color: DealGoColors.danger,
                  label: l10n.driverDropoffLabel,
                  value: ride?.dropoff.label ?? '—',
                ),
                const SizedBox(height: DealGoSpacing.s12),
                DriverMoneyRow(
                  label: l10n.driverAgreedFare,
                  value: ride == null
                      ? '—'
                      : formatRideVnd(ride.offeredFareVnd),
                  emphasize: true,
                ),
              ],
            ),
          ),
          if (actionError != null) ...[
            const SizedBox(height: DealGoSpacing.s12),
            DriverNote(message: actionError!),
          ],
          if (_wrong) ...[
            const SizedBox(height: DealGoSpacing.s12),
            DriverNote(message: l10n.driverOtpWrong),
          ],
          if (_confirmed) ...[
            const SizedBox(height: DealGoSpacing.s12),
            DriverNote(
              tone: DriverNoteTone.green,
              message: l10n.driverOtpMatched,
            ),
          ],
        ],
      ),
    );
  }
}
