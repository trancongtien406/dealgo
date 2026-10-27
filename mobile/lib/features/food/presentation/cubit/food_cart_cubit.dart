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
    this.optionIds = const [],
    this.imageUrl,
  });

  final String itemId;
  final String name;
  final int unitPriceVnd;
  final int quantity;
  final String? catalogItemId;

  /// DEC-PROD-033 — chosen option ids sent with the order line.
  final List<String> optionIds;
  final String? imageUrl;

  String get placeItemId => catalogItemId ?? itemId;

  int get lineTotalVnd => unitPriceVnd * quantity;

  FoodCartLine copyWith({
    String? name,
    int? unitPriceVnd,
    int? quantity,
    String? imageUrl,
  }) {
    return FoodCartLine(
      itemId: itemId,
      name: name ?? this.name,
      unitPriceVnd: unitPriceVnd ?? this.unitPriceVnd,
      quantity: quantity ?? this.quantity,
      catalogItemId: catalogItemId,
      optionIds: optionIds,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is FoodCartLine &&
        other.itemId == itemId &&
        other.name == name &&
        other.unitPriceVnd == unitPriceVnd &&
        other.quantity == quantity &&
        other.catalogItemId == catalogItemId &&
        _sameIds(other.optionIds, optionIds);
  }

  @override
  int get hashCode => Object.hash(
    itemId,
    name,
    unitPriceVnd,
    quantity,
    catalogItemId,
    Object.hashAll(optionIds),
  );
}

