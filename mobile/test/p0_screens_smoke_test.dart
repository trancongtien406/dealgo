import 'package:dealgo/features/driver/presentation/pages/driver_job_completed_page.dart';
import 'package:dealgo/features/driver/presentation/pages/driver_job_failed_page.dart';
import 'package:dealgo/features/food/presentation/pages/food_cancel_page.dart';
import 'package:dealgo/features/merchant/presentation/pages/merchant_accept_settings_page.dart';
import 'package:dealgo/features/merchant/presentation/pages/merchant_busy_page.dart';
import 'package:dealgo/features/merchant/presentation/pages/merchant_hours_page.dart';
import 'package:dealgo/features/ride/presentation/pages/ride_cancel_page.dart';
import 'package:dealgo/features/ride/presentation/pages/ride_safety_page.dart';
import 'package:dealgo/l10n/app_localizations.dart';
import 'package:dealgo/features/driver_history/domain/driver_history.dart';
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
    expect(
      find.byKey(const Key('ride-cancel-reason-wait_too_long')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('ride-cancel-reason-wait_too_long')));
    await tester.pump();
    expect(find.byKey(const Key('ride-cancel-confirm')), findsOneWidget);
  });

  testWidgets('C035 food cancel reason tiles', (tester) async {
    await tester.pumpWidget(_wrap(const FoodCancelPage(orderId: 'order-1')));
    expect(
      find.byKey(const Key('food-cancel-reason-wrong_items')),
      findsOneWidget,
    );
  });

  testWidgets('D031 failed job outcome UI', (tester) async {
    await tester.pumpWidget(_wrap(const DriverJobFailedPage(jobId: 'job-1')));
    expect(find.byKey(const Key('driver-job-failed-submit')), findsOneWidget);
  });

  testWidgets('D034 completed job detail', (tester) async {
    await tester.pumpWidget(
      _wrap(
        DriverJobCompletedPage(
          jobId: 'job-1',
          item: DriverHistoryItem(
            kind: DriverJobKind.ride,
            id: 'job-1',
            outcome: DriverJobOutcome.completed,
            fareVnd: 50000,
            feeVnd: 5000,
            feePercent: 10,
            earningsVnd: 45000,
            pickupLabel: 'Hải Châu',
            dropoffLabel: 'Sân bay',
            finishedAt: DateTime(2026, 10, 19, 9, 30),
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('driver-completed-back-jobs')), findsOneWidget);
    expect(find.text('Hải Châu → Sân bay'), findsOneWidget);
    expect(find.text('Phí nền tảng (10%)'), findsOneWidget);
    expect(find.text('45.000đ'), findsOneWidget);
    expect(find.text('Chuyến #JOB1'), findsOneWidget);
  });

  testWidgets('M022–M024 merchant settings shells', (tester) async {
    await tester.pumpWidget(_wrap(const MerchantAcceptSettingsPage()));
    expect(find.byType(MerchantAcceptSettingsPage), findsOneWidget);
    await tester.pumpWidget(_wrap(const MerchantHoursPage()));
    expect(find.byType(MerchantHoursPage), findsOneWidget);
    await tester.pumpWidget(_wrap(const MerchantBusyPage()));
    expect(find.byType(MerchantBusyPage), findsOneWidget);
  });
}
