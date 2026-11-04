import '../../domain/params/place_food_order_params.dart';

class PlaceFoodOrderBody {
  const PlaceFoodOrderBody({
    required this.storeId,
    required this.items,
    required this.dropoffLat,
    required this.dropoffLng,
    required this.dropoffLabel,
    required this.deliveryFareVnd,
    this.deliveryOfferVnd,
    this.voucherCode,
    this.paymentMethod,
    this.note,
    this.utensils = true,
  });

  factory PlaceFoodOrderBody.fromParams(PlaceFoodOrderParams request) {
    return PlaceFoodOrderBody(
      storeId: request.storeId,
      items: [for (final item in request.items) _itemJson(item)],
      dropoffLat: request.dropoff.lat,
      dropoffLng: request.dropoff.lng,
      dropoffLabel: request.dropoff.label,
      deliveryFareVnd: request.deliveryFareVnd,
      deliveryOfferVnd: request.deliveryOfferVnd,
      voucherCode: request.voucherCode,
      paymentMethod: request.paymentMethod,
      note: request.note,
      utensils: request.utensils,
    );
  }

  final String storeId;
  final List<Map<String, Object?>> items;
  final double dropoffLat;
  final double dropoffLng;
  final String dropoffLabel;
  final int deliveryFareVnd;
  final int? deliveryOfferVnd;
  final String? voucherCode;
  final String? paymentMethod;
  final String? note;
  final bool utensils;

  Map<String, Object?> toJson() {
    final trimmedNote = _nonBlank(note);
    return {
      'storeId': storeId,
      'items': items,
      'note': ?trimmedNote,
      'utensils': utensils,
      'dropoff': {'lat': dropoffLat, 'lng': dropoffLng, 'label': dropoffLabel},
      'deliveryFareVnd': deliveryFareVnd,
      if (deliveryOfferVnd != null) 'deliveryOfferVnd': deliveryOfferVnd,
      if (voucherCode != null) 'voucherCode': voucherCode,
      if (paymentMethod != null) 'paymentMethod': paymentMethod,
    };
  }
}

Map<String, Object?> _itemJson(FoodOrderItem item) {
  final trimmedNote = _nonBlank(item.note);
  return {
    'itemId': item.itemId,
    'quantity': item.quantity,
    if (item.optionIds.isNotEmpty) 'optionIds': item.optionIds,
    'note': ?trimmedNote,
  };
}

String? _nonBlank(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
