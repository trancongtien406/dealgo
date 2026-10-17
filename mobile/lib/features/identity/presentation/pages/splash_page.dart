import 'package:flutter/material.dart';

import '../../../../core/design_system/components/dealgo_logo.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';

/// Full-screen Splash Screen corresponding to Mockup S001.
/// Displays DealGo branding, Đà Nẵng hero visual, key service highlights,
/// and an animated loading progress bar.
class DealGoSplashScreen extends StatefulWidget {
  const DealGoSplashScreen({super.key});

  @override
  State<DealGoSplashScreen> createState() => _DealGoSplashScreenState();
}

class _DealGoSplashScreenState extends State<DealGoSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DealGoColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: DealGoSpacing.s24),

            // Top Brand Section
            const DealGoLogo.stacked(
              size: 68,
              subtitle: 'Đi muôn nơi · Ăn vạn món',
            ),

            const SizedBox(height: DealGoSpacing.s16),

            // Middle Visual Hero Section
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Danang Landmark & Transport Background
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: DealGoSpacing.s16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(DealGoRadius.card),
                      child: Image.asset(
                        'assets/images/banner_danang_hero.png',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 240,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                DealGoColors.subtlePurple,
                                DealGoColors.greenSurface,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(DealGoRadius.card),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.location_city_rounded,
                              size: 72,
                              color: DealGoColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Floating Service Badge: Ride
                  Positioned(
                    top: 24,
                    left: 20,
                    child: _ServiceFloatBadge(
                      icon: Icons.directions_car_rounded,
                      iconColor: Colors.white,
                      iconBgColor: DealGoColors.primary,
                      title: 'Đặt xe',
                      subtitle: 'Đi muôn nơi\nan toàn, tiện lợi',
                    ),
                  ),

                  // Floating Service Badge: Food
                  Positioned(
                    bottom: 28,
                    right: 20,
                    child: _ServiceFloatBadge(
                      icon: Icons.shopping_bag_rounded,
                      iconColor: Colors.white,
                      iconBgColor: DealGoColors.brandGreen,
                      title: 'Đồ ăn',
                      subtitle: 'Hàng ngàn món\nngon mỗi ngày',
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Progress Bar & Loading Message
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DealGoDimensions.pageGutter * 2,
                vertical: DealGoSpacing.s24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated Gradient Loading Bar
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          height: 5,
                          width: double.infinity,
                          color: DealGoColors.border.withValues(alpha: 0.5),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: ((_controller.value * 0.7) + 0.3).clamp(0.0, 1.0),
                            child: Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    DealGoColors.primary,
                                    DealGoColors.brandGreen,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: DealGoSpacing.s12),
                  const Text(
                    'Đang chuẩn bị trải nghiệm của bạn...',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: DealGoColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceFloatBadge extends StatelessWidget {
  const _ServiceFloatBadge({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DealGoColors.border.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconBgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: DealGoColors.text,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: DealGoColors.textSecondary,
                  height: 1.25,
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.arrow_forward_rounded,
            size: 15,
            color: DealGoColors.textSecondary,
          ),
        ],
      ),
    );
  }
}
