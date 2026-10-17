import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../identity/domain/entities/auth_state.dart';
import '../../../identity/presentation/cubit/auth_cubit.dart';
import '../cubit/driver_duty_cubit.dart';
import '../cubit/driver_feed_cubit.dart';
import '../utils/driver_routes.dart';
import '../widgets/driver_widgets.dart';

class DriverHomePage extends StatelessWidget {
  const DriverHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final feed = context.watch<DriverFeedCubit>().state;
    final online = context.watch<DriverDutyCubit>().state;
    if (feed is DriverFeedIneligible) {
      return const DriverIneligibleView();
    }
    if (!online) {
      return const DriverOfflineView();
    }
    return const DriverOnlineView();
  }
}

class DriverOfflineView extends StatefulWidget {
  const DriverOfflineView({super.key});

  @override
  State<DriverOfflineView> createState() => _DriverOfflineViewState();
}

class _DriverOfflineViewState extends State<DriverOfflineView> {
  var _historyNote = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return DriverPageFrame(
      title: 'Tổng quan tài xế',
      subtitle: driverStateSubtitle,
      onBack: () => driverBack(context),
      footer: DriverFooter(
        secondaryLabel: 'Xem lịch sử',
        primaryLabel: 'Kết nối lại',
        primaryKey: const Key('driver-go-online'),
        onSecondary: () => setState(() => _historyNote = true),
        onPrimary: () => context.read<DriverDutyCubit>().connect(),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          DealGoDimensions.pageGutter,
          DealGoSpacing.s12,
          DealGoDimensions.pageGutter,
          DealGoSpacing.s16,
        ),
        children: [
          const DriverHero(
            icon: Icons.bolt,
            iconColor: DealGoColors.amber,
            background: DealGoColors.amberSurface,
            title: 'Bạn đang ngoại tuyến',
            message: 'Hiện không thể bật nhận việc vì ứng dụng chưa kết nối được với máy chủ.',
          ),
          const SizedBox(height: DealGoSpacing.s24),
          DriverPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tình trạng hoạt động', style: textTheme.titleMedium),
                const SizedBox(height: DealGoSpacing.s12),
                const DriverChip(
                  label: 'Offline · Chưa nhận việc',
                  tone: DriverChipTone.warning,
                ),
                const SizedBox(height: DealGoSpacing.s16),
                const DriverMoneyRow(label: 'Khu vực', value: driverAreaLabel),
                const DriverMoneyRow(
                  label: 'Loại dịch vụ',
                  value: 'Chở khách, Giao đồ ăn',
                ),
              ],
            ),
          ),
          const SizedBox(height: DealGoSpacing.s12),
          const DriverNote(
            message: 'Offline trên thiết bị không đồng nghĩa backend đã đổi trạng thái ca làm. Cần đồng bộ lại.',
          ),
          if (_historyNote) ...[
            const SizedBox(height: DealGoSpacing.s12),
            Text('Chưa có lịch sử ca từ máy chủ.', style: textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

class DriverIneligibleView extends StatefulWidget {
  const DriverIneligibleView({super.key});

  @override
  State<DriverIneligibleView> createState() => _DriverIneligibleViewState();
}

class _DriverIneligibleViewState extends State<DriverIneligibleView> {
  var _licenseNote = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return DriverPageFrame(
      title: 'Tổng quan tài xế',
      subtitle: driverStateSubtitle,
      onBack: () => driverBack(context),
      footer: DriverFooter(
        secondaryLabel: 'Xem điều kiện',
        primaryLabel: 'Cập nhật giấy phép',
        onSecondary: () => setState(() => _licenseNote = true),
        onPrimary: () => setState(() => _licenseNote = true),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          DealGoDimensions.pageGutter,
          DealGoSpacing.s12,
          DealGoDimensions.pageGutter,
          DealGoSpacing.s16,
        ),
        children: [
          const DriverHero(
            icon: Icons.priority_high,
            iconColor: DealGoColors.danger,
            background: DealGoColors.dangerSurface,
            title: 'Tạm hạn chế nhận chuyến',
            message: 'Giấy phép lái xe đã hết hiệu lực. Bạn chưa thể nhận dịch vụ chở khách cho đến khi xác minh lại.',
          ),
          const SizedBox(height: DealGoSpacing.s24),
          DriverPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Quyền theo dịch vụ', style: textTheme.titleMedium),
                const SizedBox(height: DealGoSpacing.s12),
                const _RightRow(
                  label: 'Chở khách',
                  chip: 'Tạm hạn chế',
                  tone: DriverChipTone.danger,
                ),
                const SizedBox(height: DealGoSpacing.s12),
                const _RightRow(
                  label: 'Giao đồ ăn',
                  chip: 'Kiểm tra điều kiện riêng',
                  tone: DriverChipTone.warning,
                ),
                const SizedBox(height: DealGoSpacing.s12),
                const _RightRow(
                  label: 'Giấy phép lái xe',
                  chip: 'Đã hết hạn',
                  tone: DriverChipTone.neutral,
                ),
              ],
            ),
          ),
          const SizedBox(height: DealGoSpacing.s12),
          const DriverNote(
            message: 'Chỉ hạn chế dịch vụ bị ảnh hưởng; các dịch vụ còn lại phải kiểm tra eligibility độc lập.',
          ),
          if (_licenseNote) ...[
            const SizedBox(height: DealGoSpacing.s12),
            Text(
              'Giấy phép được xét trên hệ thống. Thiết bị không tự gia hạn.',
              style: textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _RightRow extends StatelessWidget {
  const _RightRow({
    required this.label,
    required this.chip,
    required this.tone,
  });

  final String label;
  final String chip;
  final DriverChipTone tone;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: DealGoSpacing.s8),
        Flexible(
          child: DriverChip(label: chip, tone: tone),
        ),
      ],
    );
  }
}

