import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/maps/map_lat_lng.dart';
import '../../../../core/maps/map_port.dart';
import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../identity/presentation/widgets/auth_widgets.dart';
import '../../domain/entities/ride_models.dart';
import '../../domain/entities/ride_money.dart';
import '../utils/ride_routes.dart';
import '../cubit/ride_session.dart';
import '../widgets/ride_widgets.dart';

class RideMapPage extends StatefulWidget {
  const RideMapPage({super.key});

  @override
  State<RideMapPage> createState() => _RideMapPageState();
}

class _RideMapPageState extends State<RideMapPage> {
  final TextEditingController _pickup = TextEditingController(
    text: rideSamplePickupLabel,
  );
  final TextEditingController _dropoff = TextEditingController();
  var _showMap = false;
  var _scheduleNote = false;

  @override
  void dispose() {
    _pickup.dispose();
    _dropoff.dispose();
    super.dispose();
  }

  void _revealMap() {
    setState(() => _showMap = true);
  }

  void _useSuggestion(String label) {
    _dropoff.text = label;
    setState(() {});
  }

  void _continue() {
    final places = RidePlaces(
      pickupLabel: _pickup.text,
      dropoffLabel: _dropoff.text,
    );
    if (!places.canContinue) {
      return;
    }
    context.push(RideRoutes.routeOverview, extra: places);
  }

  void _back() => context.go('/customer');

  @override
  Widget build(BuildContext context) {
    final openRideId = context.watch<RideSessionCubit>().state;
    return Material(
      color: DealGoColors.canvas,
      child: SafeArea(
        child: _showMap
            ? _MapReady(
                pickup: _pickup,
                dropoff: _dropoff,
                scheduleNote: _scheduleNote,
                openRideId: openRideId,
                onBack: _back,
                onChanged: () => setState(() {}),
                onSchedule: () => setState(() => _scheduleNote = true),
                onSuggestion: _useSuggestion,
                onContinue: _continue,
              )
            : _MapLoading(onBack: _back, onManual: _revealMap),
      ),
    );
  }
}

class _MapLoading extends StatelessWidget {
  const _MapLoading({required this.onBack, required this.onManual});

  final VoidCallback onBack;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        RideScreenHeader(
          title: 'Bản đồ đặt xe',
          subtitle: 'DealGo · Biến thể trạng thái',
          onBack: onBack,
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              DealGoDimensions.pageGutter,
              DealGoSpacing.s24,
              DealGoDimensions.pageGutter,
              DealGoSpacing.s16,
            ),
            children: [
              const RideStateHero(
                icon: Icons.my_location,
                iconColor: Color(0xFF2563EB),
                background: Color(0xFFE8F1FF),
                title: 'Đang tải bản đồ...',
                message:
                    'Hệ thống đang lấy bản đồ và gợi ý địa điểm đón quanh bạn.',
              ),
              const SizedBox(height: DealGoSpacing.s24),
              const _SkeletonBlock(widths: [0.92, 0.7]),
              const SizedBox(height: DealGoSpacing.s12),
              const _SkeletonBlock(widths: [0.84, 0.55]),
              const SizedBox(height: DealGoSpacing.s16),
              const RideNote(
                message: 'Bạn vẫn có thể nhập địa chỉ nếu bản đồ tải chậm.',
              ),
              const SizedBox(height: DealGoSpacing.s8),
              Text(
                'Không có khóa bản đồ. Đà Nẵng dùng điểm mẫu cố định.',
                style: textTheme.bodySmall,
              ),
            ],
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
            label: 'Nhập địa chỉ thủ công',
            trailingIcon: Icons.arrow_forward,
            onPressed: onManual,
          ),
        ),
      ],
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({required this.widths});

  final List<double> widths;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DealGoColors.card,
        borderRadius: BorderRadius.circular(DealGoRadius.card),
        border: Border.all(color: DealGoColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DealGoSpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final width in widths) ...[
              FractionallySizedBox(
                widthFactor: width,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0xFFE7E3EF),
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                  child: SizedBox(height: 12),
                ),
              ),
              const SizedBox(height: DealGoSpacing.s8),
            ],
          ],
        ),
      ),
    );
  }
}

