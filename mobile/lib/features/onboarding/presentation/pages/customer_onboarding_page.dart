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
    required this.description,
  });

  final String title;
  final String highlightText;
  final String description;
}

/// Customer Onboarding Walkthrough corresponding to Mockup S002.
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
    OnboardingSlide(
      title: 'Một ứng dụng,\n',
      highlightText: 'vạn trải nghiệm',
      description:
          'Đặt xe, khám phá món ngon và mua sắm hằng ngày — tất cả trong DealGo.',
    ),
    OnboardingSlide(
      title: 'Di chuyển nhanh,\n',
      highlightText: 'an toàn & tiết kiệm',
      description:
          'Tài xế bản địa đón tận nơi, theo dõi lộ trình thời gian thực, cước phí minh bạch.',
    ),
    OnboardingSlide(
      title: 'Món ngon nóng hổi,\n',
      highlightText: 'giao siêu tốc',
      description:
          'Hàng ngàn quán ăn, nhà hàng đặc sản chuẩn vị Đà Nẵng sẵn sàng phục vụ bạn.',
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
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar: Logo DealGo & Skip Button
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DealGoDimensions.pageGutter,
                vertical: DealGoSpacing.s8,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const DealGoLogo.wordmark(size: 26),
                  TextButton(
                    key: const Key('onboarding-skip-btn'),
                    onPressed: _finishOnboarding,
                    style: TextButton.styleFrom(
                      foregroundColor: DealGoColors.primary,
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: const Text('Bỏ qua'),
                  ),
                ],
              ),
            ),

            // Middle Visual Hero Section with 3D Da Nang graphic & floating service badges
            Expanded(
              flex: 5,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: DealGoSpacing.s16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(DealGoRadius.card),
                      child: Image.asset(
                        'assets/images/hero_dealgo_danang.png',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 220,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
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

                  // Floating Service Badge: Đặt xe
                  Positioned(
                    top: 14,
                    left: 20,
                    child: _FloatingServicePill(
                      icon: Icons.directions_car_filled_rounded,
                      iconBgColor: DealGoColors.primary,
                      title: 'Đặt xe',
                      subtitle: 'Đi muôn nơi\nan toàn, tiện lợi',
                    ),
                  ),

                  // Floating Service Badge: Đồ ăn
                  Positioned(
                    bottom: 20,
                    right: 20,
                    child: _FloatingServicePill(
                      icon: Icons.shopping_bag_rounded,
                      iconBgColor: DealGoColors.brandGreen,
                      title: 'Đồ ăn',
                      subtitle: 'Hàng ngàn món\nngon mỗi ngày',
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Carousel Content: Title, Description, Dots, CTA
            Expanded(
              flex: 4,
              child: Column(
                children: [
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _slides.length,
                      onPageChanged: (index) {
                        setState(() => _currentIndex = index);
                      },
                      itemBuilder: (context, index) {
                        final slide = _slides[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: DealGoDimensions.pageGutter * 1.5,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Title with purple highlight
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
                                      style: const TextStyle(
                                        color: DealGoColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: DealGoSpacing.s12),
                              // Description
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
                        );
                      },
                    ),
                  ),

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

                  const SizedBox(height: DealGoSpacing.s24),

                  // Bottom Action Button & Step Indicator
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DealGoDimensions.pageGutter,
                    ),
                    child: Column(
                      children: [
                        DealGoPrimaryButton(
                          key: const Key('onboarding-next-btn'),
                          label: _currentIndex == _slides.length - 1
                              ? 'Bắt đầu ngay'
                              : 'Tiếp tục',
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
      ),
    );
  }
}

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
