class MapLatLng {
  const MapLatLng({required this.lat, required this.lng});

  final double lat;
  final double lng;

  @override
  String toString() => '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
}

/// Initial map viewport before the customer's position is known: DealGo
/// operates in Da Nang (product geography, not a business setting).
const danangViewportCenter = MapLatLng(lat: 16.0544, lng: 108.2022);
