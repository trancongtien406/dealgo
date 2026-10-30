import '../../../core/mock/fake_ride_client.dart';
import '../../../core/network/api_exception.dart';
import '../../ride/domain/entities/ride_models.dart';
import '../domain/parcel_client.dart';
import '../domain/parcel_models.dart';

/// Offline/mock parcel API: fixed size classes, a motorbike + car quote, in-memory rides.
class FakeParcelClient implements ParcelClient {
  FakeParcelClient({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final Map<String, ParcelRide> _rides = {};
  final List<String> calls = [];
  int _seq = 0;

  static const sizes = [
    ParcelSizeClass(
      code: 'S',
      label: 'Nhỏ',
      maxWeightKg: 3,
      maxDimsCm: [30, 25, 15],
      surchargeVnd: 0,
    ),
    ParcelSizeClass(
      code: 'M',
      label: 'Vừa',
      maxWeightKg: 10,
      maxDimsCm: [50, 40, 30],
      surchargeVnd: 5000,
    ),
    ParcelSizeClass(
      code: 'L',
      label: 'Lớn',
      maxWeightKg: 20,
      maxDimsCm: [60, 50, 40],
      surchargeVnd: 15000,
    ),
    ParcelSizeClass(
      code: 'XL',
      label: 'Rất lớn',
      maxWeightKg: 50,
      maxDimsCm: [100, 60, 60],
      surchargeVnd: 40000,
    ),
  ];

  @override
  Future<List<ParcelSizeClass>> sizeClasses({
    required String accessToken,
  }) async => sizes;

  @override
  Future<ParcelQuote> quote({
    required String accessToken,
    required ParcelDraft draft,
  }) async {
    calls.add('quote:${draft.sizeClass}');
    final size = sizes.firstWhere((s) => s.code == draft.sizeClass);
    final bike = size.code == 'S' || size.code == 'M';
    return ParcelQuote(
      distanceKm: 4.2,
      options: [
        if (bike)
          ParcelQuoteOption(
            code: 'MOTORBIKE',
            name: 'Xe máy',
            referenceFareVnd: 30000 + size.surchargeVnd,
            minBidVnd: 24000 + size.surchargeVnd,
            maxBidVnd: 45000 + size.surchargeVnd,
            durationMin: 14,
            parcelSurchargeVnd: size.surchargeVnd,
            serviceFeeVnd: serviceFeeVnd,
            returnFeeVnd: returnFeeVnd,
          ),
        ParcelQuoteOption(
          code: 'CAR_4',
          name: 'Ô tô 4 chỗ',
          referenceFareVnd: 70000 + size.surchargeVnd,
          minBidVnd: 56000 + size.surchargeVnd,
          maxBidVnd: 105000 + size.surchargeVnd,
          durationMin: 16,
          parcelSurchargeVnd: size.surchargeVnd,
          serviceFeeVnd: serviceFeeVnd,
          returnFeeVnd: returnFeeVnd,
        ),
      ],
    );
  }

  @override
  Future<ParcelRide> create({
    required String accessToken,
    required String idempotencyKey,
    required ParcelDraft draft,
    required String vehicleClassCode,
    required int offeredFareVnd,
  }) async {
    calls.add('create:$vehicleClassCode:$offeredFareVnd');
    final id = 'parcel-${++_seq}';
    final now = _now();
    final ride = ParcelRide(
      ride: RideView(
        id: id,
        status: RideStatus.negotiating,
        pickup: draft.places.pickup,
        dropoff: draft.places.dropoff,
        offeredFareVnd: offeredFareVnd,
        referenceFareVnd: offeredFareVnd,
        agreedFareVnd: null,
        assignedDriverId: null,
        selectedOfferId: null,
        expiresAt: now
            .add(const Duration(minutes: 10))
            .toUtc()
            .toIso8601String(),
        offers: const [],
        vehicleClassCode: vehicleClassCode,
        serviceKind: 'PARCEL',
      ),
      parcel: ParcelInfo(
        sizeClass: draft.sizeClass,
        outcome: ParcelOutcome.pending,
        weightKg: draft.weightKg,
        note: draft.note,
        payer: draft.payer,
        sender: draft.sender,
        recipient: draft.recipient,
        recipientCode: '4321',
        serviceFeeVnd: serviceFeeVnd,
        returnFeeVnd: returnFeeVnd,
      ),
    );
    _rides[id] = ride;
    _codes[id] = '4321';
    return ride;
  }

  ParcelRide _require(String id) {
    final ride = _rides[id];
    if (ride == null) throw StateError('unknown parcel $id');
    return ride;
  }

  ParcelRide _with(String id, ParcelInfo parcel, {RideStatus? status}) {
    final r = _require(id).ride;
    final next = ParcelRide(
      ride: status == null
          ? r
          : RideView(
              id: r.id,
              status: status,
              pickup: r.pickup,
              dropoff: r.dropoff,
              offeredFareVnd: r.offeredFareVnd,
              referenceFareVnd: r.referenceFareVnd,
              agreedFareVnd: r.agreedFareVnd,
              assignedDriverId: r.assignedDriverId,
              selectedOfferId: r.selectedOfferId,
              expiresAt: r.expiresAt,
              offers: r.offers,
              vehicleClassCode: r.vehicleClassCode,
              serviceKind: 'PARCEL',
            ),
      parcel: parcel,
    );
    _rides[id] = next;
    return next;
  }

  ParcelInfo _copy(
    ParcelInfo p, {
    ParcelOutcome? outcome,
    String? pickedUpAt,
    String? deliveredAt,
    String? returnedAt,
    String? failReason,
  }) => ParcelInfo(
    sizeClass: p.sizeClass,
    outcome: outcome ?? p.outcome,
    weightKg: p.weightKg,
    note: p.note,
    payer: p.payer,
    surchargeVnd: p.surchargeVnd,
    serviceFeeVnd: p.serviceFeeVnd,
    returnFeeVnd: p.returnFeeVnd,
    sender: p.sender,
    recipient: p.recipient,
    recipientCode: p.recipientCode,
    failReason: failReason ?? p.failReason,
    pickedUpAt: pickedUpAt ?? p.pickedUpAt,
    deliveredAt: deliveredAt ?? p.deliveredAt,
    returnedAt: returnedAt ?? p.returnedAt,
  );

  /// Mock mode: lets the ride client (waiting-offers screen, cancel) resolve
  /// `parcel-N` ids. Unknown ids fall through to the ride client's own handlers;
  /// a still-negotiating parcel borrows the fallback's demo offers.
  void bridgeInto(FakeRideClient rides) {
    final baseGet = rides.onGet;
    final baseCancel = rides.onCancel;
    rides.onGet = (id) {
      final known = _rides[id]?.ride;
      if (known == null) {
        if (baseGet == null) {
          throw const ApiException(
            statusCode: 404,
            message: 'Ride not found',
            errorCode: 'RIDE_NOT_FOUND',
          );
        }
        return baseGet(id);
      }
      if (known.status != RideStatus.negotiating ||
          known.offers.isNotEmpty ||
          baseGet == null) {
        return known;
      }
      return _rideWith(known, offers: baseGet(id).offers);
    };
    rides.onCancel = (id) {
      final known = _rides[id];
      if (known == null) {
        if (baseCancel == null) {
          throw const ApiException(
            statusCode: 404,
            message: 'Ride not found',
            errorCode: 'RIDE_NOT_FOUND',
          );
        }
        return baseCancel(id);
      }
      return _with(id, known.parcel, status: RideStatus.cancelled).ride;
    };
  }

  RideView _rideWith(RideView r, {required List<RideOffer> offers}) => RideView(
    id: r.id,
    status: r.status,
    pickup: r.pickup,
    dropoff: r.dropoff,
    offeredFareVnd: r.offeredFareVnd,
    referenceFareVnd: r.referenceFareVnd,
    agreedFareVnd: r.agreedFareVnd,
    assignedDriverId: r.assignedDriverId,
    selectedOfferId: r.selectedOfferId,
    expiresAt: r.expiresAt,
    offers: offers,
    vehicleClassCode: r.vehicleClassCode,
    serviceKind: 'PARCEL',
  );

  /// Test hook: put a parcel ride in the store (e.g. one already assigned to a driver).
  void seed(ParcelRide ride, {String? recipientCode}) {
    _rides[ride.ride.id] = ride;
    final code = recipientCode ?? ride.parcel.recipientCode;
    if (code != null) _codes[ride.ride.id] = code;
  }

  /// Server-side recipient codes (drivers never see them in the view).
  final Map<String, String> _codes = {};

  /// Mock `PARCEL_SERVICE_FEE_VND` / `PARCEL_RETURN_FEE_VND`.
  int serviceFeeVnd = 5000;
  int returnFeeVnd = 15000;

  @override
  Future<ParcelRide> get({
    required String accessToken,
    required String rideId,
  }) async => _require(rideId);

  @override
  Future<ParcelRide> pickup({
    required String accessToken,
    required String rideId,
    required ParcelPhoto photo,
    String? pickupCode,
  }) async {
    calls.add('pickup:$rideId');
    final p = _require(rideId).parcel;
    return _with(
      rideId,
      _copy(p, pickedUpAt: _now().toUtc().toIso8601String()),
      status: RideStatus.inTrip,
    );
  }

  @override
  Future<ParcelRide> deliver({
    required String accessToken,
    required String rideId,
    required ParcelPhoto photo,
    String? recipientCode,
  }) async {
    calls.add('deliver:$rideId:${recipientCode ?? ''}');
    final p = _require(rideId).parcel;
    final expected = _codes[rideId];
    if (expected != null && recipientCode?.trim() != expected) {
      throw const ApiException(
        statusCode: 400,
        message: 'Recipient code does not match',
        errorCode: 'PARCEL_CODE_INVALID',
      );
    }
    return _with(
      rideId,
      _copy(
        p,
        outcome: ParcelOutcome.delivered,
        deliveredAt: _now().toUtc().toIso8601String(),
      ),
      status: RideStatus.completed,
    );
  }

  @override
  Future<ParcelRide> fail({
    required String accessToken,
    required String rideId,
    required ParcelFailReason reason,
    String? note,
  }) async {
    calls.add('fail:$rideId:${reason.wire}');
    final p = _require(rideId).parcel;
    return _with(
      rideId,
      _copy(p, outcome: ParcelOutcome.returning, failReason: reason.wire),
    );
  }

  @override
  Future<ParcelRide> returned({
    required String accessToken,
    required String rideId,
    required ParcelPhoto photo,
  }) async {
    calls.add('returned:$rideId');
    final p = _require(rideId).parcel;
    return _with(
      rideId,
      _copy(
        p,
        outcome: ParcelOutcome.returned,
        returnedAt: _now().toUtc().toIso8601String(),
      ),
      status: RideStatus.completed,
    );
  }
}
