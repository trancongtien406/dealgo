import 'food_options.dart';

export 'food_options.dart';

/// Why a store refuses new orders right now (DEC-PROD-026/027); null = open.
enum StoreClosedReason {
  paused,
  closed;

  static StoreClosedReason? fromWire(Object? raw) => switch (raw) {
    'PAUSED' => StoreClosedReason.paused,
    'CLOSED' => StoreClosedReason.closed,
    _ => null,
  };
}

/// M023 one weekday's opening range, Vietnam local "HH:MM" (closes may be 24:00).
class StoreDayHours {
  const StoreDayHours({
    required this.weekday,
    required this.opensAt,
    required this.closesAt,
  });

  /// 1 = Monday … 7 = Sunday.
  final int weekday;
  final String opensAt;
  final String closesAt;

  /// Closes earlier than it opens → runs into the next morning (DEC-PROD-029).
  bool get overnight => closesAt.compareTo(opensAt) < 0;

  Map<String, Object?> toJson() => {
    'weekday': weekday,
    'opensAt': opensAt,
    'closesAt': closesAt,
  };
}

class StoreClosureDay {
  const StoreClosureDay({required this.date, this.note});

  /// Vietnam calendar date `YYYY-MM-DD`.
  final String date;
  final String? note;

  Map<String, Object?> toJson() => {'date': date, 'note': ?note};
}

/// M023 schedule (DEC-PROD-027). `hoursConfigured == false` → open around the clock.
class StoreSchedule {
  const StoreSchedule({
    this.hoursConfigured = false,
    this.lastOrderMinutes = 0,
    this.weekly = const [],
    this.closures = const [],
  });

  final bool hoursConfigured;
  final int lastOrderMinutes;
  final List<StoreDayHours> weekly;
  final List<StoreClosureDay> closures;

  StoreDayHours? day(int weekday) {
    for (final row in weekly) {
      if (row.weekday == weekday) return row;
    }
    return null;
  }
}

class FoodStoreSummary {
  const FoodStoreSummary({
    required this.id,
    required this.name,
    this.category,
    this.distanceKm,
    this.closedReason,
    this.imageUrl,
  });

  final String id;
  final String name;

  /// Non-null when the store is paused or outside its hours; lists sort these last.
  final StoreClosedReason? closedReason;

  /// Catalog category code from the backend (e.g. `pho`, `cafe`); may be null.
  final String? category;

  /// Straight-line distance from the customer, only when the app sent a GPS fix.
  final double? distanceKm;

  /// Cover thumb from first menu item with a photo (DEC-PROD-041).
  final String? imageUrl;
}

class FoodMenuItem {
  const FoodMenuItem({
    required this.id,
    required this.name,
    required this.priceVnd,
    required this.available,
    this.description,
    this.prepMinutes,
    this.imageUrl,
    this.imageUrls = const [],
    this.soldCount = 0,
    this.menuCategoryId,
    this.optionGroups = const [],
  });

  final String id;
  final String name;
  final int priceVnd;
  final bool available;

  /// M027 (DEC-PROD-039).
  final String? description;
  final int? prepMinutes;
  final String? imageUrl;
  final List<String> imageUrls;
  final int soldCount;
  final String? menuCategoryId;

  /// DEC-PROD-033 — option groups in display order ([] = no choices).
  final List<FoodOptionGroup> optionGroups;

  FoodMenuItem copyWith({
    String? name,
    int? priceVnd,
    bool? available,
    String? description,
    int? prepMinutes,
    String? imageUrl,
    List<String>? imageUrls,
    int? soldCount,
    String? menuCategoryId,
    List<FoodOptionGroup>? optionGroups,
    bool clearDescription = false,
    bool clearPrepMinutes = false,
    bool clearImageUrl = false,
    bool clearMenuCategoryId = false,
  }) {
    return FoodMenuItem(
      id: id,
      name: name ?? this.name,
      priceVnd: priceVnd ?? this.priceVnd,
      available: available ?? this.available,
      description: clearDescription ? null : (description ?? this.description),
      prepMinutes: clearPrepMinutes ? null : (prepMinutes ?? this.prepMinutes),
      imageUrl: clearImageUrl ? null : (imageUrl ?? this.imageUrl),
      imageUrls: imageUrls ?? this.imageUrls,
      soldCount: soldCount ?? this.soldCount,
      menuCategoryId:
          clearMenuCategoryId ? null : (menuCategoryId ?? this.menuCategoryId),
      optionGroups: optionGroups ?? this.optionGroups,
    );
  }
}

