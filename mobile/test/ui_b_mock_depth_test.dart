import 'package:dealgo/features/pricing/data/pricing_remote_datasource.dart';

import 'support/fake_location.dart';

import 'package:dealgo/features/places/domain/place.dart';
import 'package:dealgo/features/places/data/places_remote_datasource.dart';
import 'package:dealgo/features/food/domain/entities/food_models.dart';
import 'package:dealgo/features/identity/domain/entities/user_profile.dart';
import 'package:dealgo/features/ride/domain/entities/ride_vehicle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/auth_test_harness.dart';
import 'support/fake_food_client.dart';
import 'support/fake_identity_client.dart';
import 'support/fake_ride_client.dart';

const _driverProfile = UserProfile(
  id: 'driver-1',
  phone: '+84933333333',
  email: null,
  phoneVerifiedAt: '2026-10-13T16:00:00.000Z',
  emailVerifiedAt: null,
  grants: [RoleGrant(role: 'DRIVER', status: 'ACTIVE')],
);

const _merchantProfile = UserProfile(
  id: 'merchant-1',
  phone: '+84901110001',
  email: null,
  phoneVerifiedAt: '2026-10-13T16:00:00.000Z',
  emailVerifiedAt: null,
  grants: [RoleGrant(role: 'MERCHANT', status: 'ACTIVE')],
);

void main() {
  test('ride short reference is the tail of the real id', () {
    expect(rideShortRef('3f9a1c2e-0000-4000-8000-00000abc1234'), '#1234');
    expect(rideShortRef(''), '#—');
  });

  testWidgets('unified Đặt xe opens class+offer after A/B', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final rides = FakeRideClient();
    const airport = PlaceOption(
      name: 'Sân bay Quốc tế Đà Nẵng',
      address: 'Nguyễn Văn Linh, Hải Châu, Đà Nẵng',
      lat: 16.0439,
      lng: 108.1994,
      source: PlaceSource.recent,
    );
    await pumpSignedIn(
      tester,
      profile: customerProfile,
      rideClient: rides,
      locationOverride: FakeLocationService(),
      places: FakePlacesRemoteDataSource(recent: [airport]),
      pricing: FakePricingRemoteDataSource(fixedReferenceVnd: 42000),
    );

    // One Ride entry — class chosen on the merged fare screen.
    await tester.tap(find.byKey(const Key('home-service-ride')));
    await tester.pumpAndSettle();
    expect(find.text('Bạn muốn đi đâu?'), findsOneWidget);
    await tester.tap(find.text(airport.name));
    await tester.pumpAndSettle();
    // Destination chosen → class+fare opens automatically.
    expect(find.text('Đề xuất của bạn'), findsOneWidget);
    expect(find.text('Xe máy'), findsWidgets);
    expect(find.text('Xe 4 chỗ'), findsWidgets);
    expect(find.text('Xe 7 chỗ'), findsWidgets);
    expect(find.byKey(const Key('ride-submit-fare')), findsOneWidget);
  });

  testWidgets('driver notifications use driver copy', (tester) async {
    await pumpSignedIn(tester, profile: _driverProfile);
    await tester.tap(navLabel('Thông báo'));
    await tester.pumpAndSettle();

    expect(find.text('Thông báo tài xế'), findsOneWidget);
    // Real inbox (no sample driver notices).
    expect(find.textContaining('Mẫu tài xế'), findsNothing);
    expect(find.text('Tài xế đã đến gần bạn'), findsNothing);
    expect(find.text('Ưu đãi mới dành cho bạn'), findsNothing);
  });

  testWidgets('merchant preparing shows kitchen status', (tester) async {
    final food = FakeFoodClient()
      ..queueOrders = [
        MerchantQueueOrder(
          id: 'order-prep-1',
          storeId: 'store-1',
          status: 'PREPARING',
          deliveryFareVnd: 25000,
          subtotalVnd: 125000,
          totalVnd: 150000,
          dropoff: const FoodDropoff(
            lat: 16.1,
            lng: 108.2,
            label: '456 Trần Hưng Đạo',
          ),
          lineCount: 3,
          createdAt: '2026-10-14T02:20:00.000Z',
        ),
      ];
    await pumpSignedIn(tester, profile: _merchantProfile, foodClient: food);
    await tester.tap(navLabel('Đơn hàng'));
    await tester.pumpAndSettle();
    final card = find.byKey(const Key('merchant-order-order-prep-1'));
    await tester.ensureVisible(card);
    await tester.tap(card);
    await tester.pumpAndSettle();

    expect(find.text('Đơn đang chuẩn bị'), findsOneWidget);
    // No invented kitchen timers or per-item status.
    expect(find.text('Trạng thái bếp'), findsNothing);
    expect(find.text('13:30'), findsNothing);
    expect(find.text('Món cần chuẩn bị'), findsOneWidget);
    expect(find.byKey(const Key('merchant-ready')), findsOneWidget);
  });

  testWidgets('food success screen appears after matched place', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const item = FoodMenuItem(
      id: 'item-bun',
      name: 'Bún bò đặc biệt',
      priceVnd: 60000,
      available: true,
    );
    final food =
        FakeFoodClient(
            stores: const [
              FoodStoreSummary(id: 'store-bun-bo', name: 'Bún Bò Huế'),
            ],
            details: const {
              'store-bun-bo': FoodStoreDetail(
                id: 'store-bun-bo',
                name: 'Bún Bò Huế',
                items: [item],
              ),
            },
          )
          ..placedOrder = const PlacedFoodOrder(
            id: 'order-ok',
            status: 'PLACED',
            subtotalVnd: 60000,
            deliveryFareVnd: 25000,
            totalVnd: 85000,
            lines: [
              FoodOrderLine(
                itemId: 'item-bun',
                name: 'Bún bò đặc biệt',
                unitPriceVnd: 60000,
                quantity: 1,
              ),
            ],
          );
    await pumpSignedIn(
      tester,
      profile: customerProfile,
      foodClient: food,
      pricing: FakePricingRemoteDataSource(deliveryFareVnd: 25000),
    );
    await tester.tap(navLabel('Mua'));
    await tester.pumpAndSettle();
    await tapFoodStoreCard(tester, 'store-bun-bo');
    await tester.tap(find.byKey(const Key('food-add-item-bun')));
    await tester.pumpAndSettle();
    final optionsAdd = find.byKey(const Key('food-options-add'));
    if (optionsAdd.evaluate().isNotEmpty) {
      await tester.tap(optionsAdd);
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Xem giỏ hàng'));
    await tester.pumpAndSettle();
    await chooseDeliveryAddress(tester);
    await tester.tap(find.byKey(const Key('food-place-order')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('food-order-success-title')), findsOneWidget);
    expect(find.text('Đặt hàng thành công'), findsOneWidget);
    expect(find.byKey(const Key('food-track-order')), findsOneWidget);
  });
}

Future<void> tapFoodStoreCard(WidgetTester tester, String storeId) async {
  final card = find.byKey(Key('food-store-card-$storeId'));
  await tester.scrollUntilVisible(
    card,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(card);
  await tester.pumpAndSettle();
}
