import 'package:dealgo/features/food/domain/entities/food_models.dart';
import 'package:dealgo/features/food/presentation/cubit/food_cart_cubit.dart';
import 'package:dealgo/features/food/presentation/food_cart_draft.dart';
import 'package:dealgo/features/food/presentation/widgets/food_badges.dart';
import 'package:dealgo/features/promotion/domain/entities/available_voucher.dart';
import 'package:dealgo/features/promotion/presentation/widgets/food_voucher_picker_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

const _item = FoodMenuItem(
  id: 'i1',
  name: 'Bún chả cá',
  priceVnd: 30000,
  available: true,
);

AvailableVoucher _voucher(
  VoucherDiscountKind kind,
  int value, {
  int? max,
  int minOrder = 0,
}) => AvailableVoucher(
  code: 'X',
  name: 'X',
  description: '',
  service: null,
  kind: kind,
  discountValue: value,
  maxDiscountVnd: max,
  minOrderVnd: minOrder,
  endsAt: DateTime(2030),
  usesLeft: 1,
);

void main() {
  test('cart tracks the store minimum and blocks checkout until met', () {
    final cart = FoodCartCubit()
      ..addItem(
        storeId: 's1',
        storeName: 'Quán',
        item: _item,
        minOrderVnd: 50000,
        prepMinutes: 15,
      );
    expect(cart.state.minOrderShortVnd, 20000);
    expect(cart.state.etaMinutes, 15);
    cart.addItem(storeId: 's1', storeName: 'Quán', item: _item);
    expect(cart.state.minOrderShortVnd, 0);
  });

  test('distance set before the first add feeds the ETA', () {
    final cart = FoodCartCubit()..setStoreDistance('s1', 2);
    cart.addItem(
      storeId: 's1',
      storeName: 'Quán',
      item: _item,
      prepMinutes: 10,
    );
    expect(cart.state.etaMinutes, 16);
  });

  test('voucher saving respects caps and the delivery fee', () {
    expect(
      voucherEstimatedSaving(
        _voucher(VoucherDiscountKind.percentage, 20, max: 30000),
        orderAmountVnd: 200000,
        deliveryFeeVnd: 15000,
      ),
      30000,
    );
    expect(
      voucherEstimatedSaving(
        _voucher(VoucherDiscountKind.deliveryDiscount, 25000),
        orderAmountVnd: 100000,
        deliveryFeeVnd: 15000,
      ),
      15000,
    );
    expect(
      voucherEstimatedSaving(
        _voucher(VoucherDiscountKind.fixedAmount, 50000),
        orderAmountVnd: 30000,
        deliveryFeeVnd: 15000,
      ),
      30000,
    );
  });

  test('best sellers are the top 3 dishes that sold', () {
    final items = [
      for (final (id, sold) in [
        ('a', 5),
        ('b', 50),
        ('c', 0),
        ('d', 9),
        ('e', 7),
      ])
        FoodMenuItem(
          id: id,
          name: id,
          priceVnd: 1,
          available: true,
          soldCount: sold,
        ),
    ];
    expect(foodBestSellerIds(items), {'b', 'd', 'e'});
  });

  test('new badge lasts 14 days', () {
    final now = DateTime(2026, 10, 27);
    expect(foodItemIsNew(DateTime(2026, 10, 20), now: now), isTrue);
    expect(foodItemIsNew(DateTime(2026, 10, 1), now: now), isFalse);
    expect(foodItemIsNew(null, now: now), isFalse);
  });

  test('order note and utensils survive a quantity change', () {
    final cart = FoodCartCubit()
      ..addItem(storeId: 's1', storeName: 'Quán', item: _item)
      ..setNote('Ít cay')
      ..setUtensils(false);
    cart.setQuantity('i1', 3);
    expect(cart.state.lines.single.quantity, 3);
    expect(cart.state.note, 'Ít cay');
    expect(cart.state.utensils, isFalse);
  });

  test('order note and utensils reset when the store changes', () {
    final cart = FoodCartCubit()
      ..addItem(storeId: 's1', storeName: 'Quán', item: _item)
      ..setNote('Ít cay')
      ..setUtensils(false);
    cart.addItem(
      storeId: 's2',
      storeName: 'Quán 2',
      item: const FoodMenuItem(
        id: 'i2',
        name: 'Phở',
        priceVnd: 40000,
        available: true,
      ),
    );
    expect(cart.state.note, '');
    expect(cart.state.utensils, isTrue);
  });

  test('blank order note normalises to empty, utensils default to true', () {
    final cart = FoodCartCubit();
    expect(cart.state.note, '');
    expect(cart.state.utensils, isTrue);
    cart.setNote('   ');
    expect(cart.state.note, '');
  });

  test('placing an order clears the note and restores utensils', () {
    final cart = FoodCartCubit()
      ..addItem(storeId: 's1', storeName: 'Quán', item: _item)
      ..setNote('Ít cay')
      ..setUtensils(false)
      ..clearAfterOrder();
    expect(cart.state.note, '');
    expect(cart.state.utensils, isTrue);
  });

  test('draft keeps the order note, utensils and line notes', () {
    final cart = FoodCartCubit()
      ..addItem(storeId: 's1', storeName: 'Quán', item: _item)
      ..setNote('Ít cay')
      ..setUtensils(false)
      ..setLineNote('i1', 'Không hành');
    final restored = foodCartFromDraft(foodCartToDraft(cart.state));
    expect(restored, isNotNull);
    expect(restored!.note, 'Ít cay');
    expect(restored.utensils, isFalse);
    expect(restored.lines.single.note, 'Không hành');
  });

  test('a draft from the previous version restores to the defaults', () {
    final restored = foodCartFromDraft({
      'storeId': 's1',
      'storeName': 'Quán',
      'lines': [
        {
          'itemId': 'i1',
          'name': 'Bún',
          'unitPriceVnd': 30000,
          'quantity': 1,
          'catalogItemId': null,
          'optionIds': <String>[],
          'imageUrl': null,
        },
      ],
      'dropoffLabel': '',
      'idempotencyKey': 'key-1',
    });
    expect(restored, isNotNull);
    expect(restored!.note, '');
    expect(restored.utensils, isTrue);
    expect(restored.lines.single.note, isNull);
  });
}
