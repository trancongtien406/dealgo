import 'package:dealgo/features/driver/presentation/pages/driver_job_completed_page.dart';
import 'package:dealgo/features/driver/presentation/pages/driver_job_failed_page.dart';
import 'package:dealgo/features/food/presentation/pages/food_cancel_page.dart';
import 'package:dealgo/features/merchant/presentation/pages/merchant_accept_settings_page.dart';
import 'package:dealgo/features/merchant/presentation/pages/merchant_busy_page.dart';
import 'package:dealgo/features/merchant/presentation/pages/merchant_hours_page.dart';
import 'package:dealgo/features/merchant/presentation/pages/merchant_item_variants_page.dart';
import 'package:dealgo/features/ride/presentation/pages/ride_cancel_page.dart';
import 'package:dealgo/features/ride/presentation/pages/ride_safety_page.dart';
import 'package:dealgo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('vi'),
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('C014 safety center renders share CTA', (tester) async {
    await tester.pumpWidget(_wrap(const RideSafetyPage(rideId: 'ride-1')));
    expect(find.byKey(const Key('ride-safety-share')), findsOneWidget);
  });

  testWidgets('C016 cancel ride reason tiles', (tester) async {
    await tester.pumpWidget(_wrap(const RideCancelPage(rideId: 'ride-1')));
    expect(find.byKey(const Key('ride-cancel-reason-wait_too_long')), findsOneWidget);
    await tester.tap(find.byKey(const Key('ride-cancel-reason-wait_too_long')));
    await tester.pump();
    expect(find.byKey(const Key('ride-cancel-confirm')), findsOneWidget);
  });

  testWidgets('C035 food cancel reason tiles', (tester) async {
    await tester.pumpWidget(_wrap(const FoodCancelPage(orderId: 'order-1')));
    expect(find.byKey(const Key('food-cancel-reason-wrong_items')), findsOneWidget);
  });

  testWidgets('D031 failed job outcome UI', (tester) async {
    await tester.pumpWidget(_wrap(const DriverJobFailedPage(jobId: 'job-1')));
    expect(find.byKey(const Key('driver-job-failed-submit')), findsOneWidget);
  });

  testWidgets('D034 completed job detail', (tester) async {
    await tester.pumpWidget(
      _wrap(const DriverJobCompletedPage(jobId: 'job-1')),
    );
    expect(find.byKey(const Key('driver-completed-back-jobs')), findsOneWidget);
  });

  testWidgets('M022–M024 merchant settings shells', (tester) async {
    await tester.pumpWidget(_wrap(const MerchantAcceptSettingsPage()));
    expect(find.byType(MerchantAcceptSettingsPage), findsOneWidget);
    await tester.pumpWidget(_wrap(const MerchantHoursPage()));
    expect(find.byKey(const Key('merchant-hours-mon')), findsOneWidget);
    await tester.pumpWidget(_wrap(const MerchantBusyPage()));
    expect(find.byType(MerchantBusyPage), findsOneWidget);
  });

  testWidgets('M028 variants editor shell', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const MerchantItemVariantsPage(itemId: 'item-1', itemName: 'Bun bo'),
      ),
    );
    expect(find.byKey(const Key('merchant-variants-save')), findsOneWidget);
    expect(find.byKey(const Key('merchant-topping-egg')), findsOneWidget);
  });
}
