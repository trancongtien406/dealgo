// DEC-PROD-033 — dish options: selection rules, cart pricing, wire format,
// kitchen ticket text and the merchant M028 editor.
import 'package:dealgo/core/design_system/components/dealgo_primary_button.dart';
import 'package:dealgo/core/network/api_exception.dart';
import 'package:dealgo/features/food/data/datasources/dio_food_remote_datasource.dart';
import 'package:dealgo/features/food/data/models/place_food_order_body.dart';
import 'package:dealgo/features/food/domain/entities/food_models.dart';
import 'package:dealgo/features/food/domain/params/place_food_order_params.dart';
import 'package:dealgo/features/food/presentation/cubit/food_cart_cubit.dart';
import 'package:dealgo/features/food/presentation/pages/food_item_options_page.dart';
import 'package:dealgo/features/identity/domain/entities/user_profile.dart';
import 'package:dealgo/features/merchant/data/datasources/fake_merchant_orders_client.dart';
import 'package:dealgo/features/merchant/data/repositories/merchant_orders_repository_impl.dart';
import 'package:dealgo/features/merchant/domain/usecases/get_merchant_catalog.dart';
import 'package:dealgo/features/merchant/domain/usecases/replace_merchant_item_options.dart';
import 'package:dealgo/features/merchant/presentation/cubit/merchant_item_options_cubit.dart';
import 'package:dealgo/features/merchant/presentation/pages/merchant_item_variants_page.dart';
import 'package:dealgo/features/merchant/presentation/utils/merchant_kitchen_lines.dart';
import 'package:dealgo/features/merchant/presentation/utils/merchant_routes.dart';
import 'package:dealgo/features/pricing/data/pricing_remote_datasource.dart';
import 'package:dealgo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/auth_test_harness.dart';
import 'support/fake_food_client.dart';
import 'support/fake_identity_client.dart';

const _size = FoodOptionGroup(
  id: 'g-size',
  title: 'Size',
  minSelect: 1,
  maxSelect: 1,
  choices: [
    FoodOptionChoice(id: 'o-m', label: 'M'),
    FoodOptionChoice(id: 'o-l', label: 'L', extraVnd: 10000),
  ],
);
const _topping = FoodOptionGroup(
  id: 'g-top',
  title: 'Topping',
  minSelect: 0,
  maxSelect: 2,
  choices: [
    FoodOptionChoice(id: 'o-tc', label: 'Trân châu', extraVnd: 8000),
    FoodOptionChoice(id: 'o-td', label: 'Thạch đào', extraVnd: 8000),
    FoodOptionChoice(id: 'o-kc', label: 'Kem cheese', extraVnd: 12000),
    FoodOptionChoice(
      id: 'o-x',
      label: 'Hết hàng',
      extraVnd: 5000,
      available: false,
    ),
  ],
);
const _tea = FoodMenuItem(
  id: 'item-tea',
  name: 'Trà sữa',
  priceVnd: 45000,
  available: true,
  optionGroups: [_size, _topping],
);
const _store = FoodStoreDetail(id: 'store-tea', name: 'Trà Sữa', items: [_tea]);

const _merchantProfile = UserProfile(
  id: 'merchant-1',
  phone: '+84901110001',
  email: null,
  phoneVerifiedAt: '2026-10-13T16:00:00.000Z',
  emailVerifiedAt: null,
  grants: [RoleGrant(role: 'MERCHANT', status: 'ACTIVE')],
);

