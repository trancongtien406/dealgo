import 'dart:async';

import 'package:dealgo/core/analytics/analytics_port.dart';
import 'package:dealgo/features/home_banner/data/home_banner_remote_datasource.dart';
import 'package:dealgo/features/home_banner/data/home_banner_tracker.dart';
import 'package:dealgo/features/home_banner/domain/home_banner.dart';
import 'package:dealgo/features/home_banner/presentation/home_banner_carousel.dart';
import 'package:dealgo/features/identity/domain/entities/app_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/test_l10n.dart';

class _Analytics implements AnalyticsPort {
  final events = <String>[];

  @override
  Future<void> logEvent(
    String name, {
    Map<String, Object?> parameters = const {},
  }) async {
    events.add('$name:${parameters['banner_id']}');
  }

  @override
  Future<void> setUserId(String? userId) async {}
}

class _SlowRepo extends FakeHomeBannerRepository {
  final gate = Completer<List<HomeBanner>>();

  @override
  Future<List<HomeBanner>> list({
    required AppRole role,
    double? lat,
    double? lng,
  }) => gate.future;
}

const _banners = [
  HomeBanner(
    id: 'b1',
    imageUrl: 'https://img.test/b1.png',
    cta: HomeBannerCta(kind: HomeBannerCtaKind.app, target: '/customer/shop'),
  ),
  HomeBanner(
    id: 'b2',
    imageUrl: 'https://img.test/b2.png',
    cta: HomeBannerCta(
      kind: HomeBannerCtaKind.web,
      target: 'https://dealgo.vn/',
    ),
  ),
  HomeBanner(id: 'b3', imageUrl: 'https://img.test/b3.png'),
];

Future<({HomeBannerTracker tracker, List<Uri> opened})> _pump(
  WidgetTester tester,
  HomeBannerRepository repo, {
  AnalyticsPort? analytics,
  bool tickers = true,
}) async {
  final tracker = HomeBannerTracker(
    repository: repo,
    analytics: analytics,
    flushDelay: const Duration(milliseconds: 100),
  );
  final opened = <Uri>[];
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: TickerMode(
            enabled: tickers,
            child: ListView(
              children: [
                HomeBannerCarousel(
                  role: AppRole.customer,
                  interval: const Duration(seconds: 5),
                  openWeb: (uri) async {
                    opened.add(uri);
                    return true;
                  },
                ),
                const Text('below'),
              ],
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/customer/shop',
        builder: (context, state) => const Text('SHOP PAGE'),
      ),
    ],
  );
  await tester.pumpWidget(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<HomeBannerRepository>.value(value: repo),
        RepositoryProvider<HomeBannerTracker>.value(value: tracker),
      ],
      child: MaterialApp.router(
        locale: const Locale('vi'),
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: const [Locale('vi'), Locale('en')],
        routerConfig: router,
      ),
    ),
  );
  return (tracker: tracker, opened: opened);
}

int _activeDot(WidgetTester tester) {
  for (var i = 0; i < 3; i++) {
    final box = tester.renderObject<RenderBox>(
      find.byKey(Key('home-banner-dot-$i')),
    );
    if (box.size.width > 10) {
      return i;
    }
  }
  return -1;
}

