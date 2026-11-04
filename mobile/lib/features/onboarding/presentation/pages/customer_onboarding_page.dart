import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/components/dealgo_logo.dart';
import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/storage/onboarding_storage.dart';
import '../../../identity/domain/auth_redirect.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../l10n/app_localizations.dart';

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
  final String? overlayAsset;
}

class CustomerOnboardingPage extends StatefulWidget {
  const CustomerOnboardingPage({
    super.key,
    this.onComplete,
    this.storage,
    this.initialPage = 0,
  });

  final VoidCallback? onComplete;
  final OnboardingStorage? storage;
  final int initialPage;

  @override
  State<CustomerOnboardingPage> createState() => _CustomerOnboardingPageState();
}

class _CustomerOnboardingPageState extends State<CustomerOnboardingPage> {
  late final PageController _pageController;
  late final OnboardingStorage _storage;
  late int _currentIndex;

  static const _slideCount = 3;

  List<OnboardingSlide> _slidesFor(AppLocalizations l10n) => [
    OnboardingSlide(
      title: l10n.onbSlide1Title,
      highlightText: l10n.onbSlide1Accent,
      highlightColor: DealGoColors.primary,
      description: l10n.onbSlide1Body,
      heroAsset: 'assets/images/hero_dealgo_danang.png',
      pill1Icon: DealGoIcons.car,
      pill1Color: DealGoColors.primary,
      pill1Title: l10n.serviceRideTitle,
      pill1Subtitle: l10n.serviceRideBlurb,
      pill2Icon: DealGoIcons.shoppingBag,
      pill2Color: DealGoColors.brandGreen,
      pill2Title: l10n.serviceFoodTitle,
      pill2Subtitle: l10n.serviceFoodBlurb,
    ),
    OnboardingSlide(
      title: l10n.onbSlide2Title,
      highlightText: l10n.onbSlide2Accent,
      highlightColor: DealGoColors.primary,
      description: l10n.onbSlide2Body,
      heroAsset: 'assets/images/hero_onboarding_ride.jpg',
      pill1Icon: DealGoIcons.motorbike,
      pill1Color: DealGoColors.primary,
      pill1Title: l10n.onbSlide2Pill1Title,
      pill1Subtitle: l10n.onbSlide2Pill1Body,
      pill2Icon: DealGoIcons.handshake,
      pill2Color: DealGoColors.amber,
      pill2Title: l10n.onbSlide2Pill2Title,
      pill2Subtitle: l10n.onbSlide2Pill2Body,
    ),
    OnboardingSlide(
      title: l10n.onbSlide3Title,
      highlightText: l10n.onbSlide3Accent,
      highlightColor: DealGoColors.brandGreen,
      description: l10n.onbSlide3Body,
      heroAsset: 'assets/images/hero_onboarding_food.jpg',
      pill1Icon: DealGoIcons.restaurant,
      pill1Color: DealGoColors.brandGreen,
      pill1Title: l10n.onbSlide3Pill1Title,
      pill1Subtitle: l10n.onbSlide3Pill1Body,
      pill2Icon: DealGoIcons.bolt,
      pill2Color: DealGoColors.primary,
      pill2Title: l10n.onbSlide3Pill2Title,
      pill2Subtitle: l10n.onbSlide3Pill2Body,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialPage;
    _pageController = PageController(initialPage: widget.initialPage);
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
    if (_currentIndex < _slideCount - 1) {
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
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: DealGoColors.canvas,
      body: Stack(
        children: [
          Positioned(
            top: -40,
            left: -40,
            child: IgnorePointer(
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: DealGoColors.primary.withValues(alpha: 0.05),
                ),
              ),
            ),
          ),
          Positioned(
            top: 220,
            right: -60,
            child: IgnorePointer(
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: DealGoColors.brandGreen.withValues(alpha: 0.05),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DealGoDimensions.pageGutter,
                    vertical: DealGoSpacing.s8,
                  ),
                  child: Row(
                    children: [
                      const DealGoLogo.wordmark(size: 26),
                      const Spacer(),
                      TextButton(
                        key: const Key('onboarding-skip-btn'),
                        onPressed: _finishOnboarding,
                        style: TextButton.styleFrom(
                          foregroundColor: DealGoColors.primary,
                          textStyle: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: DealGoColors.primary,
                          ),
                        ),
                        child: Text(l10n.onbSkip),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _slideCount,
                    onPageChanged: (index) {
                      setState(() => _currentIndex = index);
                    },
                    itemBuilder: (context, index) {
                      final slide = _slidesFor(l10n)[index];
                      return Column(
                        children: [
                          Expanded(
                            flex: 5,
                            child: _SlideHeroVisual(slide: slide),
                          ),
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
                                      style: textTheme.headlineMedium?.copyWith(
                                        fontSize: 26,
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
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: DealGoColors.textSecondary,
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
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DealGoDimensions.pageGutter,
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_slideCount, (index) {
                          final isSelected = index == _currentIndex;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.symmetric(
                              horizontal: DealGoSpacing.s4,
                            ),
                            width: isSelected ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? DealGoColors.primary
                                  : DealGoColors.border,
                              borderRadius: BorderRadius.circular(
                                DealGoRadius.small,
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: DealGoSpacing.s20),
                      SizedBox(
                        width: double.infinity,
                        child: DealGoPrimaryButton(
                          key: const Key('onboarding-next-btn'),
                          label: _currentIndex == _slideCount - 1
                              ? l10n.onbStart
                              : l10n.actionContinue,
                          trailingIcon: DealGoIcons.arrowRight,
                          onPressed: _nextPage,
                        ),
                      ),
                      const SizedBox(height: DealGoSpacing.s8),
                      Text(
                        l10n.onbStep(_currentIndex + 1, _slideCount),
                        style: textTheme.labelSmall?.copyWith(
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

            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DealGoSpacing.s16,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(DealGoRadius.card),
                child: Image.asset(
                  slide.heroAsset,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 220,
                    decoration: BoxDecoration(
                      color: slide.pill1Color.withValues(alpha: 0.12),
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

            Positioned(
              top: 24,
              left: 16,
              child: _FloatingServicePill(
                icon: slide.pill1Icon,
                iconBgColor: slide.pill1Color,
                title: slide.pill1Title,
                subtitle: slide.pill1Subtitle,
              ),
            ),

            Positioned(
              top: 88,
              right: 16,
              child: _FloatingServicePill(
                icon: slide.pill2Icon,
                iconBgColor: slide.pill2Color,
                title: slide.pill2Title,
                subtitle: slide.pill2Subtitle,
              ),
            ),
          ],
        );
      },
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
            child: Icon(icon, color: DealGoColors.card, size: 20),
          ),
          const SizedBox(width: DealGoSpacing.s8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: textTheme.labelLarge?.copyWith(
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
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: DealGoColors.canvas,
              shape: BoxShape.circle,
            ),
            child: Icon(
              DealGoIcons.arrowRight,
              size: 13,
              color: DealGoColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
