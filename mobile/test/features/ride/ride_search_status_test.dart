import 'package:dealgo/features/ride/presentation/widgets/ride_search_status.dart';
import 'package:dealgo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) {
  return MaterialApp(
    locale: const Locale('vi'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('viewer banner names the count and the empty state', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const RideViewerBanner(count: 0)));
    expect(find.text('Đang báo cho tài xế gần bạn'), findsOneWidget);
    expect(find.text('Chưa có tài xế mở yêu cầu'), findsOneWidget);

    await tester.pumpWidget(_app(const RideViewerBanner(count: 4)));
    expect(find.text('4 tài xế đang xem yêu cầu'), findsOneWidget);
    expect(find.text('Đang báo cho tài xế gần bạn'), findsOneWidget);
  });

  testWidgets('auto-accept switch reports the offered price', (tester) async {
    var enabled = false;
    await tester.pumpWidget(
      _app(
        RideAutoAcceptSwitch(
          priceVnd: 67000,
          enabled: enabled,
          busy: false,
          onChanged: (value) => enabled = value,
        ),
      ),
    );
    expect(find.textContaining('67.000'), findsOneWidget);
    expect(find.textContaining('Chỉ nhận đúng giá'), findsOneWidget);
    await tester.tap(find.byKey(const Key('ride-auto-accept-switch')));
    await tester.pump();
    expect(enabled, isTrue);
  });
}
