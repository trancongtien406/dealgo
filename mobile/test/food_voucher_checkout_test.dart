import 'package:dealgo/features/food/data/datasources/dio_food_remote_datasource.dart';
import 'package:dealgo/features/food/data/models/place_food_order_body.dart';
import 'package:dealgo/features/food/domain/entities/food_models.dart';
import 'package:dealgo/features/food/domain/params/place_food_order_params.dart';
import 'package:dealgo/features/food/presentation/cubit/food_cart_cubit.dart';
import 'package:dealgo/features/food/presentation/widgets/food_checkout_widgets.dart';
import 'package:dealgo/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const item = FoodMenuItem(
    id: 'item-1',
    name: 'Bún bò',
    priceVnd: 60000,
    available: true,
  );

  test('cart nets the quoted voucher and keeps its code for revalidation', () {
    final cart = FoodCartCubit()
      ..addItem(storeId: 'store-1', storeName: 'Quán', item: item)
      ..applyVoucher(code: 'FOOD20', discountVnd: 20000);
    final base = cart.state.subtotalVnd;
    expect(cart.state.voucherCode, 'FOOD20');
    expect(cart.state.previewTotalVnd, base - 20000);

    cart.addItem(storeId: 'store-1', storeName: 'Quán', item: item);
    expect(cart.state.voucherCode, 'FOOD20');
    expect(cart.state.voucherDiscountVnd, 0);
    cart.close();
  });

  test('place body carries the voucher code only when present', () {
    const params = PlaceFoodOrderParams(
      accessToken: 't',
      idempotencyKey: 'k',
      storeId: 's',
      items: [FoodOrderItem(itemId: 'i', quantity: 1)],
      dropoff: FoodDropoff(lat: 1, lng: 2, label: 'A'),
      deliveryFareVnd: 15000,
      voucherCode: 'FOOD20',
    );
    expect(
      PlaceFoodOrderBody.fromParams(params).toJson()['voucherCode'],
      'FOOD20',
    );
    const plain = PlaceFoodOrderParams(
      accessToken: 't',
      idempotencyKey: 'k',
      storeId: 's',
      items: [FoodOrderItem(itemId: 'i', quantity: 1)],
      dropoff: FoodDropoff(lat: 1, lng: 2, label: 'A'),
      deliveryFareVnd: 15000,
    );
    expect(
      PlaceFoodOrderBody.fromParams(plain).toJson().containsKey('voucherCode'),
      isFalse,
    );
  });

  test('an unqualified remembered voucher explains the checkout blocker', () {
    final cart = FoodCartCubit()
      ..addItem(storeId: 'store-1', storeName: 'Quán', item: item)
      ..setDropoff(label: '123 Nguyễn Văn Linh', lat: 10.77, lng: 106.7)
      ..setDeliveryFare(15000)
      ..applyVoucher(code: 'FOOD20');
    final l10n = lookupAppLocalizations(const Locale('vi'));

    expect(cart.state.canCheckout, isFalse);
    expect(
      checkoutBlockingMessage(cart.state, l10n),
      l10n.checkoutVoucherRejected,
    );

    cart.applyVoucher();
    expect(cart.state.canCheckout, isTrue);
    expect(checkoutBlockingMessage(cart.state, l10n), isNull);
    cart.close();
  });

  test('decodes the server discount and ready-job store details', () {
    final order = decodePlacedFoodOrder({
      'success': true,
      'data': {
        'id': 'o1',
        'status': 'PLACED',
        'subtotalVnd': 60000,
        'deliveryFareVnd': 15000,
        'discountVnd': 20000,
        'voucherCode': 'FOOD20',
        'totalVnd': 55000,
        'lines': <Object>[],
      },
    });
    expect(order.discountVnd, 20000);
    expect(order.voucherCode, 'FOOD20');
    expect(order.totalVnd, 55000);

    final jobs = decodeReadyFoodJobs({
      'success': true,
      'data': [
        {
          'id': 'j1',
          'storeId': 's1',
          'storeName': 'Bún Bò Huế',
          'storeAddress': 'Quận Hải Châu, Đà Nẵng',
          'status': 'READY',
          'deliveryFareVnd': 15000,
          'subtotalVnd': 60000,
          'totalVnd': 75000,
          'dropoff': {'lat': 16.0, 'lng': 108.2, 'label': 'Hải Châu'},
          'lineCount': 1,
        },
      ],
    });
    expect(jobs.single.storeName, 'Bún Bò Huế');
    expect(jobs.single.storeAddress, 'Quận Hải Châu, Đà Nẵng');
  });
}
