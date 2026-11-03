import 'package:dealgo/features/food/data/datasources/dio_food_remote_datasource.dart';
import 'package:dealgo/features/food/domain/entities/food_models.dart';
import 'package:dealgo/features/food/presentation/utils/food_routes.dart';
import 'package:dealgo/features/food/presentation/widgets/food_order_extras.dart';
import 'package:dealgo/l10n/app_localizations.dart';
import 'package:dealgo/features/identity/domain/entities/user_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/auth_test_harness.dart';

import 'package:dealgo/features/merchant/data/datasources/fake_merchant_orders_client.dart';

import '../../support/fake_food_client.dart';
import '../../support/fake_identity_client.dart';

const _merchantProfile = UserProfile(
  id: 'merchant-1',
  phone: '+84901110001',
  email: null,
  phoneVerifiedAt: '2026-10-13T16:00:00.000Z',
  emailVerifiedAt: null,
  grants: [RoleGrant(role: 'MERCHANT', status: 'ACTIVE')],
);

const _detail = FoodOrderDetail(
  id: 'order-notes',
  status: 'PREPARING',
  storeName: 'Bún Bò Huế',
  subtotalVnd: 45000,
  deliveryFareVnd: 15000,
  totalVnd: 60000,
  dropoff: FoodDropoff(lat: 16.1, lng: 108.2, label: 'Sơn Trà'),
  note: 'Gọi trước khi giao',
  utensils: false,
  lines: [
    FoodOrderLine(
      itemId: 'item-bun',
      name: 'Bún bò',
      unitPriceVnd: 45000,
      quantity: 1,
      note: 'ít cay',
    ),
  ],
);

FoodOrderDetail _withStatus(String status) => FoodOrderDetail(
  id: _detail.id,
  status: status,
  storeName: _detail.storeName,
  subtotalVnd: _detail.subtotalVnd,
  deliveryFareVnd: _detail.deliveryFareVnd,
  totalVnd: _detail.totalVnd,
  dropoff: _detail.dropoff,
  note: _detail.note,
  utensils: _detail.utensils,
  lines: _detail.lines,
);

Future<void> _pumpCustomer(WidgetTester tester, FakeFoodClient food) async {
  await tester.binding.setSurfaceSize(const Size(400, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await pumpSignedIn(tester, profile: customerProfile, foodClient: food);
}

Future<void> _push(WidgetTester tester, String location) async {
  final context = tester.element(find.byType(Scaffold).first);
  GoRouter.of(context).push(location);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('invoice shows the order note, cutlery and line notes', (
    tester,
  ) async {
    final food = FakeFoodClient()..orderDetail = _detail;
    await _pumpCustomer(tester, food);
    await _push(tester, FoodRoutes.invoice('order-notes'));

    expect(find.byKey(const Key('food-order-note-read')), findsOneWidget);
    expect(find.text('Gọi trước khi giao'), findsOneWidget);
    expect(find.byKey(const Key('food-order-utensils-read')), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('food-order-utensils-read')))
          .data,
      'Không',
    );
    expect(find.text('"ít cay"'), findsOneWidget);
  });

  testWidgets('tracking shows the order note line', (tester) async {
    final food = FakeFoodClient()..orderDetail = _withStatus('ASSIGNED');
    await _pumpCustomer(tester, food);
    await _push(tester, FoodRoutes.order('order-notes'));

    expect(find.byKey(const Key('food-tracking-order-note')), findsOneWidget);
    expect(find.text('Gọi trước khi giao'), findsOneWidget);
  });

  testWidgets('merchant ticket shows the order note, cutlery and line note', (
    tester,
  ) async {
    final merchant = FakeMerchantOrdersClient(
      queueOrders: [
        MerchantQueueOrder(
          id: 'order-notes',
          storeId: 'store-1',
          status: 'PREPARING',
          deliveryFareVnd: 15000,
          subtotalVnd: 45000,
          totalVnd: 60000,
          dropoff: _detail.dropoff,
          lineCount: 1,
          createdAt: '2026-10-14T02:20:00.000Z',
        ),
      ],
      onGetOrder: (_) => _withStatus('PREPARING'),
    );
    await tester.binding.setSurfaceSize(const Size(400, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpSignedIn(
      tester,
      profile: _merchantProfile,
      foodClient: FakeFoodClient(),
      merchantOrdersClient: merchant,
    );

    await tester.tap(navLabel('Đơn hàng'));
    await tester.pumpAndSettle();
    final card = find.byKey(const Key('merchant-order-order-notes'));
    await tester.ensureVisible(card);
    await tester.tap(card);
    await tester.pumpAndSettle();

    expect(find.text('"ít cay"'), findsWidgets);
    final note = find.byKey(const Key('food-order-note-read'));
    await tester.ensureVisible(note);
    expect(tester.widget<Text>(note).data, 'Gọi trước khi giao');
    expect(find.byKey(const Key('food-order-utensils-read')), findsWidgets);
  });

  testWidgets('the ready payload keeps the note and cutlery for the driver', (
    tester,
  ) async {
    final job = decodeReadyFoodJobs({
      'success': true,
      'data': [
        {
          'id': 'order-notes',
          'storeId': 'store-1',
          'storeName': 'Bún Bò Huế',
          'deliveryFareVnd': 15000,
          'subtotalVnd': 45000,
          'totalVnd': 60000,
          'lineCount': 1,
          'note': 'Gọi trước khi giao',
          'utensils': false,
          'dropoff': {'lat': 16.1, 'lng': 108.2, 'label': 'Sơn Trà'},
        },
      ],
    }).single;

    expect(job.note, 'Gọi trước khi giao');
    expect(job.utensils, isFalse);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: FoodOrderExtrasBlock(note: job.note, utensils: job.utensils),
          ),
        ),
      ),
    );
    expect(find.text('Gọi trước khi giao'), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('food-order-utensils-read')))
          .data,
      'Không',
    );
  });
}
