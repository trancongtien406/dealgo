import 'food_options.dart';
import '../../../../core/maps/route_geometry.dart';

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

/// A live merchant-funded offer that applies only at its store.
enum StoreOfferKind { fixedAmount, percentage }

class StoreOffer {
  const StoreOffer({
    required this.id,
    required this.code,
    required this.name,
    required this.kind,
    required this.discountValue,
    required this.endsAt,
    this.maxDiscountVnd,
    this.minOrderVnd = 0,
    this.remainingUses,
  });

  final String id;
  final String code;
  final String name;
  final StoreOfferKind kind;

  /// VND for [StoreOfferKind.fixedAmount], percent for [StoreOfferKind.percentage].
  final int discountValue;
  final int? maxDiscountVnd;
  final int minOrderVnd;
  final DateTime endsAt;

  /// Redemptions left before the offer is used up; null = not reported.
  final int? remainingUses;
}

/// Named menu section (merchant menu category) shown on the store page.
class FoodMenuSection {
  const FoodMenuSection({required this.id, required this.name});

  final String id;
  final String name;
}

class FoodStoreSummary {
  const FoodStoreSummary({
    required this.id,
    required this.name,
    this.category,
    this.distanceKm,
    this.closedReason,
    this.imageUrl,
    this.logoUrl,
    this.ratingAverage,
    this.ratingCount,
    this.etaMinutes,
    this.deliveryFeeFromVnd,
    this.offers = const [],
    this.minOrderVnd = 0,
    this.featuredItems = const [],
  });

  /// Smallest food subtotal the store accepts; 0 = no minimum.
  final int minOrderVnd;

  /// Up to 3 dishes for discovery rows: best sellers first, then the newest.
  final List<FoodFeaturedItem> featuredItems;

  /// Store logo; the card prefers the cover [imageUrl].
  final String? logoUrl;

  /// Null until the store has enough visible ratings to publish an average.
  final double? ratingAverage;

  /// Visible ratings; null when the list did not include rating data.
  final int? ratingCount;

  /// Prep + ride estimate; only when the app sent a GPS fix.
  final int? etaMinutes;

  /// Straight-line delivery fee estimate ("từ" price).
  final int? deliveryFeeFromVnd;

  /// Up to 3 live store offers, best first.
  final List<StoreOffer> offers;

  final String id;
  final String name;

  /// Non-null when the store is paused or outside its hours; lists sort these last.
  final StoreClosedReason? closedReason;

  bool get openNow => closedReason == null;

  /// Catalog category code from the backend (e.g. `pho`, `cafe`); may be null.
  final String? category;

  /// Straight-line distance from the customer, only when the app sent a GPS fix.
  final double? distanceKm;

  /// Cover thumb from first menu item with a photo (DEC-PROD-041).
  final String? imageUrl;
}

/// One page of store browse results. [total] is the server count for the
/// current filter, so [hasMore] stays correct even when rows are de-duplicated.
class FoodStorePageResult {
  const FoodStorePageResult({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
  });

  final List<FoodStoreSummary> items;
  final int total;
  final int page;
  final int limit;

  bool get hasMore => page * limit < total;
}

/// How long a dish counts as "Mới" after the merchant adds it.
const foodNewItemWindow = Duration(days: 14);

/// True while [addedAt] is inside [foodNewItemWindow].
bool foodItemIsNew(DateTime? addedAt, {DateTime? now}) {
  if (addedAt == null) return false;
  final age = (now ?? DateTime.now()).difference(addedAt);
  return !age.isNegative && age < foodNewItemWindow;
}

/// A dish shown on a store card in discovery rows.
class FoodFeaturedItem {
  const FoodFeaturedItem({
    required this.id,
    required this.name,
    required this.priceVnd,
    this.originalPriceVnd,
    this.imageUrl,
    this.soldCount = 0,
    this.addedAt,
  });

  final String id;
  final String name;
  final int priceVnd;

  /// List price shown struck through; only sent while above [priceVnd].
  final int? originalPriceVnd;
  final String? imageUrl;
  final int soldCount;
  final DateTime? addedAt;

  bool get isNew => foodItemIsNew(addedAt);
}

/// FOOD-001 — new dishes wait for Ops approval while item moderation is enabled.
enum FoodItemModeration {
  pending('PENDING'),
  approved('APPROVED'),
  rejected('REJECTED');

  const FoodItemModeration(this.wire);

  final String wire;

  static FoodItemModeration fromWire(Object? raw) {
    for (final value in values) {
      if (value.wire == raw) {
        return value;
      }
    }
    return FoodItemModeration.approved;
  }
}

