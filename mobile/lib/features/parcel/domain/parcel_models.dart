import 'dart:convert';
import 'dart:typed_data';

import '../../ride/domain/entities/ride_models.dart';

/// Package size class from admin `PARCEL_SIZE_CLASSES` (DEC-PROD-071 DRAFT).
class ParcelSizeClass {
  const ParcelSizeClass({
    required this.code,
    required this.label,
    required this.maxWeightKg,
    required this.maxDimsCm,
    required this.surchargeVnd,
    this.vehicleClassCodes = const [],
  });

  final String code;
  final String label;
  final double maxWeightKg;
  final List<int> maxDimsCm;
  final int surchargeVnd;
  final List<String> vehicleClassCodes;

  String get dimsLabel => maxDimsCm.join('×');
}

/// One vehicle class that can carry the package, with the bid band incl. surcharge.
class ParcelQuoteOption {
  const ParcelQuoteOption({
    required this.code,
    required this.name,
    required this.referenceFareVnd,
    required this.minBidVnd,
    required this.maxBidVnd,
    this.durationMin = 0,
    this.imageUrl,
    this.parcelSurchargeVnd = 0,
    this.serviceFeeVnd = 0,
    this.returnFeeVnd = 0,
  });

  final String code;
  final String name;
  final int referenceFareVnd;
  final int minBidVnd;
  final int maxBidVnd;
  final int durationMin;
  final String? imageUrl;
  final int parcelSurchargeVnd;

  /// Admin `PARCEL_SERVICE_FEE_VND`, already inside [referenceFareVnd] and the band.
  final int serviceFeeVnd;

  /// Admin `PARCEL_RETURN_FEE_VND`, charged only if the package comes back.
  final int returnFeeVnd;

  /// Keeps an offer inside the server band.
  int clamp(int fareVnd) => fareVnd < minBidVnd
      ? minBidVnd
      : (fareVnd > maxBidVnd ? maxBidVnd : fareVnd);
}

class ParcelQuote {
  const ParcelQuote({required this.options, this.distanceKm});

  final List<ParcelQuoteOption> options;
  final double? distanceKm;
}

class ParcelContact {
  const ParcelContact({required this.name, required this.phone});

  final String name;
  final String phone;

  Map<String, Object> toJson() => {'name': name.trim(), 'phone': phone.trim()};
}

enum ParcelPayer {
  sender('SENDER'),
  recipient('RECIPIENT');

  const ParcelPayer(this.wire);
  final String wire;
}

/// Photo proof sent inline (same transport as Food proof photos).
class ParcelPhoto {
  const ParcelPhoto({required this.bytes, this.contentType = 'image/jpeg'});

  final Uint8List bytes;
  final String contentType;

  Map<String, Object> toJson() => {
    'contentType': contentType,
    'contentBase64': base64Encode(bytes),
  };
}

enum ParcelFailReason {
  recipientUnreachable('RECIPIENT_UNREACHABLE'),
  recipientRefused('RECIPIENT_REFUSED'),
  addressWrong('ADDRESS_WRONG'),
  itemDamaged('ITEM_DAMAGED'),
  other('OTHER');

  const ParcelFailReason(this.wire);
  final String wire;
}

enum ParcelOutcome {
  pending('PENDING'),
  delivered('DELIVERED'),
  returning('RETURNING'),
  returned('RETURNED');

  const ParcelOutcome(this.wire);
  final String wire;

  static ParcelOutcome parse(String? raw) => ParcelOutcome.values.firstWhere(
    (o) => o.wire == raw,
    orElse: () => ParcelOutcome.pending,
  );
}

/// Package part of a parcel ride. Contacts are hidden from drivers until assigned.
class ParcelInfo {
  const ParcelInfo({
    required this.sizeClass,
    required this.outcome,
    this.weightKg,
    this.note,
    this.payer = ParcelPayer.sender,
    this.surchargeVnd = 0,
    this.serviceFeeVnd = 0,
    this.returnFeeVnd = 0,
    this.sender,
    this.recipient,
    this.recipientCode,
    this.failReason,
    this.pickedUpAt,
    this.deliveredAt,
    this.returnedAt,
  });

  final String sizeClass;
  final ParcelOutcome outcome;
  final double? weightKg;
  final String? note;
  final ParcelPayer payer;
  final int surchargeVnd;

  /// Service fee frozen at booking (included in the fare).
  final int serviceFeeVnd;

  /// Return fee frozen at booking; charged only when [outcome] is returned.
  final int returnFeeVnd;
  final ParcelContact? sender;
  final ParcelContact? recipient;

  /// Customer only: the code the recipient tells the driver at hand-over.
  final String? recipientCode;
  final String? failReason;
  final String? pickedUpAt;
  final String? deliveredAt;
  final String? returnedAt;

  bool get pickedUp => pickedUpAt != null;

  /// Return fee shown once a return is under way or done.
  bool get returnFeeApplies =>
      returnFeeVnd > 0 &&
      (outcome == ParcelOutcome.returning || outcome == ParcelOutcome.returned);
}

class ParcelRide {
  const ParcelRide({required this.ride, required this.parcel});

  final RideView ride;
  final ParcelInfo parcel;
}

/// What the customer fills on the package sheet.
class ParcelDraft {
  const ParcelDraft({
    required this.places,
    required this.sizeClass,
    required this.sender,
    required this.recipient,
    this.weightKg,
    this.note,
    this.payer = ParcelPayer.sender,
    this.itemPhoto,
    this.paymentMethod = 'CASH',
  });

  final RidePlaces places;
  final String sizeClass;
  final ParcelContact sender;
  final ParcelContact recipient;
  final double? weightKg;
  final String? note;
  final ParcelPayer payer;
  final ParcelPhoto? itemPhoto;

  /// Payment method code (PARCEL scope). Recipient-pays is always CASH.
  final String paymentMethod;
}

/// Vietnamese mobile number, 10 digits starting 0 or +84 (spaces/dots ignored).
bool isValidParcelPhone(String raw) {
  final s = raw.replaceAll(RegExp(r'[\s.\-]'), '');
  return RegExp(r'^(0|\+84)\d{9}$').hasMatch(s);
}

/// Null when the weight fits the size class; otherwise the limit that was exceeded.
double? parcelWeightOverLimit(ParcelSizeClass size, double? weightKg) {
  if (weightKg == null) return null;
  return weightKg > size.maxWeightKg ? size.maxWeightKg : null;
}