void main() {
  group('selection rules', () {
    test(
      'initial pre-picks required single choice; required blocks when empty',
      () {
        var selection = FoodOptionSelection.initial(_tea.optionGroups);
        expect(selection.picked('g-size'), {'o-m'});
        expect(selection.isComplete, isTrue);
        expect(
          FoodOptionSelection.initial(const [
            FoodOptionGroup(
              id: 'g',
              title: 'G',
              minSelect: 1,
              maxSelect: 2,
              choices: [FoodOptionChoice(id: 'a', label: 'A')],
            ),
          ]).isComplete,
          isFalse,
        );
        selection = selection.toggle(_size, _size.choices[1]);
        expect(selection.isComplete, isTrue);
        expect(selection.extrasVnd, 10000);
      },
    );

    test('single group swaps, multi group stops at max, sold out ignored', () {
      var selection = FoodOptionSelection.initial(_tea.optionGroups)
          .toggle(_size, _size.choices[0])
          .toggle(_size, _size.choices[1]);
      expect(selection.picked('g-size'), {'o-l'});
      selection = selection
          .toggle(_topping, _topping.choices[0])
          .toggle(_topping, _topping.choices[1])
          .toggle(_topping, _topping.choices[2]);
      expect(selection.picked('g-top'), {'o-tc', 'o-td'});
      selection = selection.toggle(_topping, _topping.choices[3]);
      expect(selection.picked('g-top'), {'o-tc', 'o-td'});
      expect(selection.extrasVnd, 26000);
      expect(selection.optionIds.toSet(), {'o-l', 'o-tc', 'o-td'});
    });

    test('line id is order-independent and separates configurations', () {
      expect(foodCartLineId('item-tea', const []), 'item-tea');
      expect(
        foodCartLineId('item-tea', const ['o-tc', 'o-l']),
        foodCartLineId('item-tea', const ['o-l', 'o-tc']),
      );
      expect(
        foodCartLineId('item-tea', const ['o-l']) ==
            foodCartLineId('item-tea', const ['o-m']),
        isFalse,
      );
    });

    test('delta mirrors server rules', () {
      expect(foodOptionDelta(_tea.optionGroups, const ['o-l', 'o-kc']), 22000);
      expect(foodOptionDelta(_tea.optionGroups, const ['o-kc']), isNull);
      expect(foodOptionDelta(_tea.optionGroups, const ['o-m', 'o-l']), isNull);
      expect(foodOptionDelta(_tea.optionGroups, const ['o-m', 'o-x']), isNull);
      expect(foodOptionDelta(_tea.optionGroups, const ['o-m', 'gone']), isNull);
      expect(
        foodOptionDelta(_tea.optionGroups, const [
          'o-m',
          'o-tc',
          'o-td',
          'o-kc',
        ]),
        isNull,
      );
    });
  });

  group('wire format', () {
    test(
      'catalog item decodes option groups, order lines decode snapshots',
      () {
        final item = decodeFoodMenuItem({
          'success': true,
          'data': {
            'id': 'item-tea',
            'name': 'Trà sữa',
            'priceVnd': 45000,
            'available': true,
            'optionGroups': [
              {
                'id': 'g-size',
                'name': 'Size',
                'minSelect': 1,
                'maxSelect': 1,
                'options': [
                  {
                    'id': 'o-l',
                    'name': 'L',
                    'priceDeltaVnd': 10000,
                    'available': true,
                  },
                ],
              },
            ],
          },
        });
        expect(item.optionGroups.single.title, 'Size');
        expect(item.optionGroups.single.required, isTrue);
        expect(item.optionGroups.single.choices.single.extraVnd, 10000);

        final options = decodeFoodLineOptions([
          {
            'optionId': 'o-l',
            'groupName': 'Size',
            'name': 'L',
            'priceDeltaVnd': 10000,
          },
          {'groupName': 'Topping', 'name': 'Trân châu', 'priceDeltaVnd': 8000},
          'junk',
        ]);
        expect(options.map((o) => o.name), ['L', 'Trân châu']);
      },
    );

    test('place body sends optionIds only for configured lines', () {
      final json = PlaceFoodOrderBody.fromParams(
        const PlaceFoodOrderParams(
          accessToken: 't',
          idempotencyKey: 'k',
          storeId: 'store-tea',
          items: [
            FoodOrderItem(itemId: 'item-tea', quantity: 2, optionIds: ['o-l']),
            FoodOrderItem(itemId: 'item-plain', quantity: 1),
          ],
          dropoff: FoodDropoff(lat: 16, lng: 108, label: 'Nhà'),
          deliveryFareVnd: 15000,
        ),
      ).toJson();
      final items = json['items']! as List;
      expect(items[0], {
        'itemId': 'item-tea',
        'quantity': 2,
        'optionIds': ['o-l'],
      });
      expect(items[1], {'itemId': 'item-plain', 'quantity': 1});
      expect(json.containsKey('subtotalVnd'), isFalse);
    });

    test('place body sends utensils always and notes only when non-blank', () {
      final plain = PlaceFoodOrderBody.fromParams(
        const PlaceFoodOrderParams(
          accessToken: 't',
          idempotencyKey: 'k',
          storeId: 'store-tea',
          items: [
            FoodOrderItem(itemId: 'item-a', quantity: 1, note: 'Ít cay'),
            FoodOrderItem(itemId: 'item-b', quantity: 1, note: '   '),
          ],
          dropoff: FoodDropoff(lat: 16, lng: 108, label: 'Nhà'),
          deliveryFareVnd: 15000,
        ),
      ).toJson();
      expect(plain['utensils'], isTrue);
      expect(plain.containsKey('note'), isFalse);
      final plainItems = plain['items']! as List;
      expect(plainItems[0], {
        'itemId': 'item-a',
        'quantity': 1,
        'note': 'Ít cay',
      });
      expect(plainItems[1], {'itemId': 'item-b', 'quantity': 1});

      final noted = PlaceFoodOrderBody.fromParams(
        const PlaceFoodOrderParams(
          accessToken: 't',
          idempotencyKey: 'k',
          storeId: 'store-tea',
          items: [FoodOrderItem(itemId: 'item-a', quantity: 1)],
          dropoff: FoodDropoff(lat: 16, lng: 108, label: 'Nhà'),
          deliveryFareVnd: 15000,
          note: 'Gọi trước 10 phút',
          utensils: false,
        ),
      ).toJson();
      expect(noted['note'], 'Gọi trước 10 phút');
      expect(noted['utensils'], isFalse);
    });

    test('read views decode notes and treat a missing utensils as true', () {
      final detail = decodeFoodOrderDetail({
        'success': true,
        'data': {
          'id': 'o1',
          'status': 'PLACED',
          'subtotalVnd': 30000,
          'deliveryFareVnd': 10000,
          'totalVnd': 40000,
          'dropoff': {'lat': 16, 'lng': 108, 'label': 'Nhà'},
          'note': 'Ít cay',
          'utensils': false,
          'lines': [
            {
              'itemId': 'item-a',
              'name': 'Bún',
              'unitPriceVnd': 30000,
              'quantity': 1,
              'note': 'Không hành',
            },
          ],
        },
      });
      expect(detail.note, 'Ít cay');
      expect(detail.utensils, isFalse);
      expect(detail.lines.single.note, 'Không hành');

      final placed = decodePlacedFoodOrder({
        'success': true,
        'data': {
          'id': 'o2',
          'status': 'PLACED',
          'subtotalVnd': 30000,
          'deliveryFareVnd': 10000,
          'totalVnd': 40000,
          'lines': [
            {
              'itemId': 'item-a',
              'name': 'Bún',
              'unitPriceVnd': 30000,
              'quantity': 1,
            },
          ],
        },
      });
      expect(placed.note, isNull);
      expect(placed.utensils, isTrue);
      expect(placed.lines.single.note, isNull);
    });

    test('kitchen ticket lists the chosen options per line', () {
      const line = FoodOrderLine(
        itemId: 'item-tea',
        name: 'Trà sữa',
        unitPriceVnd: 63000,
        quantity: 1,
        options: [
          FoodLineOption(groupName: 'Size', name: 'L', priceDeltaVnd: 10000),
          FoodLineOption(
            groupName: 'Topping',
            name: 'Trân châu',
            priceDeltaVnd: 8000,
          ),
        ],
      );
      expect(line.optionsSummary, 'Size: L · Topping: Trân châu');
      final kitchen = kitchenLinesFromDetail(
        const FoodOrderDetail(
          id: 'o1',
          status: 'PLACED',
          subtotalVnd: 63000,
          deliveryFareVnd: 0,
          totalVnd: 63000,
          dropoff: FoodDropoff(lat: 16, lng: 108, label: 'Nhà'),
          lines: [line],
        ),
      );
      expect(kitchen.single.options, 'Size: L · Topping: Trân châu');
    });
  });

  group('cart', () {
    FoodCartCubit cartWithLarge() {
      return FoodCartCubit()..addConfiguredItem(
        storeId: 'store-tea',
        storeName: 'Trà Sữa',
        lineId: foodCartLineId('item-tea', const ['o-l']),
        name: 'Trà sữa',
        unitPriceVnd: 55000,
        catalogItemId: 'item-tea',
        optionIds: const ['o-l'],
      );
    }

    test('same dish with different options makes separate lines', () {
      final cart = cartWithLarge()
        ..addConfiguredItem(
          storeId: 'store-tea',
          storeName: 'Trà Sữa',
          lineId: foodCartLineId('item-tea', const ['o-m']),
          name: 'Trà sữa',
          unitPriceVnd: 45000,
          catalogItemId: 'item-tea',
          optionIds: const ['o-m'],
        );
      expect(cart.state.lines, hasLength(2));
      expect(cart.state.lines.map((l) => l.placeItemId).toSet(), {'item-tea'});
    });

    test('line note targets one line and a blank note clears it', () {
      final large = foodCartLineId('item-tea', const ['o-l']);
      final medium = foodCartLineId('item-tea', const ['o-m']);
      final cart = cartWithLarge()
        ..addConfiguredItem(
          storeId: 'store-tea',
          storeName: 'Trà Sữa',
          lineId: medium,
          name: 'Trà sữa',
          unitPriceVnd: 45000,
          catalogItemId: 'item-tea',
          optionIds: const ['o-m'],
        )
        ..setLineNote(large, 'Ít đá')
        ..setLineNote(medium, 'Nhiều đá');
      String? noteOf(String lineId) =>
          cart.state.lines.firstWhere((l) => l.itemId == lineId).note;
      expect(noteOf(large), 'Ít đá');
      expect(noteOf(medium), 'Nhiều đá');
      cart.setLineNote(large, '   ');
      expect(noteOf(large), isNull);
      expect(noteOf(medium), 'Nhiều đá');
    });

    test('adding the same configured item keeps its line note', () {
      final large = foodCartLineId('item-tea', const ['o-l']);
      final cart = cartWithLarge()..setLineNote(large, 'Ít đá');
      cart.addConfiguredItem(
        storeId: 'store-tea',
        storeName: 'Trà Sữa',
        lineId: large,
        name: 'Trà sữa',
        unitPriceVnd: 55000,
        catalogItemId: 'item-tea',
        optionIds: const ['o-l'],
      );
      expect(cart.state.lines.single.quantity, 2);
      expect(cart.state.lines.single.note, 'Ít đá');
    });

    test('catalog refresh re-prices options and drops stale choices', () {
      final cart = cartWithLarge();
      const pricier = FoodStoreDetail(
        id: 'store-tea',
        name: 'Trà Sữa',
        items: [
          FoodMenuItem(
            id: 'item-tea',
            name: 'Trà sữa',
            priceVnd: 47000,
            available: true,
            optionGroups: [
              FoodOptionGroup(
                id: 'g-size',
                title: 'Size',
                minSelect: 1,
                maxSelect: 1,
                choices: [
                  FoodOptionChoice(id: 'o-l', label: 'L', extraVnd: 12000),
                ],
              ),
            ],
          ),
        ],
      );
      expect(foodCatalogPriceDrift(pricier, cart.state), isTrue);
      cart.applyCatalog(pricier);
      expect(cart.state.lines.single.unitPriceVnd, 59000);

      const removed = FoodStoreDetail(
        id: 'store-tea',
        name: 'Trà Sữa',
        items: [
          FoodMenuItem(
            id: 'item-tea',
            name: 'Trà sữa',
            priceVnd: 47000,
            available: true,
            optionGroups: [_topping],
          ),
        ],
      );
      cart.applyCatalog(removed);
      expect(cart.state.lines, isEmpty);
    });

    test('plain line is dropped once the dish needs a choice', () {
      final cart = FoodCartCubit()
        ..addItem(
          storeId: 'store-tea',
          storeName: 'Trà Sữa',
          item: const FoodMenuItem(
            id: 'item-tea',
            name: 'Trà sữa',
            priceVnd: 45000,
            available: true,
          ),
        );
      expect(cart.state.lines, hasLength(1));
      cart.applyCatalog(_store);
      expect(cart.state.lines, isEmpty);
    });
  });

  group('merchant options cubit', () {
    MerchantItemOptionsCubit cubitFor(FakeMerchantOrdersClient client) {
      final repo = MerchantOrdersRepositoryImpl(client);
      return MerchantItemOptionsCubit(
        getMerchantCatalog: GetMerchantCatalog(repo),
        replaceOptions: ReplaceMerchantItemOptions(repo),
        itemId: 'item-tea',
      );
    }

    test(
      'loads the dish, edits keep ids, save sends the full layout',
      () async {
        final client = FakeMerchantOrdersClient(
          onGetCatalog: () => _store,
          onReplaceOptions: (itemId, groups) => FoodMenuItem(
            id: itemId,
            name: 'Trà sữa',
            priceVnd: 45000,
            available: true,
            optionGroups: groups,
          ),
        );
        final cubit = cubitFor(client);
        await cubit.load('token');
        var ready = cubit.state as MerchantItemOptionsReady;
        expect(ready.groups, hasLength(2));
        expect(ready.dirty, isFalse);

        cubit.putChoice(
          groupIndex: 0,
          label: 'XL',
          extraVnd: 15000,
          available: true,
        );
        cubit.putGroup(title: 'Đá', minSelect: 0, maxSelect: 1);
        cubit.putChoice(
          groupIndex: 2,
          label: 'Ít đá',
          extraVnd: 0,
          available: true,
        );
        cubit.removeChoice(1, 3);
        ready = cubit.state as MerchantItemOptionsReady;
        expect(ready.dirty, isTrue);

        await cubit.save('token');
        final sent = client.optionCalls.single;
        expect(sent.itemId, 'item-tea');
        expect(sent.groups.map((g) => g.id), ['g-size', 'g-top', '']);
        expect(sent.groups[0].choices.map((c) => c.id), ['o-m', 'o-l', '']);
        expect(sent.groups[1].choices, hasLength(3));
        ready = cubit.state as MerchantItemOptionsReady;
        expect(ready.dirty, isFalse);
        expect(ready.savedTick, 1);
        await cubit.close();
      },
    );

    test(
      'invalid layout is refused locally, server error is surfaced',
      () async {
        final client = FakeMerchantOrdersClient(
          onGetCatalog: () => _store,
          optionsError: const ApiException(
            statusCode: 400,
            message: 'bad',
            errorCode: 'FOOD_OPTIONS_INVALID',
          ),
        );
        final cubit = cubitFor(client);
        await cubit.load('token');
        cubit.putGroup(title: 'Trống', minSelect: 0, maxSelect: 1);
        await cubit.save('token');
        expect(client.optionCalls, isEmpty);
        expect((cubit.state as MerchantItemOptionsReady).error, isNotNull);

        cubit.removeGroup(2);
        await cubit.save('token');
        expect(client.optionCalls, hasLength(1));
        final ready = cubit.state as MerchantItemOptionsReady;
        expect(ready.saving, isFalse);
        expect(ready.error?.error, isA<ApiException>());
        await cubit.close();
      },
    );

    test('unknown dish fails with a message', () async {
      final client = FakeMerchantOrdersClient(
        onGetCatalog: () =>
            const FoodStoreDetail(id: 's', name: 's', items: []),
      );
      final cubit = cubitFor(client);
      await cubit.load('token');
      expect(cubit.state, isA<MerchantItemOptionsFailed>());
      await cubit.close();
    });
  });

  testWidgets('M028 editor adds a group and choice, then saves to the API', (
    tester,
  ) async {
    final food = FakeFoodClient(details: const {'store-tea': _store});
    await pumpSignedIn(
      tester,
      profile: _merchantProfile,
      foodClient: food,
      initialLocation: '/merchant',
    );
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.text('Tổng quan cửa hàng')))
        .push(MerchantRoutes.itemVariants('item-tea', itemName: 'Trà sữa'));
    await tester.pumpAndSettle();
    expect(find.text('Tùy chọn món'), findsOneWidget);
    expect(find.text('Giá bán 45.000đ'), findsOneWidget);
    // Required single-choice group shows absolute prices (M028).
    expect(find.text('55.000đ'), findsOneWidget);
    expect(find.text('+8.000đ'), findsNWidgets(2));
    expect(find.text('Bắt buộc · chọn 1'), findsOneWidget);
    expect(find.text('Không bắt buộc · tối đa 2'), findsOneWidget);

    final editorScroll = find
        .descendant(
          of: find.byType(MerchantItemVariantsPage),
          matching: find.byType(Scrollable),
        )
        .first;
    final add = find.byKey(const Key('merchant-group-add'));
    await tester.scrollUntilVisible(add, 200, scrollable: editorScroll);
    await Scrollable.ensureVisible(tester.element(add), alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(add);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('merchant-group-name')), 'Đá');
    await tester.pump();
    await tester.tap(find.byKey(const Key('merchant-group-apply')));
    await tester.pumpAndSettle();

    final addChoice = find.byKey(const Key('merchant-option-add-2'));
    await tester.scrollUntilVisible(addChoice, 200, scrollable: editorScroll);
    await Scrollable.ensureVisible(tester.element(addChoice), alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(addChoice);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('merchant-option-name')),
      'Ít đá',
    );
    await tester.enterText(find.byKey(const Key('merchant-option-price')), '0');
    await tester.pump();
    await tester.tap(find.byKey(const Key('merchant-option-apply')));
    await tester.pumpAndSettle();
    bool saveEnabled() => tester
        .widget<DealGoPrimaryButton>(
          find.byKey(const Key('merchant-variants-save')),
        )
        .enabled;
    expect(saveEnabled(), isTrue);

    await tester.tap(find.byKey(const Key('merchant-variants-save')));
    await tester.pumpAndSettle();
    final sent = food.optionCalls.single;
    expect(sent.groups.map((g) => g.title), ['Size', 'Topping', 'Đá']);
    expect(sent.groups.last.choices.single.label, 'Ít đá');
    expect(find.text('Đã lưu tuỳ chọn món'), findsOneWidget);
    expect(saveEnabled(), isFalse);
  });

  testWidgets(
    'customer picks options; order carries optionIds and priced line',
    (tester) async {
      final food = FakeFoodClient(
        stores: const [FoodStoreSummary(id: 'store-tea', name: 'Trà Sữa')],
        details: const {'store-tea': _store},
      );
      await pumpSignedIn(
        tester,
        profile: customerProfile,
        foodClient: food,
        pricing: FakePricingRemoteDataSource(deliveryFareVnd: 15000),
      );
      await tester.tap(navLabel('Mua'));
      await tester.pumpAndSettle();
      final card = find.byKey(const Key('food-store-card-store-tea'));
      await tester.scrollUntilVisible(
        card,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(card);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('food-dish-item-tea')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('food-dish-item-tea')));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const Key('food-option-o-l')),
        120,
        scrollable: find
            .descendant(
              of: find.byType(FoodItemOptionsPage),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('food-option-o-l')));
      await tester.pumpAndSettle();
      final topping = find.byKey(const Key('food-option-o-tc'));
      await tester.scrollUntilVisible(
        topping,
        120,
        scrollable: find
            .descendant(
              of: find.byType(FoodItemOptionsPage),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.ensureVisible(topping);
      await tester.pumpAndSettle();
      await tester.tap(topping);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('food-options-add')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Xem giỏ hàng'));
      await tester.pumpAndSettle();
      expect(find.text('63.000đ'), findsWidgets);
      await chooseDeliveryAddress(tester);
      await tester.tap(find.byKey(const Key('food-place-order')));
      await tester.pumpAndSettle();
      final placed = food.placeCalls.single.items.single;
      expect(placed.itemId, 'item-tea');
      expect(placed.optionIds.toSet(), {'o-l', 'o-tc'});
    },
  );

  testWidgets('row add uses the default picks for a configured dish', (
    tester,
  ) async {
    final food = FakeFoodClient(
      stores: const [FoodStoreSummary(id: 'store-tea', name: 'Trà Sữa')],
      details: const {'store-tea': _store},
    );
    await pumpSignedIn(
      tester,
      profile: customerProfile,
      foodClient: food,
      pricing: FakePricingRemoteDataSource(deliveryFareVnd: 15000),
    );
    await tester.tap(navLabel('Mua'));
    await tester.pumpAndSettle();
    final card = find.byKey(const Key('food-store-card-store-tea'));
    await tester.scrollUntilVisible(
      card,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(card);
    await tester.pumpAndSettle();

    final add = find.byKey(const Key('food-add-item-tea'));
    await tester.scrollUntilVisible(
      add,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(add);
    await tester.pumpAndSettle();

    final cart = tester
        .element(find.byKey(const Key('food-add-item-tea')))
        .read<FoodCartCubit>();
    final line = cart.state.lines.single;
    expect(line.name, 'Trà sữa · M');
    expect(line.optionIds, ['o-m']);
    expect(line.unitPriceVnd, 45000);
    expect(line.quantity, 1);
  });

  testWidgets('a missing required group blocks add and is called out', (
    tester,
  ) async {
    const group = FoodOptionGroup(
      id: 'g-size',
      title: 'Chọn size',
      minSelect: 1,
      maxSelect: 2,
      choices: [
        FoodOptionChoice(id: 'o-s', label: 'S'),
        FoodOptionChoice(id: 'o-l', label: 'L'),
      ],
    );
    const item = FoodMenuItem(
      id: 'item',
      name: 'Trà đào',
      priceVnd: 20000,
      available: true,
      optionGroups: [group],
    );
    const store = FoodStoreDetail(id: 'store', name: 'Quán', items: [item]);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider(
          create: (_) => FoodCartCubit(),
          child: const FoodItemOptionsPage(
            args: FoodItemOptionsArgs(store: store, item: item),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    DealGoPrimaryButton addButton() =>
        tester.widget(find.byKey(const Key('food-options-add')));
    expect(find.byKey(const Key('food-options-missing')), findsOneWidget);
    expect(addButton().enabled, isFalse);

    await tester.scrollUntilVisible(
      find.byKey(const Key('food-option-o-s')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Miễn phí'), findsWidgets);
    await tester.tap(find.byKey(const Key('food-option-o-s')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('food-options-missing')), findsNothing);
    expect(addButton().enabled, isTrue);
  });

  test('option maxQuantity stepper and delta with multiplicity', () {
    const groups = [
      FoodOptionGroup(
        id: 'g-top',
        title: 'Topping',
        minSelect: 0,
        maxSelect: 3,
        choices: [
          FoodOptionChoice(
            id: 'o-pearl',
            label: 'Trân châu',
            extraVnd: 5000,
            maxQuantity: 2,
          ),
          FoodOptionChoice(
            id: 'o-jelly',
            label: 'Thạch',
            extraVnd: 4000,
            maxQuantity: 1,
          ),
        ],
      ),
    ];
    var sel = FoodOptionSelection.initial(groups);
    sel = sel.setQuantity(groups.first, groups.first.choices.first, 2);
    expect(sel.quantityOf('g-top', 'o-pearl'), 2);
    expect(sel.extrasVnd, 10000);
    expect(sel.optionIds, ['o-pearl', 'o-pearl']);
    expect(foodOptionDelta(groups, sel.optionIds), 10000);
    final blocked = sel.setQuantity(
      groups.first,
      groups.first.choices.first,
      3,
    );
    expect(blocked.quantityOf('g-top', 'o-pearl'), 2);
    expect(foodOptionDelta(groups, ['o-pearl', 'o-pearl', 'o-pearl']), isNull);
  });
}
