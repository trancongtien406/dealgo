import 'package:dealgo/core/design_system/components/dealgo_app_header.dart';
import 'package:dealgo/core/design_system/components/dealgo_tab_bar.dart';
import 'package:dealgo/features/shell/presentation/role_shell.dart';
import 'package:dealgo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Regression: at iOS accessibility-extra-large the
// driver tab bar and the "Thu nhập & lịch sử" header overflowed.
Widget _app(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('vi'),
  builder: (context, c) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: const TextScaler.linear(3.1)),
    child: c!,
  ),
  home: child,
);

void main() {
  testWidgets('header with subtitle fits at accessibility XL', (tester) async {
    tester.view.physicalSize = const Size(440 * 3, 956 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _app(
        const Scaffold(
          appBar: DealGoAppHeader(
            title: 'Thu nhập & lịch sử',
            subtitle: 'Tính theo công việc đã kết thúc',
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('five-tab driver bar fits at accessibility XL', (tester) async {
    tester.view.physicalSize = const Size(440 * 3, 956 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _app(
        Scaffold(
          bottomNavigationBar: MediaQuery.withClampedTextScaling(
            maxScaleFactor: kTabBarMaxTextScale,
            child: DealGoTabBar(
              selectedIndex: 0,
              onDestinationSelected: (_) {},
              destinations: [
                for (final l in [
                  'Tổng quan',
                  'Việc nhận',
                  'Thu nhập',
                  'Thông báo',
                  'Tôi',
                ])
                  DealGoTabDestination(
                    label: l,
                    icon: Icons.home,
                    selectedIcon: Icons.home,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
