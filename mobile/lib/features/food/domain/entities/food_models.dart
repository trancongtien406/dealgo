class FoodStoreSummary {
  const FoodStoreSummary({required this.id, required this.name});

  final String id;
  final String name;
}

class FoodMenuItem {
  const FoodMenuItem({
    required this.id,
    required this.name,
    required this.priceVnd,
    required this.available,
  });

  final String id;
  final String name;
  final int priceVnd;
  final bool available;
}

class FoodStoreDetail {
  const FoodStoreDetail({
    required this.id,
    required this.name,
    required this.items,
  });

  final String id;
  final String name;
  final List<FoodMenuItem> items;
}

class FoodDropoff {
  const FoodDropoff({
    required this.lat,
    required this.lng,
    required this.label,
  });

  final double lat;
  final double lng;
  final String label;
}

class FoodOrderLine {
  const FoodOrderLine({
    required this.itemId,
    required this.name,
    required this.unitPriceVnd,
    required this.quantity,
  });

  final String itemId;
  final String name;
  final int unitPriceVnd;
  final int quantity;

  int get lineTotalVnd => unitPriceVnd * quantity;
}

class ReadyFoodJob {
  const ReadyFoodJob({
    required this.id,
    required this.storeId,
    required this.deliveryFareVnd,
    required this.subtotalVnd,
    required this.totalVnd,
    required this.dropoff,
    required this.lineCount,
  });

  final String id;
  final String storeId;
  final int deliveryFareVnd;
  final int subtotalVnd;
  final int totalVnd;
  final FoodDropoff dropoff;
  final int lineCount;
}

class ClaimedFoodDelivery {
  const ClaimedFoodDelivery({required this.id, required this.status});

  final String id;
  final String status;
}

class MerchantQueueOrder {
  const MerchantQueueOrder({
    required this.id,
    required this.storeId,
    required this.status,
    required this.deliveryFareVnd,
    required this.subtotalVnd,
    required this.totalVnd,
    required this.dropoff,
    required this.lineCount,
    required this.createdAt,
  });

  final String id;
  final String storeId;
  final String status;
  final int deliveryFareVnd;
  final int subtotalVnd;
  final int totalVnd;
  final FoodDropoff dropoff;
  final int lineCount;
  final String createdAt;

  MerchantQueueOrder apply(MerchantOrderUpdate update) {
    return MerchantQueueOrder(
      id: update.id,
      storeId: update.storeId ?? storeId,
      status: update.status,
      deliveryFareVnd: update.deliveryFareVnd ?? deliveryFareVnd,
      subtotalVnd: update.subtotalVnd ?? subtotalVnd,
      totalVnd: update.totalVnd ?? totalVnd,
      dropoff: update.dropoff ?? dropoff,
      lineCount: update.lineCount ?? lineCount,
      createdAt: update.createdAt ?? createdAt,
    );
  }
}

class MerchantOrderUpdate {
  const MerchantOrderUpdate({
    required this.id,
    required this.status,
    this.storeId,
    this.deliveryFareVnd,
    this.subtotalVnd,
    this.totalVnd,
    this.dropoff,
    this.lineCount,
    this.createdAt,
  });

  final String id;
  final String status;
  final String? storeId;
  final int? deliveryFareVnd;
  final int? subtotalVnd;
  final int? totalVnd;
  final FoodDropoff? dropoff;
  final int? lineCount;
  final String? createdAt;
}

enum FoodTrackingStage { preparing, onTheWay, cancelled, unknown }

FoodTrackingStage foodTrackingStage(String status) {
  return switch (status) {
    'PLACED' || 'PREPARING' => FoodTrackingStage.preparing,
    'READY' || 'ASSIGNED' => FoodTrackingStage.onTheWay,
    'CANCELLED' => FoodTrackingStage.cancelled,
    _ => FoodTrackingStage.unknown,
  };
}

String foodTrackingTitle(FoodTrackingStage stage) {
  return switch (stage) {
    FoodTrackingStage.preparing => 'Đang chuẩn bị món',
    FoodTrackingStage.onTheWay => 'Đơn đang được giao',
    FoodTrackingStage.cancelled => 'Đơn đã hủy',
    FoodTrackingStage.unknown => 'Chưa rõ trạng thái đơn',
  };
}

class FoodOrderDetail {
  const FoodOrderDetail({
    required this.id,
    required this.status,
    required this.subtotalVnd,
    required this.deliveryFareVnd,
    required this.totalVnd,
    required this.dropoff,
    required this.lines,
  });

  final String id;
  final String status;
  final int subtotalVnd;
  final int deliveryFareVnd;
  final int totalVnd;
  final FoodDropoff dropoff;
  final List<FoodOrderLine> lines;

  FoodTrackingStage get stage => foodTrackingStage(status);
}

class PlacedFoodOrder {
  const PlacedFoodOrder({
    required this.id,
    required this.status,
    required this.subtotalVnd,
    required this.deliveryFareVnd,
    required this.totalVnd,
    required this.lines,
  });

  final String id;
  final String status;
  final int subtotalVnd;
  final int deliveryFareVnd;
  final int totalVnd;
  final List<FoodOrderLine> lines;
}
