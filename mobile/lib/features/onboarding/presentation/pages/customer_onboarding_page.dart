import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/components/dealgo_logo.dart';
import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/storage/onboarding_storage.dart';
import '../../../identity/domain/auth_redirect.dart';

class OnboardingSlide {
  const OnboardingSlide({
    required this.title,
    required this.highlightText,
    required this.highlightColor,
    required this.description,
    required this.heroAsset,
    required this.pill1Icon,
    required this.pill1Color,
    required this.pill1Title,
    required this.pill1Subtitle,
    required this.pill2Icon,
    required this.pill2Color,
    required this.pill2Title,
    required this.pill2Subtitle,
    required this.accentIcon,
    required this.accentColor,
    required this.accentLabel,
    this.overlayAsset,
  });

  final String title;
  final String highlightText;
  final Color highlightColor;
  final String description;
  final String heroAsset;
  final IconData pill1Icon;
  final Color pill1Color;
  final String pill1Title;
  final String pill1Subtitle;
  final IconData pill2Icon;
  final Color pill2Color;
  final String pill2Title;
  final String pill2Subtitle;
  final IconData accentIcon;
  final Color accentColor;
  final String accentLabel;
  final String? overlayAsset;
}

/// Customer Onboarding Walkthrough corresponding to Mockup S002.
/// Fully dynamic across Step 1 (Overview), Step 2 (Ride), and Step 3 (Food).
class CustomerOnboardingPage extends StatefulWidget {
  const CustomerOnboardingPage({
    super.key,
    this.onComplete,
    this.storage,
  });

  final VoidCallback? onComplete;
  final OnboardingStorage? storage;

  @override
  State<CustomerOnboardingPage> createState() => _CustomerOnboardingPageState();
}

class _CustomerOnboardingPageState extends State<CustomerOnboardingPage> {
  final PageController _pageController = PageController();
  late final OnboardingStorage _storage;
  int _currentIndex = 0;