class DriverOnlineView extends StatefulWidget {
  const DriverOnlineView({super.key});

  @override
  State<DriverOnlineView> createState() => _DriverOnlineViewState();
}

class _DriverOnlineViewState extends State<DriverOnlineView> {
  var _passengerOn = true;
  var _foodOn = true;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final auth = context.watch<AuthCubit>().state;
    final phone = auth is AuthSignedIn ? auth.profile.phone : null;
    final headline = (phone == null || phone.isEmpty) ? 'Tài xế' : phone;

    return DriverPageFrame(
      title: 'Tổng quan tài xế',
      onBack: () => driverBack(context),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          DealGoDimensions.pageGutter,
          DealGoSpacing.s8,
          DealGoDimensions.pageGutter,
          DealGoSpacing.s24,
        ),
        children: [
          DriverPanel(
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 22,
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
                      Text(
                        headline == 'Tài xế' ? 'Trần Minh Anh' : headline,
                        style: textTheme.titleMedium,
                      ),
                      Text(
                        'Honda Vision · 43H1-123.45',
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                _OnlineBadge(
                  onPressed: () => context.read<DriverDutyCubit>().disconnect(),
                ),
              ],
            ),
          ),
          const SizedBox(height: DealGoSpacing.s12),
          const _DutyMap(),
          const SizedBox(height: DealGoSpacing.s12),
          const Row(
            children: [
              Expanded(
                child: _StatTile(label: 'Chuyến hoàn thành', value: '12'),
              ),
              SizedBox(width: DealGoSpacing.s12),
              Expanded(
                child: _StatTile(
                  label: 'Thu nhập thực nhận',
                  value: '1.250.000đ',
                ),
              ),
            ],
          ),
          const SizedBox(height: DealGoSpacing.s12),
          const Row(
            children: [
              Expanded(
                child: _StatTile(label: 'Đánh giá trung bình', value: '⭐ 4,9'),
              ),
              SizedBox(width: DealGoSpacing.s12),
              Expanded(
                child: _StatTile(
                  label: 'Thời gian hoạt động',
                  value: '2 giờ 30 phút',
                ),
              ),
            ],
          ),
          const SizedBox(height: DealGoSpacing.s12),
          DriverPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Dịch vụ được phép nhận',
                        style: textTheme.titleMedium,
                      ),
                    ),
                    TextButton(
                      key: const Key('driver-open-services'),
                      onPressed: () => context.push(DriverRoutes.services),
                      child: const Text('Cấu hình'),
                    ),
                  ],
                ),
                const SizedBox(height: DealGoSpacing.s8),
                _ServiceSwitch(
                  icon: Icons.two_wheeler,
                  title: 'Chở khách',
                  subtitle: 'Xe máy · Đã duyệt',
                  value: _passengerOn,
                  onChanged: (value) => setState(() => _passengerOn = value),
                ),
                const Divider(height: 1),
                _ServiceSwitch(
                  icon: Icons.inventory_2_outlined,
                  title: 'Giao đồ ăn',
                  subtitle: 'Đã đủ điều kiện',
                  value: _foodOn,
                  onChanged: (value) => setState(() => _foodOn = value),
                ),
              ],
            ),
          ),
          const SizedBox(height: DealGoSpacing.s12),
          const DriverNote(
            tone: DriverNoteTone.green,
            message:
                'Giá và quyền nhận chuyến được kiểm tra bởi hệ thống. Tài xế chỉ có một công việc đang thực hiện tại một thời điểm. Số liệu thống kê trên trang chủ là fixture bố cục.',
          ),
        ],
      ),
    );
  }
}

