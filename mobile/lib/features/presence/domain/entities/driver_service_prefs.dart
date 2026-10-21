/// Services the driver takes while online (DEC-PROD-023). Both on until the driver changes them.
class DriverServicePrefs {
  const DriverServicePrefs({required this.rideEnabled, required this.foodEnabled});

  static const defaults = DriverServicePrefs(rideEnabled: true, foodEnabled: true);

  final bool rideEnabled;
  final bool foodEnabled;

  DriverServicePrefs copyWith({bool? rideEnabled, bool? foodEnabled}) => DriverServicePrefs(
    rideEnabled: rideEnabled ?? this.rideEnabled,
    foodEnabled: foodEnabled ?? this.foodEnabled,
  );

  @override
  bool operator ==(Object other) =>
      other is DriverServicePrefs &&
      other.rideEnabled == rideEnabled &&
      other.foodEnabled == foodEnabled;

  @override
  int get hashCode => Object.hash(rideEnabled, foodEnabled);
}

/// Reads `{rideEnabled, foodEnabled}` from GET /v1/me/presence; missing fields stay on.
DriverServicePrefs decodeDriverServicePrefs(Object? data) {
  if (data is! Map) {
    return DriverServicePrefs.defaults;
  }
  final ride = data['rideEnabled'];
  final food = data['foodEnabled'];
  return DriverServicePrefs(
    rideEnabled: ride is bool ? ride : true,
    foodEnabled: food is bool ? food : true,
  );
}
