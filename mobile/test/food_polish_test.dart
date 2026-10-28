import 'package:dealgo/features/food/domain/entities/food_models.dart';
import 'package:dealgo/features/food/presentation/cubit/food_cart_cubit.dart';
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
}