class _MapReady extends StatelessWidget {
  const _MapReady({
    required this.pickup,
    required this.dropoff,
    required this.scheduleNote,
    required this.openRideId,
    required this.onBack,
    required this.onChanged,
    required this.onSchedule,
    required this.onSuggestion,
    required this.onContinue,
  });

  final TextEditingController pickup;
  final TextEditingController dropoff;
  final bool scheduleNote;
  final String? openRideId;
  final VoidCallback onBack;
  final VoidCallback onChanged;
  final VoidCallback onSchedule;
  final ValueChanged<String> onSuggestion;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final places = RidePlaces(
      pickupLabel: pickup.text,
      dropoffLabel: dropoff.text,
    );
    final pendingRideId = openRideId;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        RideScreenHeader(
          title: 'Đặt xe',
          onBack: onBack,
          trailing: const DealGoWordmark(),
        ),
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DealGoDimensions.pageGutter,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(DealGoRadius.card),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  context.read<MapPort>().buildMap(
                    center: const MapLatLng(
                      lat: rideSamplePickupLat,
                      lng: rideSamplePickupLng,
                    ),
                    markers: const [
                      MapLatLng(
                        lat: rideSamplePickupLat,
                        lng: rideSamplePickupLng,
                      ),
                      MapLatLng(
                        lat: rideSampleDropoffLat,
                        lng: rideSampleDropoffLng,
                      ),
                    ],
                  ),
                  const _MapChrome(),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          flex: 6,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              DealGoDimensions.pageGutter,
              DealGoSpacing.s12,
              DealGoDimensions.pageGutter,
              DealGoSpacing.s16,
            ),
            children: [
              Text('Bạn muốn đi đâu?', style: textTheme.titleLarge),
              Text('Khám phá Đà Nẵng cùng DealGo', style: textTheme.bodySmall),
              const SizedBox(height: DealGoSpacing.s12),
              _ModeRow(scheduleNote: scheduleNote, onSchedule: onSchedule),
              if (scheduleNote) ...[
                const SizedBox(height: DealGoSpacing.s8),
                const RideNote(
                  message: 'Đặt lịch chưa mở. Chuyến này là đơn ngay.',
                ),
              ],
              const SizedBox(height: DealGoSpacing.s12),
              _LabelField(
                fieldKey: const Key('ride-pickup-label'),
                icon: Icons.place_outlined,
                label: 'Điểm đón',
                hint: 'Điểm đón',
                controller: pickup,
                onChanged: onChanged,
              ),
              const SizedBox(height: DealGoSpacing.s8),
              _LabelField(
                fieldKey: const Key('ride-dropoff-label'),
                icon: Icons.search,
                label: 'Điểm đến',
                hint: 'Nhập điểm đến của bạn',
                controller: dropoff,
                onChanged: onChanged,
              ),
              const SizedBox(height: DealGoSpacing.s8),
              Text(
                'Tọa độ gửi lên là điểm mẫu Đà Nẵng, kể cả khi bạn đổi tên địa điểm.',
                style: textTheme.bodySmall,
              ),
              const SizedBox(height: DealGoSpacing.s16),
              Row(
                children: [
                  Text(
                    'ĐỊA ĐIỂM GỢI Ý',
                    style: textTheme.labelSmall?.copyWith(
                      color: DealGoColors.textSecondary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Xem tất cả',
                    style: textTheme.labelSmall?.copyWith(
                      color: DealGoColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DealGoSpacing.s8),
              _SuggestionTile(
                icon: Icons.place,
                iconColor: DealGoColors.primary,
                title: 'Cầu Rồng',
                subtitle: 'An Hải, Sơn Trà, Đà Nẵng',
                onTap: () => onSuggestion('Cầu Rồng'),
              ),
              _SuggestionTile(
                key: const Key('ride-suggestion-airport'),
                icon: Icons.flight,
                iconColor: DealGoColors.brandGreen,
                title: 'Sân bay quốc tế Đà Nẵng',
                subtitle: 'Đường Duy Tân, Hải Châu',
                onTap: () => onSuggestion(rideSampleDropoffLabel),
              ),
              if (pendingRideId != null) ...[
                const SizedBox(height: DealGoSpacing.s12),
                DealGoPrimaryButton(
                  label: 'Xem đề xuất đang chờ',
                  onPressed: () =>
                      context.push(RideRoutes.offers(pendingRideId)),
                ),
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
            key: const Key('ride-open-route-overview'),
            label: 'Kiểm tra hành trình',
            trailingIcon: Icons.arrow_forward,
            enabled: places.canContinue,
            onPressed: _continueGuard(places, onContinue),
          ),
        ),
      ],
    );
  }
}

