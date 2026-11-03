import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/food_models.dart';
import '../../domain/entities/food_money.dart';
import '../../../pricing/domain/pricing.dart';

class FoodCartLine {
  const FoodCartLine({
    required this.itemId,
    required this.name,
    required this.unitPriceVnd,
    required this.quantity,
    this.catalogItemId,
    this.optionIds = const [],
    this.imageUrl,
    this.note,
  });

  final String itemId;
  final String name;
  final int unitPriceVnd;
  final int quantity;
  final String? catalogItemId;

  /// DEC-PROD-033 — chosen option ids sent with the order line.
  final List<String> optionIds;
  final String? imageUrl;

  /// Customer note for this line; null = none. Not part of the line identity.
  final String? note;

  String get placeItemId => catalogItemId ?? itemId;

  int get lineTotalVnd => unitPriceVnd * quantity;

  FoodCartLine copyWith({
    String? name,
    int? unitPriceVnd,
    int? quantity,
    String? imageUrl,
    String? note,
    bool clearNote = false,
  }) {
    return FoodCartLine(
      itemId: itemId,
      name: name ?? this.name,
      unitPriceVnd: unitPriceVnd ?? this.unitPriceVnd,
      quantity: quantity ?? this.quantity,
      catalogItemId: catalogItemId,
      optionIds: optionIds,
      imageUrl: imageUrl ?? this.imageUrl,
      note: clearNote ? null : note ?? this.note,
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
    this.deliveryQuote,
    this.deliveryOfferVnd,
    this.minOrderVnd = 0,
    this.prepMinutes,
    this.storeDistanceKm,
    this.note = '',
    this.utensils = true,
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

  /// Full quote with the offer bounds and step (null on old servers / before
  /// the quote). [deliveryFareVnd] is its suggestion.
  final FoodDeliveryQuote? deliveryQuote;

  /// The customer's delivery-fee offer; null = take the suggestion. Drivers
  /// accept it or counter; the agreed fee is fixed when one is assigned.
  final int? deliveryOfferVnd;

  /// What is sent and shown: the offer, else the suggestion.
  int? get offeredDeliveryFareVnd => deliveryOfferVnd ?? deliveryFareVnd;
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

  /// The store's minimum subtotal (0 = none); the server enforces it too.
  final int minOrderVnd;

  /// Store prep estimate and the buyer's straight-line distance to it, both
  /// display-only inputs for the arrival estimate.
  final int? prepMinutes;
  final double? storeDistanceKm;

  /// Customer note to the store and driver; blank = none.
  final String note;

  /// Cutlery requested for this order; sent with the order.
  final bool utensils;

  /// Same estimate as the store list: prep + 3 min per km.
  int? get etaMinutes {
    final prep = prepMinutes;
    if (prep == null) return null;
    final km = storeDistanceKm;
    return km == null ? prep : prep + (km * 3).round();
  }

  /// How much more the buyer must add to reach [minOrderVnd]; 0 when met.
  int get minOrderShortVnd {
    final short = minOrderVnd - subtotalVnd;
    return short > 0 ? short : 0;
  }

  int get itemCount => lines.fold(0, (sum, line) => sum + line.quantity);

  int get subtotalVnd => lines.fold(0, (sum, line) => sum + line.lineTotalVnd);

  int get previewTotalVnd {
    final total =
        subtotalVnd + (offeredDeliveryFareVnd ?? 0) - voucherDiscountVnd;
    return total < 0 ? 0 : total;
  }

  bool get canCheckout {
    return storeId != null &&
        lines.isNotEmpty &&
        hasDropoff &&
        minOrderShortVnd == 0 &&
        dropoffLabel.length <= 160 &&
        deliveryFareVnd != null;
  }

  FoodCartState copyWith({
    String? storeId,
    String? storeName,
    List<FoodCartLine>? lines,
    int? deliveryFareVnd,
    bool clearDeliveryFare = false,
    FoodDeliveryQuote? deliveryQuote,
    int? deliveryOfferVnd,
    String? dropoffLabel,
    double? dropoffLat,
    double? dropoffLng,
    String? idempotencyKey,
    bool clearStore = false,
    String? voucherCode,
    int? voucherDiscountVnd,
    bool clearVoucher = false,
    int? minOrderVnd,
    int? prepMinutes,
    double? storeDistanceKm,
    String? note,
    bool? utensils,
  }) {
    // Any change to what is being bought invalidates the quoted discount.
    // A note-only edit leaves the lines equal, so the voucher can stay.
    final linesChanged = lines != null && !_sameLines(this.lines, lines);
    final dropVoucher =
        clearVoucher || clearStore || linesChanged || idempotencyKey != null;
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
      deliveryQuote: clearDeliveryFare || storeChanged
          ? null
          : deliveryQuote ??
                (deliveryFareVnd != null ? null : this.deliveryQuote),
      // A new quote (or store/address) resets the offer to the suggestion.
      deliveryOfferVnd: clearDeliveryFare || storeChanged
          ? null
          : deliveryOfferVnd ??
                (deliveryFareVnd != null ? null : this.deliveryOfferVnd),
      dropoffLabel: dropoffLabel ?? this.dropoffLabel,
      dropoffLat: dropoffLat ?? this.dropoffLat,
      dropoffLng: dropoffLng ?? this.dropoffLng,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      voucherCode: voucherCode ?? (dropVoucher ? null : this.voucherCode),
      voucherDiscountVnd:
          voucherDiscountVnd ?? (dropVoucher ? 0 : this.voucherDiscountVnd),
      minOrderVnd: clearStore ? 0 : minOrderVnd ?? this.minOrderVnd,
      prepMinutes: clearStore
          ? null
          : prepMinutes ?? (storeChanged ? null : this.prepMinutes),
      storeDistanceKm: clearStore
          ? null
          : storeDistanceKm ?? (storeChanged ? null : this.storeDistanceKm),
      note: clearStore || storeChanged ? '' : note ?? this.note,
      utensils: clearStore || storeChanged ? true : utensils ?? this.utensils,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is FoodCartState &&
        other.storeId == storeId &&
        other.storeName == storeName &&
        _sameLines(other.lines, lines) &&
        other.deliveryFareVnd == deliveryFareVnd &&
        other.deliveryQuote == deliveryQuote &&
        other.deliveryOfferVnd == deliveryOfferVnd &&
        other.dropoffLabel == dropoffLabel &&
        other.dropoffLat == dropoffLat &&
        other.dropoffLng == dropoffLng &&
        other.idempotencyKey == idempotencyKey &&
        other.voucherCode == voucherCode &&
        other.voucherDiscountVnd == voucherDiscountVnd &&
        other.minOrderVnd == minOrderVnd &&
        other.prepMinutes == prepMinutes &&
        other.storeDistanceKm == storeDistanceKm &&
        other.note == note &&
        other.utensils == utensils &&
        _sameLineNotes(other.lines, lines);
  }

  @override
  int get hashCode => Object.hash(
    storeId,
    storeName,
    Object.hashAll(lines),
    Object.hash(deliveryFareVnd, deliveryQuote, deliveryOfferVnd),
    dropoffLabel,
    dropoffLat,
    dropoffLng,
    idempotencyKey,
    voucherCode,
    voucherDiscountVnd,
    minOrderVnd,
    prepMinutes,
    storeDistanceKm,
    note,
    utensils,
    Object.hashAll(lines.map((line) => line.note)),
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

bool _sameLineNotes(List<FoodCartLine> left, List<FoodCartLine> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index++) {
    if (left[index].note != right[index].note) {
      return false;
    }
  }
  return true;
}

class FoodCartCubit extends Cubit<FoodCartState> {
  FoodCartCubit() : super(FoodCartState.initial());

  /// Last known distance per store, so the first dish added picks it up.
  final Map<String, double> _distanceKm = {};

  void addItem({
    required String storeId,
    required String storeName,
    required FoodMenuItem item,
    int minOrderVnd = 0,
    int? prepMinutes,
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
      minOrderVnd: minOrderVnd,
      prepMinutes: prepMinutes,
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
    int minOrderVnd = 0,
    int? prepMinutes,
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
          minOrderVnd: minOrderVnd,
          prepMinutes: prepMinutes,
          storeDistanceKm: _distanceKm[storeId],
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
        minOrderVnd: minOrderVnd,
        prepMinutes: prepMinutes,
        storeDistanceKm: _distanceKm[storeId],
      ),
    );
  }

  /// Distance from the buyer to the cart's store, for the arrival estimate.
  void setStoreDistance(String storeId, double km) {
    _distanceKm[storeId] = km;
    if (state.storeId != storeId || state.storeDistanceKm == km) {
      return;
    }
    emit(state.copyWith(storeDistanceKm: km));
  }

  /// Order-level note; blank (or whitespace) clears it.
  void setNote(String note) {
    final text = note.trim();
    if (text == state.note) {
      return;
    }
    emit(state.copyWith(note: text));
  }

  void setUtensils(bool utensils) {
    if (utensils == state.utensils) {
      return;
    }
    emit(state.copyWith(utensils: utensils));
  }

  /// Sets the note of the line whose key is [itemId] (same identity as
  /// [setQuantity]); blank or null clears it.
  void setLineNote(String itemId, String? note) {
    final index = state.lines.indexWhere((line) => line.itemId == itemId);
    if (index < 0) {
      return;
    }
    final text = note?.trim();
    final next = text == null || text.isEmpty ? null : text;
    final lines = [...state.lines];
    final current = lines[index];
    if (current.note == next) {
      return;
    }
    lines[index] = next == null
        ? current.copyWith(clearNote: true)
        : current.copyWith(note: next);
    emit(state.copyWith(lines: List.unmodifiable(lines)));
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

  /// Stores the full quote; the offer resets to the suggestion.
  void setDeliveryQuote(FoodDeliveryQuote quote) {
    if (quote == state.deliveryQuote &&
        quote.suggestedVnd == state.deliveryFareVnd) {
      return;
    }
    emit(
      state.copyWith(deliveryFareVnd: quote.suggestedVnd, deliveryQuote: quote),
    );
  }

  /// Checkout stepper: moves the offer by [steps] × server fareStep, kept in
  /// the quote bounds. Returns false when it cannot move further.
  bool stepDeliveryOffer(int steps) {
    final quote = state.deliveryQuote;
    final current = state.offeredDeliveryFareVnd;
    if (quote == null || current == null || !quote.negotiable) return false;
    final step = quote.fareStepVnd;
    // Snap to the step grid first so odd suggestions (e.g. 15.400đ) round.
    final base = steps > 0
        ? (current ~/ step) * step
        : ((current + step - 1) ~/ step) * step;
    final next = quote.clamp(base + steps * step);
    if (next == current) return false;
    emit(state.copyWith(deliveryOfferVnd: next));
    return true;
  }

  /// Back to the suggested fee.
  void resetDeliveryOffer() {
    if (state.deliveryOfferVnd == null) return;
    emit(
      FoodCartState(
        storeId: state.storeId,
        storeName: state.storeName,
        lines: state.lines,
        deliveryFareVnd: state.deliveryFareVnd,
        deliveryQuote: state.deliveryQuote,
        dropoffLabel: state.dropoffLabel,
        dropoffLat: state.dropoffLat,
        dropoffLng: state.dropoffLng,
        idempotencyKey: state.idempotencyKey,
        voucherCode: state.voucherCode,
        voucherDiscountVnd: state.voucherDiscountVnd,
        minOrderVnd: state.minOrderVnd,
        prepMinutes: state.prepMinutes,
        storeDistanceKm: state.storeDistanceKm,
        note: state.note,
        utensils: state.utensils,
      ),
    );
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
        minOrderVnd: store.minOrderVnd,
        prepMinutes: store.estimatedPrepMinutes,
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
        minOrderVnd: store.minOrderVnd,
        prepMinutes: store.estimatedPrepMinutes,
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
    // Only the checkout calls this, right after the order was accepted.
    if (!_placed.isClosed) _placed.add(null);
  }

  /// QA C1 — the order was accepted: empty the cart so it cannot be placed
  /// twice. The drop-off is kept for the next order; a fresh key is minted.
  void clearAfterOrder() {
    final prev = state;
    emit(
      FoodCartState(
        storeId: null,
        storeName: null,
        lines: const [],
        deliveryFareVnd: null,
        dropoffLabel: prev.dropoffLabel,
        dropoffLat: prev.dropoffLat,
        dropoffLng: prev.dropoffLng,
        idempotencyKey: createFoodIdempotencyKey(),
      ),
    );
  }

  final _placed = StreamController<void>.broadcast(sync: true);

  /// T85 — fires when an order from this cart was accepted (key rotated).
  Stream<void> get orderPlaced => _placed.stream;

  @override
  Future<void> close() async {
    await _placed.close();
    return super.close();
  }

  /// T85 — puts back a cart saved before the app was killed. Ignored once the
  /// buyer has started a new cart. Keeps the saved idempotency key so a
  /// re-sent order is deduplicated by the server.
  void restoreDraft(FoodCartState snapshot) {
    if (state.lines.isNotEmpty || snapshot.lines.isEmpty) {
      return;
    }
    emit(snapshot);
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
