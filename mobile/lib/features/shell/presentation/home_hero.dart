import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../identity/presentation/widgets/auth_widgets.dart';
import 'home_shared.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const DealGoWordmark(),
              Text(AppLocalizations.of(context).homeTagline, style: textTheme.bodySmall),
            ],
          ),
        ),
        const _LocationChip(),
        const SizedBox(width: DealGoSpacing.s8),
        const _Bell(),
        const SizedBox(width: DealGoSpacing.s8),
        const _Avatar(),
      ],
    );
  }
}

class _LocationChip extends StatelessWidget {
  const _LocationChip();

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
          vertical: DealGoSpacing.s8,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.place, color: DealGoColors.primary, size: 16),
            const SizedBox(width: 2),
            Text(
              AppLocalizations.of(context).homeCitySample,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: DealGoColors.text,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Icon(
              Icons.expand_more,
              size: 16,
              color: DealGoColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _Bell extends StatelessWidget {
  const _Bell();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              color: DealGoColors.card,
              shape: BoxShape.circle,
              border: Border.fromBorderSide(
                BorderSide(color: DealGoColors.border),
              ),
            ),
            child: SizedBox(
              width: 36,
              height: 36,
              child: Icon(
                Icons.notifications_none_rounded,
                color: DealGoColors.text,
                size: 20,
              ),
            ),
          ),
          Positioned(
            right: 6,
            top: 6,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: DealGoColors.danger,
                shape: BoxShape.circle,
                border: Border.all(color: DealGoColors.card, width: 1.5),
              ),
              child: const SizedBox(width: 8, height: 8),
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar();

  @override
  Widget build(BuildContext context) {
    return const CircleAvatar(
      radius: 18,
      backgroundColor: DealGoColors.subtlePurple,
      child: Icon(Icons.person, color: DealGoColors.primary, size: 20),
    );
  }
}

class HomeSearch extends StatelessWidget {
  const HomeSearch({super.key});

  @override
  Widget build(BuildContext context) {
    return TextField(
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Tìm điểm đến, cửa hàng, món ăn...',
        hintStyle: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: DealGoColors.textSecondary),
        filled: true,
        fillColor: DealGoColors.card,
        prefixIcon: const Icon(Icons.search, color: DealGoColors.textSecondary),
        suffixIcon: const Icon(
          Icons.qr_code_scanner,
          color: DealGoColors.textSecondary,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: DealGoSpacing.s12),
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

class HeroBanner extends StatelessWidget {
  const HeroBanner({required this.onExplore, super.key});

  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(DealGoRadius.card),
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/hero_danang_sunset_clean.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) {
                return const CustomPaint(painter: _DanangBannerPainter());
              },
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.black.withValues(alpha: 0.55),
                    Colors.black.withValues(alpha: 0.15),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DealGoSpacing.s16,
              DealGoSpacing.s16,
              108,
              DealGoSpacing.s16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    children: const [
                      TextSpan(
                        text: 'Deal',
                        style: TextStyle(color: Colors.white),
                      ),
                      TextSpan(
                        text: 'Go',
                        style: TextStyle(color: Color(0xFF86EFAC)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: DealGoSpacing.s4),
                Text(
                  'Một ứng dụng\nvạn trải nghiệm',
                  style: textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontSize: 20,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: DealGoSpacing.s4),
                Text(
                  'Đặt xe · Mua sắm · Giao hàng\nTiện lợi mỗi ngày tại Đà Nẵng',
                  style: textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.92),
                  ),
                ),
                const SizedBox(height: DealGoSpacing.s12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: HomePillButton(
                    label: AppLocalizations.of(context).actionExplore,
                    onPressed: onExplore,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 16,
            top: 28,
            child: Text(
              'Đà Nẵng\nđẹp đâu cũng gần',
              textAlign: TextAlign.right,
              style: textTheme.bodyMedium?.copyWith(
                color: const Color(0xFFFFE7A3),
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DanangBannerPainter extends CustomPainter {
  const _DanangBannerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final sky = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1B2A6D), Color(0xFF6B4C93), Color(0xFFE08A62)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, sky);

    final river = Path()
      ..moveTo(0, size.height * 0.68)
      ..quadraticBezierTo(
        size.width * 0.45,
        size.height * 0.55,
        size.width,
        size.height * 0.72,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(river, Paint()..color = const Color(0xFF1D4E86));

    final tower = Paint()..color = const Color(0xFF24325F);
    for (var index = 0; index < 5; index++) {
      final height = 36.0 + (index % 3) * 16;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            12.0 + index * 14,
            size.height * 0.42 - height * 0.2,
            10,
            height,
          ),
          const Radius.circular(2),
        ),
        tower,
      );
    }

    final bridge = Paint()
      ..color = const Color(0xFFF0D48A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromLTWH(
        size.width * 0.46,
        size.height * 0.42,
        size.width * 0.28,
        70,
      ),
      math.pi,
      math.pi,
      false,
      bridge,
    );
    final dragon = Path()
      ..moveTo(size.width * 0.42, size.height * 0.62)
      ..cubicTo(
        size.width * 0.55,
        size.height * 0.28,
        size.width * 0.72,
        size.height * 0.7,
        size.width * 0.9,
        size.height * 0.4,
      );
    canvas.drawPath(
      dragon,
      bridge
        ..color = const Color(0xFFFFD15C)
        ..strokeWidth = 4,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

