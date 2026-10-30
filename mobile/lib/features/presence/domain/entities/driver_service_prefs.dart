/// Services the driver takes while online (DEC-PROD-023). Both on until the driver changes them.
class DriverServicePrefs {
  const DriverServicePrefs({
    required this.rideEnabled,
    required this.foodEnabled,
    this.parcelEnabled = false,
    this.online,
  });

  static const defaults = DriverServicePrefs(
    rideEnabled: true,
    foodEnabled: true,
  );

  final bool rideEnabled;
  final bool foodEnabled;

  /// Parcel delivery (DEC-PROD-071): opt-in, off until the driver turns it on.
  final bool parcelEnabled;

  /// Server duty state (`driver_presence.online`); null when unknown. Not part
  /// of equality — prefs compare by the two service toggles only.
  final bool? online;

  DriverServicePrefs copyWith({
    bool? rideEnabled,
    bool? foodEnabled,
    bool? parcelEnabled,
  }) => DriverServicePrefs(
    rideEnabled: rideEnabled ?? this.rideEnabled,
    foodEnabled: foodEnabled ?? this.foodEnabled,
    parcelEnabled: parcelEnabled ?? this.parcelEnabled,
  );

  @override
  bool operator ==(Object other) =>
      other is DriverServicePrefs &&
      other.rideEnabled == rideEnabled &&
      other.foodEnabled == foodEnabled &&
      other.parcelEnabled == parcelEnabled;

  @override
  int get hashCode => Object.hash(rideEnabled, foodEnabled, parcelEnabled);
}

/// Reads `{rideEnabled, foodEnabled}` from GET /v1/me/presence; missing fields stay on.
DriverServicePrefs decodeDriverServicePrefs(Object? data) {
  if (data is! Map) {
    return DriverServicePrefs.defaults;
  }
  final ride = data['rideEnabled'];
  final food = data['foodEnabled'];
  final parcel = data['parcelEnabled'];
  final online = data['online'];
  return DriverServicePrefs(
    rideEnabled: ride is bool ? ride : true,
    foodEnabled: food is bool ? food : true,
    parcelEnabled: parcel is bool ? parcel : false,
    online: online is bool ? online : false,
  );
}