  final List<OnboardingSlide> _slides = const [
    // Step 1: Siêu ứng dụng Đà Nẵng (S002 Concept)
    OnboardingSlide(
      title: 'Một ứng dụng,\n',
      highlightText: 'vạn trải nghiệm',
      highlightColor: DealGoColors.primary,
      description:
          'Đặt xe, khám phá món ngon và mua sắm hằng ngày — tất cả trong DealGo.',
      heroAsset: 'assets/images/hero_dealgo_danang.png',
      pill1Icon: Icons.directions_car_filled_rounded,
      pill1Color: DealGoColors.primary,
      pill1Title: 'Đặt xe',
      pill1Subtitle: 'Đi muôn nơi\nan toàn, tiện lợi',
      pill2Icon: Icons.shopping_bag_rounded,
      pill2Color: DealGoColors.brandGreen,
      pill2Title: 'Đồ ăn',
      pill2Subtitle: 'Hàng ngàn món\nngon mỗi ngày',
      accentIcon: Icons.verified_rounded,
      accentColor: DealGoColors.primary,
      accentLabel: 'Nền tảng công nghệ Đà Nẵng',
    ),

    // Step 2: Di chuyển thông minh & Giá thương lượng (Ride)
    OnboardingSlide(
      title: 'Di chuyển nhanh,\n',
      highlightText: 'an toàn & tiết kiệm',
      highlightColor: DealGoColors.primary,
      description:
          'Tài xế bản địa đón tận nơi, theo dõi lộ trình thời gian thực, cước phí minh bạch và tự do thương lượng giá.',
      heroAsset: 'assets/images/hero_danang_sunset_clean.png',
      overlayAsset: 'assets/images/vehicle_scooter_green.png',
      pill1Icon: Icons.two_wheeler_rounded,
      pill1Color: DealGoColors.primary,
      pill1Title: 'Xe máy & Ô tô',
      pill1Subtitle: 'Đón nhanh chỉ\ntừ 3 phút',
      pill2Icon: Icons.handshake_rounded,
      pill2Color: DealGoColors.amber,
      pill2Title: 'Giá thương lượng',
      pill2Subtitle: 'Chủ động chốt\ngiá ưng ý',
      accentIcon: Icons.location_on_rounded,
      accentColor: DealGoColors.amber,
      accentLabel: '100% Bác tài bản địa thân thiện',
    ),

    // Step 3: Ẩm thực & Món ngon nóng hổi (Food)
    OnboardingSlide(
      title: 'Món ngon nóng hổi,\n',
      highlightText: 'giao siêu tốc',
      highlightColor: DealGoColors.brandGreen,
      description:
          'Hàng ngàn quán ăn, nhà hàng đặc sản chuẩn vị Đà Nẵng sẵn sàng phục vụ bạn. Đặt món dễ dàng, giao tận tay trong 20 phút.',
      heroAsset: 'assets/images/hero_food_clean.png',
      pill1Icon: Icons.restaurant_rounded,
      pill1Color: DealGoColors.brandGreen,
      pill1Title: 'Đặc sản chuẩn vị',
      pill1Subtitle: 'Mì Quảng, Bún chả cá,\nBánh mì giòn',
      pill2Icon: Icons.bolt_rounded,
      pill2Color: DealGoColors.primary,
      pill2Title: 'Giao siêu tốc 20\'',
      pill2Subtitle: 'Món ngon luôn\nnóng hổi tận tay',
      accentIcon: Icons.storefront_rounded,
      accentColor: DealGoColors.brandGreen,
      accentLabel: 'Hơn 1.500+ quán ngon Đà Nẵng',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _storage = widget.storage ?? SecureOnboardingStorage();
  }

  Future<void> _finishOnboarding() async {
    try {
      await _storage.setSeenOnboarding(true);
    } catch (_) {}
    if (!mounted) return;

    if (widget.onComplete != null) {
      widget.onComplete!();
    } else {
      context.go(AuthRoutes.login);
    }
  }

  void _nextPage() {
    if (_currentIndex < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DealGoColors.canvas,
      body: Stack(
        children: [
          // Subtle background glow orbs matching S002 aesthetic
          Positioned(
            top: -40,
            left: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: DealGoColors.primary.withValues(alpha: 0.05),
              ),
            ),
          ),
          Positioned(
            top: 220,
            right: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: DealGoColors.brandGreen.withValues(alpha: 0.05),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top Bar: Logo DealGo
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DealGoDimensions.pageGutter,
                    vertical: DealGoSpacing.s8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: const [
                      DealGoLogo.wordmark(size: 26),
                    ],
                  ),
                ),

                // Main Content Swipable PageView (Hero graphic + floating cards + title + desc)
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _slides.length,
                    onPageChanged: (index) {
                      setState(() => _currentIndex = index);
                    },
                    itemBuilder: (context, index) {
                      final slide = _slides[index];
                      return Column(
                        children: [
                          // Top 3D Visual Hero with floating cards
                          Expanded(
                            flex: 5,
                            child: _SlideHeroVisual(slide: slide),
                          ),

                          // Bottom Text Content
                          Expanded(
                            flex: 3,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: DealGoDimensions.pageGutter * 1.5,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text.rich(
                                    TextSpan(
                                      style: const TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w800,
                                        color: DealGoColors.text,
                                        height: 1.25,
                                        letterSpacing: -0.5,
                                      ),
                                      children: [
                                        TextSpan(text: slide.title),
                                        TextSpan(
                                          text: slide.highlightText,
                                          style: TextStyle(
                                            color: slide.highlightColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: DealGoSpacing.s12),
                                  Text(
                                    slide.description,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                      color: DealGoColors.textSecondary,
                                      height: 1.45,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),

                // Bottom Action Area: Indicators, Primary Button & Step Label
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DealGoDimensions.pageGutter,
                  ),
                  child: Column(
                    children: [
                      // Pagination Dots Indicator
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_slides.length, (index) {
                          final isSelected = index == _currentIndex;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: isSelected ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? DealGoColors.primary
                                  : DealGoColors.border,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                      ),

                      const SizedBox(height: DealGoSpacing.s20),

                      // Primary Next / Continue Button
                      DealGoPrimaryButton(
                        key: const Key('onboarding-next-btn'),
                        label: 'Tiếp tục',
                        trailingIcon: Icons.arrow_forward_rounded,
                        onPressed: _nextPage,
                      ),
                      const SizedBox(height: DealGoSpacing.s8),
                      Text(
                        'Bước ${_currentIndex + 1} trong ${_slides.length}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: DealGoColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: DealGoSpacing.s8),
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

/// Renders the 3D Graphic Composition for a specific onboarding slide
class _SlideHeroVisual extends StatelessWidget {
  const _SlideHeroVisual({required this.slide});

  final OnboardingSlide slide;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Soft atmospheric glow behind subject
            Positioned(
              top: 10,
              left: 30,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: slide.pill1Color.withValues(alpha: 0.08),
                ),
              ),
            ),
            Positioned(
              bottom: 20,
              right: 30,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: slide.pill2Color.withValues(alpha: 0.08),
                ),
              ),
            ),

            // Base Hero Image Container
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: DealGoSpacing.s16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(DealGoRadius.card),
                child: Image.asset(
                  slide.heroAsset,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 220,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          slide.pill1Color.withValues(alpha: 0.15),
                          slide.pill2Color.withValues(alpha: 0.15),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(DealGoRadius.card),
                    ),
                    child: Center(
                      child: Icon(
                        slide.pill1Icon,
                        size: 72,
                        color: slide.pill1Color,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Optional 3D vehicle overlay for slide 2 (Ride)
            if (slide.overlayAsset != null)
              Positioned(
                bottom: 12,
                right: 36,
                child: Image.asset(
                  slide.overlayAsset!,
                  height: 125,
                  fit: BoxFit.contain,
                ),
              ),

            // Floating Pill 1 (Top-Left)
            Positioned(
              top: 14,
              left: 16,
              child: _FloatingServicePill(
                icon: slide.pill1Icon,
                iconBgColor: slide.pill1Color,
                title: slide.pill1Title,
                subtitle: slide.pill1Subtitle,
              ),
            ),

            // Floating Pill 2 (Top-Right / Middle-Right)
            Positioned(
              top: 76,
              right: 16,
              child: _FloatingServicePill(
                icon: slide.pill2Icon,
                iconBgColor: slide.pill2Color,
                title: slide.pill2Title,
                subtitle: slide.pill2Subtitle,
              ),
            ),

            // Bottom Accent Badge
            Positioned(
              bottom: 8,
              child: _AccentPill(
                icon: slide.accentIcon,
                iconColor: slide.accentColor,
                label: slide.accentLabel,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Glassmorphism Floating Pill Badge with Icon, 2-line title/subtitle, and Trailing Arrow
class _FloatingServicePill extends StatelessWidget {
  const _FloatingServicePill({
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
            width: 38,
            height: 38,
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
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: DealGoColors.textSecondary,
                  height: 1.25,
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: DealGoColors.canvas,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.arrow_forward_rounded,
              size: 13,
              color: DealGoColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Subtle Bottom Tag for Localized Trust / Quality Accent
class _AccentPill extends StatelessWidget {
  const _AccentPill({
    required this.icon,
    required this.iconColor,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: DealGoColors.text,
            ),
          ),
        ],
      ),
    );
  }
}
