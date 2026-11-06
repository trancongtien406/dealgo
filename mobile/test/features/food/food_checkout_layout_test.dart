import 'package:dealgo/features/food/domain/entities/food_models.dart';
import 'package:dealgo/features/food/presentation/cubit/food_cart_cubit.dart';
import 'package:dealgo/features/food/presentation/utils/food_routes.dart';
import 'package:dealgo/features/pricing/data/pricing_remote_datasource.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/auth_test_harness.dart';
import '../../support/fake_food_client.dart';
import '../../support/fake_identity_client.dart';

const _storeId = 'store-bun-bo';
const _bunId = 'item-bun';

void main() {
  testWidgets('checkout groups store, address, items, bill and payment', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpSignedIn(
      tester,
      profile: customerProfile,
      foodClient: FakeFoodClient(),
      pricing: FakePricingRemoteDataSource(deliveryFareVnd: 25000),
    );
    final context = tester.element(find.byType(Scaffold).first);
    final cart = context.read<FoodCartCubit>();
    final item = const FoodMenuItem(
      id: _bunId,
      name: 'Bún bò đặc biệt',
      priceVnd: 60000,
      available: true,
    );
    cart
      ..addItem(
        storeId: _storeId,
        storeName: 'Bún Bò Huế',
        item: item,
        minOrderVnd: 0,
        prepMinutes: 25,
      )
      ..addItem(
        storeId: _storeId,
        storeName: 'Bún Bò Huế',
        item: item,
        minOrderVnd: 0,
        prepMinutes: 25,
      )
      ..setDropoff(label: 'Nhà, 45 Lê Duẩn', lat: 16.0717, lng: 108.2207)
      ..setDeliveryFare(25000);

    GoRouter.of(context).push(FoodRoutes.checkout);
    await tester.pumpAndSettle();

    expect(find.text('Bún Bò Huế'), findsOneWidget);
    expect(find.text('2 món · Giao trong ~25 phút'), findsOneWidget);
    expect(find.byKey(const Key('food-checkout-avatar')), findsOneWidget);
    expect(find.text('Đơn của bạn'), findsOneWidget);
    expect(find.text('2 món'), findsOneWidget);
    expect(find.text('Bún bò đặc biệt'), findsOneWidget);
    expect(find.byKey(const Key('food-checkout-total')), findsOneWidget);
    expect(find.text('145.000đ'), findsWidgets);
    expect(find.byKey(const Key('food-checkout-payment')), findsOneWidget);
    expect(find.byKey(const Key('payment-method-tile')), findsOneWidget);
    expect(find.byKey(const Key('checkout-voucher-picker')), findsOneWidget);
  });

  testWidgets('a restored fare without bounds is re-quoted for the stepper', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpSignedIn(
      tester,
      profile: customerProfile,
      foodClient: FakeFoodClient(),
      pricing: FakePricingRemoteDataSource(deliveryFareVnd: 25000),
    );
    final context = tester.element(find.byType(Scaffold).first);
    final cart = context.read<FoodCartCubit>();
    cart
      ..addItem(
        storeId: _storeId,
        storeName: 'Bún Bò Huế',
        item: const FoodMenuItem(
          id: _bunId,
          name: 'Bún bò đặc biệt',
          priceVnd: 60000,
          available: true,
        ),
      )
      ..setDropoff(label: 'Nhà, 45 Lê Duẩn', lat: 16.0717, lng: 108.2207)
      // Draft restore keeps the amount but drops the quote bounds.
      ..setDeliveryFare(25000);

    GoRouter.of(context).push(FoodRoutes.checkout);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('food-fare-offer-panel')), findsOneWidget);
    expect(find.byKey(const Key('food-fare-increase')), findsOneWidget);
    expect(find.byKey(const Key('food-fare-offer-amount')), findsOneWidget);
  });
}
