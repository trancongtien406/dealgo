import 'package:dealgo/features/food/domain/entities/food_models.dart';
import 'package:dealgo/features/food/presentation/cubit/food_cart_cubit.dart';
import 'package:dealgo/features/food/presentation/pages/food_cart_page.dart';
import 'package:dealgo/features/food/presentation/utils/food_routes.dart';
import 'package:dealgo/features/food/presentation/widgets/food_cart_upsell.dart';
import 'package:dealgo/features/pricing/data/pricing_remote_datasource.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/auth_test_harness.dart';
import '../../support/fake_food_client.dart';
import '../../support/fake_identity_client.dart';

const _storeId = 'store-com';
const _mainDish = FoodMenuItem(
  id: 'main',
  name: 'Cơm gà',
  priceVnd: 45000,
  available: true,
  menuCategoryId: 'mains',
);
const _sameGroupDish = FoodMenuItem(
  id: 'side',
  name: 'Cơm sườn',
  priceVnd: 49000,
  available: true,
  menuCategoryId: 'mains',
);
const _drink = FoodMenuItem(
  id: 'drink',
  name: 'Trà đào',
  priceVnd: 20000,
  available: true,
  menuCategoryId: 'drinks',
  soldCount: 10,
);
const _soldOut = FoodMenuItem(
  id: 'sold-out',
  name: 'Chè hết hàng',
  priceVnd: 15000,
  available: false,
  menuCategoryId: 'drinks',
);

FoodStoreDetail _store(List<FoodMenuItem> items) =>
    FoodStoreDetail(id: _storeId, name: 'Quán Cơm', items: items);

FakeFoodClient _client(List<FoodMenuItem> items) => FakeFoodClient(
  stores: const [FoodStoreSummary(id: _storeId, name: 'Quán Cơm')],
  details: {_storeId: _store(items)},
);