/// DEC-PROD-026 — M024 intake mode stored on the store; paused stores refuse new orders.
enum StoreServiceMode {
  open('OPEN'),
  busy('BUSY'),
  paused('PAUSED');

  const StoreServiceMode(this.wire);

  final String wire;

  static StoreServiceMode fromWire(Object? raw) {
    for (final mode in values) {
      if (mode.wire == raw) {
        return mode;
      }
    }
    return StoreServiceMode.open;
  }
}

/// M022 — manual accept vs auto accept (DEC-PROD-028).
enum StoreAcceptMode {
  manual('MANUAL'),
  auto('AUTO');

  const StoreAcceptMode(this.wire);

  final String wire;

  static StoreAcceptMode fromWire(Object? raw) =>
      raw == 'AUTO' ? StoreAcceptMode.auto : StoreAcceptMode.manual;
}

/// M022 settings as saved on the backend; defaults match the backend defaults.
class StoreAcceptSettings {
  const StoreAcceptSettings({
    this.acceptMode = StoreAcceptMode.manual,
    this.maxActiveOrders,
    this.defaultPrepMinutes = 15,
    this.busyExtraMinutes = 15,
  });

  final StoreAcceptMode acceptMode;

  /// Max orders in the kitchen (new + preparing); null = no cap.
  final int? maxActiveOrders;
  final int defaultPrepMinutes;

  /// Added to the prep estimate while the store is BUSY (M024).
  final int busyExtraMinutes;

  StoreAcceptSettings copyWith({
    StoreAcceptMode? acceptMode,
    int? maxActiveOrders,
    bool clearMaxActiveOrders = false,
    int? defaultPrepMinutes,
    int? busyExtraMinutes,
  }) {
    return StoreAcceptSettings(
      acceptMode: acceptMode ?? this.acceptMode,
      maxActiveOrders: clearMaxActiveOrders
          ? null
          : (maxActiveOrders ?? this.maxActiveOrders),
      defaultPrepMinutes: defaultPrepMinutes ?? this.defaultPrepMinutes,
      busyExtraMinutes: busyExtraMinutes ?? this.busyExtraMinutes,
    );
  }
}

class FoodStoreDetail {
  const FoodStoreDetail({
    required this.id,
    required this.name,
    required this.items,
    this.category,
    this.addressLabel,
    this.logoUrl,
    this.lat,
    this.lng,
    this.serviceMode = StoreServiceMode.open,
    this.serviceModeUntil,
    this.closedReason,
    this.schedule = const StoreSchedule(),
    this.acceptSettings = const StoreAcceptSettings(),
    this.estimatedPrepMinutes,
  });

  /// Merchant-only M022 settings (the customer payload omits them → defaults).
  final StoreAcceptSettings acceptSettings;

  /// Kitchen time customers see right now (default prep + BUSY extra).
  final int? estimatedPrepMinutes;

  /// Non-null when new orders are refused right now (paused or outside hours).
  final StoreClosedReason? closedReason;
  final StoreSchedule schedule;

  bool get openNow => closedReason == null;

  final String id;
  final String name;
  final List<FoodMenuItem> items;
  final String? category;
  final String? addressLabel;

  /// M030 logo path under /v1/public/store-logos; null = none (DEC-PROD-045).
  final String? logoUrl;

  /// Pickup point drivers navigate to; null until the merchant sets it (M030).
  final double? lat;
  final double? lng;

  bool get hasLocation => lat != null && lng != null;
  final StoreServiceMode serviceMode;

  /// Auto-resume instant; null while open or when the merchant resumes manually.
  final DateTime? serviceModeUntil;

  bool get isPaused => serviceMode == StoreServiceMode.paused;

