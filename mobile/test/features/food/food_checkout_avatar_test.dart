import 'package:dealgo/core/design_system/components/dealgo_network_image.dart';
import 'package:dealgo/core/design_system/icons/dealgo_icons.dart';
import 'package:dealgo/core/design_system/theme/dealgo_theme.dart';
import 'package:dealgo/features/food/domain/entities/food_models.dart';
import 'package:dealgo/features/food/presentation/cubit/food_cart_cubit.dart';
import 'package:dealgo/features/pricing/data/pricing_remote_datasource.dart';
import 'package:dealgo/features/pricing/domain/pricing.dart';
import 'package:dealgo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/auth_test_harness.dart';
import '../../support/fake_food_client.dart';
import '../../support/fake_identity_client.dart';

const _storeId = 'store-avatar';
const _dish = FoodMenuItem(
  id: 'dish',
  name: 'Bún bò',
  priceVnd: 45000,
  available: true,
);

final _withAvatar = customerProfile.copyWith(
  avatarUrl: '/v1/public/avatars/user-1/portrait.png',
);

Future<void> _openCheckout(WidgetTester tester, {required bool signedInAvatar}) async {
  tester.view.physicalSize = const Size(1206, 3200);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await pumpSignedIn(
    tester,
    profile: signedInAvatar ? _withAvatar : customerProfile,
    foodClient: FakeFoodClient(
      stores: const [FoodStoreSummary(id: _storeId, name: 'Quán Bún')],
      details: const {
        _storeId: FoodStoreDetail(
          id: _storeId,
          name: 'Quán Bún',
          items: [_dish],
        ),
      },
    ),
    pricing: FakePricingRemoteDataSource(deliveryFareVnd: 15000),
  );
  final ctx = tester.element(find.byType(Scaffold).first);
  final cart = ctx.read<FoodCartCubit>()
    ..addItem(storeId: _storeId, storeName: 'Quán Bún', item: _dish)
    ..setDropoff(lat: 10.77, lng: 106.7, label: '123 Nguyễn Văn Linh')
    ..setDeliveryQuote(
      const FoodDeliveryQuote(
        suggestedVnd: 15000,
        minOfferVnd: 12000,
        maxOfferVnd: 45000,
        fareStepVnd: 1000,
      ),
    );
  GoRouter.of(ctx).push('/customer/food/checkout');
  await tester.pumpAndSettle();
  expect(cart.state.lines, isNotEmpty);
}

void main() {
  testWidgets('checkout shows the signed-in avatar on the recipient card', (
    tester,
  ) async {
    await _openCheckout(tester, signedInAvatar: true);

    final avatar = find.byKey(const Key('food-checkout-avatar'));
    expect(avatar, findsOneWidget);
    expect(
      find.descendant(of: avatar, matching: find.byType(DealGoNetworkImage)),
      findsOneWidget,
    );
  });

  testWidgets('checkout falls back to the person icon without an avatar', (
    tester,
  ) async {
    await _openCheckout(tester, signedInAvatar: false);

    final avatar = find.byKey(const Key('food-checkout-avatar'));
    expect(avatar, findsOneWidget);
    expect(
      find.descendant(of: avatar, matching: find.byType(DealGoNetworkImage)),
      findsNothing,
    );
    expect(
      find.descendant(
        of: avatar,
        matching: find.byIcon(DealGoIcons.user),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the food feed header shows the signed-in avatar', (tester) async {
    await pumpSignedIn(
      tester,
      profile: _withAvatar,
      foodClient: FakeFoodClient(),
    );
    await tester.tap(find.text('Đồ ăn').first);
    await tester.pumpAndSettle();

    final avatar = find.byKey(const Key('food-discovery-avatar'));
    expect(avatar, findsOneWidget);
    expect(
      find.descendant(of: avatar, matching: find.byType(DealGoNetworkImage)),
      findsOneWidget,
    );
  });
}
