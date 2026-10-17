class MapLatLng {
  const MapLatLng({required this.lat, required this.lng});

  final double lat;
  final double lng;

  @override
  String toString() => '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
}
