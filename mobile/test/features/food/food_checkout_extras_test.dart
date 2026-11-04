import 'package:dealgo/core/design_system/theme/dealgo_theme.dart';
import 'package:dealgo/features/food/domain/entities/food_models.dart';
import 'package:dealgo/features/food/presentation/cubit/food_cart_cubit.dart';
import 'package:dealgo/features/food/presentation/widgets/food_checkout_extras.dart';
import 'package:dealgo/features/food/presentation/widgets/food_fare_widgets.dart';
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

const _storeId = 'store-notes';
const _dish = FoodMenuItem(
  id: 'dish',
  name: 'Bún bò',
  priceVnd: 45000,
  available: true,
);

FoodStoreDetail _store() =>
    FoodStoreDetail(id: _storeId, name: 'Quán Bún', items: const [_dish]);

Future<FakeFoodClient> _openCheckout(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1206, 3200);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final client = FakeFoodClient(
    stores: const [FoodStoreSummary(id: _storeId, name: 'Quán Bún')],
    details: {_storeId: _store()},
    placedOrder: const PlacedFoodOrder(
      id: 'order-1',
      status: 'PLACED',
      subtotalVnd: 45000,
      deliveryFareVnd: 15000,
      totalVnd: 60000,
      lines: [],
    ),
  );
  await pumpSignedIn(
    tester,
    profile: customerProfile,
    foodClient: client,
    pricing: FakePricingRemoteDataSource(deliveryFareVnd: 15000),
  );
  final ctx = tester.element(find.byType(Scaffold).first);
  final cart = ctx.read<FoodCartCubit>();
  cart.addItem(storeId: _storeId, storeName: 'Quán Bún', item: _dish);
  cart.setLineNote(_dish.id, 'ít cay');
  cart.setDropoff(lat: 10.77, lng: 106.7, label: '123 Nguyễn Văn Linh');
  cart.setDeliveryQuote(
    const FoodDeliveryQuote(
      suggestedVnd: 15000,
      minOfferVnd: 12000,
      maxOfferVnd: 45000,
      fareStepVnd: 1000,
    ),
  );
  GoRouter.of(ctx).push('/customer/food/checkout');
  await tester.pumpAndSettle();
  return client;
}

Widget _host(FoodCartCubit cart, Widget child) => MaterialApp(
  locale: const Locale('vi'),
  theme: DealGoTheme.light,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: BlocProvider.value(
    value: cart,
    child: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

FoodCartCubit _cartWith(FoodDeliveryQuote quote) {
  return FoodCartCubit()
    ..addItem(storeId: _storeId, storeName: 'Quán Bún', item: _dish)
    ..setDeliveryQuote(quote);
}

void main() {
  testWidgets('the checkout reflects and edits the cart note', (tester) async {
    final client = await _openCheckout(tester);

    final noteRow = find.byKey(const Key('food-checkout-note-row'));
    await tester.scrollUntilVisible(
      noteRow,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.byType(FoodCheckoutExtrasPanel), findsOneWidget);
    expect(find.byKey(const Key('food-checkout-note-value')), findsOneWidget);
    expect(find.text('Chưa có ghi chú cho quán hoặc tài xế'), findsOneWidget);

    await tester.tap(noteRow);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('food-checkout-note-field')),
      'Gọi trước khi giao',
    );
    await tester.tap(find.byKey(const Key('food-checkout-note-save')));
    await tester.pumpAndSettle();

    final cart = tester
        .element(find.byType(FoodCheckoutExtrasPanel))
        .read<FoodCartCubit>();
    expect(cart.state.note, 'Gọi trước khi giao');

    await tester.tap(find.byKey(const Key('food-checkout-utensils')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Không').last);
    await tester.pumpAndSettle();
    expect(cart.state.utensils, isFalse);

    await tester.tap(find.byKey(const Key('food-place-order')));
    await tester.pumpAndSettle();

    final request = client.placeCalls.single;
    expect(request.note, 'Gọi trước khi giao');
    expect(request.utensils, isFalse);
    expect(request.items.single.note, 'ít cay');
  });

  testWidgets('the receipt quotes a line note under the dish', (tester) async {
    await _openCheckout(tester);
    expect(find.text('"ít cay"'), findsOneWidget);
  });

  testWidgets('a negotiated fee shows the stepper and the counter hint', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        _cartWith(
          const FoodDeliveryQuote(
            suggestedVnd: 15000,
            minOfferVnd: 12000,
            maxOfferVnd: 45000,
            fareStepVnd: 1000,
          ),
        ),
        const FoodFareOfferPanel(),
      ),
    );

    expect(find.byKey(const Key('food-fare-offer-panel')), findsOneWidget);
    expect(find.byKey(const Key('food-fare-increase')), findsOneWidget);
    expect(find.byKey(const Key('food-fare-negotiation-hint')), findsOneWidget);
  });

  testWidgets('a fixed fee shows the amount and no stepper', (tester) async {
    await tester.pumpWidget(
      _host(
        _cartWith(
          const FoodDeliveryQuote(
            suggestedVnd: 15000,
            minOfferVnd: 15000,
            maxOfferVnd: 15000,
            fareStepVnd: 1000,
            feeMode: FoodDeliveryFeeMode.fixed,
          ),
        ),
        const FoodFareOfferPanel(),
      ),
    );

    expect(find.byKey(const Key('food-fare-fixed-panel')), findsOneWidget);
    expect(find.text('Phí giao cố định'), findsOneWidget);
    expect(find.text('15.000đ'), findsOneWidget);
    expect(find.byKey(const Key('food-fare-increase')), findsNothing);
    expect(find.byKey(const Key('food-fare-negotiation-hint')), findsNothing);
  });
}
