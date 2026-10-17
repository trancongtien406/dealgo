import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/components/dealgo_logo.dart';
import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../identity/domain/auth_redirect.dart';

class OnboardingSlide {
  const OnboardingSlide({
    required this.title,
    required this.highlightText,
    required this.description,
    required this.imageAsset,
    this.badgeWidget,
  });

  final String title;
  final String highlightText;
  final String description;
  final String imageAsset;
  final Widget? badgeWidget;
}

/// Customer Onboarding Walkthrough corresponding to Mockup S002.
class CustomerOnboardingPage extends StatefulWidget {
  const CustomerOnboardingPage({
    super.key,
    this.onComplete,
  });

  final VoidCallback? onComplete;

  @override
  State<CustomerOnboardingPage> createState() => _CustomerOnboardingPageState();
}

class _CustomerOnboardingPageState extends State<CustomerOnboardingPage> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  final List<OnboardingSlide> _slides = const [
    OnboardingSlide(
      title: 'Một ứng dụng,\n',
      highlightText: 'vạn trải nghiệm',
      description:
          'Đặt xe, khám phá món ngon và mua sắm hằng ngày — tất cả trong DealGo.',
      imageAsset: 'assets/images/banner_danang_hero.png',
    ),
    OnboardingSlide(
      title: 'Di chuyển nhanh,\n',
      highlightText: 'an toàn & tiết kiệm',
      description:
          'Tài xế bản địa đón tận nơi, theo dõi lộ trình thời gian thực, cước phí minh bạch.',
      imageAsset: 'assets/images/card_ride.png',
    ),
    OnboardingSlide(
      title: 'Món ngon nóng hổi,\n',
      highlightText: 'giao siêu tốc',
      description:
          'Hàng ngàn quán ăn, nhà hàng đặc sản chuẩn vị Đà Nẵng sẵn sàng phục vụ bạn.',
      imageAsset: 'assets/images/card_food.png',
    ),
  ];

  void _finishOnboarding() {
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
            // Top Bar: Logo & Skip Button
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
                    onPressed: _finishOnboarding,
                    style: TextButton.styleFrom(
                      foregroundColor: DealGoColors.primary,
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: const Text('Bỏ qua'),
                  ),
                ],
              ),
            ),

            // Middle Carousel Section
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
                      horizontal: DealGoDimensions.pageGutter,
                    ),
                    child: Center(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Hero Visual Image with Glass Frame
                            Container(
                              constraints: const BoxConstraints(maxHeight: 220),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(DealGoRadius.card),
                                boxShadow: [
                                  BoxShadow(
                                    color: DealGoColors.primary.withValues(alpha: 0.08),
                                    blurRadius: 24,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(DealGoRadius.card),
                                child: Image.asset(
                                  slide.imageAsset,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                    height: 180,
                                    decoration: BoxDecoration(
                                      color: DealGoColors.subtlePurple,
                                      borderRadius: BorderRadius.circular(
                                        DealGoRadius.card,
                                      ),
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.auto_awesome_rounded,
                                        size: 64,
                                        color: DealGoColors.primary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: DealGoSpacing.s24),

                            // Title Text with Highlighting
                            Text.rich(
                              TextSpan(
                                style: const TextStyle(
                                  fontSize: 24,
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

                            // Subtitle Description
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                slide.description,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w400,
                                  color: DealGoColors.textSecondary,
                                  height: 1.45,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
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

            // Bottom CTA Section
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
                  const SizedBox(height: DealGoSpacing.s12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