  FoodStoreDetail copyWith({
    StoreServiceMode? serviceMode,
    DateTime? serviceModeUntil,
    bool clearServiceModeUntil = false,
    StoreSchedule? schedule,
    StoreAcceptSettings? acceptSettings,
    int? estimatedPrepMinutes,
    List<FoodMenuItem>? items,
    double? lat,
    double? lng,
    String? addressLabel,
    String? name,
    String? logoUrl,
    bool clearLogoUrl = false,
  }) {
    return FoodStoreDetail(
      id: id,
      name: name ?? this.name,
      items: items ?? this.items,
      category: category,
      addressLabel: addressLabel ?? this.addressLabel,
      logoUrl: clearLogoUrl ? null : (logoUrl ?? this.logoUrl),
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      closedReason: closedReason,
      schedule: schedule ?? this.schedule,
      acceptSettings: acceptSettings ?? this.acceptSettings,
      estimatedPrepMinutes: estimatedPrepMinutes ?? this.estimatedPrepMinutes,
      serviceMode: serviceMode ?? this.serviceMode,
      serviceModeUntil: clearServiceModeUntil
          ? null
          : (serviceModeUntil ?? this.serviceModeUntil),
    );
  }
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
    this.imageUrl,
    this.options = const [],
  });

  final String itemId;
  final String name;

  /// Base price + chosen option surcharges, per unit (server-computed).
  final int unitPriceVnd;
  final int quantity;

  /// Cover snapshotted at placement (DEC-PROD-043).
  final String? imageUrl;

  /// Options the customer chose, snapshotted at placement.
  final List<FoodLineOption> options;

  /// "Size: L · Topping: Trân châu" for receipts and kitchen tickets.
  String get optionsSummary =>
      options.map((option) => '${option.groupName}: ${option.name}').join(' · ');

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
    this.storeName,
    this.storeAddress,
    this.pickup,
  });

  final String id;
  final String storeId;
  final String? storeName;
  final String? storeAddress;

  /// Store point snapshotted on the order (DEC-PROD-034); null when the store
  /// had no coordinates. The label falls back to the store address/name.
  final FoodDropoff? pickup;
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
    this.customerName,
    this.driverName,
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

  /// Masked by the server ("Tiến T."); never the full name or an id.
  final String? customerName;

  /// Masked assigned driver name once a driver has claimed the delivery.
  final String? driverName;

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
      customerName: customerName,
      driverName: driverName,
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

enum FoodTrackingStage {
  preparing,
  onTheWay,
  delivered,
  failed,
  cancelled,
  unknown,
}

FoodTrackingStage foodTrackingStage(String status) {
  return switch (status) {
    'PLACED' || 'PREPARING' => FoodTrackingStage.preparing,
    'READY' || 'ASSIGNED' || 'PICKED_UP' => FoodTrackingStage.onTheWay,
    'DELIVERED' => FoodTrackingStage.delivered,
    'FAILED' => FoodTrackingStage.failed,
    'CANCELLED' => FoodTrackingStage.cancelled,
    _ => FoodTrackingStage.unknown,
  };
}

/// Why a store declined an order (backend FOOD_REJECT_REASONS).
enum FoodRejectReason {
  outOfStock('OUT_OF_STOCK'),
  storeBusy('STORE_BUSY'),
  storeClosing('STORE_CLOSING'),
  itemPriceChanged('ITEM_PRICE_CHANGED'),
  other('OTHER');

  const FoodRejectReason(this.wire);

  final String wire;

  static FoodRejectReason fromWire(Object? value) => FoodRejectReason.values
      .firstWhere((r) => r.wire == value, orElse: () => FoodRejectReason.other);
}

/// Max length of the free-text note (backend FOOD_REJECT_NOTE_MAX).
const foodRejectNoteMax = 200;

class FoodCancelReason {
  const FoodCancelReason({required this.reason, this.note});

  final FoodRejectReason reason;
  final String? note;
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
    this.storeName,
    this.assignedDriverId,
    this.discountVnd = 0,
    this.cancelReason,
    this.prepMinutes,
    this.estimatedReadyAt,
    this.deliveryCode,
    this.handoverCode,
  });

  /// DEC-PROD-036: customer-only delivery code while the courier is assigned / on the way.
  final String? deliveryCode;

  /// DEC-PROD-036: store-only handover code while a driver is assigned (opt-in setting).
  final String? handoverCode;

  /// Kitchen estimate snapshotted at placement (DEC-PROD-028); null on old orders.
  final int? prepMinutes;
  final DateTime? estimatedReadyAt;

  /// Set when the store declined the order (shown to the customer).
  final FoodCancelReason? cancelReason;
  final String id;
  final String status;
  final int subtotalVnd;
  final int deliveryFareVnd;
  final int totalVnd;
  final FoodDropoff dropoff;
  final List<FoodOrderLine> lines;
  final String? storeName;
  final String? assignedDriverId;
  final int discountVnd;

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
    this.discountVnd = 0,
    this.voucherCode,
  });

  final String id;
  final String status;
  final int subtotalVnd;
  final int deliveryFareVnd;

  /// Voucher discount the server applied; [totalVnd] is already net of it.
  final int discountVnd;
  final String? voucherCode;
  final int totalVnd;
  final List<FoodOrderLine> lines;
}
