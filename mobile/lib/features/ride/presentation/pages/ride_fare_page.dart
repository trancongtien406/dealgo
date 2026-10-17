import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_error_l10n.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../domain/entities/ride_money.dart';
import '../../domain/entities/ride_models.dart';
import '../../domain/params/create_ride_params.dart';
import '../../domain/ride_idempotency.dart';
import '../../domain/usecases/create_ride.dart';
import '../cubit/ride_fare_cubit.dart';
import '../utils/ride_routes.dart';
import '../cubit/ride_session.dart';
import '../widgets/ride_widgets.dart';

class RideFarePage extends StatelessWidget {
  const RideFarePage({
    required this.places,
    this.initialFareVnd = rideDefaultOfferVnd,
    this.vehicleLabel = rideVehicleLabel,
    super.key,
  });

  final RidePlaces places;
  final int initialFareVnd;
  final String vehicleLabel;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => RideFareCubit(createRide: context.read<CreateRide>()),
      child: _RideFareView(
        places: places,
        initialFareVnd: initialFareVnd,
        vehicleLabel: vehicleLabel,
      ),
    );
  }
}

class _RideFareView extends StatefulWidget {
  const _RideFareView({
    required this.places,
    required this.initialFareVnd,
    required this.vehicleLabel,
  });

  final RidePlaces places;
  final int initialFareVnd;
  final String vehicleLabel;

  @override
  State<_RideFareView> createState() => _RideFarePageState();
}

class _RideFarePageState extends State<_RideFareView> {
  late final TextEditingController _fare = TextEditingController(
    text: '${widget.initialFareVnd}',
  );
  CreateRideRequest? _attempt;
  String? _openRideId;
  var _busy = false;
  var _offline = false;
  String? _message;

  @override
  void dispose() {
    _fare.dispose();
    super.dispose();
  }

  int? get _amount => parseRideFareInput(_fare.text);

  Future<void> _submit() async {
    if (_busy) {
      return;
    }
    final openRideId = _openRideId;
    final amount = _amount;
    if (openRideId != null &&
        _attempt != null &&
        amount == _attempt!.offeredFareVnd) {
      await context.push(RideRoutes.matching(openRideId));
      return;
    }
    if (amount == null || !rideFareAllowed(amount)) {
      setState(() {
        _offline = false;
        _message = rideFareRangeLabel();
      });
      return;
    }
    final token = rideAccessToken(context);
    if (token == null) {
      setState(() {
        _offline = false;
        _message = sessionExpiredMessage(context);
      });
      return;
    }
    final pickup = widget.places.pickup;
    final dropoff = widget.places.dropoff;
    final previous = _attempt;
    final CreateRideRequest request;
    if (previous != null &&
        previous.offeredFareVnd == amount &&
        previous.pickup.label == pickup.label &&
        previous.dropoff.label == dropoff.label) {
      request = previous;
    } else {
      request = CreateRideRequest(
        accessToken: token,
        idempotencyKey: createRideIdempotencyKey(),
        pickup: pickup,
        dropoff: dropoff,
        offeredFareVnd: amount,
      );
    }
    _attempt = request;
    setState(() {
      _busy = true;
      _offline = false;
      _message = null;
    });
    try {
      final ride = await context.read<RideFareCubit>().create(request);
      if (!mounted) {
        return;
      }
      context.read<RideSessionCubit>().remember(ride.id);
      setState(() {
        _busy = false;
        _openRideId = ride.id;
      });
      await _openCreatedRide(ride);
    } catch (error) {
      if (!mounted) {
        return;
      }
      final alreadyOpen =
          error is ApiException && error.errorCode == 'RIDE_ALREADY_OPEN';
      setState(() {
        _busy = false;
        if (rideFailureIsOffline(error)) {
          _offline = true;
          _message = null;
        } else {
          _offline = false;
          _message = alreadyOpen
              ? 'Bạn đang có một đề xuất chờ. Hãy mở báo giá đó hoặc hủy trước khi gửi giá mới.'
              : error is ApiException
              ? error.message
              : 'Không gửi được đề xuất.';
        }
      });
    }
  }

  Future<void> _openCreatedRide(RideView ride) async {
    final expired =
        ride.status == RideStatus.expired ||
        rideNegotiationExpired(ride, DateTime.now());
    final waiting =
        ride.status == RideStatus.negotiating &&
        ride.selectedOfferId == null &&
        ride.offers.isEmpty &&
        !expired;
    if (ride.status == RideStatus.assigned) {
      await context.push(RideRoutes.tracking(ride.id));
      return;
    }
    if (waiting || expired) {
      await context.push(RideRoutes.matching(ride.id));
      return;
    }
    await context.push(RideRoutes.offers(ride.id));
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/customer');
  }

