import 'package:dealgo/core/design_system/tokens/dealgo_tokens.dart';
import 'package:dealgo/features/food/domain/entities/food_models.dart';
import 'package:dealgo/features/food/domain/entities/food_money.dart';
import 'package:dealgo/features/food/presentation/cubit/food_cart_cubit.dart';
import 'package:dealgo/features/food/presentation/pages/food_checkout_page.dart';
import 'package:dealgo/features/food/presentation/utils/food_maps.dart';
import 'package:dealgo/features/promotion/domain/entities/available_voucher.dart';
import 'package:dealgo/features/promotion/domain/entities/voucher_quote.dart';
import 'package:dealgo/features/promotion/presentation/widgets/food_voucher_picker_sheet.dart';
import 'package:dealgo/l10n/app_localizations.dart';
import 'package:dealgo/features/rating/data/rating_remote_datasource.dart';
import 'package:dealgo/features/rating/domain/service_rating.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/auth_test_harness.dart';
import 'support/fake_food_client.dart';
import 'support/fake_identity_client.dart';

const _id = 'store-com';

FakeFoodClient _client() => FakeFoodClient(
  stores: const [
    FoodStoreSummary(id: _id, name: 'Cơm Tấm Sài Gòn', category: 'rice'),
  ],
  details: {
    _id: FoodStoreDetail(
      id: _id,
      name: 'Cơm Tấm Sài Gòn',
      category: 'rice',
      menuSections: const [
        FoodMenuSection(id: 'sec-com', name: 'Cơm'),
        FoodMenuSection(id: 'sec-drink', name: 'Đồ uống'),
      ],
      offers: [
        StoreOffer(
          id: 'o1',
          code: 'COM20',
          name: 'Giảm 20%',
          kind: StoreOfferKind.percentage,
          discountValue: 20,
          maxDiscountVnd: 30000,
          minOrderVnd: 80000,
          endsAt: DateTime(2026, 12, 31),
        ),
        StoreOffer(
          id: 'o2',
          code: 'GIAM15',
          name: 'Giảm 15K đơn đầu',
          kind: StoreOfferKind.fixedAmount,
          discountValue: 15000,
          minOrderVnd: 0,
          endsAt: DateTime(2026, 12, 31),
          remainingUses: 3,
        ),
      ],
      items: const [
        FoodMenuItem(
          id: 'i1',
          name: 'Cơm sườn bì chả',
          priceVnd: 55000,
          available: true,
          soldCount: 120,
          menuCategoryId: 'sec-com',
        ),
        FoodMenuItem(
          id: 'i2',
          name: 'Cơm gà xối mỡ',
          priceVnd: 50000,
          available: true,
          soldCount: 80,
          menuCategoryId: 'sec-com',
        ),
        FoodMenuItem(
          id: 'i3',
          name: 'Trà đá',
          priceVnd: 5000,
          available: true,
          menuCategoryId: 'sec-drink',
        ),
      ],
    ),
  },
);

FakeFoodClient _longMenuClient() {
  final base = _client();
  base.details[_id] = base.details[_id]!.copyWith(
    items: [
      for (var index = 1; index <= 6; index++)
        FoodMenuItem(
          id: 'c$index',
          name: 'Món cơm số $index',
          priceVnd: 40000 + index * 1000,
          available: true,
          soldCount: 10,
          menuCategoryId: 'sec-com',
        ),
      for (var index = 1; index <= 4; index++)
        FoodMenuItem(
          id: 'd$index',
          name: 'Đồ uống số $index',
          priceVnd: 15000,
          available: true,
          menuCategoryId: 'sec-drink',
        ),
    ],
  );
  return base;
}

FakeRatingRemoteDataSource _ratings() => FakeRatingRemoteDataSource(
  stores: {
    _id: const StoreRating(
      storeId: _id,
      count: 6,
      average: 4.3,
      distribution: [0, 1, 0, 1, 4],
    ),
  },
  reviews: {
    _id: [
      StoreReview(
        id: 'r1',
        stars: 5,
        tags: const [],
        comment: 'Sườn mềm, rất ngon',
        createdAt: DateTime(2026, 10, 20),
        merchantReply: 'Cảm ơn bạn',
      ),
      StoreReview(
        id: 'r2',
        stars: 2,
        tags: const [],
        comment: 'Giao hơi trễ',
        createdAt: DateTime(2026, 10, 21),
      ),
    ],
  },
);

