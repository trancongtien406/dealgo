// Renders PNG previews of the floating bottom navigation for each role shell.
// Skipped unless a target directory is given:
//   flutter test test/nav_bar_preview_test.dart \
//     --dart-define=NAV_PREVIEW_DIR=/tmp/nav-preview
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dealgo/core/design_system/components/dealgo_tab_bar.dart';
import 'package:dealgo/core/design_system/theme/dealgo_theme.dart';
import 'package:dealgo/core/design_system/tokens/dealgo_tokens.dart';
import 'package:dealgo/features/shell/presentation/role_shell.dart';
import 'package:dealgo/features/shell/presentation/shell_tab.dart';
import 'package:dealgo/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _outDir = String.fromEnvironment('NAV_PREVIEW_DIR');

Future<void> _loadFonts() async {
  final be = FontLoader('BeVietnamPro');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    final bytes = File('assets/fonts/BeVietnamPro-$w.ttf').readAsBytesSync();
    be.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await be.load();
  final lucide = FontLoader('packages/lucide_icons_flutter/Lucide')
    ..addFont(
      rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf'),
    );
  await lucide.load();
}

Widget _fakeContent() => ListView(
  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
  children: [
    for (var i = 0; i < 8; i++)
      Container(
        height: 96,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: DealGoColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: DealGoColors.border),
        ),
      ),
  ],
);

Future<void> _shot(
  WidgetTester tester,
  String name,
  List<ShellTab> tabs,
  int selected, {
  int badgeIndex = -1,
}) async {
  final key = GlobalKey();
  await tester.pumpWidget(
    RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: DealGoTheme.light,
        locale: const Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            final l10n = AppLocalizations.of(context);
            return Scaffold(
              backgroundColor: DealGoColors.canvas,
              extendBody: true,
              body: FloatingNavBody(child: SafeArea(child: _fakeContent())),
              bottomNavigationBar: DealGoTabBar(
                selectedIndex: selected,
                onDestinationSelected: (_) {},
                destinations: [
                  for (var i = 0; i < tabs.length; i++)
                    DealGoTabDestination(
                      label: tabs[i].localizedLabel(l10n),
                      icon: tabs[i].icon,
                      selectedIcon: tabs[i].selectedIcon,
                      badgeCount: i == badgeIndex ? 3 : 0,
                    ),
                ],
              ),
            );
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$_outDir/preview-$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(data!.buffer.asUint8List());
  });
}

void main() {
  testWidgets('bottom navigation previews', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1
      ..padding = const FakeViewPadding(top: 47, bottom: 34)
      ..viewPadding = const FakeViewPadding(top: 47, bottom: 34);
    addTearDown(tester.view.reset);
    await tester.runAsync(_loadFonts);

    await _shot(tester, 'customer', customerShellTabs, 0);
    await _shot(tester, 'customer-account', customerShellTabs, 4);
    await _shot(tester, 'driver', driverShellTabs, 1, badgeIndex: 3);
    await _shot(tester, 'merchant', merchantShellTabs, 2);
    debugDefaultTargetPlatformOverride = null;
  }, skip: _outDir.isEmpty);
}