class FoodMenuItem {
  const FoodMenuItem({
    required this.id,
    required this.name,
    required this.priceVnd,
    required this.available,
    this.moderation = FoodItemModeration.approved,
    this.description,
    this.prepMinutes,
    this.imageUrl,
    this.imageUrls = const [],
    this.soldCount = 0,
    this.menuCategoryId,
    this.optionGroups = const [],
    this.originalPriceVnd,
    this.addedAt,
  });

  final String id;
  final String name;
  final int priceVnd;
  final bool available;

  /// FOOD-001: with item moderation on, a new dish stays PENDING until Ops approves it.
  final FoodItemModeration moderation;

  /// Customers only see and order APPROVED dishes; a PENDING/REJECTED dish is not on sale.
  bool get onSale => available && moderation == FoodItemModeration.approved;

  /// List price shown struck through; null unless above [priceVnd].
  final int? originalPriceVnd;

  /// When the merchant added the dish (drives the "Mới" badge).
  final DateTime? addedAt;

  bool get isNew => foodItemIsNew(addedAt);

  /// Percent saved against [originalPriceVnd]; 0 when there is no list price.
  int get discountPercent {
    final original = originalPriceVnd;
    if (original == null || original <= priceVnd) return 0;
    return ((original - priceVnd) * 100 / original).round();
  }

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
    int? originalPriceVnd,
    bool clearOriginalPrice = false,
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
      moderation: moderation,
      description: clearDescription ? null : (description ?? this.description),
      prepMinutes: clearPrepMinutes ? null : (prepMinutes ?? this.prepMinutes),
      imageUrl: clearImageUrl ? null : (imageUrl ?? this.imageUrl),
      imageUrls: imageUrls ?? this.imageUrls,
      soldCount: soldCount ?? this.soldCount,
      menuCategoryId: clearMenuCategoryId
          ? null
          : (menuCategoryId ?? this.menuCategoryId),
      optionGroups: optionGroups ?? this.optionGroups,
      originalPriceVnd: clearOriginalPrice
          ? null
          : (originalPriceVnd ?? this.originalPriceVnd),
      addedAt: addedAt,
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
    this.coverUrl,
    this.description,
    this.lat,
    this.lng,
    this.serviceMode = StoreServiceMode.open,
    this.serviceModeUntil,
    this.closedReason,
    this.schedule = const StoreSchedule(),
    this.acceptSettings = const StoreAcceptSettings(),
    this.estimatedPrepMinutes,
    this.offers = const [],
    this.menuSections = const [],
    this.minOrderVnd = 0,
  });

  /// Smallest food subtotal the store accepts; 0 = no minimum.
  final int minOrderVnd;

  /// Live store offers, best first (customer payload only).
  final List<StoreOffer> offers;

  /// Menu sections in merchant order (customer payload only).
  final List<FoodMenuSection> menuSections;

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

  /// Merchant cover photo under /v1/public/store-covers; null = the page
  /// falls back to the first dish photo.
  final String? coverUrl;

  /// Merchant "about the store" text; null = none.
  final String? description;

  /// Pickup point drivers navigate to; null until the merchant sets it (M030).
  final double? lat;
  final double? lng;

  bool get hasLocation => lat != null && lng != null;
  final StoreServiceMode serviceMode;

  /// Auto-resume instant; null while open or when the merchant resumes manually.
  final DateTime? serviceModeUntil;

  bool get isPaused => serviceMode == StoreServiceMode.paused;

  /// A paused store keeps its menu visible but refuses new lines.
  bool get canOrder => openNow && !isPaused;

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
    String? category,
    String? logoUrl,
    bool clearLogoUrl = false,
    String? coverUrl,
    bool clearCoverUrl = false,
    String? description,
    bool clearDescription = false,
    int? minOrderVnd,
  }) {
    return FoodStoreDetail(
      id: id,
      name: name ?? this.name,
      items: items ?? this.items,
      category: category ?? this.category,
      addressLabel: addressLabel ?? this.addressLabel,
      logoUrl: clearLogoUrl ? null : (logoUrl ?? this.logoUrl),
      coverUrl: clearCoverUrl ? null : (coverUrl ?? this.coverUrl),
      description: clearDescription ? null : (description ?? this.description),
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      closedReason: closedReason,
      schedule: schedule ?? this.schedule,
      acceptSettings: acceptSettings ?? this.acceptSettings,
      estimatedPrepMinutes: estimatedPrepMinutes ?? this.estimatedPrepMinutes,
      offers: offers,
      menuSections: menuSections,
      minOrderVnd: minOrderVnd ?? this.minOrderVnd,
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
    this.id,
    required this.itemId,
    required this.name,
    required this.unitPriceVnd,
    required this.quantity,
    this.imageUrl,
    this.options = const [],
    this.note,
  });

  /// Server line id (the store edits a line by id); null on old fakes.
  final String? id;
  final String itemId;
  final String name;

  /// Base price + chosen option surcharges, per unit (server-computed).
  final int unitPriceVnd;
  final int quantity;

  /// Cover snapshotted at placement (DEC-PROD-043).
  final String? imageUrl;

  /// Options the customer chose, snapshotted at placement.
  final List<FoodLineOption> options;

  /// Customer note for this line ("ít cay, không hành"); null = none.
  final String? note;

  /// "Size: L · Topping: Trân châu" for receipts and kitchen tickets.
  String get optionsSummary => options
      .map((option) => '${option.groupName}: ${option.name}')
      .join(' · ');

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
    this.route,
    this.approachRoute,
    this.note,
    this.utensils = true,
  });

  final String id;
  final String storeId;

  /// Customer note for the store and courier; null = none.
  final String? note;

  /// Whether the customer asked for cutlery.
  final bool utensils;

  /// DEC-PROD-031 rev 3 (DRAFT): driver→store leg snapshot (assigned only).
  final RouteGeometry? approachRoute;
  final String? storeName;

  /// Road geometry pickup→dropoff from Nest (DEC-PROD-045). Null/unavailable →
  /// the map draws no line (never a straight store→customer segment).
  final RouteGeometry? route;
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
  other('OTHER'),

  /// The customer declined the store's edit / did not answer in time.
  changeRejected('CHANGE_REJECTED'),
  changeExpired('CHANGE_EXPIRED');

  const FoodRejectReason(this.wire);

  /// Reasons a store may pick when declining (the change ones are set by the server).
  static const storeChoices = [
    outOfStock,
    storeBusy,
    storeClosing,
    itemPriceChanged,
    other,
  ];

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
    this.storeId,
    this.assignedDriverId,
    this.discountVnd = 0,
    this.cancelReason,
    this.prepMinutes,
    this.estimatedReadyAt,
    this.deliveryCode,
    this.handoverCode,
    this.pickup,
    this.route,
    this.approachRoute,
    this.pendingChange,
    this.note,
    this.utensils = true,
  });

  /// Store edit waiting for the customer's answer (customer/store only).
  final FoodOrderChange? pendingChange;

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

  /// Needed to reorder ("Đặt lại"); null on old fakes.
  final String? storeId;
  final String? assignedDriverId;
  final int discountVnd;

  /// Store pickup snapshotted on the order; null when the store had no coords.
  final FoodDropoff? pickup;

  /// Nest road geometry when pickup coords exist.
  final RouteGeometry? route;

  /// DEC-PROD-031 rev 3 (DRAFT): driver→store leg while ASSIGNED.
  final RouteGeometry? approachRoute;

  /// Customer note to the store and driver; null = none.
  final String? note;

  /// Whether cutlery was requested; the server defaults to true.
  final bool utensils;

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
    this.note,
    this.utensils = true,
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

  /// Customer note to the store and driver; null = none.
  final String? note;

  /// Whether cutlery was requested; the server defaults to true.
  final bool utensils;
}

