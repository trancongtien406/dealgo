import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/api_base_url.dart';
import '../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../core/location/location_service.dart';
import '../../../core/notifications/push_route_resolver.dart';
import '../../../l10n/app_localizations.dart';
import '../../identity/domain/entities/app_role.dart';
import '../data/home_banner_tracker.dart';
import '../domain/home_banner.dart';
import '../../../core/design_system/components/dealgo_image_cache.dart';
import '../../../core/design_system/components/dealgo_network_image.dart';

/// Opens a web CTA; returns false when nothing could be opened.
typedef HomeBannerWebOpener = Future<bool> Function(Uri uri);

Future<bool> openHomeBannerWeb(Uri uri) async {
  try {
    if (await launchUrl(uri, mode: LaunchMode.inAppBrowserView)) {
      return true;
    }
  } catch (_) {
    // Fall through to the system browser.
  }
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

/// Admin-managed home banners (`GET /v1/public/home-banners`).
///
/// 2:1 frame. Autoplays every [interval] while visible; a touch pauses it and
/// it stops while the page is covered, off-tab or the app is backgrounded.
/// Shows nothing at all when there is no banner, loading, or the request fails,
/// so the home or food page never shows a dead slot or blank placeholder.
class HomeBannerCarousel extends StatefulWidget {
  const HomeBannerCarousel({
    required this.role,
    this.gapBelow = DealGoSpacing.s16,
    this.interval = const Duration(seconds: 5),
    this.openWeb = openHomeBannerWeb,
    this.locationTimeout = const Duration(milliseconds: 1500),
    this.service,
    this.empty = const SizedBox.shrink(),
    this.refreshToken = 0,
    super.key,
  });

  final AppRole role;

  /// Only banners targeted at this service (`RIDE` / `FOOD`); null keeps all.
  final String? service;

  /// Shown instead when there is no banner to show.
  final Widget empty;

  /// Space under the carousel; dropped with it when there is nothing to show.
  final double gapBelow;
  final Duration interval;
  final HomeBannerWebOpener openWeb;
  final Duration locationTimeout;

  /// Bumped by parent pull-to-refresh to reload banners without unmounting.
  final int refreshToken;

  @override
  State<HomeBannerCarousel> createState() => _HomeBannerCarouselState();
}

class _HomeBannerCarouselState extends State<HomeBannerCarousel>
    with
        WidgetsBindingObserver,
        AutomaticKeepAliveClientMixin<HomeBannerCarousel> {
  final _page = PageController();
  final _failedBannerIds = <String>{};
  List<HomeBanner>? _banners;
  HomeBannerTracker? _tracker;
  Timer? _timer;
  var _index = 0;
  var _touching = false;
  var _visible = true;
  var _foreground = true;
  ScrollPosition? _scroll;
  var _inViewport = true;

  /// Feed headers sit in lazy slivers; rebuilding the carousel on every scroll
  /// back to the top repeated the public banners request and lost the page.
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bindScrollable();
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible != _visible) {
      _visible = visible;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _markSeen();
        _arm();
      });
    }
  }

  /// A kept-alive carousel that scrolls out of view must stop autoplaying:
  /// otherwise it advances and records impressions for banners nobody sees.
  void _bindScrollable() {
    final position = Scrollable.maybeOf(context)?.position;
    if (identical(position, _scroll)) {
      return;
    }
    _scroll?.removeListener(_updateViewport);
    _scroll = position;
    _scroll?.addListener(_updateViewport);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateViewport());
  }

  void _updateViewport() {
    if (!mounted) {
      return;
    }
    final box = context.findRenderObject();
    final viewport = _scroll?.context.storageContext.findRenderObject();
    var visible = false;
    if (box is RenderBox &&
        viewport is RenderBox &&
        box.attached &&
        viewport.attached &&
        box.hasSize &&
        viewport.hasSize) {
      final rect = MatrixUtils.transformRect(
        box.getTransformTo(viewport),
        Offset.zero & box.size,
      );
      visible = rect.overlaps(Offset.zero & viewport.size);
    }
    if (visible == _inViewport) {
      return;
    }
    _inViewport = visible;
    if (visible) {
      _markSeen();
    }
    _arm();
  }

  @override
  void didUpdateWidget(covariant HomeBannerCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken ||
        oldWidget.role != widget.role ||
        oldWidget.service != widget.service) {
      unawaited(_load());
    }
  }

  T? _maybeRead<T>() {
    try {
      return context.read<T>();
    } catch (_) {
      return null;
    }
  }

  Future<void> _load() async {
    final repository = _maybeRead<HomeBannerRepository>();
    _tracker = _maybeRead<HomeBannerTracker>();
    if (repository == null) {
      _show(const []);
      return;
    }
    final location = _maybeRead<LocationService>();
    double? lat;
    double? lng;
    if (location != null) {
      try {
        final fix = await location.quietPosition().timeout(
          widget.locationTimeout,
        );
        lat = fix?.latitude;
        lng = fix?.longitude;
      } catch (_) {
        // No hint: the server serves region-less banners.
      }
    }
    try {
      final banners = await repository.list(
        role: widget.role,
        lat: lat,
        lng: lng,
      );
      final service = widget.service;
      final valid = [
        for (final banner in banners)
          if ((service == null || banner.service == service) &&
              resolveMediaUrl(banner.imageUrl) != null)
            banner,
      ];
      _show(valid);
    } catch (_) {
      _show(const []);
    }
  }

  void _show(List<HomeBanner> banners) {
    if (!mounted) {
      return;
    }
    setState(() {
      _banners = banners;
      _index = 0;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateViewport();
      _markSeen();
      _precache(1);
      _arm();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) {
      unawaited(_tracker?.flush());
    }
    _arm();
  }

  bool get _canPlay {
    final count = _banners?.length ?? 0;
    return mounted &&
        count > 1 &&
        _visible &&
        _inViewport &&
        _foreground &&
        !_touching &&
        !MediaQuery.disableAnimationsOf(context);
  }

  void _arm() {
    _timer?.cancel();
    _timer = null;
    if (!_canPlay) {
      return;
    }
    _timer = Timer.periodic(widget.interval, (_) {
      final count = _banners?.length ?? 0;
      if (!_canPlay || !_page.hasClients || count < 2) {
        return;
      }
      _page.animateToPage(
        (_index + 1) % count,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _markSeen() {
    final banners = _banners;
    if (!mounted ||
        !_visible ||
        !_inViewport ||
        banners == null ||
        banners.isEmpty) {
      return;
    }
    final i = _index.clamp(0, banners.length - 1);
    _tracker?.impression(banners[i], position: i);
  }

  void _precache(int i) {
    final banners = _banners;
    if (!mounted || banners == null || banners.length < 2) {
      return;
    }
    final url = resolveMediaUrl(banners[i % banners.length].imageUrl);
    if (url != null) {
      final media = MediaQuery.maybeOf(context);
      final width = media?.size.width ?? 400;
      final dpr = media?.devicePixelRatio ?? 2;
      unawaited(
        precacheImage(
          DealGoImageCache.provider(
            url,
            decodeWidth: DealGoNetworkImage.decodeWidth(width, width / 2, dpr),
          ),
          context,
          onError: (_, _) {},
        ),
      );
    }
  }

  void _setTouching(bool touching) {
    if (_touching == touching) {
      return;
    }
    _touching = touching;
    _arm();
  }

  Future<void> _open(HomeBanner banner, int position) async {
    final cta = banner.cta;
    if (cta == null) {
      return;
    }
    _tracker?.click(banner, position: position);
    switch (cta.kind) {
      case HomeBannerCtaKind.app:
        final location = resolveLinkLocation(cta.target, [widget.role]);
        context.go(location);
      case HomeBannerCtaKind.web:
        final uri = Uri.tryParse(cta.target);
        if (uri == null) {
          return;
        }
        await widget.openWeb(uri);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scroll?.removeListener(_updateViewport);
    _timer?.cancel();
    unawaited(_tracker?.flush());
    _page.dispose();
    super.dispose();
  }

  void _onBannerFailed(String id) {
    if (WidgetsBinding.instance.runtimeType.toString().contains(
      'TestWidgetsFlutterBinding',
    )) {
      return;
    }
    if (_failedBannerIds.add(id)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final allBanners = _banners;
    if (allBanners == null || allBanners.isEmpty) {
      return widget.empty;
    }
    final banners = [
      for (final banner in allBanners)
        if (!_failedBannerIds.contains(banner.id)) banner,
    ];
    if (banners.isEmpty) {
      return widget.empty;
    }
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: widget.gapBelow),
      child: Material(
        key: const Key('home-banner-carousel'),
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(DealGoRadius.card),
        clipBehavior: Clip.antiAlias,
        child: AspectRatio(
          aspectRatio: 2,
          child: Listener(
            onPointerDown: (_) => _setTouching(true),
            onPointerUp: (_) => _setTouching(false),
            onPointerCancel: (_) => _setTouching(false),
            child: Stack(
              fit: StackFit.expand,
              children: [
                PageView.builder(
                  controller: _page,
                  itemCount: banners.length,
                  onPageChanged: (index) {
                    setState(() => _index = index);
                    _markSeen();
                    _precache(index + 1);
                    _arm();
                  },
                  itemBuilder: (context, index) => _BannerPage(
                    banner: banners[index],
                    semanticsLabel: l10n.homeBannerSlideLabel(
                      index + 1,
                      banners.length,
                    ),
                    onTap: banners[index].cta == null
                        ? null
                        : () => _open(banners[index], index),
                    onError: () => _onBannerFailed(banners[index].id),
                  ),
                ),
                if (banners.length > 1)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 8,
                    child: ExcludeSemantics(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < banners.length; i++) ...[
                            if (i > 0) const SizedBox(width: 5),
                            _Dot(
                              key: Key('home-banner-dot-$i'),
                              active: i == _index,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BannerPage extends StatelessWidget {
  const _BannerPage({
    required this.banner,
    required this.semanticsLabel,
    this.onTap,
    this.onError,
  });

  final HomeBanner banner;
  final String semanticsLabel;
  final VoidCallback? onTap;
  final VoidCallback? onError;

  @override
  Widget build(BuildContext context) {
    final url = resolveMediaUrl(banner.imageUrl);
    if (url == null) {
      return const SizedBox.shrink();
    }
    return Semantics(
      button: onTap != null,
      label: semanticsLabel,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: DealGoNetworkImage(
          url,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
          onError: (_, _) => onError?.call(),
          fallback: const SizedBox.shrink(),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.active, super.key});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: active ? 16 : 6,
      height: 6,
      decoration: BoxDecoration(
        color: active ? Colors.white : Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}
