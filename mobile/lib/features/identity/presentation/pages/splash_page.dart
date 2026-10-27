import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/components/dealgo_logo.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/storage/onboarding_storage.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../identity/domain/auth_redirect.dart';
import '../../../identity/domain/entities/auth_state.dart';
import '../../../identity/presentation/cubit/auth_cubit.dart';

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

  /// False once something else (a cold-start push tap, a deep link, the auth
  /// redirect) already navigated away: the splash may still be mounted
  /// during the outgoing transition and must not drag the user back to home.
  bool get _stillOnSplash {
    if (!mounted) return false;
    final route = ModalRoute.of(context);
    return route == null || route.isCurrent;
  }

  Future<void> _proceed() async {
    if (!_stillOnSplash) return;

    try {
      final authCubit = context.read<AuthCubit>();
      final state = authCubit.state;
      if (state is AuthSignedIn) {
        context.go('/customer');
        return;
      }
    } catch (_) {}

    final hasSeenOnboarding = await _storage.hasSeenOnboarding();
    if (!mounted || !_stillOnSplash) return;

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
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: DealGoColors.canvas,
      body: Stack(
        children: [
          Positioned(
            top: -48,
            left: -56,
            child: _SoftBlob(
              size: 200,
              color: DealGoColors.primary.withValues(alpha: 0.06),
            ),
          ),
          Positioned(
            top: 210,
            right: -70,
            child: _SoftBlob(
              size: 220,
              color: DealGoColors.brandGreen.withValues(alpha: 0.05),
            ),
          ),
          Positioned(
            bottom: 80,
            left: -40,
            child: _SoftBlob(
              size: 160,
              color: DealGoColors.primary.withValues(alpha: 0.04),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: DealGoSpacing.s20),
                DealGoLogo.stacked(size: 58, subtitle: l10n.splashTagline),
                const SizedBox(height: DealGoSpacing.s12),
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: DealGoSpacing.s16,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(
                            DealGoRadius.card,
                          ),
                          child: Image.asset(
                            'assets/images/hero_dealgo_danang.png',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  height: 240,
                                  decoration: BoxDecoration(
                                    color: DealGoColors.subtlePurple,
                                    borderRadius: BorderRadius.circular(
                                      DealGoRadius.card,
                                    ),
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      DealGoIcons.city,
                                      size: 72,
                                      color: DealGoColors.primary,
                                    ),
                                  ),
                                ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 20,
                        left: 16,
                        child: _ServiceFloatBadge(
                          icon: DealGoIcons.car,
                          iconBgColor: DealGoColors.primary,
                          title: l10n.serviceRideTitle,
                          subtitle: l10n.serviceRideBlurb,
                        ),
                      ),
                      Positioned(
                        top: 96,
                        right: 16,
                        child: _ServiceFloatBadge(
                          icon: DealGoIcons.shoppingBag,
                          iconBgColor: DealGoColors.brandGreen,
                          title: l10n.serviceFoodTitle,
                          subtitle: l10n.serviceFoodBlurb,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DealGoDimensions.pageGutter * 2,
                    vertical: DealGoSpacing.s24,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedBuilder(
                        animation: _controller,
                        builder: (context, child) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(
                              DealGoRadius.small,
                            ),
                            child: ColoredBox(
                              color: DealGoColors.border.withValues(
                                alpha: 0.55,
                              ),
                              child: SizedBox(
                                height: 5,
                                width: double.infinity,
                                child: FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: ((_controller.value * 0.7) + 0.3)
                                      .clamp(0.0, 1.0),
                                  child: const ColoredBox(
                                    color: DealGoColors.primary,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: DealGoSpacing.s12),
                      Text(
                        l10n.splashPreparing,
                        style: textTheme.labelSmall,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SoftBlob extends StatelessWidget {
  const _SoftBlob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
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
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DealGoSpacing.s12,
        vertical: DealGoSpacing.s8,
      ),
      decoration: BoxDecoration(
        color: DealGoColors.card.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(DealGoRadius.card),
        border: Border.all(color: DealGoColors.card, width: 1.5),
        boxShadow: DealGoShadows.floating,
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
            child: Icon(icon, color: DealGoColors.card, size: 20),
          ),
          const SizedBox(width: DealGoSpacing.s12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: DealGoColors.text,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: DealGoColors.textSecondary,
                  height: 1.25,
                ),
              ),
            ],
          ),
          const SizedBox(width: DealGoSpacing.s8),
          Container(
            width: 26,
            height: 26,
            decoration: const BoxDecoration(
              color: DealGoColors.canvas,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              DealGoIcons.arrowRight,
              size: 14,
              color: DealGoColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
