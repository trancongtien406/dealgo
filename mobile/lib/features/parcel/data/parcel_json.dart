import '../../../core/network/api_envelope.dart';
import '../../../core/network/api_exception.dart';
import '../../ride/data/models/ride_models.dart';
import '../../ride/domain/entities/ride_models.dart';
import '../domain/parcel_models.dart';

const _invalid = ApiException(
  statusCode: 200,
  message: 'Invalid response',
  errorCode: 'INVALID_RESPONSE',
);

int _int(Object? v) => v is num ? v.round() : 0;
double? _double(Object? v) => v is num ? v.toDouble() : null;
String? _str(Object? v) => v is String && v.isNotEmpty ? v : null;

/// `GET /v1/parcels/size-classes` → enabled classes (bad rows skipped).
List<ParcelSizeClass> parseParcelSizeClasses(Object? body) {
  final data = body is Map ? body['data'] : body;
  if (data is! List) throw _invalid;
  final out = <ParcelSizeClass>[];
  for (final raw in data) {
    final m = asJsonMap(raw);
    final code = _str(m?['code']);
    if (m == null || code == null) continue;
    final dims = m['maxDimsCm'];
    final classes = m['vehicleClassCodes'];
    out.add(
      ParcelSizeClass(
        code: code,
        label: _str(m['label']) ?? code,
        maxWeightKg: _double(m['maxWeightKg']) ?? 0,
        maxDimsCm: dims is List ? [for (final d in dims) _int(d)] : const [],
        surchargeVnd: _int(m['surchargeVnd']),
        vehicleClassCodes: classes is List
            ? [
                for (final c in classes)
                  if (c is String) c,
              ]
            : const [],
      ),
    );
  }
  return List.unmodifiable(out);
}

ParcelQuote parseParcelQuote(Map<String, Object?> data) {
  final raw = data['options'];
  if (raw is! List) throw _invalid;
  final options = <ParcelQuoteOption>[];
  for (final r in raw) {
    final m = asJsonMap(r);
    final code = _str(m?['code']);
    if (m == null || code == null) continue;
    options.add(
      ParcelQuoteOption(
        code: code,
        name: _str(m['name']) ?? code,
        referenceFareVnd: _int(m['referenceFareVnd']),
        minBidVnd: _int(m['minBidVnd']),
        maxBidVnd: _int(m['maxBidVnd']),
        durationMin: _int(m['durationMin']),
        imageUrl: _str(m['imageUrl']),
        parcelSurchargeVnd: _int(m['parcelSurchargeVnd']),
        serviceFeeVnd: _int(m['parcelServiceFeeVnd']),
        returnFeeVnd: _int(m['parcelReturnFeeVnd']),
      ),
    );
  }
  return ParcelQuote(
    options: List.unmodifiable(options),
    distanceKm: _double(data['distanceKm']),
  );
}

ParcelContact? _contact(Object? raw) {
  final m = asJsonMap(raw);
  final name = _str(m?['name']);
  final phone = _str(m?['phone']);
  if (name == null || phone == null) return null;
  return ParcelContact(name: name, phone: phone);
}

ParcelInfo parseParcelInfo(Map<String, Object?> m) {
  final size = _str(m['sizeClass']);
  if (size == null) throw _invalid;
  return ParcelInfo(
    sizeClass: size,
    outcome: ParcelOutcome.parse(_str(m['outcome'])),
    weightKg: _double(m['weightKg']),
    note: _str(m['note']),
    payer: _str(m['payer']) == 'RECIPIENT'
        ? ParcelPayer.recipient
        : ParcelPayer.sender,
    surchargeVnd: _int(m['surchargeVnd']),
    serviceFeeVnd: _int(m['serviceFeeVnd']),
    returnFeeVnd: _int(m['returnFeeVnd']),
    sender: _contact(m['sender']),
    recipient: _contact(m['recipient']),
    recipientCode: _str(m['recipientCode']),
    failReason: _str(m['failReason']),
    pickedUpAt: _str(m['pickedUpAt']),
    deliveredAt: _str(m['deliveredAt']),
    returnedAt: _str(m['returnedAt']),
  );
}

/// Ride view + `parcel` from any `/v1/parcels/:id*` response envelope.
ParcelRide parseParcelRide(Object? body) {
  final data = requireSuccessData(body);
  final parcel = asJsonMap(data['parcel']);
  if (parcel == null) throw _invalid;
  return ParcelRide(
    ride: RideViewModel.fromJson(data).toEntity(),
    parcel: parseParcelInfo(parcel),
  );
}

Map<String, Object?> _point(RidePoint p) =>
    RidePointModel.fromEntity(p).toJson();

Map<String, Object?> parcelQuoteBody(ParcelDraft d) => {
  'pickup': _point(d.places.pickup),
  'dropoff': _point(d.places.dropoff),
  'sizeClass': d.sizeClass,
  if (d.weightKg != null) 'weightKg': d.weightKg,
};

Map<String, Object?> parcelCreateBody(
  ParcelDraft d, {
  required String vehicleClassCode,
  required int offeredFareVnd,
}) => {
  ...parcelQuoteBody(d),
  'vehicleClassCode': vehicleClassCode,
  'offeredFareVnd': offeredFareVnd,
  'sender': d.sender.toJson(),
  'recipient': d.recipient.toJson(),
  if ((d.note ?? '').trim().isNotEmpty) 'note': d.note!.trim(),
  'payer': d.payer.wire,
  'paymentMethod': d.payer == ParcelPayer.recipient ? 'CASH' : d.paymentMethod,
  if (d.itemPhoto != null) 'itemPhoto': d.itemPhoto!.toJson(),
};
