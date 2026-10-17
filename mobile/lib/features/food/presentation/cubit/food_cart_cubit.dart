import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/food_models.dart';
import '../../domain/entities/food_money.dart';

class FoodCartLine {
  const FoodCartLine({
    required this.itemId,
    required this.name,
    required this.unitPriceVnd,
    required this.quantity,
    this.catalogItemId,
  });

  final String itemId;
  final String name;
  final int unitPriceVnd;
  final int quantity;
  final String? catalogItemId;

  String get placeItemId => catalogItemId ?? itemId;

  int get lineTotalVnd => unitPriceVnd * quantity;

  FoodCartLine copyWith({String? name, int? unitPriceVnd, int? quantity}) {
    return FoodCartLine(
      itemId: itemId,
      name: name ?? this.name,
      unitPriceVnd: unitPriceVnd ?? this.unitPriceVnd,
      quantity: quantity ?? this.quantity,
      catalogItemId: catalogItemId,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is FoodCartLine &&
        other.itemId == itemId &&
        other.name == name &&
        other.unitPriceVnd == unitPriceVnd &&
        other.quantity == quantity &&
        other.catalogItemId == catalogItemId;
  }

  @override
  int get hashCode =>
      Object.hash(itemId, name, unitPriceVnd, quantity, catalogItemId);
}

class FoodCartState {
  const FoodCartState({
    required this.storeId,
    required this.storeName,
    required this.lines,
    required this.deliveryFareVnd,
    required this.dropoffLabel,
    required this.dropoffLat,
    required this.dropoffLng,
    required this.idempotencyKey,
  });

  factory FoodCartState.initial() {
    return FoodCartState(
      storeId: null,
      storeName: null,
      lines: const [],
      deliveryFareVnd: foodDefaultDeliveryFareVnd,
      dropoffLabel: foodDefaultDropoffLabel,
      dropoffLat: foodDefaultDropoffLat,
      dropoffLng: foodDefaultDropoffLng,
      idempotencyKey: createFoodIdempotencyKey(),
    );
  }

  final String? storeId;
  final String? storeName;
  final List<FoodCartLine> lines;
  final int deliveryFareVnd;
  final String dropoffLabel;
  final double dropoffLat;
  final double dropoffLng;
  final String idempotencyKey;

  int get itemCount => lines.fold(0, (sum, line) => sum + line.quantity);

  int get subtotalVnd => lines.fold(0, (sum, line) => sum + line.lineTotalVnd);

  int get previewTotalVnd => subtotalVnd + deliveryFareVnd;

  bool get canCheckout {
    final label = dropoffLabel.trim();
    return storeId != null &&
        lines.isNotEmpty &&
        label.isNotEmpty &&
        label.length <= 160 &&
        deliveryFareInRange(deliveryFareVnd);
  }

  FoodCartState copyWith({
    String? storeId,
    String? storeName,
    List<FoodCartLine>? lines,
    int? deliveryFareVnd,
    String? dropoffLabel,
    String? idempotencyKey,
    bool clearStore = false,
  }) {
    return FoodCartState(
      storeId: clearStore ? null : storeId ?? this.storeId,
      storeName: clearStore ? null : storeName ?? this.storeName,
      lines: lines ?? this.lines,
      deliveryFareVnd: deliveryFareVnd ?? this.deliveryFareVnd,
      dropoffLabel: dropoffLabel ?? this.dropoffLabel,
      dropoffLat: dropoffLat,
      dropoffLng: dropoffLng,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is FoodCartState &&
        other.storeId == storeId &&
        other.storeName == storeName &&
        _sameLines(other.lines, lines) &&
        other.deliveryFareVnd == deliveryFareVnd &&
        other.dropoffLabel == dropoffLabel &&
        other.dropoffLat == dropoffLat &&
        other.dropoffLng == dropoffLng &&
        other.idempotencyKey == idempotencyKey;
  }

  @override
  int get hashCode => Object.hash(
    storeId,
    storeName,
    Object.hashAll(lines),
    deliveryFareVnd,
    dropoffLabel,
    dropoffLat,
    dropoffLng,
    idempotencyKey,
  );
}

bool _sameLines(List<FoodCartLine> left, List<FoodCartLine> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}

class FoodCartCubit extends Cubit<FoodCartState> {
  FoodCartCubit() : super(FoodCartState.initial());

  void addItem({
    required String storeId,
    required String storeName,
    required FoodMenuItem item,
  }) {
    if (!item.available || item.priceVnd < 0 || storeId.isEmpty) {
      return;
    }
    addConfiguredItem(
      storeId: storeId,
      storeName: storeName,
      lineId: item.id,
      name: item.name,
      unitPriceVnd: item.priceVnd,
      catalogItemId: item.id,
    );
  }

