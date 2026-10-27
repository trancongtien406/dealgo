import 'package:dealgo/features/food/domain/entities/food_models.dart';
import 'package:dealgo/features/food/presentation/widgets/food_reorder_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_l10n.dart';

void main() {
  testWidgets('reorder asks for confirmation; cancel leaves the cart alone', (
    tester,
  ) async {
    const order = FoodOrderDetail(
      id: 'o-1',
      status: 'DELIVERED',
      storeId: 's-1',
      storeName: 'Bún chả cá Bà Lữ',
      subtotalVnd: 77000,
      deliveryFareVnd: 15000,
      totalVnd: 92000,
      dropoff: FoodDropoff(lat: 16.07, lng: 108.22, label: '45 Lê Duẩn'),
      lines: [],
    );
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('vi'),
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: [Locale('vi'), Locale('en')],
        home: Scaffold(body: FoodReorderButton(order: order)),
      ),
    );
    await tester.tap(find.byKey(const Key('food-reorder-o-1')));
    await tester.pumpAndSettle();
    expect(find.text('Đặt lại đơn này?'), findsOneWidget);
    // No AuthCubit/GetFoodStore in the tree: proceeding would throw, so a
    // clean cancel proves nothing ran before the user confirmed.
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(find.text('Đặt lại đơn này?'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
