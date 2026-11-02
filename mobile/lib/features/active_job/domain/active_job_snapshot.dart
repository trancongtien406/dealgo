import '../../driver_card/domain/driver_card.dart';

enum ActiveJobKind {
  ride('RIDE'),
  foodOrder('FOOD_ORDER');

  const ActiveJobKind(this.wire);

  final String wire;

  static ActiveJobKind? parse(Object? raw) {
    for (final kind in values) {
      if (kind.wire == raw) return kind;
    }
    return null;
  }
}

/// What the customer needs to see and call about their latest ride / food
/// order when the network is gone: the last server copy, never authoritative.
class ActiveJobSnapshot {
  const ActiveJobSnapshot({
    required this.kind,
    required this.id,
    required this.status,
    required this.savedAt,
    this.pickupLabel,
    this.dropoffLabel,
    this.stopLabels = const [],
    this.storeName,
    this.amountVnd,
    this.cashDueVnd,
    this.code,
    this.driver,
    this.endedAt,
  });

  /// Kept usable this long after the last server confirmation.
  static const maxAge = Duration(hours: 6);

  /// A finished job stays visible (without phone or code) this long.
  static const endedGrace = Duration(minutes: 30);

  final ActiveJobKind kind;
  final String id;

  /// Server wire status (`IN_TRIP`, `PICKED_UP`…).
  final String status;

  /// When the server last confirmed this copy.
  final DateTime savedAt;
  final String? pickupLabel;
  final String? dropoffLabel;
  final List<String> stopLabels;
  final String? storeName;

  /// Agreed ride fare, or the food order total.
  final int? amountVnd;

  /// Cash still due after a voucher, when it differs from [amountVnd].
  final int? cashDueVnd;

  /// Ride pickup code / food delivery code.
  final String? code;
  final DriverCard? driver;

  /// Set once the server reported a terminal status.
  final DateTime? endedAt;

  bool get ended => endedAt != null;

  bool usableAt(DateTime now) {
    if (now.difference(savedAt) > maxAge) return false;
    final end = endedAt;
    return end == null || now.difference(end) <= endedGrace;
  }

  ActiveJobSnapshot withDriver(DriverCard card) =>
      _copy(driver: ended ? _withoutPhone(card) : card);

  ActiveJobSnapshot savedAtTime(DateTime time) => _copy(savedAt: time);

  /// Drops the phone and code at once: the server stops sharing them when the
  /// job ends (DEC-PROD-091), so the device must not keep them either.
  ActiveJobSnapshot endedAtTime(DateTime time) => ActiveJobSnapshot(
    kind: kind,
    id: id,
    status: status,
    savedAt: savedAt,
    pickupLabel: pickupLabel,
    dropoffLabel: dropoffLabel,
    stopLabels: stopLabels,
    storeName: storeName,
    amountVnd: amountVnd,
    cashDueVnd: cashDueVnd,
    driver: driver == null ? null : _withoutPhone(driver!),
    endedAt: endedAt ?? time,
  );

  ActiveJobSnapshot _copy({DriverCard? driver, DateTime? savedAt}) =>
      ActiveJobSnapshot(
        kind: kind,
        id: id,
        status: status,
        savedAt: savedAt ?? this.savedAt,
        pickupLabel: pickupLabel,
        dropoffLabel: dropoffLabel,
        stopLabels: stopLabels,
        storeName: storeName,
        amountVnd: amountVnd,
        cashDueVnd: cashDueVnd,
        code: code,
        driver: driver ?? this.driver,
        endedAt: endedAt,
      );

  static DriverCard _withoutPhone(DriverCard card) => DriverCard(
    driverId: card.driverId,
    displayName: card.displayName,
    avatarUrl: card.avatarUrl,
    vehiclePlate: card.vehiclePlate,
    vehicleType: card.vehicleType,
    vehicleName: card.vehicleName,
    ratingAverage: card.ratingAverage,
    ratingCount: card.ratingCount,
    completedTrips: card.completedTrips,
  );

  Map<String, Object?> toJson() => {
    'kind': kind.wire,
    'id': id,
    'status': status,
    'savedAt': savedAt.toUtc().toIso8601String(),
    'pickupLabel': pickupLabel,
    'dropoffLabel': dropoffLabel,
    'stopLabels': stopLabels,
    'storeName': storeName,
    'amountVnd': amountVnd,
    'cashDueVnd': cashDueVnd,
    'code': code,
    'driver': driver == null ? null : _driverToJson(driver!),
    'endedAt': endedAt?.toUtc().toIso8601String(),
  };

  static ActiveJobSnapshot? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final kind = ActiveJobKind.parse(raw['kind']);
    final id = raw['id'];
    final status = raw['status'];
    final savedAt = DateTime.tryParse('${raw['savedAt']}');
    if (kind == null ||
        id is! String ||
        id.isEmpty ||
        status is! String ||
        savedAt == null) {
      return null;
    }
    final stops = raw['stopLabels'];
    return ActiveJobSnapshot(
      kind: kind,
      id: id,
      status: status,
      savedAt: savedAt,
      pickupLabel: _string(raw['pickupLabel']),
      dropoffLabel: _string(raw['dropoffLabel']),
      stopLabels: stops is List
          ? [for (final s in stops) ?_string(s)]
          : const [],
      storeName: _string(raw['storeName']),
      amountVnd: _int(raw['amountVnd']),
      cashDueVnd: _int(raw['cashDueVnd']),
      code: _string(raw['code']),
      driver: _driverFromJson(raw['driver']),
      endedAt: raw['endedAt'] == null
          ? null
          : DateTime.tryParse('${raw['endedAt']}'),
    );
  }

  static Map<String, Object?> _driverToJson(DriverCard card) => {
    'driverId': card.driverId,
    'displayName': card.displayName,
    'avatarUrl': card.avatarUrl,
    'vehiclePlate': card.vehiclePlate,
    'vehicleType': card.vehicleType,
    'vehicleName': card.vehicleName,
    'ratingAverage': card.ratingAverage,
    'ratingCount': card.ratingCount,
    'completedTrips': card.completedTrips,
    'phone': card.phone,
  };

  static DriverCard? _driverFromJson(Object? raw) {
    if (raw is! Map) return null;
    final rating = raw['ratingAverage'];
    return DriverCard(
      driverId: _string(raw['driverId']) ?? '',
      displayName: _string(raw['displayName']) ?? '',
      avatarUrl: _string(raw['avatarUrl']),
      vehiclePlate: _string(raw['vehiclePlate']),
      vehicleType: _string(raw['vehicleType']),
      vehicleName: _string(raw['vehicleName']),
      ratingAverage: rating is num ? rating.toDouble() : null,
      ratingCount: _int(raw['ratingCount']) ?? 0,
      completedTrips: _int(raw['completedTrips']),
      phone: _string(raw['phone']),
    );
  }

  static String? _string(Object? value) =>
      value is String && value.trim().isNotEmpty ? value : null;

  static int? _int(Object? value) => value is num ? value.toInt() : null;
}