  void addConfiguredItem({
    required String storeId,
    required String storeName,
    required String lineId,
    required String name,
    required int unitPriceVnd,
    String? catalogItemId,
  }) {
    if (unitPriceVnd < 0 || storeId.isEmpty || lineId.isEmpty) {
      return;
    }
    final nextLine = FoodCartLine(
      itemId: lineId,
      name: name,
      unitPriceVnd: unitPriceVnd,
      quantity: 1,
      catalogItemId: catalogItemId,
    );
    if (state.storeId != null && state.storeId != storeId) {
      emit(
        state.copyWith(
          storeId: storeId,
          storeName: storeName,
          lines: [nextLine],
          idempotencyKey: createFoodIdempotencyKey(),
        ),
      );
      return;
    }
    final lines = [...state.lines];
    final index = lines.indexWhere((line) => line.itemId == lineId);
    if (index >= 0) {
      final current = lines[index];
      if (current.quantity >= foodLineQuantityMax) {
        return;
      }
      lines[index] = current.copyWith(quantity: current.quantity + 1);
    } else {
      lines.add(nextLine);
    }
    emit(
      state.copyWith(
        storeId: storeId,
        storeName: storeName,
        lines: List.unmodifiable(lines),
        idempotencyKey: createFoodIdempotencyKey(),
      ),
    );
  }

  void setQuantity(String itemId, int quantity) {
    if (quantity > foodLineQuantityMax) {
      return;
    }
    final lines = [
      for (final line in state.lines)
        if (line.itemId != itemId)
          line
        else if (quantity > 0)
          line.copyWith(quantity: quantity),
    ];
    emit(
      state.copyWith(
        lines: List.unmodifiable(lines),
        clearStore: lines.isEmpty,
        idempotencyKey: createFoodIdempotencyKey(),
      ),
    );
  }

  void adjustCatalogQuantity(String catalogItemId, int delta) {
    if (delta == 0) {
      return;
    }
    final lines = [...state.lines];
    if (delta > 0) {
      final index = lines.indexWhere(
        (line) => line.placeItemId == catalogItemId,
      );
      if (index < 0) {
        return;
      }
      final current = lines[index];
      if (current.quantity >= foodLineQuantityMax) {
        return;
      }
      lines[index] = current.copyWith(quantity: current.quantity + 1);
    } else {
      final index = lines.lastIndexWhere(
        (line) => line.placeItemId == catalogItemId,
      );
      if (index < 0) {
        return;
      }
      final current = lines[index];
      if (current.quantity <= 1) {
        lines.removeAt(index);
      } else {
        lines[index] = current.copyWith(quantity: current.quantity - 1);
      }
    }
    emit(
      state.copyWith(
        lines: List.unmodifiable(lines),
        clearStore: lines.isEmpty,
        idempotencyKey: createFoodIdempotencyKey(),
      ),
    );
  }

  void setDeliveryFare(int amount) {
    final next = clampDeliveryFare(amount);
    if (next == state.deliveryFareVnd) {
      return;
    }
    emit(
      state.copyWith(
        deliveryFareVnd: next,
        idempotencyKey: createFoodIdempotencyKey(),
      ),
    );
  }

  void setDropoffLabel(String label) {
    if (label == state.dropoffLabel) {
      return;
    }
    emit(
      state.copyWith(
        dropoffLabel: label,
        idempotencyKey: createFoodIdempotencyKey(),
      ),
    );
  }

  void applyCatalog(FoodStoreDetail store) {
    if (state.storeId != store.id) {
      return;
    }
    final byId = {for (final item in store.items) item.id: item};
    final lines = <FoodCartLine>[];
    for (final line in state.lines) {
      final item = byId[line.placeItemId];
      if (item == null || !item.available) {
        continue;
      }
      if (line.catalogItemId != null && line.catalogItemId != line.itemId) {
        lines.add(line);
        continue;
      }
      lines.add(line.copyWith(name: item.name, unitPriceVnd: item.priceVnd));
    }
    emit(
      state.copyWith(
        storeName: store.name,
        lines: List.unmodifiable(lines),
        clearStore: lines.isEmpty,
        idempotencyKey: createFoodIdempotencyKey(),
      ),
    );
  }

  void rotateIdempotencyKey() {
    emit(state.copyWith(idempotencyKey: createFoodIdempotencyKey()));
  }
}

bool foodCatalogPriceDrift(FoodStoreDetail store, FoodCartState cart) {
  if (cart.storeId != store.id) {
    return true;
  }
  final byId = {for (final item in store.items) item.id: item};
  for (final line in cart.lines) {
    final item = byId[line.placeItemId];
    if (item == null || !item.available) {
      return true;
    }
    if (line.catalogItemId != null && line.catalogItemId != line.itemId) {
      continue;
    }
    if (item.priceVnd != line.unitPriceVnd) {
      return true;
    }
  }
  return false;
}

String createFoodIdempotencyKey() {
  final time = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
  final salt = identityHashCode(Object()).toUnsigned(32).toRadixString(16);
  return 'food-$time-$salt';
}
