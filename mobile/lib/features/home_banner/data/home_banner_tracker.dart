import 'dart:async';

import '../../../core/analytics/analytics_port.dart';
import '../domain/home_banner.dart';

/// Batches banner impressions/clicks to the server and mirrors them to
/// [AnalyticsPort]. One impression per banner per app session.
class HomeBannerTracker {
  HomeBannerTracker({
    required this.repository,
    this.analytics,
    this.flushDelay = const Duration(seconds: 2),
  });

  final HomeBannerRepository repository;
  final AnalyticsPort? analytics;
  final Duration flushDelay;

  final Set<String> _seen = {};
  final List<HomeBannerEvent> _pending = [];
  Timer? _timer;

  bool seen(String bannerId) => _seen.contains(bannerId);

  void impression(HomeBanner banner, {required int position}) {
    if (!_seen.add(banner.id)) {
      return;
    }
    _queue(HomeBannerEvent(banner.id, HomeBannerEventType.impression));
    unawaited(
      analytics?.logEvent(
        'home_banner_impression',
        parameters: {'banner_id': banner.id, 'position': position},
      ),
    );
  }

  void click(HomeBanner banner, {required int position}) {
    _queue(HomeBannerEvent(banner.id, HomeBannerEventType.click));
    unawaited(
      analytics?.logEvent(
        'home_banner_click',
        parameters: {
          'banner_id': banner.id,
          'position': position,
          'cta_kind': banner.cta?.kind.name ?? 'none',
        },
      ),
    );
    // A click usually navigates away; send it now.
    unawaited(flush());
  }

  void _queue(HomeBannerEvent event) {
    _pending.add(event);
    _timer ??= Timer(flushDelay, () => unawaited(flush()));
  }

  Future<void> flush() async {
    _timer?.cancel();
    _timer = null;
    if (_pending.isEmpty) {
      return;
    }
    final batch = List<HomeBannerEvent>.of(_pending);
    _pending.clear();
    try {
      await repository.record(batch);
    } catch (_) {
      // Analytics is best effort; never surface or retry-loop.
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