void main() {
  group('decodeHomeBanners', () {
    test('keeps valid rows, drops bad rows and unsafe CTAs', () {
      final out = decodeHomeBanners({
        'items': [
          {
            'id': 'a',
            'imageUrl': '/v1/public/home-banners/images/a/x.png',
            'cta': {'kind': 'app', 'target': '/customer/book'},
            'service': 'RIDE',
          },
          {'id': 'b'},
          'junk',
          {
            'id': 'c',
            'imageUrl': 'https://x/c.png',
            'cta': {'kind': 'web', 'target': 'http://insecure'},
          },
        ],
      });
      expect(out.map((b) => b.id), ['a', 'c']);
      expect(out.first.cta?.kind, HomeBannerCtaKind.app);
      expect(out.first.service, 'RIDE');
      expect(out.last.cta, isNull);
      expect(decodeHomeBanners(null), isEmpty);
    });

    test('event json matches the server contract', () {
      expect(const HomeBannerEvent('x', HomeBannerEventType.click).toJson(), {
        'bannerId': 'x',
        'type': 'CLICK',
      });
    });
  });

  test('tracker: one impression per banner, batched; click flushes', () async {
    final repo = FakeHomeBannerRepository();
    final analytics = _Analytics();
    final tracker = HomeBannerTracker(
      repository: repo,
      analytics: analytics,
      flushDelay: const Duration(milliseconds: 10),
    );
    tracker.impression(_banners[0], position: 0);
    tracker.impression(_banners[0], position: 0);
    tracker.impression(_banners[1], position: 1);
    expect(repo.recorded, isEmpty);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(repo.recorded.map((e) => e.toJson()['bannerId']), ['b1', 'b2']);
    tracker.click(_banners[0], position: 0);
    await Future<void>.delayed(Duration.zero);
    expect(repo.recorded.last.type, HomeBannerEventType.click);
    expect(analytics.events, [
      'home_banner_impression:b1',
      'home_banner_impression:b2',
      'home_banner_click:b1',
    ]);
    tracker.dispose();
  });

  testWidgets('skeleton while loading, then hidden when empty', (tester) async {
    final repo = _SlowRepo();
    await _pump(tester, repo);
    await tester.pump();
    expect(find.byKey(const Key('home-banner-skeleton')), findsOneWidget);
    repo.gate.complete(const []);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-banner-skeleton')), findsNothing);
    expect(find.byKey(const Key('home-banner-carousel')), findsNothing);
    expect(find.text('below'), findsOneWidget);
  });

  testWidgets('hidden when the request fails', (tester) async {
    await _pump(tester, FakeHomeBannerRepository(error: StateError('down')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-banner-carousel')), findsNothing);
    expect(find.byKey(const Key('home-banner-skeleton')), findsNothing);
  });

  testWidgets('one dot per banner, 2:1 frame, autoplay, touch pauses', (
    tester,
  ) async {
    final repo = FakeHomeBannerRepository(banners: _banners);
    await _pump(tester, repo);
    await tester.pumpAndSettle();
    final frame = tester.getSize(find.byKey(const Key('home-banner-carousel')));
    expect(frame.width / frame.height, closeTo(2, 0.01));
    expect(find.byKey(const Key('home-banner-dot-2')), findsOneWidget);
    expect(find.byKey(const Key('home-banner-dot-3')), findsNothing);
    expect(_activeDot(tester), 0);
    // Image-only slides: no text overlay, generic screen-reader label.
    expect(
      find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'Banner 1/3',
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('home-banner-carousel')),
        matching: find.byType(Text),
      ),
      findsNothing,
    );

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(_activeDot(tester), 1);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('home-banner-carousel'))),
    );
    await tester.pump(const Duration(seconds: 11));
    await tester.pumpAndSettle();
    expect(_activeDot(tester), 1);
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(_activeDot(tester), 2);

    await tester.pump(const Duration(milliseconds: 200));
    expect(repo.recorded.map((e) => e.bannerId).toSet(), {'b1', 'b2', 'b3'});
  });

  testWidgets('no autoplay and no impression while offstage', (tester) async {
    final repo = FakeHomeBannerRepository(banners: _banners);
    await _pump(tester, repo, tickers: false);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 12));
    await tester.pumpAndSettle();
    expect(_activeDot(tester), 0);
    await tester.pump(const Duration(milliseconds: 200));
    expect(repo.recorded, isEmpty);
  });

  testWidgets('app CTA navigates in app; web CTA opens the browser', (
    tester,
  ) async {
    final repo = FakeHomeBannerRepository(banners: _banners);
    final analytics = _Analytics();
    final ctx = await _pump(tester, repo, analytics: analytics);
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const Key('home-banner-carousel')),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();
    expect(_activeDot(tester), 1);
    await tester.tap(find.byKey(const Key('home-banner-carousel')));
    await tester.pumpAndSettle();
    expect(ctx.opened.single.toString(), 'https://dealgo.vn/');
    expect(analytics.events, contains('home_banner_click:b2'));

    await tester.drag(
      find.byKey(const Key('home-banner-carousel')),
      const Offset(500, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-banner-carousel')));
    await tester.pumpAndSettle();
    expect(find.text('SHOP PAGE'), findsOneWidget);
    expect(
      repo.recorded
          .where((e) => e.type == HomeBannerEventType.click)
          .map((e) => e.bannerId),
      ['b2', 'b1'],
    );
  });

  testWidgets('a service carousel keeps its banners, else shows the fallback', (
    tester,
  ) async {
    Future<void> pump(List<HomeBanner> banners) async {
      await tester.pumpWidget(
        RepositoryProvider<HomeBannerRepository>.value(
          value: FakeHomeBannerRepository(banners: banners),
          child: MaterialApp(
            locale: const Locale('vi'),
            localizationsDelegates: testLocalizationsDelegates,
            supportedLocales: const [Locale('vi'), Locale('en')],
            home: Scaffold(
              body: HomeBannerCarousel(
                key: ValueKey(banners.length),
                role: AppRole.customer,
                service: 'FOOD',
                empty: const Text('STATIC'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pump(_banners);
    expect(find.text('STATIC'), findsOneWidget);
    expect(find.byKey(const Key('home-banner-carousel')), findsNothing);

    await pump(const [
      HomeBanner(
        id: 'f1',
        imageUrl: 'https://img.test/f1.png',
        service: 'FOOD',
      ),
    ]);
    expect(find.byKey(const Key('home-banner-carousel')), findsOneWidget);
    expect(find.text('STATIC'), findsNothing);
  });
}
