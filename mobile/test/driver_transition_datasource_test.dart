import 'dart:convert';
import 'dart:typed_data';

import 'package:dealgo/features/food/data/datasources/dio_food_remote_datasource.dart';
import 'package:dealgo/features/food/domain/params/food_delivery_action.dart';
import 'package:dealgo/features/promotion/data/datasources/promotion_remote_datasource.dart';
import 'package:dealgo/features/promotion/domain/entities/voucher_quote.dart';
import 'package:dealgo/features/ride/data/datasources/dio_ride_remote_datasource.dart';
import 'package:dealgo/features/ride/domain/entities/ride_models.dart';
import 'package:dealgo/features/ride/domain/params/ride_driver_action.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records requests and answers with a canned success envelope.
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.data);

  final Map<String, Object?> data;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode({'success': true, 'data': data}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _dio(HttpClientAdapter adapter) {
  return Dio(BaseOptions(baseUrl: 'http://api.test'))
    ..httpClientAdapter = adapter;
}

void main() {
  test('ride driver actions POST to the matching transition path', () async {
    final adapter = _RecordingAdapter({
      'id': 'ride-1',
      'status': 'DRIVER_EN_ROUTE',
      'pickup': {'lat': 16.05, 'lng': 108.2, 'label': 'A'},
      'dropoff': {'lat': 16.04, 'lng': 108.21, 'label': 'B'},
      'offeredFareVnd': 40000,
      'referenceFareVnd': 40000,
      'expiresAt': '2030-01-01T00:00:00.000Z',
      'offers': <Object?>[],
    });
    final source = DioRideRemoteDataSource(dio: _dio(adapter));

    for (final action in RideDriverAction.values) {
      await source.advanceRide(
        accessToken: 'tok',
        rideId: 'ride-1',
        action: action,
      );
    }

    expect(adapter.requests.map((r) => '${r.method} ${r.path}'), [
      'POST /v1/rides/ride-1/en-route',
      'POST /v1/rides/ride-1/arrived',
      'POST /v1/rides/ride-1/start',
      'POST /v1/rides/ride-1/complete',
    ]);
    expect(adapter.requests.first.headers['Authorization'], 'Bearer tok');
    final view = (await source.advanceRide(
      accessToken: 'tok',
      rideId: 'ride-1',
      action: RideDriverAction.enRoute,
    )).toEntity();
    expect(view.status, RideStatus.parse('DRIVER_EN_ROUTE'));
  });

  test('food delivery actions and cancel POST to the order paths', () async {
    final adapter = _RecordingAdapter({'id': 'order-1', 'status': 'PICKED_UP'});
    final source = DioFoodRemoteDataSource(dio: _dio(adapter));

    final picked = await source.advanceDelivery(
      accessToken: 'tok',
      orderId: 'order-1',
      action: FoodDeliveryAction.pickup,
    );
    await source.advanceDelivery(
      accessToken: 'tok',
      orderId: 'order-1',
      action: FoodDeliveryAction.deliver,
    );
    await source.cancelOrder(accessToken: 'tok', orderId: 'order-1');

    expect(picked.status, 'PICKED_UP');
    expect(adapter.requests.map((r) => '${r.method} ${r.path}'), [
      'POST /v1/food/orders/order-1/pickup',
      'POST /v1/food/orders/order-1/deliver',
      'POST /v1/food/orders/order-1/cancel',
    ]);
  });

  test('food codes go in the pickup / deliver bodies (DEC-PROD-036)', () async {
    final adapter = _RecordingAdapter({'id': 'order-1', 'status': 'DELIVERED'});
    final source = DioFoodRemoteDataSource(dio: _dio(adapter));
    await source.advanceDelivery(
      accessToken: 'tok',
      orderId: 'order-1',
      action: FoodDeliveryAction.pickup,
      code: '2891',
    );
    await source.advanceDelivery(
      accessToken: 'tok',
      orderId: 'order-1',
      action: FoodDeliveryAction.deliver,
      code: '4821',
    );
    await source.advanceDelivery(
      accessToken: 'tok',
      orderId: 'order-1',
      action: FoodDeliveryAction.deliver,
    );
    expect(adapter.requests.map((r) => r.data).toList(), [
      {'handoverCode': '2891'},
      {'deliveryCode': '4821'},
      null,
    ]);
  });

  test(
    'voucher validate posts the checkout body and decodes the quote',
    () async {
      final adapter = _RecordingAdapter({
        'valid': true,
        'code': 'DEALGO10',
        'discountAmount': 12000,
        'finalAmount': 108000,
        'campaign': {
          'id': 'c1',
          'name': 'Giảm 10%',
          'discountType': 'PERCENT',
          'discountValue': 10,
        },
      });
      final source = DioPromotionRemoteDataSource(dio: _dio(adapter));

      final quote = await source.validateVoucher(
        accessToken: 'tok',
        code: 'DEALGO10',
        service: VoucherService.food,
        orderAmountVnd: 120000,
        deliveryFeeVnd: 15000,
        storeId: 'store-1',
      );

      expect(adapter.requests.single.path, '/v1/promotions/validate');
      expect(adapter.requests.single.data, {
        'voucherCode': 'DEALGO10',
        'serviceType': 'FOOD',
        'orderAmount': 120000,
        'deliveryFee': 15000,
        'storeId': 'store-1',
      });
      expect(quote.valid, isTrue);
      expect(quote.discountVnd, 12000);
      expect(quote.campaignName, 'Giảm 10%');
    },
  );
}
