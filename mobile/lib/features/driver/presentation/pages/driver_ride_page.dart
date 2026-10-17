import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/network/api_exception.dart';
import '../../../ride/domain/entities/ride_models.dart';
import '../../../ride/domain/entities/ride_money.dart';
import '../../../ride/domain/params/submit_ride_offer_params.dart';
import '../../domain/usecases/submit_driver_ride_offer.dart';
import '../cubit/driver_offer_cubit.dart';
import '../utils/driver_routes.dart';
import '../widgets/driver_widgets.dart';

class DriverRideDetailPage extends StatelessWidget {
  const DriverRideDetailPage({required this.ride, super.key});

  final OpenRide ride;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DriverPageFrame(
        title: 'Chi tiết yêu cầu chở khách',
        insetBottom: true,
        onBack: () => driverBack(context),
        footer: DriverFooter(
          secondaryLabel: 'Bỏ qua',
          primaryLabel: 'Chào giá',
          primaryKey: const Key('driver-open-offer'),
          onSecondary: () => driverBack(context),
          onPrimary: () =>
              context.push(DriverRoutes.offer(ride.id), extra: ride),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            DealGoDimensions.pageGutter,
            DealGoSpacing.s8,
            DealGoDimensions.pageGutter,
            DealGoSpacing.s16,
          ),
          children: [
            DriverPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const DriverChip(
                    label: 'Chở khách · Xe máy',
                    tone: DriverChipTone.green,
                  ),
                  const SizedBox(height: DealGoSpacing.s12),
                  Text('Đơn #${ride.id}'),
                  const SizedBox(height: DealGoSpacing.s12),
                  DriverStop(
                    color: DealGoColors.brandGreen,
                    label: 'Điểm đón',
                    value: ride.pickup.label,
                  ),
                  const SizedBox(height: DealGoSpacing.s12),
                  DriverStop(
                    color: DealGoColors.danger,
                    label: 'Điểm đến',
                    value: ride.dropoff.label,
                  ),
                ],
              ),
            ),
            const SizedBox(height: DealGoSpacing.s12),
            DriverPanel(
              child: Column(
                children: [
                  DriverMoneyRow(
                    label: 'Giá khách đề xuất',
                    value: formatRideVnd(ride.offeredFareVnd),
                    emphasize: true,
                  ),
                  DriverMoneyRow(
                    label: 'Giá tham chiếu',
                    value: formatRideVnd(ride.referenceFareVnd),
                  ),
                  DriverMoneyRow(
                    label: 'Số chào giá',
                    value: '${ride.offerCount}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: DealGoSpacing.s12),
            const DriverNote(
              tone: DriverNoteTone.green,
              message: 'Cùng số tiền với giá khách là ACCEPT. Số khác là COUNTER. Server mới chốt giá chuyến.',
            ),
          ],
        ),
      ),
    );
  }
}

class DriverOfferPage extends StatelessWidget {
  const DriverOfferPage({required this.ride, super.key});

  final OpenRide ride;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          DriverOfferCubit(
            submitDriverRideOffer: context.read<SubmitDriverRideOffer>(),
          ),
      child: _DriverOfferView(ride: ride),
    );
  }
}

class _DriverOfferView extends StatefulWidget {
  const _DriverOfferView({required this.ride});

  final OpenRide ride;

  @override
  State<_DriverOfferView> createState() => _DriverOfferPageState();
}

