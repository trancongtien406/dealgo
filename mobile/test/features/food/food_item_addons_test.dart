import 'package:dealgo/features/food/domain/entities/food_models.dart';
import 'package:dealgo/features/food/presentation/cubit/food_cart_cubit.dart';
import 'package:dealgo/features/food/presentation/pages/food_item_options_page.dart';
import 'package:dealgo/features/food/presentation/utils/food_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/auth_test_harness.dart';
import '../../support/fake_food_client.dart';
import '../../support/fake_identity_client.dart';

const _storeId = 'store-1';
const _itemId = 'item-bun';

const _store = FoodStoreDetail(
  id: _storeId,
  name: 'Bún Bò Huế',
  category: 'noodles',
  menuSections: [
    FoodMenuSection(id: 'sec-main', name: 'Món chính'),
    FoodMenuSection(id: 'sec-drink', name: 'Đồ uống'),
  ],
  items: [
    FoodMenuItem(
      id: _itemId,
      name: 'Bún bò',
      priceVnd: 45000,
      available: true,
      menuCategoryId: 'sec-main',
    ),
  ],
);

FoodFeaturedItem _featured(String id, String name, int priceVnd) =>
    FoodFeaturedItem(id: id, name: name, priceVnd: priceVnd);

FakeFoodClient _client({
  List<FoodFeaturedItem> suggestions = const [],
  Object? suggestionsError,
}) => FakeFoodClient(
  stores: const [
    FoodStoreSummary(id: _storeId, name: 'Bún Bò Huế', category: 'noodles'),
  ],
  details: const {_storeId: _store},
  suggestions: suggestions,
  suggestionsError: suggestionsError,
);

Future<void> _openItem(WidgetTester tester, FakeFoodClient food) async {
  tester.view.physicalSize = const Size(1170, 5400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await pumpSignedIn(tester, profile: customerProfile, foodClient: food);
  GoRouter.of(tester.element(find.byType(Scaffold).first))
      .push(FoodRoutes.store(_storeId));
  await tester.pumpAndSettle();
  final dish = find.byKey(const Key('food-menu-sec-main-$_itemId'));
  await tester.ensureVisible(dish);
  await tester.pumpAndSettle();
  await tester.tap(dish);
  await tester.pumpAndSettle();
}

FoodCartCubit _cart(WidgetTester tester) =>
    tester.element(find.byType(FoodItemOptionsPage)).read<FoodCartCubit>();

Finder _addonTiles() => find.byWidgetPredicate((widget) {
  final key = widget.key;
  if (key is! ValueKey<String>) return false;
  return key.value.startsWith('food-addon-') &&
      !key.value.startsWith('food-addon-add-');
});

void main() {
  testWidgets('suggests at most 6 add-ons and a tap adds one plain unit', (
    tester,
  ) async {
    final food = _client(
      suggestions: [
        _featured('tra-dao', 'Trà đào', 20000),
        _featured('che', 'Chè ba màu', 15000),
        _featured('sua-dau', 'Sữa đậu nành', 12000),
        _featured('nuoc-cam', 'Nước cam', 18000),
        _featured('tra-chanh', 'Trà chanh', 15000),
        _featured('banh-flan', 'Bánh flan', 12000),
        _featured('kem', 'Kem dừa', 22000),
        _featured('goi-cuon', 'Gỏi cuốn', 25000),
      ],
    );
    await _openItem(tester, food);

    expect(find.byKey(const Key('food-item-addons')), findsOneWidget);
    final strip = tester.widget<ListView>(
      find.byKey(const Key('food-item-addons-list')),
    );
    // Six tiles and the five separators between them, not the eight the
    // server may return.
    expect(strip.childrenDelegate.estimatedChildCount, 11);
    expect(_addonTiles(), findsWidgets);

    expect(food.suggestionCalls.single.storeId, _storeId);
    expect(food.suggestionCalls.single.exclude, [_itemId]);

    final tile = find.byKey(const Key('food-addon-tra-dao'));
    expect(tile, findsOneWidget);
    expect(find.byKey(const Key('food-addon-che')), findsOneWidget);
    expect(tester.getSize(tile).height, greaterThanOrEqualTo(48));

    final cart = _cart(tester);
    await tester.tap(tile);
    await tester.pumpAndSettle();

    final line = cart.state.lines.single;
    expect(line.placeItemId, 'tra-dao');
    expect(line.quantity, 1);
    expect(line.optionIds, isEmpty);
    expect(find.byKey(const Key('food-cart-bar')), findsOneWidget);
    expect(find.byKey(const Key('food-item-addons')), findsOneWidget);
  });

  testWidgets('fewer than two suggestions hides the block', (tester) async {
    final food = _client(suggestions: [_featured('tra-dao', 'Trà đào', 20000)]);
    await _openItem(tester, food);

    expect(find.byKey(const Key('food-item-addons')), findsNothing);
    expect(_addonTiles(), findsNothing);
    expect(find.byKey(const Key('food-options-add')), findsOneWidget);
  });

  testWidgets('a failed suggestion read hides the block, not the main add', (
    tester,
  ) async {
    final food = _client(
      suggestions: [
        _featured('tra-dao', 'Trà đào', 20000),
        _featured('che', 'Chè ba màu', 15000),
      ],
      suggestionsError: StateError('suggestions down'),
    );
    await _openItem(tester, food);

    expect(food.suggestionCalls, isNotEmpty);
    expect(find.byKey(const Key('food-item-addons')), findsNothing);

    final cart = _cart(tester);
    await tester.tap(find.byKey(const Key('food-options-add')));
    await tester.pumpAndSettle();

    final line = cart.state.lines.single;
    expect(line.placeItemId, _itemId);
    expect(line.quantity, 1);
  });
}
