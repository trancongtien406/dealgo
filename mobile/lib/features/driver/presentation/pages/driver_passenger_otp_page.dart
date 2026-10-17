import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/components/dealgo_banner.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../ride/domain/entities/ride_models.dart';
import '../../../ride/domain/entities/ride_money.dart';
import '../../../ride/domain/entities/ride_vehicle.dart';
import '../utils/driver_routes.dart';
import '../widgets/driver_widgets.dart';

/// D023 — passenger OTP entry for driver before trip start.
class DriverPassengerOtpPage extends StatefulWidget {
  const DriverPassengerOtpPage({
    required this.rideId,
    this.ride,
    super.key,
  });

  final String rideId;
  final OpenRide? ride;

  @override
  State<DriverPassengerOtpPage> createState() => _DriverPassengerOtpPageState();
}

class _DriverPassengerOtpPageState extends State<DriverPassengerOtpPage> {
  final TextEditingController _code = TextEditingController();
  var _wrong = false;
  var _confirmed = false;

  static const _otpLength = 4;

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

  void _confirm() {
    final expected = ridePickupCode(widget.rideId);
    if (_code.text.length != _otpLength || _code.text != expected) {
      setState(() {
        _wrong = true;
        _confirmed = false;
      });
      return;
    }
    setState(() {
      _wrong = false;
      _confirmed = true;
    });
    context.push(DriverRoutes.active(widget.rideId), extra: {
      'ride': widget.ride,
      'phase': 'onTrip',
    });
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
        primaryEnabled: _code.text.length == _otpLength,
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
                'DEALGO DRIVER · D023',
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
                      Icons.verified_user,
                      color: DealGoColors.brandGreen,
                    ),
                    const SizedBox(width: DealGoSpacing.s8),
                    Text(l10n.driverOtpVerifyTitle, style: textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: DealGoSpacing.s8),
                Text(
                  l10n.driverOtpValidFor(widget.rideId),
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
                      child: Text(
                        'T',
                        style: TextStyle(
                          color: DealGoColors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: DealGoSpacing.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Trần Minh Anh', style: textTheme.titleMedium),
                          Text(
                            'Khách hàng · 4.9 ★',
                            style: textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton.outlined(
                      onPressed: () {},
                      icon: const Icon(Icons.phone_outlined),
                      color: DealGoColors.primary,
                    ),
                    IconButton.outlined(
                      onPressed: () {},
                      icon: const Icon(Icons.chat_bubble_outline),
                      color: DealGoColors.primary,
                    ),
                  ],
                ),
                const SizedBox(height: DealGoSpacing.s16),
                DriverStop(
                  color: DealGoColors.brandGreen,
                  label: 'Điểm đón',
                  value: ride?.pickup.label ?? '123 Nguyễn Văn Linh, Hải Châu',
                ),
                const SizedBox(height: DealGoSpacing.s12),
                DriverStop(
                  color: DealGoColors.danger,
                  label: 'Điểm đến',
                  value: ride?.dropoff.label ?? '302 Trần Phú, Hải Châu',
                ),
                const SizedBox(height: DealGoSpacing.s12),
                DriverMoneyRow(
                  label: 'Loại xe',
                  value: 'Xe máy · Honda Vision',
                ),
                DriverMoneyRow(
                  label: 'Giá đã chốt',
                  value: ride == null
                      ? '—'
                      : formatRideVnd(ride.offeredFareVnd),
                  emphasize: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: DealGoSpacing.s12),
          DealGoBanner(
            tone: DealGoBannerTone.info,
            message: l10n.driverOtpGuide,
          ),
          const SizedBox(height: DealGoSpacing.s8),
          DealGoBanner(
            tone: DealGoBannerTone.warning,
            message: l10n.driverOtpPrivacy,
          ),
          if (_wrong) ...[
            const SizedBox(height: DealGoSpacing.s12),
            DriverNote(message: l10n.driverOtpWrong),
          ],
          if (_confirmed) ...[
            const SizedBox(height: DealGoSpacing.s12),
            const DriverNote(
              tone: DriverNoteTone.green,
              message: 'OTP khớp — chuyển sang chuyến đang chạy (mock).',
            ),
          ],
        ],
      ),
    );
  }
}