bool _sameIds(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
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
    this.voucherCode,
    this.voucherDiscountVnd = 0,
  });

  factory FoodCartState.initial() {
    return FoodCartState(
      storeId: null,
      storeName: null,
      lines: const [],
      deliveryFareVnd: null,
      dropoffLabel: '',
      dropoffLat: null,
      dropoffLng: null,
      idempotencyKey: createFoodIdempotencyKey(),
    );
  }

  final String? storeId;
  final String? storeName;
  final List<FoodCartLine> lines;

  /// Server quote (`POST /v1/food/quote`); null until store and drop-off
  /// are known. Placement recomputes it, so this is for display only.
  final int? deliveryFareVnd;
  final String dropoffLabel;
  final double? dropoffLat;
  final double? dropoffLng;

  bool get hasDropoff =>
      dropoffLat != null && dropoffLng != null && dropoffLabel.isNotEmpty;
  final String idempotencyKey;

  /// Code quoted by `POST /v1/promotions/validate`; sent with the order.
  final String? voucherCode;

  /// Quoted discount for display only. The server recomputes it at placement.
  final int voucherDiscountVnd;

  int get itemCount => lines.fold(0, (sum, line) => sum + line.quantity);

  int get subtotalVnd => lines.fold(0, (sum, line) => sum + line.lineTotalVnd);

  int get previewTotalVnd {
    final total = subtotalVnd + (deliveryFareVnd ?? 0) - voucherDiscountVnd;
    return total < 0 ? 0 : total;
  }

  bool get canCheckout {
    return storeId != null &&
        lines.isNotEmpty &&
        hasDropoff &&
        dropoffLabel.length <= 160 &&
        deliveryFareVnd != null;
  }

  FoodCartState copyWith({
    String? storeId,
    String? storeName,
    List<FoodCartLine>? lines,
    int? deliveryFareVnd,
    bool clearDeliveryFare = false,
    String? dropoffLabel,
    double? dropoffLat,
    double? dropoffLng,
    String? idempotencyKey,
    bool clearStore = false,
    String? voucherCode,
    int? voucherDiscountVnd,
    bool clearVoucher = false,
  }) {
    // Any change to what is being bought invalidates the quoted discount.
    final dropVoucher =
        clearVoucher || clearStore || lines != null || idempotencyKey != null;
    // The delivery quote depends on the store; another store needs a new one.
    final storeChanged =
        clearStore || (storeId != null && storeId != this.storeId);
    return FoodCartState(
      storeId: clearStore ? null : storeId ?? this.storeId,
      storeName: clearStore ? null : storeName ?? this.storeName,
      lines: lines ?? this.lines,
      deliveryFareVnd: clearDeliveryFare || storeChanged
          ? null
          : deliveryFareVnd ?? this.deliveryFareVnd,
      dropoffLabel: dropoffLabel ?? this.dropoffLabel,
      dropoffLat: dropoffLat ?? this.dropoffLat,
      dropoffLng: dropoffLng ?? this.dropoffLng,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      voucherCode: voucherCode ?? (dropVoucher ? null : this.voucherCode),
      voucherDiscountVnd:
          voucherDiscountVnd ?? (dropVoucher ? 0 : this.voucherDiscountVnd),
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
        other.idempotencyKey == idempotencyKey &&
        other.voucherCode == voucherCode &&
        other.voucherDiscountVnd == voucherDiscountVnd;
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
    voucherCode,
    voucherDiscountVnd,
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
      imageUrl: item.imageUrl,
    );
  }

  void addConfiguredItem({
    required String storeId,
    required String storeName,
    required String lineId,
    required String name,
    required int unitPriceVnd,
    String? catalogItemId,
    List<String> optionIds = const [],
    String? imageUrl,
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
      optionIds: List.unmodifiable(optionIds),
      imageUrl: imageUrl,
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

  /// Stores the server delivery quote for the current store and drop-off.
  void setDeliveryFare(int amount) {
    if (amount == state.deliveryFareVnd) {
      return;
    }
    emit(state.copyWith(deliveryFareVnd: amount));
  }

  /// New drop-off from the place picker; the old fare quote no longer applies.
  void setDropoff({
    required String label,
    required double lat,
    required double lng,
  }) {
    if (label == state.dropoffLabel &&
        lat == state.dropoffLat &&
        lng == state.dropoffLng) {
      return;
    }
    emit(
      state.copyWith(
        dropoffLabel: label,
        dropoffLat: lat,
        dropoffLng: lng,
        clearDeliveryFare: true,
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
        // Configured line: re-price from the live option groups; drop it when
        // the choice is no longer valid (the server would refuse it anyway).
        final delta = foodOptionDelta(item.optionGroups, line.optionIds);
        if (delta == null) {
          continue;
        }
        lines.add(line.copyWith(unitPriceVnd: item.priceVnd + delta));
        continue;
      }
      if (item.optionGroups.any((group) => group.required)) {
        // A plain line for a dish that now needs a choice cannot be placed.
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

  /// "Đặt lại": replaces the cart with an old order's lines, re-priced from
  /// the live [store] catalog. Unavailable dishes / stale choices are dropped.
  /// Returns how many old lines could not be restored. The server re-prices
  /// everything again at placement.
  int reorder(FoodOrderDetail order, FoodStoreDetail store) {
    final byId = {for (final item in store.items) item.id: item};
    final lines = <FoodCartLine>[];
    var dropped = 0;
    for (final old in order.lines) {
      final item = byId[old.itemId];
      if (item == null || !item.available) {
        dropped++;
        continue;
      }
      final optionIds = <String>[
        for (final option in old.options)
          if (option.optionId != null)
            for (var i = 0; i < option.quantity; i++) option.optionId!,
      ];
      if (optionIds.length !=
          old.options.fold<int>(0, (sum, o) => sum + o.quantity)) {
        dropped++;
        continue;
      }
      final delta = foodOptionDelta(item.optionGroups, optionIds);
      if (delta == null ||
          (optionIds.isEmpty && item.optionGroups.any((g) => g.required))) {
        dropped++;
        continue;
      }
      final quantity = old.quantity.clamp(1, foodLineQuantityMax);
      lines.add(
        FoodCartLine(
          itemId: foodCartLineId(item.id, optionIds),
          name: optionIds.isEmpty
              ? item.name
              : [item.name, ...old.options.map((o) => o.name)].join(' · '),
          unitPriceVnd: item.priceVnd + delta,
          quantity: quantity,
          catalogItemId: item.id,
          optionIds: List.unmodifiable(optionIds),
          imageUrl: item.imageUrl,
        ),
      );
    }
    emit(
      state.copyWith(
        storeId: store.id,
        storeName: store.name,
        lines: List.unmodifiable(lines),
        clearStore: lines.isEmpty,
        idempotencyKey: createFoodIdempotencyKey(),
      ),
    );
    return dropped;
  }

  /// Stores (or clears, with null) the voucher quote shown at checkout.
  void applyVoucher({String? code, int discountVnd = 0}) {
    if (code == null || code.isEmpty) {
      emit(state.copyWith(clearVoucher: true));
      return;
    }
    emit(state.copyWith(voucherCode: code, voucherDiscountVnd: discountVnd));
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
      final delta = foodOptionDelta(item.optionGroups, line.optionIds);
      if (delta == null || item.priceVnd + delta != line.unitPriceVnd) {
        return true;
      }
      continue;
    }
    if (item.priceVnd != line.unitPriceVnd ||
        item.optionGroups.any((group) => group.required)) {
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