/// The cart draft save is debounced; advancing past it keeps the test's
/// timer check from tripping on a pending save.
Future<void> _flushDraft(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

Future<FoodCartCubit> _openCart(
  WidgetTester tester,
  FakeFoodClient food, {
  FoodMenuItem item = _mainDish,
}) async {
  await tester.binding.setSurfaceSize(const Size(400, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await pumpSignedIn(
    tester,
    profile: customerProfile,
    foodClient: food,
    pricing: FakePricingRemoteDataSource(deliveryFareVnd: 25000),
  );
  final context = tester.element(find.byType(Scaffold).first);
  final cart = context.read<FoodCartCubit>();
  cart.addItem(storeId: _storeId, storeName: 'Quán Cơm', item: item);
  GoRouter.of(context).push(FoodRoutes.cart);
  await tester.pumpAndSettle();
  expect(find.byType(FoodCartPage), findsOneWidget);
  return cart;
}

void main() {
  testWidgets('typing an order note updates the cubit and survives quantity', (
    tester,
  ) async {
    final cart = await _openCart(tester, _client(const [_mainDish]));

    await tester.enterText(
      find.byKey(const Key('food-order-note-field')),
      'Ít cay, không hành',
    );
    await tester.pump();

    expect(cart.state.note, 'Ít cay, không hành');

    await tester.tap(find.byKey(const Key('food-cart-line-plus-main')));
    await tester.pumpAndSettle();

    expect(cart.state.lines.single.quantity, 2);
    expect(cart.state.note, 'Ít cay, không hành');
    final field = tester.widget<TextFormField>(
      find.byKey(const Key('food-order-note-field')),
    );
    expect(field.controller?.text, 'Ít cay, không hành');
    await _flushDraft(tester);
  });

  testWidgets('choosing Không turns the cutlery preference off', (
    tester,
  ) async {
    final cart = await _openCart(tester, _client(const [_mainDish]));
    expect(cart.state.utensils, isTrue);

    await tester.tap(find.text('Không'));
    await tester.pumpAndSettle();

    expect(cart.state.utensils, isFalse);

    await tester.tap(find.text('Có'));
    await tester.pumpAndSettle();

    expect(cart.state.utensils, isTrue);
    await _flushDraft(tester);
  });

  testWidgets('a line note saves, shows quoted, and clearing removes it', (
    tester,
  ) async {
    final cart = await _openCart(tester, _client(const [_mainDish]));

    await tester.tap(find.byKey(const Key('food-cart-line-main')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('food-line-note-sheet')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('food-line-note-field')),
      ' ít cay ',
    );
    await tester.tap(find.byKey(const Key('food-line-note-save')));
    await tester.pumpAndSettle();

    expect(cart.state.lines.single.note, 'ít cay');
    expect(find.text('"ít cay"'), findsOneWidget);

    await tester.tap(find.byKey(const Key('food-cart-line-main')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('food-line-note-clear')));
    await tester.pumpAndSettle();

    expect(cart.state.lines.single.note, isNull);
    expect(find.text('"ít cay"'), findsNothing);
    await _flushDraft(tester);
  });

  testWidgets('the line still changes quantity and can be removed', (
    tester,
  ) async {
    final cart = await _openCart(tester, _client(const [_mainDish]));

    await tester.tap(find.byKey(const Key('food-cart-line-plus-main')));
    await tester.pumpAndSettle();
    expect(cart.state.lines.single.quantity, 2);

    await tester.tap(find.byKey(const Key('food-cart-line-minus-main')));
    await tester.pumpAndSettle();
    expect(cart.state.lines.single.quantity, 1);

    await tester.tap(find.byKey(const Key('food-cart-line-remove-main')));
    await tester.pumpAndSettle();
    expect(cart.state.lines, isEmpty);
    await _flushDraft(tester);
  });

  testWidgets('upsell hides dishes already in the cart and sold out', (
    tester,
  ) async {
    final cart = await _openCart(
      tester,
      _client(const [_mainDish, _sameGroupDish, _drink, _soldOut]),
    );

    expect(find.byKey(const Key('food-cart-upsell')), findsOneWidget);
    expect(find.byKey(const Key('food-cart-upsell-add-drink')), findsOneWidget);
    expect(find.byKey(const Key('food-cart-upsell-add-side')), findsNothing);
    expect(
      find.byKey(const Key('food-cart-upsell-add-sold-out')),
      findsNothing,
    );
    expect(find.byKey(const Key('food-cart-upsell-add-main')), findsNothing);

    await tester.tap(find.byKey(const Key('food-cart-upsell-add-drink')));
    await tester.pumpAndSettle();

    expect(cart.state.lines, hasLength(2));
    expect(cart.state.lines.last.itemId, 'drink');
    expect(find.byKey(const Key('food-cart-upsell-add-drink')), findsNothing);
    await _flushDraft(tester);
  });

  test('upsell picks best sellers and caps the strip at six', () {
    final items = [
      for (var i = 0; i < 8; i++)
        FoodMenuItem(
          id: 'extra-$i',
          name: 'Món $i',
          priceVnd: 10000 + i,
          available: true,
          menuCategoryId: 'group-$i',
          soldCount: i,
        ),
    ];
    const cart = FoodCartState(
      storeId: _storeId,
      storeName: 'Quán Cơm',
      lines: [
        FoodCartLine(
          itemId: 'main',
          name: 'Cơm gà',
          unitPriceVnd: 45000,
          quantity: 1,
        ),
      ],
      deliveryFareVnd: null,
      dropoffLabel: '',
      dropoffLat: null,
      dropoffLng: null,
      idempotencyKey: 'key',
    );

    final picked = foodUpsellItems(
      store: _store([_mainDish, ...items]),
      cart: cart,
    );

    expect(picked, hasLength(foodUpsellMaxItems));
    expect(picked.first.id, 'extra-7');
    expect(picked.map((item) => item.id), isNot(contains('main')));
  });

  testWidgets('upsell disappears when nothing qualifies', (tester) async {
    await _openCart(
      tester,
      _client(const [_mainDish, _sameGroupDish, _soldOut]),
    );
    expect(find.byKey(const Key('food-cart-upsell')), findsNothing);
  });

  testWidgets('upsell stays hidden when the catalog cannot load', (
    tester,
  ) async {
    await _openCart(tester, FakeFoodClient());
    expect(find.byKey(const Key('food-cart-upsell')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