class _DriverOfferPageState extends State<_DriverOfferView> {
  late final TextEditingController _amount = TextEditingController(
    text: '${widget.ride.offeredFareVnd}',
  );
  var _submitting = false;
  String? _error;
  int? _sentAmount;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || _sentAmount != null) {
      return;
    }
    final amount = parseRideFareInput(_amount.text);
    if (amount == null || !rideFareAllowed(amount)) {
      setState(() => _error = rideFareRangeLabel());
      return;
    }
    final token = driverAccessToken(context);
    if (token == null || token.isEmpty) {
      setState(() => _error = 'Phiên đăng nhập không còn hiệu lực');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await context.read<DriverOfferCubit>().submit(
        SubmitRideOfferRequest(
          accessToken: token,
          rideId: widget.ride.id,
          amountVnd: amount,
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _submitting = false;
        _sentAmount = amount;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _submitting = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _submitting = false;
        _error = 'Không gửi được báo giá';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ride = widget.ride;
    final amount = parseRideFareInput(_amount.text);
    final sent = _sentAmount;
    return Scaffold(
      body: DriverPageFrame(
        title: 'Thương lượng giá chuyến',
        subtitle: driverVehicleLabel,
        insetBottom: true,
        onBack: () => driverBack(context),
        footer: sent == null
            ? Padding(
                padding: const EdgeInsets.fromLTRB(
                  DealGoDimensions.pageGutter,
                  DealGoSpacing.s8,
                  DealGoDimensions.pageGutter,
                  DealGoSpacing.s16,
                ),
                child: DealGoPrimaryButton(
                  key: const Key('driver-submit-offer'),
                  label: 'Gửi báo giá',
                  trailingIcon: Icons.arrow_forward,
                  isLoading: _submitting,
                  enabled: !_submitting,
                  onPressed: _submit,
                ),
              )
            : null,
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            DealGoDimensions.pageGutter,
            DealGoSpacing.s8,
            DealGoDimensions.pageGutter,
            DealGoSpacing.s16,
          ),
          children: [
            DriverPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Báo giá của khách', style: textTheme.titleMedium),
                  const SizedBox(height: DealGoSpacing.s12),
                  Text('Đơn #${ride.id}', style: textTheme.bodySmall),
                  DriverMoneyRow(
                    label: 'Phí đề nghị',
                    value: formatRideVnd(ride.offeredFareVnd),
                  ),
                  const DriverMoneyRow(label: 'Phương tiện', value: 'Xe máy'),
                ],
              ),
            ),
            const SizedBox(height: DealGoSpacing.s12),
            if (sent != null) ...[
              DriverPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Đã gửi báo giá', style: textTheme.titleMedium),
                    const SizedBox(height: DealGoSpacing.s8),
                    Text(
                      formatRideVnd(sent),
                      style: textTheme.headlineSmall?.copyWith(
                        color: DealGoColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: DealGoSpacing.s8),
                    DriverChip(
                      label: sent == ride.offeredFareVnd
                          ? 'ACCEPT · Chờ khách chọn'
                          : 'COUNTER · Chờ khách chọn',
                      tone: DriverChipTone.green,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DealGoSpacing.s12),
              DriverPanel(
                color: const Color(0xFF1E1B4B),
                child: Row(
                  children: [
                    const Icon(Icons.navigation, color: Colors.white),
                    const SizedBox(width: DealGoSpacing.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sẵn sàng điều hướng đón khách',
                            style: textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Khi khách chọn báo giá, mở lộ trình đón (D021). Demo có thể mở ngay.',
                            style: textTheme.bodySmall?.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DealGoSpacing.s12),
              DealGoPrimaryButton(
                key: const Key('driver-open-active-ride'),
                label: 'Mở điều hướng đón (demo)',
                trailingIcon: Icons.arrow_forward,
                onPressed: () => context.push(
                  DriverRoutes.active(ride.id),
                  extra: ride,
                ),
              ),
            ] else ...[
              DriverPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Chào giá của bạn', style: textTheme.titleMedium),
                    const SizedBox(height: DealGoSpacing.s12),
                    TextField(
                      key: const Key('driver-offer-amount'),
                      controller: _amount,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: textTheme.headlineSmall?.copyWith(
                        color: DealGoColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                      decoration: InputDecoration(
                        suffixText: 'đ',
                        filled: true,
                        fillColor: DealGoColors.canvas,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            DealGoRadius.input,
                          ),
                          borderSide: const BorderSide(
                            color: DealGoColors.border,
                          ),
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: DealGoSpacing.s8),
                    Text(
                      _hint(amount, ride.offeredFareVnd),
                      style: textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DealGoSpacing.s12),
              DriverPanel(
                child: Column(
                  children: [
                    DriverMoneyRow(
                      label: 'Giá gửi lên',
                      value: amount == null ? '—' : formatRideVnd(amount),
                      emphasize: true,
                    ),
                    DriverMoneyRow(
                      label: 'Hình thức',
                      value: amount == ride.offeredFareVnd
                          ? 'ACCEPT'
                          : 'COUNTER',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DealGoSpacing.s12),
              const DriverNote(
                tone: DriverNoteTone.green,
                message: 'Giá khác giá khách đề xuất được ghi nhận là COUNTER. Đúng giá khách đề xuất được ghi nhận là ACCEPT.',
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: DealGoSpacing.s12),
              DriverNote(message: _error!),
            ],
          ],
        ),
      ),
    );
  }

  String _hint(int? amount, int offered) {
    if (amount == null || !rideFareAllowed(amount)) {
      return rideFareRangeLabel();
    }
    if (amount == offered) {
      return 'Chưa đổi báo giá khi khách chưa đồng ý.';
    }
    return 'Khác giá khách đề xuất. Gửi lên được ghi nhận là COUNTER.';
  }
}
