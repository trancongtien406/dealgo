// Role shells draw content behind the floating tab bar (`extendBody`); the
// last list item must still scroll fully above the bar on small and notched
// phones, with and without a sticky footer.
import 'package:dealgo/core/design_system/components/dealgo_nav_insets.dart';
import 'package:dealgo/core/design_system/components/dealgo_tab_bar.dart';
import 'package:dealgo/core/design_system/theme/dealgo_theme.dart';
import 'package:dealgo/core/design_system/tokens/dealgo_tokens.dart';
import 'package:dealgo/features/driver/presentation/widgets/driver_widgets.dart';
import 'package:dealgo/features/merchant/presentation/widgets/merchant_widgets.dart';
import 'package:dealgo/features/shell/presentation/role_shell.dart';
import 'package:dealgo/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/visual_shot.dart';

typedef _Device = ({String name, Size size, double bottomInset});

const List<_Device> _devices = [
  (name: 'se1-320x568', size: Size(320, 568), bottomInset: 0),
  (name: 'se2-375x667', size: Size(375, 667), bottomInset: 0),
  (name: 'iphone-390x844', size: Size(390, 844), bottomInset: 34),
];

const _lastKey = Key('last-item');
const _footerKey = Key('sticky-footer');

Widget _items(BuildContext context, EdgeInsets base) => ListView(
  padding: dealGoScrollPadding(context, base),
  children: [
    for (var i = 0; i < 30; i++)
      Container(
        key: i == 29 ? _lastKey : null,
        height: 72,
        margin: const EdgeInsets.only(bottom: DealGoSpacing.s12),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: DealGoSpacing.s16),
        decoration: BoxDecoration(
          color: i == 29 ? DealGoColors.primaryLight : DealGoColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: DealGoColors.border),
        ),
        child: Text(i == 29 ? 'Mục cuối cùng' : 'Mục ${i + 1}'),
      ),
  ],
);

Widget _footer() => Container(
  key: _footerKey,
  height: 56,
  color: DealGoColors.card,
  alignment: Alignment.center,
  child: const Text('Nút cố định'),
);

/// The three page shapes used in the shells.
final Map<String, Widget Function(bool footer)> _pages = {
  'customer': (_) => SafeArea(
    bottom: false,
    child: Builder(
      builder: (context) => _items(context, const EdgeInsets.all(16)),
    ),
  ),
  'driver': (footer) => DriverPageFrame(
    title: 'Tài xế',
    showBack: false,
    footer: footer ? _footer() : null,
    body: Builder(builder: (context) => _items(context, EdgeInsets.zero)),
  ),
  'merchant': (footer) => MerchantPageFrame(
    title: 'Cửa hàng',
    showBack: false,
    footer: footer ? _footer() : null,
    body: Builder(builder: (context) => _items(context, merchantPagePadding)),
  ),
};

Future<double> _pumpShell(
  WidgetTester tester,
  _Device device,
  Widget page,
) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  tester.view.physicalSize = device.size * 3;
  tester.view.devicePixelRatio = 3;
  tester.view.padding = FakeViewPadding(
    top: device.bottomInset > 0 ? 47 * 3 : 20 * 3,
    bottom: device.bottomInset * 3,
  );
  tester.view.viewPadding = tester.view.padding;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    RepaintBoundary(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: DealGoTheme.light,
        locale: const Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            backgroundColor: DealGoColors.canvas,
            extendBody: true,
            body: FloatingNavBody(
              coveredBottom: dealGoNavBarMetricsOf(context).totalHeight,
              child: page,
            ),
            bottomNavigationBar: DealGoTabBar(
              selectedIndex: 0,
              onDestinationSelected: (_) {},
              destinations: [
                for (final l in ['Trang chủ', 'Đơn', 'Món', 'Thống kê', 'Tôi'])
                  DealGoTabDestination(
                    label: l,
                    icon: Icons.circle_outlined,
                    selectedIcon: Icons.circle,
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  // Top edge of everything the bar draws, the raised active circle included.
  return tester.getTopLeft(find.byType(DealGoTabBar)).dy;
}

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  for (final device in _devices) {
    for (final role in _pages.keys) {
      for (final footer in [false, if (role != 'customer') true]) {
        final label = '$role${footer ? '+footer' : ''} @ ${device.name}';
        testWidgets('last item clears the tab bar: $label', (tester) async {
          await loadShotFonts(tester);
          final barTop = await _pumpShell(
            tester,
            device,
            _pages[role]!(footer),
          );
          // Without a sticky footer the content runs behind the bar.
          final list = find.byType(ListView);
          if (!footer) {
            expect(tester.getBottomLeft(list).dy, greaterThan(barTop));
          }

          await tester.dragUntilVisible(
            find.byKey(_lastKey),
            list,
            const Offset(0, -300),
          );
          await tester.drag(list, const Offset(0, -3000));
          await tester.pumpAndSettle();

          final last = tester.getRect(find.byKey(_lastKey));
          final limit = footer
              ? tester.getTopLeft(find.byKey(_footerKey)).dy
              : barTop;
          expect(last.bottom, lessThanOrEqualTo(limit));
          if (footer) {
            expect(
              tester.getBottomLeft(find.byKey(_footerKey)).dy,
              lessThanOrEqualTo(barTop),
            );
          }
          await saveShot(
            tester,
            'C-$role${footer ? '-footer' : ''}-${device.name}',
          );
          debugDefaultTargetPlatformOverride = null;
        });
      }
    }
  }
}