/// Why a store edited an order (backend FOOD_ORDER_CHANGE_REASONS).
enum FoodOrderChangeReason {
  outOfStock('OUT_OF_STOCK'),
  notEnoughPortions('NOT_ENOUGH_PORTIONS'),
  other('OTHER');

  const FoodOrderChangeReason(this.wire);

  final String wire;

  static FoodOrderChangeReason fromWire(Object? value) =>
      FoodOrderChangeReason.values.firstWhere(
        (r) => r.wire == value,
        orElse: () => FoodOrderChangeReason.other,
      );
}

/// One edited line: the store can only lower a quantity or remove the line (0).
class FoodOrderChangeLine {
  const FoodOrderChangeLine({
    required this.lineId,
    required this.name,
    required this.unitPriceVnd,
    required this.fromQuantity,
    required this.toQuantity,
  });

  final String lineId;
  final String name;
  final int unitPriceVnd;
  final int fromQuantity;
  final int toQuantity;

  bool get removed => toQuantity == 0;
}

/// Store edit the customer accepts or rejects.
/// Rejecting (or not answering before [expiresAt]) cancels the order without a fee.
class FoodOrderChange {
  const FoodOrderChange({
    required this.id,
    required this.status,
    required this.reason,
    required this.lines,
    required this.oldSubtotalVnd,
    required this.newSubtotalVnd,
    required this.newDiscountVnd,
    required this.newTotalVnd,
    required this.expiresAt,
    this.note,
  });

  final String id;

  /// PENDING | ACCEPTED | REJECTED | EXPIRED
  final String status;
  final FoodOrderChangeReason reason;
  final String? note;
  final List<FoodOrderChangeLine> lines;
  final int oldSubtotalVnd;
  final int newSubtotalVnd;
  final int newDiscountVnd;
  final int newTotalVnd;
  final DateTime expiresAt;

  bool get pending => status == 'PENDING';
}
