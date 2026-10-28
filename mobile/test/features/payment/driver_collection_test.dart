import 'package:dealgo/features/driver/presentation/widgets/driver_payment_collection.dart';
import 'package:dealgo/features/payment/data/driver_collection_api.dart';
import 'package:dealgo/features/payment/domain/payment_models.dart';
import 'package:dealgo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

DriverCollectionLoader fixed(Map<String, Object?> json, List<String> paths) =>
    ({required accessToken, required entityType, required entityId}) async {
      paths.add(driverCollectionPath(entityType, entityId));
      return DriverCollection.fromJson(json);
    };

Future<void> pump(WidgetTester tester, Map<String, Object?> json, {String entityType = 'RIDE'}) async {
  final paths = <String>[];
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('vi'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: DriverPaymentCollection(
          entityType: entityType,
          entityId: 'r1',
          accessToken: 't',
          loader: fixed(json, paths),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(paths.single, entityType == 'RIDE' ? '/v1/rides/r1/collection' : '/v1/food/orders/r1/collection');
}

void main() {
  test('parses the server split', () {
    final c = DriverCollection.fromJson({'methodCode': 'MOMO', 'status': 'PAID', 'paidOnlineVnd': 40000, 'cashToCollectVnd': 0});
    expect(c.fullyPaidOnline, isTrue);
    expect(c.status, PaymentCheckoutStatus.paid);
    expect(DriverCollection.fromJson({'methodCode': 'ZALOPAY', 'status': 'PENDING'}).onlinePending, isTrue);
    expect(paymentMethodBrand('VNPAY_ATM'), 'VNPAY');
  });

  testWidgets('paid online: nothing to collect', (tester) async {
    await pump(tester, {'methodCode': 'MOMO', 'status': 'PAID', 'paidOnlineVnd': 40000, 'cashToCollectVnd': 0});
    expect(find.text('MoMo'), findsOneWidget);
    expect(find.text('Đã thanh toán online'), findsOneWidget);
  });

  testWidgets('cash: collect the full amount', (tester) async {
    await pump(tester, {'methodCode': 'CASH', 'status': 'CASH', 'paidOnlineVnd': 0, 'cashToCollectVnd': 52000}, entityType: 'FOOD_ORDER');
    expect(find.text('Tiền mặt'), findsOneWidget);
    expect(find.textContaining('Thu tiền mặt'), findsOneWidget);
    expect(find.textContaining('52'), findsOneWidget);
  });

  testWidgets('partially online after a partial refund', (tester) async {
    await pump(tester, {'methodCode': 'ZALOPAY', 'status': 'PAID', 'paidOnlineVnd': 30000, 'cashToCollectVnd': 10000});
    expect(find.textContaining('Đã thanh toán online'), findsOneWidget);
    expect(find.textContaining('Thu tiền mặt'), findsOneWidget);
  });
}