VoidCallback _continueGuard(RidePlaces places, VoidCallback onContinue) {
  if (!places.canContinue) {
    return () {};
  }
  return onContinue;
}

class _ModeRow extends StatelessWidget {
  const _ModeRow({required this.scheduleNote, required this.onSchedule});

  final bool scheduleNote;
  final VoidCallback onSchedule;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const _ModeChip(
          icon: Icons.access_time,
          label: 'Đón ngay',
          selected: true,
          onTap: _noop,
        ),
        const SizedBox(width: DealGoSpacing.s8),
        _ModeChip(
          icon: Icons.calendar_today_outlined,
          label: 'Đặt lịch',
          selected: scheduleNote,
          onTap: onSchedule,
        ),
      ],
    );
  }
}

void _noop() {}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? DealGoColors.primary : DealGoColors.textSecondary;
    return Material(
      color: selected ? DealGoColors.subtlePurple : DealGoColors.card,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DealGoSpacing.s12,
            vertical: DealGoSpacing.s8,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: DealGoSpacing.s4),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: color, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LabelField extends StatelessWidget {
  const _LabelField({
    required this.fieldKey,
    required this.icon,
    required this.label,
    required this.hint,
    required this.controller,
    required this.onChanged,
  });

  final Key fieldKey;
  final IconData icon;
  final String label;
  final String hint;
  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: fieldKey,
      controller: controller,
      textInputAction: TextInputAction.next,
      maxLength: rideLabelMaxLength,
      onChanged: (_) => onChanged(),
      decoration: InputDecoration(
        counterText: '',
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: DealGoColors.primary),
        filled: true,
        fillColor: DealGoColors.card,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DealGoRadius.input),
          borderSide: const BorderSide(color: DealGoColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DealGoRadius.input),
          borderSide: const BorderSide(color: DealGoColors.primary, width: 1.4),
        ),
      ),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: iconColor),
      title: Text(
        title,
        style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(subtitle, style: textTheme.bodySmall),
      onTap: onTap,
    );
  }
}

class _MapChrome extends StatelessWidget {
  const _MapChrome();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Stack(
      children: [
        Positioned(
          left: 12,
          top: 12,
          child: Text(
            'HẢI CHÂU',
            style: textTheme.labelSmall?.copyWith(
              color: DealGoColors.textSecondary,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
        ),
        Positioned(
          right: 16,
          top: 36,
          child: Text(
            'SÔNG HÀN',
            style: textTheme.labelSmall?.copyWith(
              color: const Color(0xFF5B7C99),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const Align(alignment: Alignment(0, -0.05), child: _PickupPin()),
        const Align(alignment: Alignment(0.15, 0.42), child: _HereChip()),
      ],
    );
  }
}

class _PickupPin extends StatelessWidget {
  const _PickupPin();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DealGoColors.card,
        shape: BoxShape.circle,
        border: Border.all(color: DealGoColors.border),
        boxShadow: [
          BoxShadow(
            color: DealGoColors.text.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const SizedBox(
        width: 36,
        height: 36,
        child: Icon(Icons.circle, color: DealGoColors.primary, size: 16),
      ),
    );
  }
}

class _HereChip extends StatelessWidget {
  const _HereChip();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DealGoColors.card,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: DealGoColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DealGoSpacing.s8,
          vertical: DealGoSpacing.s4,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.place, color: DealGoColors.primary, size: 14),
            const SizedBox(width: 4),
            Text(
              'Vị trí hiện tại',
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
