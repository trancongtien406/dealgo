import 'package:dealgo/core/location/location_service.dart';
import 'package:dealgo/core/mock/fake_food_client.dart';
import 'package:dealgo/features/food/domain/entities/food_models.dart';
import 'package:dealgo/features/food/presentation/utils/food_routes.dart';
import 'package:dealgo/features/food/presentation/widgets/food_store_card.dart';
import 'package:dealgo/features/food/presentation/widgets/store_meta.dart';
import 'package:dealgo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/auth_test_harness.dart';
import '../../support/fake_identity_client.dart';
import '../../support/fake_location.dart';

Widget foodTestApp(Widget child) {
  return MaterialApp(
    locale: const Locale('vi'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

FakeFoodClient _storeClient({String? closesAtToday}) {
  return FakeFoodClient(
    stores: const [FoodStoreSummary(id: 'store-1', name: 'Bún Bò Huế')],
    details: {
      'store-1': FoodStoreDetail(
        id: 'store-1',
        name: 'Bún Bò Huế',
        items: const [
          FoodMenuItem(
            id: 'i1',
            name: 'Bún bò',
            priceVnd: 45000,
            available: true,
          ),
        ],
        closesAtToday: closesAtToday,
      ),
    },
  );
}

Future<void> _openStore(WidgetTester tester, {String? closesAtToday}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await pumpSignedIn(
    tester,
    profile: customerProfile,
    foodClient: _storeClient(closesAtToday: closesAtToday),
  );
  GoRouter.of(tester.element(find.byType(Scaffold).first))
      .push(FoodRoutes.store('store-1'));
  await tester.pumpAndSettle();
}

Future<void> _openCategory(
  WidgetTester tester, {
  String? category,
  LocationService? location,
}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await pumpSignedIn(
    tester,
    profile: customerProfile,
    foodClient: FakeFoodClient(),
    locationOverride: location,
  );
  GoRouter.of(tester.element(find.byType(Scaffold).first))
      .push(FoodRoutes.categoryOf(category));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('card and hero show "Mở đến" only with data', (tester) async {
    final store = storeSummary(
      id: 'store-1',
      name: 'Bún Bò Huế',
      closesAtToday: '22:00',
    );
    await tester.pumpWidget(
      foodTestApp(FoodStoreCard(store: store, onTap: () {})),
    );
    expect(find.byKey(const Key('store-open-until-store-1')), findsOneWidget);
    expect(find.text('Mở đến 22:00'), findsOneWidget);

    final closed = storeSummary(
      id: 'store-2',
      name: 'Quán đóng',
      closesAtToday: null,
    );
    await tester.pumpWidget(
      foodTestApp(FoodStoreCard(store: closed, onTap: () {})),
    );
    expect(find.byKey(const Key('store-open-until-store-2')), findsNothing);
  });

  testWidgets('hero shows the trust strip only with real data', (tester) async {
    await _openStore(tester, closesAtToday: '22:00');
    expect(find.byKey(const Key('store-trust-strip')), findsOneWidget);
    expect(find.text('Mở đến 22:00'), findsOneWidget);
  });

  testWidgets('hero hides the trust strip without a closing time', (
    tester,
  ) async {
    await _openStore(tester, closesAtToday: null);
    expect(find.byKey(const Key('store-trust-strip')), findsNothing);
    expect(find.textContaining('Mở đến'), findsNothing);
  });

  testWidgets('trust strip joins both items and skips a missing one', (
    tester,
  ) async {
    await tester.pumpWidget(
      foodTestApp(
        const StoreTrustStrip(closesAtToday: '22:00', feeFromVnd: 15000),
      ),
    );
    expect(find.text('Mở đến 22:00 · Phí giao từ 15.000đ'), findsOneWidget);

    await tester.pumpWidget(foodTestApp(const StoreTrustStrip(feeFromVnd: 0)));
    expect(find.text('Miễn phí giao'), findsOneWidget);
    expect(find.byKey(const Key('store-trust-strip')), findsOneWidget);

    await tester.pumpWidget(foodTestApp(const StoreTrustStrip()));
    expect(find.byKey(const Key('store-trust-strip')), findsNothing);
  });

  testWidgets(
    'category empty state talks about distance when there is no fix',
    (tester) async {
      await _openCategory(tester, location: FakeLocationService.denied());
      expect(find.byKey(const Key('food-category-empty')), findsOneWidget);
      expect(find.text('DealGo chưa giao tới khu vực này'), findsOneWidget);
    },
  );

  testWidgets('category empty state names the category when a fix exists', (
    tester,
  ) async {
    await _openCategory(tester, category: 'pho');
    expect(find.byKey(const Key('food-category-empty')), findsOneWidget);
    expect(find.text('Chưa có quán trong danh mục này'), findsOneWidget);
  });
}
