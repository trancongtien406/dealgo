import 'package:dealgo/core/network/api_exception.dart';
import 'package:dealgo/features/food/domain/entities/food_models.dart';
import 'package:dealgo/features/food/presentation/cubit/food_cart_cubit.dart';
import 'package:dealgo/features/food/presentation/pages/food_checkout_page.dart';
import 'package:dealgo/features/pricing/domain/pricing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/auth_test_harness.dart';
import '../../support/fake_food_client.dart';
import '../../support/fake_identity_client.dart';

const _storeId = 'store-far';

class _RefusingPricing implements PricingRepository {
  @override
  Future<FoodDeliveryQuote> quoteFoodDelivery({
    required String accessToken,
    required String storeId,
    required PricePoint dropoff,
  }) async {
    throw const ApiException(
      statusCode: 422,
      message: 'Drop-off is more than 15 km from the store',
      errorCode: 'FOOD_TOO_FAR',
    );
  }

  @override
  Future<RideQuote> quoteRide({
    required String accessToken,
    required PricePoint pickup,
    required PricePoint dropoff,
    List<PricePoint> stops = const [],
  }) =>
      throw UnimplementedError();

  @override
  Future<List<RideVehicleClassOption>> listVehicleClasses({
    required String accessToken,
  }) =>
      throw UnimplementedError();
}

void main() {
  testWidgets('checkout names the distance refusal instead of a generic error', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await pumpSignedIn(
      tester,
      profile: customerProfile,
      foodClient: FakeFoodClient(
        stores: const [
          FoodStoreSummary(id: _storeId, name: 'Quán', category: 'rice'),
        ],
      ),
      pricing: _RefusingPricing(),
    );

    final context = tester.element(find.byType(Scaffold).first);
    context.read<FoodCartCubit>()
      ..addItem(
        storeId: _storeId,
        storeName: 'Quán',
        item: const FoodMenuItem(
          id: 'item-1',
          name: 'Bánh mì',
          priceVnd: 20000,
          available: true,
        ),
        minOrderVnd: 0,
      )
      ..setDropoff(label: 'Đà Nẵng', lat: 16.0544, lng: 108.2022);
    GoRouter.of(context).push('/customer/food/checkout');
    await tester.pumpAndSettle();

    expect(find.byType(FoodCheckoutPage), findsOneWidget);
    final message = find.byKey(const Key('food-fare-error'));
    expect(message, findsOneWidget);
    expect(tester.widget<Text>(message).data, contains('quá xa'));

    expect(
      find.byKey(const Key('food-fare-change-address')),
      findsOneWidget,
      reason: 'a nearer address is the only way past FOOD_TOO_FAR',
    );
  });
}