  @override
  Widget build(BuildContext context) {
    final amount = _amount;
    final allowed = amount != null && rideFareAllowed(amount);
    final textTheme = Theme.of(context).textTheme;
    final viewExisting =
        _openRideId != null &&
        _attempt != null &&
        amount == _attempt!.offeredFareVnd;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        backgroundColor: DealGoColors.canvas,
        body: SafeArea(
          child: Column(
            children: [
              RideScreenHeader(title: 'Tự đề xuất giá chuyến', onBack: _back),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    DealGoDimensions.pageGutter,
                    DealGoSpacing.s8,
                    DealGoDimensions.pageGutter,
                    DealGoSpacing.s16,
                  ),
                  children: [
                    RidePanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const RideSectionTitle('Thông tin đặt xe'),
                          const SizedBox(height: DealGoSpacing.s12),
                          RideStopList(
                            pickup: widget.places.pickup.label,
                            dropoff: widget.places.dropoff.label,
                          ),
                          const SizedBox(height: DealGoSpacing.s12),
                          Row(
                            children: [
                              const Icon(
                                Icons.two_wheeler,
                                color: DealGoColors.primary,
                                size: 18,
                              ),
                              const SizedBox(width: DealGoSpacing.s8),
                              Text(
                                widget.vehicleLabel,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: DealGoSpacing.s12),
                    RidePanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const RideSectionTitle('Mức giá bạn muốn đề xuất'),
                          const SizedBox(height: DealGoSpacing.s4),
                          Text(
                            rideFareRangeLabel(),
                            style: textTheme.bodySmall,
                          ),
                          const SizedBox(height: DealGoSpacing.s12),
                          Text('Đề xuất của bạn', style: textTheme.bodySmall),
                          const SizedBox(height: DealGoSpacing.s8),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: DealGoColors.subtlePurple,
                              borderRadius: BorderRadius.circular(
                                DealGoRadius.input,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: DealGoSpacing.s16,
                              ),
                              child: Center(
                                child: Text(
                                  amount == null ? '—' : formatRideVnd(amount),
                                  style: textTheme.headlineMedium?.copyWith(
                                    color: DealGoColors.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: DealGoSpacing.s12),
                          TextField(
                            key: const Key('ride-fare-field'),
                            controller: _fare,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onChanged: (_) => setState(() => _message = null),
                            textAlign: TextAlign.center,
                            style: textTheme.titleLarge?.copyWith(
                              color: DealGoColors.primary,
                              fontWeight: FontWeight.w800,
                            ),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: DealGoColors.canvas,
                              hintText: 'Nhập số tiền',
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  DealGoRadius.input,
                                ),
                                borderSide: const BorderSide(
                                  color: DealGoColors.border,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  DealGoRadius.input,
                                ),
                                borderSide: const BorderSide(
                                  color: DealGoColors.primary,
                                  width: 1.4,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: DealGoSpacing.s12),
                          Row(
                            children: [
                              for (final preset in rideFarePresetsVnd) ...[
                                Expanded(
                                  child: _FarePreset(
                                    amount: preset,
                                    selected: amount == preset,
                                    onTap: () {
                                      _fare.text = '$preset';
                                      setState(() => _message = null);
                                    },
                                  ),
                                ),
                                if (preset != rideFarePresetsVnd.last)
                                  const SizedBox(width: DealGoSpacing.s8),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: DealGoSpacing.s12),
                    const RidePanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RideSectionTitle('Thương lượng minh bạch'),
                          SizedBox(height: DealGoSpacing.s8),
                          Text(
                            'Tài xế có thể chào giá khác. Bạn chỉ trả số tiền của báo giá đã được máy chủ chấp nhận.',
                          ),
                        ],
                      ),
                    ),
                    if (_offline) ...[
                      const SizedBox(height: DealGoSpacing.s16),
                      const RideOfflineNotice(
                        detail:
                            'Chưa gửi được đề xuất. Chuyến xe chưa được tạo.',
                      ),
                    ],
                    if (_message != null) ...[
                      const SizedBox(height: DealGoSpacing.s12),
                      RideNote(message: _message!),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  DealGoDimensions.pageGutter,
                  DealGoSpacing.s8,
                  DealGoDimensions.pageGutter,
                  DealGoSpacing.s12,
                ),
                child: DealGoPrimaryButton(
                  key: const Key('ride-submit-fare'),
                  label: viewExisting
                      ? 'Xem tài xế chào giá'
                      : 'Gửi đề xuất ${amount == null ? '' : formatRideVnd(amount)}',
                  trailingIcon: Icons.arrow_forward,
                  isLoading: _busy,
                  enabled: viewExisting || allowed,
                  onPressed: _submit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FarePreset extends StatelessWidget {
  const _FarePreset({
    required this.amount,
    required this.selected,
    required this.onTap,
  });

  final int amount;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? DealGoColors.card : DealGoColors.canvas,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(
          color: selected ? DealGoColors.primary : DealGoColors.border,
          width: selected ? 1.4 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: DealGoSpacing.s8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  formatRideVnd(amount),
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: selected
                        ? DealGoColors.primary
                        : DealGoColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 2),
                const Icon(Icons.check, size: 14, color: DealGoColors.primary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
