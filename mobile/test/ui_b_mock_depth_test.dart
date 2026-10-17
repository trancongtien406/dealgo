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
  test('ride quote display helpers stay stable for mock UI', () {
    expect(rideQuoteDisplayId('ride-1'), 'Q-CAR-IDE1');
    expect(ridePickupCode('ride-track').length, 4);
  });

  testWidgets('vehicle picker appears before fare', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final rides = FakeRideClient();
    await pumpSignedIn(tester, profile: customerProfile, rideClient: rides);

    await tester.tap(find.text('Đặt xe').hitTestable().first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nhập địa chỉ thủ công'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('ride-suggestion-airport')),
    );
    await tester.tap(find.byKey(const Key('ride-suggestion-airport')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('ride-open-route-overview')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ride-open-vehicle')));
    await tester.pumpAndSettle();

    expect(find.text('Chọn loại xe'), findsOneWidget);
    expect(find.text('Xe máy'), findsWidgets);
    expect(find.text('Xe 4 chỗ'), findsWidgets);
    expect(find.text('Xe 7 chỗ'), findsOneWidget);
    expect(find.text('Tự đề xuất giá chuyến'), findsNothing);
  });

  testWidgets('driver notifications use driver copy', (tester) async {
    await pumpSignedIn(tester, profile: _driverProfile);
    await tester.tap(navLabel('Thông báo'));
    await tester.pumpAndSettle();

    expect(find.text('Thông báo tài xế'), findsOneWidget);
    expect(find.text('Có yêu cầu chở khách gần bạn'), findsOneWidget);
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
    expect(find.text('Trạng thái bếp'), findsOneWidget);
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
    await pumpSignedIn(tester, profile: customerProfile, foodClient: food);
    await tester.tap(navLabel('Mua hàng'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('food-store-card-store-bun-bo')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('food-add-item-bun')));
    await tester.pumpAndSettle();
    final optionsAdd = find.byKey(const Key('food-options-add'));
    if (optionsAdd.evaluate().isNotEmpty) {
      await tester.tap(optionsAdd);
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Xem giỏ hàng'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tiếp tục thanh toán'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('food-place-order')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('food-order-success-title')), findsOneWidget);
    expect(find.text('Đặt hàng thành công'), findsOneWidget);
    expect(find.byKey(const Key('food-track-order')), findsOneWidget);
  });
}
