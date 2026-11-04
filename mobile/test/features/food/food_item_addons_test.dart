import 'dart:async';

import 'package:dealgo/core/auth/token_store.dart';
import 'package:dealgo/features/food/data/repositories/food_repository_impl.dart';
import 'package:dealgo/features/food/domain/entities/food_models.dart';
import 'package:dealgo/features/food/domain/repositories/food_repository.dart';
import 'package:dealgo/features/food/presentation/cubit/food_cart_cubit.dart';
import 'package:dealgo/features/food/presentation/pages/food_item_options_page.dart';
import 'package:dealgo/features/food/presentation/utils/food_routes.dart';
import 'package:dealgo/features/food/presentation/widgets/food_item_addons.dart';
import 'package:dealgo/features/identity/domain/entities/auth_state.dart';
import 'package:dealgo/features/identity/presentation/cubit/auth_cubit.dart';
import 'package:dealgo/l10n/app_localizations.dart';
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

  testWidgets('exactly two suggestions render two tiles', (tester) async {
    final food = _client(
      suggestions: [
        _featured('tra-dao', 'Trà đào', 20000),
        _featured('che', 'Chè ba màu', 15000),
      ],
    );
    await _openItem(tester, food);

    expect(find.byKey(const Key('food-item-addons')), findsOneWidget);
    expect(_addonTiles(), findsNWidgets(2));
    expect(food.suggestionCalls, hasLength(1));
  });

  testWidgets('the + affordance adds exactly one plain unit', (tester) async {
    final food = _client(
      suggestions: [
        _featured('tra-dao', 'Trà đào', 20000),
        _featured('che', 'Chè ba màu', 15000),
      ],
    );
    await _openItem(tester, food);

    final cart = _cart(tester);
    expect(cart.state.lines, isEmpty);

    await tester.tap(find.byKey(const Key('food-addon-add-tra-dao')));
    await tester.pumpAndSettle();

    expect(cart.state.lines, hasLength(1));
    final line = cart.state.lines.single;
    expect(line.placeItemId, 'tra-dao');
    expect(line.quantity, 1);
    expect(line.optionIds, isEmpty);
  });

  testWidgets('each + names its own dish for screen readers', (tester) async {
    final handle = tester.ensureSemantics();
    final food = _client(
      suggestions: [
        _featured('tra-dao', 'Trà đào', 20000),
        _featured('che', 'Chè ba màu', 15000),
      ],
    );
    await _openItem(tester, food);

    expect(find.bySemanticsLabel('Thêm vào giỏ: Trà đào'), findsOneWidget);
    expect(find.bySemanticsLabel('Thêm vào giỏ: Chè ba màu'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('fewer than two suggestions hides the block', (tester) async {
    final food = _client(suggestions: [_featured('tra-dao', 'Trà đào', 20000)]);
    await _openItem(tester, food);

    expect(food.suggestionCalls, hasLength(1));
    expect(find.byKey(const Key('food-item-addons')), findsNothing);
    expect(_addonTiles(), findsNothing);
    expect(find.byKey(const Key('food-options-add')), findsOneWidget);
  });

  testWidgets('a reply for the previous dish never repaints the new one', (
    tester,
  ) async {
    final client =
        _GatedSuggestionsClient(
            stores: const [
              FoodStoreSummary(
                id: _storeId,
                name: 'Bún Bò Huế',
                category: 'noodles',
              ),
            ],
            details: const {_storeId: _store},
          )
          ..replies.addAll([
            [
              _featured('tra-dao', 'Trà đào', 20000),
              _featured('sua-dau', 'Sữa đậu nành', 12000),
            ],
            [
              _featured('che', 'Chè ba màu', 15000),
              _featured('banh-flan', 'Bánh flan', 12000),
            ],
          ]);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<FoodCartCubit>(create: (_) => FoodCartCubit()),
          BlocProvider<AuthCubit>(create: (_) => _Auth(_signedIn)),
        ],
        child: RepositoryProvider<FoodRepository>.value(
          value: FoodRepositoryImpl(client),
          child: MaterialApp(
            locale: const Locale('vi'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: _AddonsHost(store: _store, excludeItemId: 'item-bun'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(client.suggestionCalls, hasLength(1));
    expect(client.suggestionCalls.single.exclude, ['item-bun']);

    tester
        .state<_AddonsHostState>(find.byType(_AddonsHost))
        .showDish('item-pho');
    await tester.pump();

    expect(client.suggestionCalls, hasLength(2));
    expect(client.suggestionCalls.last.exclude, ['item-pho']);

    client.gates[1].complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('food-addon-che')), findsOneWidget);

    client.gates[0].complete();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('food-addon-che')), findsOneWidget);
    expect(find.byKey(const Key('food-addon-tra-dao')), findsNothing);
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

final _signedIn = AuthSignedIn(
  tokens: const StoredTokens(
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
  ),
  profile: customerProfile,
);

/// Reads only [AuthCubit.state], which is all the suggestion load needs.
class _Auth extends Cubit<AuthState> implements AuthCubit {
  _Auth(super.initial);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AddonsHost extends StatefulWidget {
  const _AddonsHost({required this.store, required this.excludeItemId});

  final FoodStoreDetail store;
  final String excludeItemId;

  @override
  State<_AddonsHost> createState() => _AddonsHostState();
}

class _AddonsHostState extends State<_AddonsHost> {
  late String _excludeItemId = widget.excludeItemId;

  void showDish(String itemId) => setState(() => _excludeItemId = itemId);

  @override
  Widget build(BuildContext context) =>
      FoodItemAddons(store: widget.store, excludeItemId: _excludeItemId);
}

/// Holds every suggestion reply until the test releases it, so replies can
/// land in a different order than the requests.
class _GatedSuggestionsClient extends FakeFoodClient {
  _GatedSuggestionsClient({required super.stores, required super.details});

  final List<Completer<void>> gates = [];
  final List<List<FoodFeaturedItem>> replies = [];

  @override
  Future<List<FoodFeaturedItem>> listStoreSuggestions(
    String accessToken,
    String storeId, {
    List<String> exclude = const [],
  }) async {
    final index = gates.length;
    final gate = Completer<void>();
    gates.add(gate);
    suggestionCalls.add((storeId: storeId, exclude: List.of(exclude)));
    await gate.future;
    return replies[index];
  }
}
