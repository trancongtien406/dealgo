import '../../../../core/network/api_envelope.dart';
import '../../../../core/network/api_exception.dart';
import '../../domain/entities/food_models.dart';

class FoodMenuItemModel {
  const FoodMenuItemModel({
    required this.id,
    required this.name,
    required this.priceVnd,
    required this.available,
  });

  final String id;
  final String name;
  final int priceVnd;
  final bool available;

  factory FoodMenuItemModel.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final name = json['name'];
    final priceVnd = _asInt(json['priceVnd']);
    final available = json['available'];
    if (id is! String ||
        id.isEmpty ||
        name is! String ||
        name.isEmpty ||
        priceVnd == null ||
        available is! bool) {
      throw const ApiException(
        statusCode: 200,
        message: 'Phản hồi không hợp lệ',
        errorCode: 'INVALID_RESPONSE',
      );
    }
    return FoodMenuItemModel(
      id: id,
      name: name,
      priceVnd: priceVnd,
      available: available,
    );
  }

  factory FoodMenuItemModel.fromEntity(FoodMenuItem item) {
    return FoodMenuItemModel(
      id: item.id,
      name: item.name,
      priceVnd: item.priceVnd,
      available: item.available,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'name': name,
      'priceVnd': priceVnd,
      'available': available,
    };
  }

  FoodMenuItem toEntity() {
    return FoodMenuItem(
      id: id,
      name: name,
      priceVnd: priceVnd,
      available: available,
    );
  }
}

class FoodStoreSummaryModel {
  const FoodStoreSummaryModel({required this.id, required this.name});

  final String id;
  final String name;

  factory FoodStoreSummaryModel.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final name = json['name'];
    if (id is! String || id.isEmpty || name is! String || name.isEmpty) {
      throw const ApiException(
        statusCode: 200,
        message: 'Phản hồi không hợp lệ',
        errorCode: 'INVALID_RESPONSE',
      );
    }
    return FoodStoreSummaryModel(id: id, name: name);
  }

  factory FoodStoreSummaryModel.fromEntity(FoodStoreSummary store) {
    return FoodStoreSummaryModel(id: store.id, name: store.name);
  }

  Map<String, Object?> toJson() => {'id': id, 'name': name};

  FoodStoreSummary toEntity() => FoodStoreSummary(id: id, name: name);
}

class FoodStoreDetailModel {
  const FoodStoreDetailModel({
    required this.id,
    required this.name,
    required this.items,
  });

  final String id;
  final String name;
  final List<FoodMenuItemModel> items;

  factory FoodStoreDetailModel.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final name = json['name'];
    final rawItems = json['items'];
    if (id is! String ||
        id.isEmpty ||
        name is! String ||
        name.isEmpty ||
        rawItems is! List) {
      throw const ApiException(
        statusCode: 200,
        message: 'Phản hồi không hợp lệ',
        errorCode: 'INVALID_RESPONSE',
      );
    }
    final items = <FoodMenuItemModel>[];
    for (final raw in rawItems) {
      final map = asJsonMap(raw);
      if (map == null) {
        continue;
      }
      try {
        items.add(FoodMenuItemModel.fromJson(map));
      } on ApiException {
        continue;
      }
    }
    return FoodStoreDetailModel(
      id: id,
      name: name,
      items: List.unmodifiable(items),
    );
  }

  factory FoodStoreDetailModel.fromEntity(FoodStoreDetail store) {
    return FoodStoreDetailModel(
      id: store.id,
      name: store.name,
      items: [
        for (final item in store.items) FoodMenuItemModel.fromEntity(item),
      ],
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'name': name,
      'items': [for (final item in items) item.toJson()],
    };
  }

  FoodStoreDetail toEntity() {
    return FoodStoreDetail(
      id: id,
      name: name,
      items: List.unmodifiable([for (final item in items) item.toEntity()]),
    );
  }
}

class PlacedFoodOrderModel {
  const PlacedFoodOrderModel({
    required this.id,
    required this.status,
    required this.deliveryFareVnd,
    required this.subtotalVnd,
    required this.totalVnd,
    required this.lines,
  });

  final String id;
  final String status;
  final int deliveryFareVnd;
  final int subtotalVnd;
  final int totalVnd;
  final List<FoodOrderLine> lines;

  factory PlacedFoodOrderModel.fromEntity(PlacedFoodOrder order) {
    return PlacedFoodOrderModel(
      id: order.id,
      status: order.status,
      deliveryFareVnd: order.deliveryFareVnd,
      subtotalVnd: order.subtotalVnd,
      totalVnd: order.totalVnd,
      lines: order.lines,
    );
  }

  PlacedFoodOrder toEntity() {
    return PlacedFoodOrder(
      id: id,
      status: status,
      deliveryFareVnd: deliveryFareVnd,
      subtotalVnd: subtotalVnd,
      totalVnd: totalVnd,
      lines: lines,
    );
  }
}

int? _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num && value == value.roundToDouble()) {
    return value.toInt();
  }
  return null;
}
