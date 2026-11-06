import 'package:dealgo/core/design_system/components/dealgo_banner.dart';
import 'package:dealgo/core/design_system/components/dealgo_dialog.dart';
import 'package:dealgo/core/design_system/components/dealgo_network_image.dart';
import 'package:dealgo/core/design_system/components/dealgo_skeleton.dart';
import 'package:dealgo/core/design_system/components/dealgo_state_view.dart';
import 'package:dealgo/core/design_system/icons/dealgo_icons.dart';
import 'package:dealgo/core/design_system/theme/dealgo_theme.dart';
import 'package:dealgo/core/design_system/tokens/dealgo_tokens.dart';
import 'package:dealgo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DealGoNetworkImage.decodeWidth', () {
    test('wide cover decodes at its own width', () {
      expect(DealGoNetworkImage.decodeWidth(390, 195, 3), 1170);
    });

    test('square thumb decodes wide enough for a 2:1 photo', () {
      expect(DealGoNetworkImage.decodeWidth(56, 56, 3), 336);
    });

    test('caps huge boxes', () {
      expect(
        DealGoNetworkImage.decodeWidth(2000, null, 3),
        DealGoNetworkImage.maxDecodeWidth,
      );
    });
  });

  testWidgets('uses cover fit and a decode width', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(
            width: 100,
            height: 100,
            child: DealGoNetworkImage('https://example.invalid/a.jpg'),
          ),
        ),
      ),
    );
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.fit, BoxFit.cover);
    expect(image.image, isA<ResizeImage>());
    expect(find.byType(DealGoImagePlaceholder), findsOneWidget);
  });

  testWidgets('shows distinct DealGoImageFallback when image fails to load', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(
            width: 120,
            height: 120,
            child: DealGoNetworkImage('https://example.invalid/broken.jpg'),
          ),
        ),
      ),
    );
    final image = tester.widget<Image>(find.byType(Image));
    final ctx = tester.element(find.byType(Image));
    final fallbackWidget = image.errorBuilder!(
      ctx,
      Exception('404'),
      StackTrace.empty,
    );
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: fallbackWidget)));
    expect(find.byType(DealGoImageFallback), findsOneWidget);
  });

  testWidgets('DealGoShimmer applies diagonal gradient ShaderMask and skeletons render', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: DealGoTheme.light,
        home: const Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                DealGoBannerSkeleton(),
                DealGoStoreCardSkeleton(),
                DealGoGridSkeleton(itemCount: 4),
                DealGoSkeletonList(itemCount: 2),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.byType(ShaderMask), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('all 16 DealGoStateArt variants render layered artwork in light & dark mode', (
    tester,
  ) async {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      DealGoPalette.use(brightness);
      for (final art in DealGoStateArt.values) {
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('vi'),
            theme: brightness == Brightness.dark
                ? DealGoTheme.dark
                : DealGoTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: DealGoStateView(
                art: art,
                title: 'Tiêu đề ${art.name}',
                message: 'Mô tả chi tiết cho trạng thái ${art.name}',
                actionLabel: 'Thử lại',
                onAction: () {},
                secondaryLabel: 'Quay lại',
                onSecondary: () {},
              ),
            ),
          ),
        );
        expect(find.byType(DealGoStateArtwork), findsOneWidget);
        expect(find.text('Tiêu đề ${art.name}'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    }
    DealGoPalette.use(Brightness.light);
  });

  testWidgets('DealGoDialog and DealGoBanner render semantic icon badges', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: DealGoTheme.light,
        home: Scaffold(
          body: Column(
            children: [
              DealGoBanner(
                title: 'Mất kết nối mạng',
                message: 'Đang tự động thử kết nối lại...',
                tone: DealGoBannerTone.offline,
                actionLabel: 'Thử lại',
                onAction: () {},
              ),
              const DealGoDialog(
                title: 'Xác nhận hủy đơn?',
                body: 'Đơn hàng sẽ không thể khôi phục sau khi hủy.',
                primaryLabel: 'Hủy đơn',
                secondaryLabel: 'Giữ lại',
                primaryTone: DealGoDialogPrimaryTone.danger,
                icon: DealGoIcons.warning,
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('dealgo-dialog-icon-badge')), findsOneWidget);
    expect(find.byKey(const Key('dealgo-banner-icon-badge')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
