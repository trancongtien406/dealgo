enum SavedAddressKind {
  home('HOME'),
  work('WORK'),
  other('OTHER');

  const SavedAddressKind(this.wire);

  final String wire;

  static SavedAddressKind fromWire(Object? value) {
    return SavedAddressKind.values.firstWhere(
      (kind) => kind.wire == value,
      orElse: () => SavedAddressKind.other,
    );
  }
}

class SavedAddress {
  const SavedAddress({
    required this.id,
    required this.kind,
    required this.label,
    required this.addressLine,
    required this.isDefault,
    this.note,
    this.lat,
    this.lng,
  });

  final String id;
  final SavedAddressKind kind;
  final String label;
  final String addressLine;
  final String? note;
  final double? lat;
  final double? lng;
  final bool isDefault;

  bool get hasPin => lat != null && lng != null;
}

/// Create/edit payload. `null` coordinates mean "no pin".
class SavedAddressDraft {
  const SavedAddressDraft({
    required this.kind,
    required this.label,
    required this.addressLine,
    this.note,
    this.lat,
    this.lng,
    this.isDefault = false,
  });

  final SavedAddressKind kind;
  final String label;
  final String addressLine;
  final String? note;
  final double? lat;
  final double? lng;
  final bool isDefault;

  Map<String, Object?> toJson() => {
    'kind': kind.wire,
    'label': label,
    'addressLine': addressLine,
    if (note != null && note!.isNotEmpty) 'note': note,
    if (lat != null && lng != null) ...{'lat': lat, 'lng': lng},
    if (isDefault) 'isDefault': true,
  };
}
