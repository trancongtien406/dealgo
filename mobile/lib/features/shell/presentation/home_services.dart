import 'package:flutter/material.dart';

import '../../../core/design_system/components/dealgo_illustration.dart';
import '../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../l10n/app_localizations.dart';
import 'home_shared.dart';

class ServiceRow extends StatelessWidget {
  const ServiceRow({required this.onBook, required this.onFood, super.key});

  final VoidCallback onBook;
  final VoidCallback onFood;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _ServiceCard(
            title: 'Đặt xe',
            subtitle: 'Đi muôn nơi\nan toàn, tiện lợi',
            background: const Color(0xFFF3EAFF),
            icon: Icons.two_wheeler,
            iconColor: DealGoColors.primary,
            illustration: Image.asset(
              'assets/images/service_ride_clean.png',
              height: 72,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stack) {
                return const DealGoIllustration(
                  'assets/illustrations/vehicle_motorbike.svg',
                  height: 72,
                );
              },
            ),
            onTap: onBook,
          ),
        ),
        const SizedBox(width: DealGoSpacing.s12),
        Expanded(
          child: _ServiceCard(
            title: 'Đồ ăn',
            subtitle: 'Hàng ngàn cửa hàng\ngiao tận nơi',
            background: const Color(0xFFE7F8EC),
            icon: Icons.shopping_bag_outlined,
            iconColor: DealGoColors.brandGreen,
            illustration: Image.asset(
              'assets/images/service_food_clean.png',
              height: 72,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stack) {
                return const DealGoIllustration(
                  'assets/illustrations/card_food.svg',
                  height: 72,
                );
              },
            ),
            onTap: onFood,
          ),
        ),
      ],
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.title,
    required this.subtitle,
    required this.background,
    required this.icon,
    required this.iconColor,
    required this.illustration,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final Color background;
  final IconData icon;
  final Color iconColor;
  final Widget illustration;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(DealGoRadius.card),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(DealGoSpacing.s12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: iconColor, size: 18),
                  const SizedBox(width: DealGoSpacing.s8),
                  Expanded(
                    child: Text(
                      title,
                      style: textTheme.titleMedium?.copyWith(fontSize: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DealGoSpacing.s4),
              Text(subtitle, style: textTheme.bodySmall),
              const SizedBox(height: DealGoSpacing.s8),
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Align(alignment: Alignment.centerRight, child: illustration),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: iconColor,
                      shape: BoxShape.circle,
                    ),
                    child: const SizedBox(
                      width: 28,
                      height: 28,
                      child: Icon(
                        Icons.arrow_forward,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class QuickBookCard extends StatelessWidget {
  const QuickBookCard({required this.onBook, super.key});

  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DealGoColors.card,
        borderRadius: BorderRadius.circular(DealGoRadius.card),
        border: Border.all(color: DealGoColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DealGoSpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.two_wheeler,
                  color: DealGoColors.primary,
                  size: 20,
                ),
                const SizedBox(width: DealGoSpacing.s8),
                Expanded(
                  child: Text('Đặt xe nhanh', style: textTheme.titleMedium),
                ),
                const _MotorbikeChip(),
              ],
            ),
            const SizedBox(height: DealGoSpacing.s16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(child: _RoutePreview()),
                const SizedBox(width: DealGoSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ước tính', style: textTheme.bodySmall),
                      const SizedBox(height: DealGoSpacing.s4),
                      Text(
                        '~ 42.000đ',
                        style: textTheme.titleMedium?.copyWith(
                          color: DealGoColors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: DealGoSpacing.s8),
                      Text('Thời gian ~ 12 phút', style: textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: DealGoSpacing.s16),
            HomePillButton(
              label: AppLocalizations.of(context).actionBookRideNow,
              onPressed: onBook,
              expanded: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _MotorbikeChip extends StatelessWidget {
  const _MotorbikeChip();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DealGoColors.canvas,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: DealGoColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DealGoSpacing.s8,
          vertical: DealGoSpacing.s4,
        ),
        child: Text(
          'Xe máy',
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: DealGoColors.text, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _RoutePreview extends StatelessWidget {
  const _RoutePreview();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        _StopLine(
          color: DealGoColors.brandGreen,
          label: AppLocalizations.of(context).ridePickup,
          value: '123 Nguyễn Văn Linh, Hải Châu, Đà Nẵng',
          style: textTheme,
        ),
        const SizedBox(height: DealGoSpacing.s8),
        const Icon(
          Icons.swap_vert,
          size: 16,
          color: DealGoColors.textSecondary,
        ),
        const SizedBox(height: DealGoSpacing.s8),
        _StopLine(
          color: DealGoColors.danger,
          label: AppLocalizations.of(context).rideDropoff,
          value: 'Bạn muốn đi đâu?',
          style: textTheme,
        ),
      ],
    );
  }
}

class _StopLine extends StatelessWidget {
  const _StopLine({
    required this.color,
    required this.label,
    required this.value,
    required this.style,
  });

  final Color color;
  final String label;
  final String value;
  final TextTheme style;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: DecoratedBox(
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: const SizedBox(width: 8, height: 8),
          ),
        ),
        const SizedBox(width: DealGoSpacing.s8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: style.bodySmall),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: style.bodySmall?.copyWith(
                  color: DealGoColors.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