Future<void> _openStore(WidgetTester tester, {FakeFoodClient? food}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await pumpSignedIn(
    tester,
    profile: customerProfile,
    foodClient: food ?? _client(),
    ratings: _ratings(),
  );
  GoRouter.of(tester.element(find.byType(Scaffold).first))
      .push('/customer/food/stores/$_id');
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('menu has a category rail, every section and in-store search', (
    tester,
  ) async {
    await _openStore(tester);
    expect(find.byKey(const Key('food-menu-categories')), findsOneWidget);
    expect(find.byKey(const Key('food-menu-category-best')), findsOneWidget);
    expect(find.byKey(const Key('food-menu-category-sec-com')), findsOneWidget);
    expect(
      find.byKey(const Key('food-menu-category-sec-drink')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('food-menu-best-i1')), findsOneWidget);
    expect(find.byKey(const Key('food-menu-sec-com-i1')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('food-store-search')),
      'tra da',
    );
    await tester.pumpAndSettle();
    expect(find.text('Trà đá'), findsOneWidget);
    expect(find.text('Cơm sườn bì chả'), findsNothing);

    await tester.enterText(find.byKey(const Key('food-store-search')), 'pizza');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('food-store-search-empty')), findsOneWidget);

    await tester.tap(find.byKey(const Key('food-store-search-clear')));
    await tester.pumpAndSettle();
    expect(find.text('Cơm sườn bì chả'), findsWidgets);
  });

  testWidgets('tap opens dish details; only the plus adds to the cart', (
    tester,
  ) async {
    await _openStore(tester);
    final cart = tester
        .element(find.byKey(const Key('food-store-cover')))
        .read<FoodCartCubit>();

    final dish = find.byKey(const Key('food-menu-sec-com-i1'));
    await tester.ensureVisible(dish);
    await tester.pumpAndSettle();
    await tester.tap(dish);
    await tester.pumpAndSettle();
    expect(find.text('Chi tiết món'), findsOneWidget);
    expect(cart.state.lines, isEmpty);

    await tester.tap(find.byKey(const Key('food-item-qty-inc')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('food-options-add')));
    await tester.pumpAndSettle();
    expect(cart.state.lines.single.quantity, 2);
  });

  testWidgets('the category rail follows the scrolled menu', (tester) async {
    await _openStore(tester, food: _longMenuClient());
    String? activeId() {
      final highlighted = [
        for (final id in ['best', 'sec-com', 'sec-drink'])
          if (tester
                  .widget<Text>(find.byKey(Key('food-menu-category-label-$id')))
                  .style
                  ?.color ==
              DealGoColors.primary)
            id,
      ];
      return highlighted.isEmpty ? null : highlighted.single;
    }

    expect(activeId(), 'best');

    // The first drags collapse the store header, then the menu itself scrolls.
    for (var i = 0; i < 12 && activeId() != 'sec-com'; i++) {
      await tester.drag(
        find.byKey(const Key('food-menu-items')),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
    }
    expect(activeId(), 'sec-com');

    for (var i = 0; i < 12 && activeId() != 'sec-drink'; i++) {
      await tester.drag(
        find.byKey(const Key('food-menu-items')),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
    }
    expect(activeId(), 'sec-drink');
  });

  testWidgets('tapping a category scrolls the items to that section', (
    tester,
  ) async {
    await _openStore(tester, food: _longMenuClient());
    final rail = find.byKey(const Key('food-menu-categories'));
    final category = find.byKey(const Key('food-menu-category-sec-drink'));
    for (var i = 0; i < 6 && tester.getCenter(category).dy > 800; i++) {
      await tester.drag(rail, const Offset(0, -80));
      await tester.pumpAndSettle();
    }
    await tester.tap(category);
    await tester.pumpAndSettle();

    final header = tester.getTopLeft(
      find.byKey(const Key('food-menu-section-sec-com')),
    );
    // The last section cannot always reach the very top (the document ends
    // before it); it must still land in the upper half of the viewport.
    expect(header.dy, lessThan(300));
    expect(
      tester
          .widget<Text>(
            find.byKey(const Key('food-menu-category-label-sec-drink')),
          )
          .style
          ?.color,
      DealGoColors.primary,
    );
  });

  testWidgets('a paused store refuses new lines and explains why', (
    tester,
  ) async {
    final food = _client();
    food.details[_id] = food.details[_id]!.copyWith(
      serviceMode: StoreServiceMode.paused,
    );
    await _openStore(tester, food: food);

    expect(find.byKey(const Key('food-add-i1')), findsNothing);
    final dish = find.byKey(const Key('food-menu-sec-com-i1'));
    await tester.ensureVisible(dish);
    await tester.pumpAndSettle();
    await tester.tap(dish);
    await tester.pumpAndSettle();
    expect(find.text('Chi tiết món'), findsNothing);
    expect(find.text('Quán đang tạm ngưng nhận đơn mới.'), findsOneWidget);
  });

  testWidgets('store offer "Dùng" applies the code to the cart', (
    tester,
  ) async {
    await _openStore(tester);
    expect(find.byKey(const Key('food-store-offer-o1')), findsOneWidget);
    await tester.tap(find.byKey(const Key('food-store-offer-use-o1')));
    await tester.pumpAndSettle();
    final cart = tester
        .element(find.byKey(const Key('food-store-offers')))
        .read<FoodCartCubit>();
    expect(cart.state.voucherCode, 'COM20');
    expect(find.byKey(const Key('food-store-offer-use-o1')), findsNothing);
  });

  testWidgets('reviews tab filters by stars and shows the merchant reply', (
    tester,
  ) async {
    await _openStore(tester);
    await tester.tap(find.byKey(const Key('food-store-tab-reviews')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('food-review-bar-5')), findsOneWidget);
    expect(find.text('Sườn mềm, rất ngon'), findsOneWidget);
    expect(find.text('Cảm ơn bạn'), findsOneWidget);
    expect(find.text('Giao hơi trễ'), findsOneWidget);

    await tester.dragUntilVisible(
      find.byKey(const Key('food-review-filter-2')),
      find.byType(CustomScrollView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('food-review-filter-2')));
    await tester.pumpAndSettle();
    expect(find.text('Giao hơi trễ'), findsOneWidget);
    expect(find.text('Sườn mềm, rất ngon'), findsNothing);
  });

  testWidgets(
    'cart bar: hidden empty, min-order shortfall, saving, opens cart',
    (tester) async {
      await _openStore(tester);
      expect(find.byKey(const Key('food-cart-bar')), findsNothing);
      final cart = tester
          .element(find.byKey(const Key('food-store-offers')))
          .read<FoodCartCubit>();
      const item = FoodMenuItem(
        id: 'i1',
        name: 'Cơm sườn bì chả',
        priceVnd: 55000,
        available: true,
      );
      cart.addItem(
        storeId: _id,
        storeName: 'Cơm Tấm Sài Gòn',
        item: item,
        minOrderVnd: 80000,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('food-cart-bar')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('food-cart-bar-count'))).data,
        '1',
      );
      expect(find.text('Còn thiếu ${formatVnd(25000)}'), findsOneWidget);

      cart.addItem(
        storeId: _id,
        storeName: 'Cơm Tấm Sài Gòn',
        item: item,
        minOrderVnd: 80000,
      );
      cart.applyVoucher(code: 'COM20');
      await tester.pumpAndSettle();
      // 20% of 110.000đ = 22.000đ off.
      expect(
        tester.widget<Text>(find.byKey(const Key('food-cart-bar-total'))).data,
        formatVnd(88000),
      );
      expect(find.text('Tiết kiệm ${formatVnd(22000)}'), findsOneWidget);

      await tester.tap(find.byKey(const Key('food-cart-bar-open')));
      await tester.pumpAndSettle();
      expect(find.byType(FoodCheckoutPage), findsOneWidget);
    },
  );

  testWidgets('offers: ticket strip, full conditions, "Xem tất cả" sheet', (
    tester,
  ) async {
    await _openStore(tester);
    expect(find.text('Giảm 20%'), findsWidgets);
    expect(find.text('Giảm 15K'), findsOneWidget);
    expect(find.text('Còn 3 lượt'), findsOneWidget);
    expect(find.text('HSD 31/12/2026'), findsWidgets);

    await tester.tap(find.byKey(const Key('food-store-offers-all')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('food-store-offers-sheet')), findsOneWidget);
    await tester.tap(find.byKey(const Key('food-store-sheet-offer-use-o2')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('food-store-sheet-offer-used-o2')),
      findsOneWidget,
    );
    final cart = tester
        .element(find.byKey(const Key('food-store-offers-sheet')))
        .read<FoodCartCubit>();
    expect(cart.state.voucherCode, 'GIAM15');
  });

  testWidgets('checkout voucher list: tickets, best pick, "Đã dùng"', (
    tester,
  ) async {
    String? picked;
    final vouchers = [
      AvailableVoucher(
        code: 'BIG',
        name: 'Giảm 20% món ngon',
        description: '',
        service: VoucherService.food,
        kind: VoucherDiscountKind.percentage,
        discountValue: 20,
        maxDiscountVnd: 40000,
        minOrderVnd: 0,
        endsAt: DateTime(2026, 12, 31),
        usesLeft: 2,
      ),
      AvailableVoucher(
        code: 'FAR',
        name: 'Giảm 50K đơn lớn',
        description: '',
        service: VoucherService.food,
        kind: VoucherDiscountKind.fixedAmount,
        discountValue: 50000,
        minOrderVnd: 500000,
        endsAt: DateTime(2026, 12, 31),
        usesLeft: 1,
      ),
    ];
    Widget sheet(String? selected) => MaterialApp(
      locale: const Locale('vi'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async {
                picked = await showModalBottomSheet<String>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => FoodVoucherPickerSheet(
                    load: () async => vouchers,
                    orderAmountVnd: 200000,
                    selectedCode: selected,
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.pumpWidget(sheet(null));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Ưu đãi của tôi'), findsOneWidget);
    expect(find.byKey(const Key('checkout-voucher-best')), findsOneWidget);
    expect(find.text('Tối đa ${formatVnd(40000)}'), findsOneWidget);
    expect(find.text('Còn 2 lượt'), findsOneWidget);
    expect(find.text('Mua thêm ${formatVnd(300000)}'), findsOneWidget);
    expect(find.byKey(const Key('checkout-voucher-use-FAR')), findsNothing);
    await tester.tap(find.byKey(const Key('checkout-voucher-use-BIG')));
    await tester.pumpAndSettle();
    expect(picked, 'BIG');

    await tester.pumpWidget(sheet('BIG'));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('checkout-voucher-used-BIG')), findsOneWidget);
    expect(find.text('Đã dùng'), findsOneWidget);
  });

  testWidgets('the map lives on the info tab and opens Google Maps', (
    tester,
  ) async {
    final food = _client();
    food.details[_id] = food.details[_id]!.copyWith(
      lat: 16.0544,
      lng: 108.2022,
      addressLabel: '12 Lê Lợi, Hải Châu',
    );
    final opened = <Uri>[];
    debugFoodMapOpener = (uri) async {
      opened.add(uri);
      return true;
    };
    addTearDown(() => debugFoodMapOpener = null);

    await _openStore(tester, food: food);

    expect(find.byKey(const Key('food-store-map')), findsNothing);
    await tester.tap(find.byKey(const Key('food-store-tab-info')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('food-store-map')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('food-store-map-open')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('food-store-map-open')));
    await tester.pumpAndSettle();

    expect(opened.single.host, 'www.google.com');
    expect(opened.single.path, '/maps/search/');
    expect(opened.single.queryParameters['query'], '16.0544,108.2022');
  });

  testWidgets('unpinned store still shows an address block that opens Maps', (
    tester,
  ) async {
    final food = _client();
    food.details[_id] = food.details[_id]!.copyWith(
      addressLabel: '88 Bạch Đằng, Hải Châu',
    );
    final opened = <Uri>[];
    debugFoodMapOpener = (uri) async {
      opened.add(uri);
      return true;
    };
    addTearDown(() => debugFoodMapOpener = null);

    await _openStore(tester, food: food);

    await tester.tap(find.byKey(const Key('food-store-tab-info')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('food-store-map')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('food-store-map')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('food-store-map')));
    await tester.pumpAndSettle();

    expect(opened.single.host, 'www.google.com');
    expect(
      opened.single.queryParameters['query'],
      contains('88 Bạch Đằng, Hải Châu'),
    );
  });

  testWidgets('tapping a category lands its heading under the pinned bar', (
    tester,
  ) async {
    await _openStore(tester, food: _longMenuClient());
    // The rail only shows a couple of rows while the store header is expanded.
    await tester.drag(
      find.byKey(const Key('food-menu-categories')),
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('food-menu-category-sec-com')));
    await tester.pumpAndSettle();

    final barBottom = tester
        .getBottomLeft(find.byKey(const Key('food-store-search')))
        .dy;
    final headingTop = tester
        .getTopLeft(find.byKey(const Key('food-menu-section-sec-com')))
        .dy;
    expect(headingTop, greaterThanOrEqualTo(barBottom));
    expect(headingTop - barBottom, lessThan(24));
  });

  testWidgets('the highlighted category stays clear of the pinned bar', (
    tester,
  ) async {
    await _openStore(tester, food: _longMenuClient());
    for (var i = 0; i < 6; i++) {
      await tester.drag(
        find.byKey(const Key('food-menu-items')),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
    }

    String? activeId() {
      for (final id in ['best', 'sec-com', 'sec-drink']) {
        final label = find.byKey(Key('food-menu-category-label-$id'));
        if (label.evaluate().isNotEmpty &&
            tester.widget<Text>(label).style?.color == DealGoColors.primary) {
          return id;
        }
      }
      return null;
    }

    final active = activeId();
    expect(active, isNotNull);
    final barBottom = tester
        .getBottomLeft(find.byKey(const Key('food-store-search')))
        .dy;
    final row = find.byKey(Key('food-menu-category-$active'));
    expect(tester.getTopLeft(row).dy, greaterThanOrEqualTo(barBottom - 1));
    expect(
      tester.getBottomLeft(row).dy,
      lessThanOrEqualTo(tester.view.physicalSize.height / 3),
    );
  });

  testWidgets('search and the category rail stay pinned while scrolling', (
    tester,
  ) async {
    await _openStore(tester);
    for (var i = 0; i < 4; i++) {
      await tester.drag(
        find.byKey(const Key('food-menu-items')),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
    }

    expect(find.byKey(const Key('food-store-search')), findsOneWidget);
    expect(find.byKey(const Key('food-menu-categories')), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const Key('food-store-search'))).dy,
      lessThan(300),
    );
  });

  testWidgets('dish photo is a square on the left with a compact add button', (
    tester,
  ) async {
    await _openStore(tester);
    final card = find.byKey(const Key('food-menu-best-i1'));

    final photo = find.byKey(const Key('food-menu-photo-i1')).first;
    final photoSize = tester.getSize(photo);
    expect(photoSize.width, 84);
    expect(photoSize.height, photoSize.width);
    expect(
      tester.getTopLeft(photo).dx,
      lessThan(
        tester.getTopLeft(find.byKey(const Key('food-price-i1')).first).dx,
      ),
    );
    expect(tester.getSize(card).height, greaterThan(photoSize.height));

    final add = tester.getSize(find.byKey(const Key('food-add-i1')).first);
    expect(add.width, add.height);
    expect(add.width, lessThanOrEqualTo(32));
    expect(add.height, lessThanOrEqualTo(32));
  });

  testWidgets('menu headings capitalize the merchant category name', (
    tester,
  ) async {
    final food = FakeFoodClient(
      stores: const [FoodStoreSummary(id: _id, name: 'Quán Bún')],
      details: {
        _id: const FoodStoreDetail(
          id: _id,
          name: 'Quán Bún',
          menuSections: [
            FoodMenuSection(id: 'sec-bun', name: 'món nước'),
            FoodMenuSection(id: 'sec-tra', name: 'đồ uống'),
          ],
          items: [
            FoodMenuItem(
              id: 'b1',
              name: 'Bún bò',
              priceVnd: 45000,
              available: true,
              menuCategoryId: 'sec-bun',
            ),
            FoodMenuItem(
              id: 'b2',
              name: 'Bún riêu',
              priceVnd: 40000,
              available: true,
              menuCategoryId: 'sec-bun',
            ),
            FoodMenuItem(
              id: 'b3',
              name: 'Trà đá',
              priceVnd: 5000,
              available: true,
              menuCategoryId: 'sec-tra',
            ),
          ],
        ),
      },
    );
    await _openStore(tester, food: food);

    expect(find.text('món nước'), findsNothing);
    expect(find.text('đồ uống'), findsNothing);
    expect(find.text('Món nước'), findsWidgets);
    expect(find.text('Đồ uống'), findsWidgets);
    expect(find.byKey(const Key('food-menu-section-sec-bun')), findsOneWidget);
  });

  test('map link falls back to the written address without coordinates', () {
    final uri = foodStoreMapsUri(
      const FoodStoreDetail(
        id: 'store',
        name: 'Trà Sữa',
        addressLabel: '1 Bạch Đằng',
        items: [],
      ),
    );
    expect(uri.queryParameters['query'], 'Trà Sữa, 1 Bạch Đằng');
  });
}
