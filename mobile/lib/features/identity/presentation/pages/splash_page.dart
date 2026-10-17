import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/components/dealgo_logo.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/storage/onboarding_storage.dart';
import '../../../identity/domain/auth_redirect.dart';
import '../../../identity/domain/entities/auth_state.dart';
import '../../../identity/presentation/cubit/auth_cubit.dart';

/// Full-screen Splash Screen corresponding to Mockup S001.
/// Displays DealGo branding, Đà Nẵng hero visual, key service highlights,
/// an animated loading progress bar, and handles initial auto-navigation.
class DealGoSplashScreen extends StatefulWidget {
  const DealGoSplashScreen({
    super.key,
    this.autoNavigate = true,
    this.minDuration = const Duration(milliseconds: 1500),
    this.storage,
  });

  final bool autoNavigate;
  final Duration minDuration;
  final OnboardingStorage? storage;

  @override
  State<DealGoSplashScreen> createState() => _DealGoSplashScreenState();
}

class _DealGoSplashScreenState extends State<DealGoSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final OnboardingStorage _storage;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _storage = widget.storage ?? SecureOnboardingStorage();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    if (widget.autoNavigate) {
      _startBootstrapTimer();
    }
  }

  void _startBootstrapTimer() {
    _timer = Timer(widget.minDuration, () {
      if (!mounted) return;
      _proceed();
    });
  }

  Future<void> _proceed() async {
    if (!mounted) return;

    // Check auth state if available in context
    try {
      final authCubit = context.read<AuthCubit>();
      final state = authCubit.state;
      if (state is AuthSignedIn) {
        context.go('/customer');
        return;
      }
    } catch (_) {
      // In standalone test without BlocProvider, proceed to onboarding check
    }

    final hasSeenOnboarding = await _storage.hasSeenOnboarding();
    if (!mounted) return;

    if (hasSeenOnboarding) {
      context.go(AuthRoutes.login);
    } else {
      context.go(AuthRoutes.onboarding);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
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
            const SizedBox(height: DealGoSpacing.s20),

            // Top Brand Section
            const DealGoLogo.stacked(
              size: 58,
              subtitle: 'Đi muôn nơi · Ăn vạn món',
            ),

            const SizedBox(height: DealGoSpacing.s12),

            // Middle Visual Hero Section with Floating Badges
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // High-fidelity Da Nang Hero Visual (Bridge, car, pho, milk tea)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: DealGoSpacing.s16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(DealGoRadius.card),
                      child: Image.asset(
                        'assets/images/hero_dealgo_danang.png',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 240,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
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

                  // Floating Service Badge: Đặt xe (top left)
                  Positioned(
                    top: 18,
                    left: 20,
                    child: _ServiceFloatBadge(
                      icon: Icons.directions_car_filled_rounded,
                      iconBgColor: DealGoColors.primary,
                      title: 'Đặt xe',
                      subtitle: 'Đi muôn nơi\nan toàn, tiện lợi',
                    ),
                  ),

                  // Floating Service Badge: Đồ ăn (middle right)
                  Positioned(
                    bottom: 24,
                    right: 20,
                    child: _ServiceFloatBadge(
                      icon: Icons.shopping_bag_rounded,
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
    required this.iconBgColor,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color iconBgColor;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBgColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: iconBgColor.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: DealGoColors.text,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: DealGoColors.textSecondary,
                  height: 1.25,
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          Container(
            width: 26,
            height: 26,
            decoration: const BoxDecoration(
              color: DealGoColors.canvas,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.arrow_forward_rounded,
              size: 14,
              color: DealGoColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