class _OnlineBadge extends StatelessWidget {
  const _OnlineBadge({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: DealGoColors.greenSurface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        key: const Key('driver-go-offline'),
        onTap: onPressed,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DealGoSpacing.s12,
            vertical: DealGoSpacing.s8,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  color: DealGoColors.brandGreen,
                  shape: BoxShape.circle,
                ),
                child: SizedBox(width: 8, height: 8),
              ),
              const SizedBox(width: DealGoSpacing.s8),
              Text(
                'Online',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: DealGoColors.brandGreen,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DutyMap extends StatelessWidget {
  const _DutyMap();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(DealGoRadius.card),
      child: SizedBox(
        height: 180,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const CustomPaint(painter: _DutyMapPainter()),
            const Positioned(
              left: 12,
              top: 12,
              child: _MapLabel(text: 'Hải Châu · Đà Nẵng'),
            ),
            const Positioned(
              left: 16,
              top: 56,
              child: _MapMark(label: 'HẢI CHÂU'),
            ),
            const Positioned(
              right: 28,
              top: 28,
              child: _MapMark(label: 'CẦU RỒNG'),
            ),
            const Positioned(
              right: 20,
              bottom: 52,
              child: _MapMark(label: 'SÔNG HÀN'),
            ),
            const Align(
              alignment: Alignment(0.15, 0.05),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: DealGoColors.card,
                  shape: BoxShape.circle,
                ),
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: Icon(
                    Icons.two_wheeler,
                    color: DealGoColors.primary,
                    size: 20,
                  ),
                ),
              ),
            ),
            const Positioned(
              right: 12,
              bottom: 12,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: DealGoColors.primary,
                  borderRadius: BorderRadius.all(Radius.circular(999)),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: DealGoSpacing.s12,
                    vertical: DealGoSpacing.s8,
                  ),
                  child: Text(
                    'Khu vực hoạt động',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapLabel extends StatelessWidget {
  const _MapLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DealGoColors.card,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DealGoSpacing.s8,
          vertical: DealGoSpacing.s4,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.place, color: DealGoColors.danger, size: 16),
            const SizedBox(width: 4),
            Text(
              text,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapMark extends StatelessWidget {
  const _MapMark({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: const Color(0xFF5B7C99),
        fontWeight: FontWeight.w800,
        letterSpacing: 0.4,
      ),
    );
  }
}

class _DutyMapPainter extends CustomPainter {
  const _DutyMapPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFE7EEF5),
    );
    final street = Paint()
      ..color = const Color(0xFFF7F4EA)
      ..strokeWidth = 14
      ..style = PaintingStyle.stroke;
    for (var y = 18.0; y < size.height; y += 36) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 10), street);
    }
    for (var x = 12.0; x < size.width; x += 46) {
      canvas.drawLine(Offset(x, 0), Offset(x + 16, size.height), street);
    }
    final river = Path()
      ..moveTo(size.width * 0.62, 0)
      ..quadraticBezierTo(
        size.width * 0.84,
        size.height * 0.45,
        size.width * 0.5,
        size.height,
      )
      ..lineTo(size.width * 0.68, size.height)
      ..quadraticBezierTo(
        size.width * 0.98,
        size.height * 0.4,
        size.width * 0.78,
        0,
      )
      ..close();
    canvas.drawPath(river, Paint()..color = const Color(0xFFD5E6F5));

    final route = Path()
      ..moveTo(size.width * 0.18, size.height * 0.78)
      ..lineTo(size.width * 0.18, size.height * 0.42)
      ..lineTo(size.width * 0.46, size.height * 0.42)
      ..lineTo(size.width * 0.46, size.height * 0.22)
      ..lineTo(size.width * 0.72, size.height * 0.22);
    canvas.drawPath(
      route,
      Paint()
        ..color = DealGoColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(
      Offset(size.width * 0.72, size.height * 0.22),
      5,
      Paint()..color = DealGoColors.danger,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return DriverPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: textTheme.bodySmall),
          const SizedBox(height: DealGoSpacing.s8),
          Text(value, style: textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _ServiceSwitch extends StatelessWidget {
  const _ServiceSwitch({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: DealGoColors.canvas,
            borderRadius: BorderRadius.circular(12),
          ),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, color: DealGoColors.primary),
          ),
        ),
        const SizedBox(width: DealGoSpacing.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: textTheme.titleMedium?.copyWith(fontSize: 16)),
              Text(subtitle, style: textTheme.bodySmall),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.white;
            }
            return DealGoColors.textSecondary;
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return DealGoColors.brandGreen;
            }
            return DealGoColors.border;
          }),
        ),
      ],
    );
  }
}
