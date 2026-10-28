import '../../domain/params/place_food_order_params.dart';

class PlaceFoodOrderBody {
  const PlaceFoodOrderBody({
    required this.storeId,
    required this.items,
    required this.dropoffLat,
    required this.dropoffLng,
    required this.dropoffLabel,
    required this.deliveryFareVnd,
    this.voucherCode,
    this.paymentMethod,
  });

  factory PlaceFoodOrderBody.fromParams(PlaceFoodOrderParams request) {
    return PlaceFoodOrderBody(
      storeId: request.storeId,
      items: [
        for (final item in request.items)
          {
            'itemId': item.itemId,
            'quantity': item.quantity,
            if (item.optionIds.isNotEmpty) 'optionIds': item.optionIds,
          },
      ],
      dropoffLat: request.dropoff.lat,
      dropoffLng: request.dropoff.lng,
      dropoffLabel: request.dropoff.label,
      deliveryFareVnd: request.deliveryFareVnd,
      voucherCode: request.voucherCode,
      paymentMethod: request.paymentMethod,
    );
  }

  final String storeId;
  final List<Map<String, Object?>> items;
  final double dropoffLat;
  final double dropoffLng;
  final String dropoffLabel;
  final int deliveryFareVnd;
  final String? voucherCode;
  final String? paymentMethod;

  Map<String, Object?> toJson() {
    return {
      'storeId': storeId,
      'items': items,
      'dropoff': {'lat': dropoffLat, 'lng': dropoffLng, 'label': dropoffLabel},
      'deliveryFareVnd': deliveryFareVnd,
      if (voucherCode != null) 'voucherCode': voucherCode,
      if (paymentMethod != null) 'paymentMethod': paymentMethod,
    };
  }
}
