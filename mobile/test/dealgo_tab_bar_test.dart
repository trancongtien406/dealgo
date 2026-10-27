import 'package:dealgo/core/design_system/components/dealgo_nav_insets.dart';
import 'package:dealgo/core/design_system/components/dealgo_tab_bar.dart';
import 'package:dealgo/features/shell/presentation/role_shell.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _labels = ['Tổng quan', 'Việc nhận', 'Thu nhập', 'Thông báo', 'Tôi'];

List<DealGoTabDestination> _destinations({int badgeOn = -1, int badge = 0}) => [
  for (var i = 0; i < _labels.length; i++)
    DealGoTabDestination(
      label: _labels[i],
      icon: Icons.circle_outlined,
      selectedIcon: Icons.circle,
      badgeCount: i == badgeOn ? badge : 0,
    ),
];

class _Host extends StatefulWidget {
  const _Host({this.destinations});

  final List<DealGoTabDestination>? destinations;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  var index = 0;
  final taps = <int>[];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: const SizedBox.expand(),
      bottomNavigationBar: DealGoTabBar(
        destinations: widget.destinations ?? _destinations(),
        selectedIndex: index,
        onDestinationSelected: (i) {
          taps.add(i);
          setState(() => index = i);
        },
      ),
    );
  }
}

Future<_HostState> _pump(
  WidgetTester tester, {
  bool reducedMotion = false,
  List<DealGoTabDestination>? destinations,
}) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: reducedMotion,
            viewPadding: const EdgeInsets.only(bottom: 34),
            padding: const EdgeInsets.only(bottom: 34),
          ),
          child: _Host(destinations: destinations),
        ),
      ),
    ),
  );
  return tester.state<_HostState>(find.byType(_Host));
}

DealGoNotchedBarPainter _painter(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(find.byKey(const Key('dealgo-tab-bar-pill')))
            .painter!
        as DealGoNotchedBarPainter;

/// Notch centre x for [index] on a 390 wide screen (12 side margins).
double _notchX(int index) => (index + 0.5) * ((390 - 2 * 12) / 5);

void main() {
  testWidgets('tapping a tab selects it and slides the notch there', (
    tester,
  ) async {
    final host = await _pump(tester);
    expect(_painter(tester).notchCenterX, closeTo(_notchX(0), 0.01));

    await tester.tap(find.text('Thu nhập'));
    await tester.pump();
    expect(host.taps, [2]);

    // Mid-animation the notch is between the old and the new tab.
    await tester.pump(const Duration(milliseconds: 100));
    final mid = _painter(tester).notchCenterX;
    expect(mid, greaterThan(_notchX(0)));
    expect(mid, lessThan(_notchX(2)));

    await tester.pumpAndSettle();
    expect(_painter(tester).notchCenterX, closeTo(_notchX(2), 0.01));

    // The raised circle follows the notch.
    final circle = tester.getCenter(
      find.byKey(const Key('dealgo-tab-bar-active')),
    );
    expect(circle.dx, closeTo(12 + _notchX(2), 0.01));
  });

  testWidgets('reduced motion jumps the notch without animating', (
    tester,
  ) async {
    await _pump(tester, reducedMotion: true);
    await tester.tap(find.text('Tôi'));
    // One frame after the tap the notch is already at the target (the ink
    // ripple may still run, so only the notch is checked).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(_painter(tester).notchCenterX, closeTo(_notchX(4), 0.01));
  });

  testWidgets(
    'active circle rises above the pill',
    (tester) async {
      await _pump(tester);
      final bar = tester.getRect(find.byKey(const Key('dealgo-tab-bar')));
      final pill = tester.getRect(find.byKey(const Key('dealgo-tab-bar-pill')));
      final circle = tester.getRect(
        find.byKey(const Key('dealgo-tab-bar-active')),
      );
      expect(bar.height, 102); // 20 circle + 58 pill + 24 gap
      expect(circle.top, lessThan(pill.top));
      expect(circle.top, bar.top);
      expect(pill.left, 12);
      expect(pill.right, 390 - 12);
      expect(844 - pill.bottom, greaterThanOrEqualTo(8));
    },
    variant: const TargetPlatformVariant(<TargetPlatform>{TargetPlatform.iOS}),
  );

  testWidgets('tabs expose button + selected semantics and 44pt targets', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester);
    for (var i = 0; i < _labels.length; i++) {
      final node = tester.getSemantics(find.bySemanticsLabel(_labels[i]));
      expect(node, isSemantics(isButton: true, isSelected: i == 0));
      expect(node.rect.width, greaterThanOrEqualTo(44));
      expect(node.rect.height, greaterThanOrEqualTo(44));
    }
    await tester.tap(find.text('Thông báo'));
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(find.bySemanticsLabel('Thông báo')),
      isSemantics(isButton: true, isSelected: true),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Tổng quan')),
      isSemantics(isSelected: false),
    );
    handle.dispose();
  });

  testWidgets('badge count renders and caps at 99+', (tester) async {
    await _pump(tester, destinations: _destinations(badgeOn: 3, badge: 120));
    expect(find.text('99+'), findsOneWidget);
  });

  testWidgets('every label stays visible, active one included', (tester) async {
    await _pump(tester);
    for (final l in _labels) {
      expect(find.text(l), findsOneWidget);
    }
  });

  group('FloatingNavBody', () {
    Future<(Size, EdgeInsets)> pumpBody(
      WidgetTester tester, {
      required bool keyboardOpen,
    }) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      late EdgeInsets seen;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            viewPadding: EdgeInsets.only(bottom: 34),
            padding: EdgeInsets.only(bottom: 34),
          ),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: FloatingNavBody(
              keyboardOpen: keyboardOpen,
              child: Builder(
                key: const Key('body'),
                builder: (context) {
                  seen = MediaQuery.paddingOf(context);
                  return const SizedBox.expand();
                },
              ),
            ),
          ),
        ),
      );
      final size = tester.getSize(find.byKey(const Key('body')));
      debugDefaultTargetPlatformOverride = null;
      return (size, seen);
    }

    testWidgets('body ends at the pill top and gets no bottom padding', (
      tester,
    ) async {
      final (size, padding) = await pumpBody(tester, keyboardOpen: false);
      final m = dealGoNavBarMetrics(TargetPlatform.iOS, 34);
      expect(size.height, 844 - m.contentClearance);
      expect(padding.bottom, 0);
    });

    testWidgets('keyboard open: no clearance', (tester) async {
      final (size, _) = await pumpBody(tester, keyboardOpen: true);
      expect(size.height, 844);
    });
  });
}
