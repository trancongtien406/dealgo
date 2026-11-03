import 'package:dealgo/core/location/location_service.dart';
import 'package:dealgo/core/mock/fake_food_client.dart';
import 'package:dealgo/features/food/domain/entities/food_models.dart';
import 'package:dealgo/features/food/domain/repositories/food_repository.dart';
import 'package:dealgo/features/food/domain/usecases/list_food_stores.dart';
import 'package:dealgo/features/food/presentation/cubit/food_discovery_cubit.dart';
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

FakeFoodClient _storeClient({
  String? closesAtToday,
  int? deliveryFeeFromVnd,
}) {
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
        deliveryFeeFromVnd: deliveryFeeFromVnd,
      ),
    },
  );
}

Future<FakeFoodClient> _openStore(
  WidgetTester tester, {
  String? closesAtToday,
  int? deliveryFeeFromVnd,
  LocationService? location,
}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final client = _storeClient(
    closesAtToday: closesAtToday,
    deliveryFeeFromVnd: deliveryFeeFromVnd,
  );
  await pumpSignedIn(
    tester,
    profile: customerProfile,
    foodClient: client,
    locationOverride: location,
  );
  GoRouter.of(tester.element(find.byType(Scaffold).first))
      .push(FoodRoutes.store('store-1'));
  await tester.pumpAndSettle();
  return client;
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

  testWidgets('hero shows the quoted fee beside the closing time', (
    tester,
  ) async {
    await _openStore(
      tester,
      closesAtToday: '22:00',
      deliveryFeeFromVnd: 15000,
    );
    expect(find.text('Mở đến 22:00 · Phí giao từ 15.000đ'), findsOneWidget);
  });

  testWidgets('hero keeps only the closing time when the fee is missing', (
    tester,
  ) async {
    await _openStore(tester, closesAtToday: '22:00');
    expect(find.text('Mở đến 22:00'), findsOneWidget);
    expect(find.textContaining('Phí giao'), findsNothing);
  });

  testWidgets('store detail read carries the customer position', (
    tester,
  ) async {
    final located = await _openStore(tester, closesAtToday: '22:00');
    expect(located.storeReadGeo, [true]);
  });

  testWidgets('store detail read omits the position when it is unknown', (
    tester,
  ) async {
    final denied = await _openStore(
      tester,
      closesAtToday: '22:00',
      location: FakeLocationService.denied(),
    );
    expect(denied.storeReadGeo, [false]);
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

  testWidgets('filtered category without a fix still blames the area', (
    tester,
  ) async {
    await _openCategory(
      tester,
      category: 'pho',
      location: FakeLocationService.denied(),
    );
    expect(find.byKey(const Key('food-category-empty')), findsOneWidget);
    expect(find.text('DealGo chưa giao tới khu vực này'), findsOneWidget);
  });

  test('discovery hasLocation reflects the coordinates it browsed with', () async {
    final withoutFix = FoodDiscoveryCubit(
      listFoodStores: ListFoodStores(_EmptyFoodRepo()),
      location: FakeLocationService.denied(),
    );
    await withoutFix.load('tok');
    expect((withoutFix.state as FoodDiscoveryReady).hasLocation, isFalse);

    final withFix = FoodDiscoveryCubit(
      listFoodStores: ListFoodStores(_EmptyFoodRepo()),
    );
    await withFix.load('tok', lat: testPickupLat, lng: testPickupLng);
    expect((withFix.state as FoodDiscoveryReady).hasLocation, isTrue);

    await withoutFix.close();
    await withFix.close();
  });

  testWidgets('feed card fits 360 px with long name and full meta', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = storeSummary(
      id: 'store-1',
      name: 'Quán Bún Bò Huế Gia Truyền Đặc Biệt Số Một Đà Nẵng',
      distanceKm: 12.7,
      etaMinutes: 45,
      deliveryFeeFromVnd: 25000,
      closesAtToday: '23:30',
    );
    await tester.pumpWidget(
      foodTestApp(
        Center(
          child: SizedBox(
            width: 360,
            child: FoodStoreCard(store: store, onTap: () {}),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('store-open-until-store-1')), findsOneWidget);
  });
}

class _EmptyFoodRepo implements FoodRepository {
  @override
  Future<FoodStorePageResult> listStores(
    String accessToken, {
    double? lat,
    double? lng,
    String? search,
    String? sortBy,
    int? maxKm,
    String? category,
    int page = 1,
    int limit = 20,
  }) async {
    return FoodStorePageResult(
      items: const [],
      total: 0,
      page: page,
      limit: limit,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
