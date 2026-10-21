import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design_system/components/dealgo_text_field.dart';
import '../../../core/design_system/icons/dealgo_icons.dart';
import '../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../identity/presentation/widgets/auth_widgets.dart';
import '../../food/presentation/utils/food_routes.dart';
import '../../places/presentation/place_picker_page.dart';
import '../../ride/presentation/cubit/ride_destination.dart';
import 'account_routes.dart';
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
              Text(
                AppLocalizations.of(context).homeTagline,
                style: textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const _LocationChip(),
        const SizedBox(width: DealGoSpacing.s8),
        const _Bell(),
        const SizedBox(width: DealGoSpacing.s8),
       ],
    );
  }
}

class _LocationChip extends StatelessWidget {
  const _LocationChip();

  Future<void> _pick(BuildContext context) async {
    final place = await pickPlace(context, PlacePickPurpose.pickup);
    if (place == null || !context.mounted) {
      return;
    }
    context.read<RideDestinationCubit>().choose(place);
    context.go('/customer/book');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Material(
      color: DealGoColors.card,
      shape: StadiumBorder(
        side: const BorderSide(color: DealGoColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _pick(context),
        child: Semantics(
          button: true,
          label: l10n.homeCitySample,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DealGoSpacing.s8,
            vertical: DealGoSpacing.s8,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                DealGoIcons.pinFilled,
                color: DealGoColors.primary,
                size: 16,
              ),
              const SizedBox(width: 2),
              Text(
                l10n.homeCitySample,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: DealGoColors.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Icon(
                DealGoIcons.expandMore,
                size: 16,
                color: DealGoColors.textSecondary,
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

class _Bell extends StatelessWidget {
  const _Bell();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      width: 36,
      height: 36,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: DealGoColors.card,
            shape: const CircleBorder(
              side: BorderSide(color: DealGoColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => context.push(
                AccountRoutes.notifications('/customer/account'),
              ),
              child: SizedBox(
                width: 36,
                height: 36,
                child: Icon(
                  DealGoIcons.notifications,
                  color: DealGoColors.text,
                  size: 20,
                  semanticLabel: l10n.accountNotifications,
                ),
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
 

/// C001 search: one field for destinations and food. Submitting asks which
/// kind of search to run (DEC-PROD-030) instead of guessing.
class HomeSearch extends StatefulWidget {
  const HomeSearch({required this.onBook, super.key});

  /// Opens ride booking once a destination is chosen.
  final VoidCallback onBook;

  @override
  State<HomeSearch> createState() => _HomeSearchState();
}

class _HomeSearchState extends State<HomeSearch> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit(String raw) async {
    final query = raw.trim();
    if (query.isEmpty) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final choice = await showModalBottomSheet<_HomeSearchKind>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DealGoSpacing.s16,
              ),
              child: Text(
                l10n.homeSearchChooseTitle,
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
            ),
            ListTile(
              key: const Key('home-search-food'),
              leading: const Icon(
                DealGoIcons.food,
                color: DealGoColors.primary,
              ),
              title: Text(l10n.homeSearchAsFood(query)),
              onTap: () => Navigator.of(sheetContext).pop(_HomeSearchKind.food),
            ),
            ListTile(
              key: const Key('home-search-place'),
              leading: const Icon(
                DealGoIcons.pinFilled,
                color: DealGoColors.brandGreen,
              ),
              title: Text(l10n.homeSearchAsPlace(query)),
              onTap: () =>
                  Navigator.of(sheetContext).pop(_HomeSearchKind.place),
            ),
            const SizedBox(height: DealGoSpacing.s8),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) {
      return;
    }
    switch (choice) {
      case _HomeSearchKind.food:
        await context.push(FoodRoutes.searchFor(query));
      case _HomeSearchKind.place:
        final destination = context.read<RideDestinationCubit>();
        final place = await pickPlace(
          context,
          PlacePickPurpose.dropoff,
          initialQuery: query,
        );
        if (place == null || !mounted) {
          return;
        }
        destination.choose(place);
        widget.onBook();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DealGoTextField(
      label: l10n.homeSearchHint,
      showLabel: false,
      hint: l10n.homeSearchHint,
      prefixIcon: DealGoIcons.search,
      controller: _controller,
      fieldKey: const Key('home-search-field'),
      textInputAction: TextInputAction.search,
      onSubmitted: _submit,
      suffix: IconButton(
        onPressed: widget.onBook,
        tooltip: l10n.tabBook,
        icon: const Icon(
          DealGoIcons.scan,
          color: DealGoColors.textSecondary,
          size: 22,
        ),
      ),
    );
  }
}

enum _HomeSearchKind { food, place }

/// C001 hero carousel. Auto-advances unless the user prefers reduced motion.
class HeroBanner extends StatefulWidget {
  const HeroBanner({
    required this.onExplore,
    required this.onBook,
    required this.onFood,
    super.key,
  });

  final VoidCallback onExplore;
  final VoidCallback onBook;
  final VoidCallback onFood;

  @override
  State<HeroBanner> createState() => _HeroBannerState();
}

class _HeroSlide {
  const _HeroSlide({
    required this.image,
    required this.title,
    required this.subtitle,
    required this.cta,
    required this.onPressed,
    required this.wash,
    this.fallback,
    this.caption,
    this.showWordmark = false,
  });

  final String image;
  final String? fallback;
  final String title;
  final String subtitle;
  final String? caption;
  final String cta;
  final VoidCallback onPressed;
  final List<Color> wash;
  final bool showWordmark;
}

class _HeroBannerState extends State<HeroBanner> {
  final _page = PageController();
  Timer? _timer;
  var _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _arm());
  }

  void _arm() {
    _timer?.cancel();
    if (!mounted || MediaQuery.disableAnimationsOf(context)) {
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_page.hasClients) {
        return;
      }
      final count = 3;
      final next = (_index + 1) % count;
      _page.animateToPage(
        next,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _page.dispose();
    super.dispose();
  }

  List<_HeroSlide> _slides(AppLocalizations l10n) {
    return [
      _HeroSlide(
        image: 'assets/images/hero_danang_banner_bg.png',
        fallback: 'assets/images/hero_danang_sunset_clean.png',
        title: l10n.homeHeroTitle,
        subtitle: l10n.homeHeroSubtitle,
        caption: l10n.homeHeroCity,
        cta: l10n.actionExplore,
        onPressed: widget.onExplore,
        showWordmark: true,
        wash: const [Color(0xC44C1D95), Color(0x664C1D95), Color(0x004C1D95)],
      ),
      _HeroSlide(
        image: 'assets/images/hero_food_clean.png',
        title: l10n.homeCatFood,
        subtitle: l10n.homeServiceFoodSub,
        cta: l10n.actionSeeAll,
        onPressed: widget.onFood,
        wash: const [Color(0xC4148A3E), Color(0x6616A34A), Color(0x0016A34A)],
      ),
      _HeroSlide(
        image: 'assets/images/hero_danang_sunset_clean.png',
        title: l10n.rideBookTitle,
        subtitle: l10n.serviceRideBlurb,
        cta: l10n.actionBookRideNow,
        onPressed: widget.onBook,
        wash: const [Color(0xC44C1D95), Color(0x664C1D95), Color(0x004C1D95)],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final slides = _slides(l10n);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(DealGoRadius.card),
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _page,
              itemCount: slides.length,
              onPageChanged: (index) {
                setState(() => _index = index);
                _arm();
              },
              itemBuilder: (context, index) => _HeroPage(slide: slides[index]),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 10,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < slides.length; i++) ...[
                    if (i > 0) const SizedBox(width: 5),
                    _HeroDot(active: i == _index),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroPage extends StatelessWidget {
  const _HeroPage({required this.slide});

  final _HeroSlide slide;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: slide.onPressed,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            slide.image,
            fit: BoxFit.cover,
            alignment: Alignment.centerRight,
            filterQuality: FilterQuality.high,
            errorBuilder: (context, error, stack) {
              final fallback = slide.fallback;
              if (fallback == null) {
                return const CustomPaint(painter: _DanangBannerPainter());
              }
              return Image.asset(
                fallback,
                fit: BoxFit.cover,
                alignment: Alignment.centerRight,
                errorBuilder: (context, error, stack) {
                  return const CustomPaint(painter: _DanangBannerPainter());
                },
              );
            },
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: slide.wash,
                stops: const [0, 0.34, 0.55],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DealGoSpacing.s16,
              DealGoSpacing.s12,
              DealGoSpacing.s16,
              DealGoSpacing.s12,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: 0.52,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (slide.showWordmark)
                      Text.rich(
                        TextSpan(
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                          children: const [
                            TextSpan(
                              text: 'Deal',
                              style: TextStyle(color: Colors.white),
                            ),
                            TextSpan(
                              text: 'Go',
                              style: TextStyle(color: DealGoColors.brandGreen),
                            ),
                          ],
                        ),
                      )
                    else
                      const SizedBox(height: 4),
                    const SizedBox(height: DealGoSpacing.s6),
                    Text(
                      slide.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: DealGoSpacing.s4),
                    Text(
                      slide.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.95),
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: DealGoSpacing.s8),
                    HomePillButton(label: slide.cta, onPressed: slide.onPressed),
                  ],
                ),
              ),
            ),
          ),
          if (slide.caption != null)
            Positioned(
              right: DealGoSpacing.s12,
              top: DealGoSpacing.s16,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: Text(
                  slide.caption!,
                  textAlign: TextAlign.right,
                  style: textTheme.bodySmall?.copyWith(
                    color: const Color(0xFFFFE7A3),
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}


class _HeroDot extends StatelessWidget {
  const _HeroDot({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: active ? 16 : 6,
      height: 6,
      decoration: BoxDecoration(
        color: active ? Colors.white : Colors.white.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _DanangBannerPainter extends CustomPainter {
  const _DanangBannerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final sky = Paint()..color = DealGoColors.primaryDeep;
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
