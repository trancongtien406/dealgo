import 'package:dealgo/core/design_system/components/dealgo_refresh.dart';
import 'package:dealgo/core/design_system/components/dealgo_state_view.dart';
import 'package:dealgo/core/design_system/theme/dealgo_theme.dart';
import 'package:dealgo/core/ui/keyboard_dismiss.dart';
import 'package:dealgo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'DealGoRefresh triggers onRefresh on a short ListView even without explicit physics',
    (tester) async {
      var refreshed = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: DealGoTheme.light,
          scrollBehavior: const DealGoScrollBehavior(),
          home: Scaffold(
            body: DealGoRefresh(
              onRefresh: () async {
                refreshed++;
              },
              child: ListView(
                children: const [
                  SizedBox(height: 60, child: Center(child: Text('Item 1'))),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.drag(find.text('Item 1'), const Offset(0, 300));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(refreshed, 1);
    },
  );

  testWidgets(
    'DealGoRefresh triggers onRefresh when dragging directly on DealGoStateView inside ListView (Android & iOS)',
    (tester) async {
      for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
        var refreshed = 0;
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('vi'),
            theme: DealGoTheme.light.copyWith(platform: platform),
            scrollBehavior: const DealGoScrollBehavior(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: DealGoRefresh(
                onRefresh: () async {
                  refreshed++;
                },
                child: ListView(
                  children: const [
                    DealGoStateView(
                      art: DealGoStateArt.noOrders,
                      title: 'Chưa có đơn hàng',
                      message: 'Kéo xuống để tải lại danh sách',
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.drag(find.text('Chưa có đơn hàng'), const Offset(0, 300));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();

        expect(refreshed, 1, reason: 'Failed on $platform');
      }
    },
  );

  testWidgets(
    'DealGoRefresh triggers onRefresh when wrapping a standalone DealGoStateView',
    (tester) async {
      var refreshed = 0;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('vi'),
          theme: DealGoTheme.light,
          scrollBehavior: const DealGoScrollBehavior(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: DealGoRefresh(
              onRefresh: () async {
                refreshed++;
              },
              child: const DealGoStateView(
                art: DealGoStateArt.offline,
                title: 'Mất kết nối mạng',
                message: 'Kéo xuống để thử lại',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.drag(find.text('Mất kết nối mạng'), const Offset(0, 300));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(refreshed, 1);
    },
  );

  testWidgets(
    'DealGoRefresh triggers onRefresh on a CustomScrollView and NestedScrollView body',
    (tester) async {
      var customRefreshed = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: DealGoTheme.light,
          scrollBehavior: const DealGoScrollBehavior(),
          home: Scaffold(
            body: DealGoRefresh(
              onRefresh: () async {
                customRefreshed++;
              },
              child: const CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 80,
                      child: Center(child: Text('Discovery Header')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.drag(
        find.text('Discovery Header'),
        const Offset(0, 300),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(customRefreshed, 1);

      var nestedRefreshed = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: DealGoTheme.light,
          scrollBehavior: const DealGoScrollBehavior(),
          home: Scaffold(
            body: DealGoRefresh(
              onRefresh: () async {
                nestedRefreshed++;
              },
              child: NestedScrollView(
                headerSliverBuilder: (context, _) => const [
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 120,
                      child: Center(child: Text('Store Hero')),
                    ),
                  ),
                ],
                body: ListView(
                  children: const [
                    SizedBox(
                      height: 60,
                      child: Center(child: Text('Menu Item')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.drag(find.text('Menu Item'), const Offset(0, 300));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(nestedRefreshed, 1);
    },
  );
}
