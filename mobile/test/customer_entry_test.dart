import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dealgo/core/mock/fake_food_client.dart';
import 'package:dealgo/features/food/domain/entities/food_models.dart';

import 'support/auth_test_harness.dart';
import 'support/fake_identity_client.dart';

void main() {
  testWidgets(
    'login screen shows auth methods and Tiếp tục when phone chosen',
    (tester) async {
      await pumpDealGo(tester, client: FakeIdentityClient());

      expect(find.byKey(const Key('auth-method-phone')), findsOneWidget);
      expect(
        find.text('Chào mừng đến với\nDealGo', findRichText: true),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('auth-method-phone')));
      await tester.pumpAndSettle();

      expect(find.text('Tiếp tục'), findsOneWidget);
    },
  );

  testWidgets('customer home shows Đặt xe and Đồ ăn', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpSignedIn(
      tester,
      profile: customerProfile,
      foodClient: FakeFoodClient(
        stores: const [FoodStoreSummary(id: 's1', name: 'Bún Bò Huế Ô Cồ')],
      ),
    );

    expect(find.text('Đặt xe'), findsWidgets);
    expect(find.text('Đồ ăn'), findsWidgets);
    expect(find.byKey(const Key('home-service-ride')), findsOneWidget);
    expect(find.byKey(const Key('home-service-food')), findsOneWidget);
    expect(find.byKey(const Key('home-service-bike')), findsNothing);
    expect(find.byKey(const Key('home-service-car')), findsNothing);
    expect(find.text('Bún Bò Huế Ô Cồ'), findsOneWidget);
    expect(find.byKey(const Key('home-store-s1')), findsOneWidget);
    // The recent card shows the latest ride from the history endpoint.
    expect(
      find.descendant(
        of: find.byKey(const Key('home-recent-activity')),
        matching: find.text('Chuyến đi đến sân bay'),
      ),
      findsOneWidget,
    );
    expect(find.text('Sân bay Đà Nẵng → 123 Nguyễn Văn Linh'), findsNothing);
    expect(find.textContaining('50%'), findsNothing);
    expect(navLabel('Trang'), findsOneWidget);
  });

  testWidgets('featured new-store cards hug their content, same height', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpSignedIn(
      tester,
      profile: customerProfile,
      foodClient: FakeFoodClient(
        stores: const [
          FoodStoreSummary(id: 's1', name: 'My Store'),
          FoodStoreSummary(
            id: 's2',
            name: 'Quán bún bò có cái tên rất dài để xuống hai dòng',
          ),
        ],
      ),
    );
    final a = tester.getSize(find.byKey(const Key('home-store-s1')));
    final b = tester.getSize(find.byKey(const Key('home-store-s2')));
    expect(a.height, b.height);
    // 16:9 cover (99) + name + one meta line + padding — no empty block.
    expect(a.height, lessThan(200));
    expect(tester.takeException(), isNull);
  });
}
