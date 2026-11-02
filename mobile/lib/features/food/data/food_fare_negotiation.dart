import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_mapper.dart';
import '../../pricing/domain/pricing.dart'
    show FoodDeliveryFeeMode, parseFoodDeliveryFeeMode;

/// Food delivery-fee negotiation (docs/02-domain/food-delivery-fee-negotiation.md).
///
/// The server only *suggests* the fee. The customer offers an amount; drivers
/// accept it (claim) or counter; the customer picks one counter and that fee
/// becomes the order's `deliveryFareVnd`.

enum FoodDeliveryOfferStatus { pending, selected, lost, withdrawn, expired }

FoodDeliveryOfferStatus _status(Object? raw) => switch (raw) {
  'SELECTED' => FoodDeliveryOfferStatus.selected,
  'LOST' => FoodDeliveryOfferStatus.lost,
  'WITHDRAWN' => FoodDeliveryOfferStatus.withdrawn,
  'EXPIRED' => FoodDeliveryOfferStatus.expired,
  _ => FoodDeliveryOfferStatus.pending,
};

class FoodDeliveryOffer {
  const FoodDeliveryOffer({
    required this.id,
    required this.driverId,
    required this.amountVnd,
    required this.status,
    this.driverName,
    this.expiresAt,
  });

  final String id;
  final String driverId;
  final String? driverName;
  final int amountVnd;
  final FoodDeliveryOfferStatus status;
  final DateTime? expiresAt;

  bool get isPending => status == FoodDeliveryOfferStatus.pending;
}

class FoodDeliveryOffers {
  const FoodDeliveryOffers({
    required this.orderId,
    required this.deliveryFareVnd,
    required this.suggestedDeliveryFareVnd,
    required this.raiseCount,
    required this.maxFareRaises,
    required this.fareStepVnd,
    required this.maxOfferVnd,
    required this.counterMaxVnd,
    required this.offers,
    this.agreedAt,
    this.feeMode = FoodDeliveryFeeMode.negotiate,
  });

  /// FIXED: drivers only accept the customer's fee (no counters to pick).
  final FoodDeliveryFeeMode feeMode;
  bool get driversCanCounter => feeMode == FoodDeliveryFeeMode.negotiate;

  final String orderId;

  /// Customer's current offer, or the agreed fee once [agreedAt] is set.
  final int deliveryFareVnd;
  final int suggestedDeliveryFareVnd;
  final DateTime? agreedAt;
  final int raiseCount;
  final int maxFareRaises;
  final int fareStepVnd;
  final int maxOfferVnd;
  final int counterMaxVnd;
  final List<FoodDeliveryOffer> offers;

  bool get agreed => agreedAt != null;
  int get raisesLeft =>
      (maxFareRaises - raiseCount).clamp(0, maxFareRaises).toInt();

  /// Next raise amount (one step), or null when no raise is allowed.
  int? get nextRaiseVnd {
    if (agreed || raisesLeft == 0) return null;
    final next = deliveryFareVnd + fareStepVnd;
    return next > maxOfferVnd ? null : next;
  }

  List<FoodDeliveryOffer> get pendingOffers =>
      offers.where((o) => o.isPending).toList(growable: false);
}

int _int(Object? v, [int fallback = 0]) => v is num ? v.toInt() : fallback;
DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v) : null;

FoodDeliveryOffers decodeFoodDeliveryOffers(Map<String, Object?> data) {
  final rawOffers = data['offers'];
  final fare = _int(data['deliveryFareVnd']);
  return FoodDeliveryOffers(
    orderId: data['orderId'] as String? ?? '',
    deliveryFareVnd: fare,
    suggestedDeliveryFareVnd: _int(data['suggestedDeliveryFareVnd'], fare),
    agreedAt: _date(data['deliveryFareAgreedAt'] ?? data['agreedAt']),
    raiseCount: _int(data['raiseCount']),
    maxFareRaises: _int(data['maxFareRaises']),
    fareStepVnd: _int(data['fareStepVnd'], 1000),
    maxOfferVnd: _int(data['maxOfferVnd'], fare),
    counterMaxVnd: _int(data['counterMaxVnd'], fare),
    feeMode: parseFoodDeliveryFeeMode(data['feeMode']),
    offers: [
      if (rawOffers is List)
        for (final o in rawOffers.whereType<Map<String, Object?>>())
          FoodDeliveryOffer(
            id: o['id'] as String? ?? '',
            driverId: o['driverId'] as String? ?? '',
            driverName: o['driverName'] as String?,
            amountVnd: _int(o['amountVnd']),
            status: _status(o['status']),
            expiresAt: _date(o['expiresAt']),
          ),
    ],
  );
}

abstract interface class FoodFareClient {
  Future<FoodDeliveryOffers> list({
    required String accessToken,
    required String orderId,
  });

  /// Driver counter-offer.
  Future<void> counter({
    required String accessToken,
    required String orderId,
    required int amountVnd,
  });

  Future<void> withdraw({required String accessToken, required String orderId});

  /// Customer picks a counter; the driver is assigned at that fee.
  Future<void> select({
    required String accessToken,
    required String orderId,
    required String offerId,
  });

  /// Customer raises their own offer.
  Future<void> raise({
    required String accessToken,
    required String orderId,
    required int amountVnd,
  });
}

String _base(String orderId) =>
    '/v1/food/orders/${Uri.encodeComponent(orderId)}';

class DioFoodFareClient implements FoodFareClient {
  DioFoodFareClient({required this.dio});

  final Dio dio;

  Options _auth(String t) => Options(headers: {'Authorization': 'Bearer $t'});

  Future<Object?> _send(Future<Response<Object?>> Function() send) async {
    try {
      return (await send()).data;
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }

  @override
  Future<FoodDeliveryOffers> list({
    required String accessToken,
    required String orderId,
  }) async {
    final body = await _send(
      () => dio.get<Object?>(
        '${_base(orderId)}/delivery-offers',
        options: _auth(accessToken),
      ),
    );
    return decodeFoodDeliveryOffers(requireSuccessData(body));
  }

  @override
  Future<void> counter({
    required String accessToken,
    required String orderId,
    required int amountVnd,
  }) => _send(
    () => dio.post<Object?>(
      '${_base(orderId)}/delivery-offers',
      data: {'amountVnd': amountVnd},
      options: _auth(accessToken),
    ),
  );

  @override
  Future<void> withdraw({
    required String accessToken,
    required String orderId,
  }) => _send(
    () => dio.delete<Object?>(
      '${_base(orderId)}/delivery-offers/mine',
      options: _auth(accessToken),
    ),
  );

  @override
  Future<void> select({
    required String accessToken,
    required String orderId,
    required String offerId,
  }) => _send(
    () => dio.post<Object?>(
      '${_base(orderId)}/delivery-offers/${Uri.encodeComponent(offerId)}/select',
      options: _auth(accessToken),
    ),
  );

  @override
  Future<void> raise({
    required String accessToken,
    required String orderId,
    required int amountVnd,
  }) => _send(
    () => dio.post<Object?>(
      '${_base(orderId)}/delivery-fare',
      data: {'amountVnd': amountVnd},
      options: _auth(accessToken),
    ),
  );
}

/// In-memory client for mock builds and tests.
class FakeFoodFareClient implements FoodFareClient {
  FakeFoodFareClient({
    this.fareVnd = 15000,
    List<FoodDeliveryOffer>? offers,
    this.feeMode = FoodDeliveryFeeMode.negotiate,
  }) : offers = offers ?? [];

  FoodDeliveryFeeMode feeMode;

  int fareVnd;
  int raiseCount = 0;
  DateTime? agreedAt;
  final List<FoodDeliveryOffer> offers;
  final List<String> calls = [];
  ApiException? failNext;

  void _maybeFail() {
    final f = failNext;
    if (f != null) {
      failNext = null;
      throw f;
    }
  }

  @override
  Future<FoodDeliveryOffers> list({
    required String accessToken,
    required String orderId,
  }) async {
    _maybeFail();
    return FoodDeliveryOffers(
      orderId: orderId,
      deliveryFareVnd: fareVnd,
      suggestedDeliveryFareVnd: 15000,
      agreedAt: agreedAt,
      raiseCount: raiseCount,
      maxFareRaises: 3,
      fareStepVnd: 1000,
      maxOfferVnd: 60000,
      counterMaxVnd: (fareVnd * 1.5).round(),
      feeMode: feeMode,
      offers: feeMode == FoodDeliveryFeeMode.fixed
          ? const []
          : List.unmodifiable(offers),
    );
  }

  @override
  Future<void> counter({
    required String accessToken,
    required String orderId,
    required int amountVnd,
  }) async {
    _maybeFail();
    calls.add('counter:$amountVnd');
    offers.add(
      FoodDeliveryOffer(
        id: 'offer-${offers.length + 1}',
        driverId: 'me',
        amountVnd: amountVnd,
        status: FoodDeliveryOfferStatus.pending,
      ),
    );
  }

  @override
  Future<void> withdraw({
    required String accessToken,
    required String orderId,
  }) async {
    _maybeFail();
    calls.add('withdraw');
  }

  @override
  Future<void> select({
    required String accessToken,
    required String orderId,
    required String offerId,
  }) async {
    _maybeFail();
    calls.add('select:$offerId');
    for (var i = 0; i < offers.length; i++) {
      final o = offers[i];
      offers[i] = FoodDeliveryOffer(
        id: o.id,
        driverId: o.driverId,
        driverName: o.driverName,
        amountVnd: o.amountVnd,
        status: o.id == offerId
            ? FoodDeliveryOfferStatus.selected
            : FoodDeliveryOfferStatus.lost,
      );
      if (o.id == offerId) fareVnd = o.amountVnd;
    }
    agreedAt = DateTime.now();
  }

  @override
  Future<void> raise({
    required String accessToken,
    required String orderId,
    required int amountVnd,
  }) async {
    _maybeFail();
    calls.add('raise:$amountVnd');
    fareVnd = amountVnd;
    raiseCount++;
  }
}

class FoodFareState {
  const FoodFareState({this.offers, this.loading = false, this.error});

  final FoodDeliveryOffers? offers;
  final bool loading;

  /// Last action error code (for a snackbar), cleared on the next action.
  final String? error;
}

/// Customer side of the negotiation on the waiting/tracking screen.
class FoodFareCubit extends Cubit<FoodFareState> {
  FoodFareCubit({
    required this.client,
    required this.orderId,
    required String Function() accessToken,
  }) : _token = accessToken,
       super(const FoodFareState());

  final FoodFareClient client;
  final String orderId;
  final String Function() _token;

  Future<void> refresh() async {
    try {
      final offers = await client.list(accessToken: _token(), orderId: orderId);
      if (!isClosed) emit(FoodFareState(offers: offers));
    } on ApiException catch (e) {
      if (!isClosed) {
        emit(FoodFareState(offers: state.offers, error: e.errorCode));
      }
    }
  }

  Future<bool> _act(Future<void> Function() action, String fallback) async {
    if (state.loading) return false;
    emit(FoodFareState(offers: state.offers, loading: true));
    try {
      await action();
      await refresh();
      return true;
    } on ApiException catch (e) {
      if (!isClosed) {
        emit(
          FoodFareState(
            offers: state.offers,
            error: e.errorCode.isEmpty ? fallback : e.errorCode,
          ),
        );
      }
      await refresh();
      return false;
    }
  }

  Future<bool> select(String offerId) => _act(
    () => client.select(
      accessToken: _token(),
      orderId: orderId,
      offerId: offerId,
    ),
    'SELECT_FAILED',
  );

  Future<bool> raise() {
    final next = state.offers?.nextRaiseVnd;
    if (next == null) return Future.value(false);
    return _act(
      () => client.raise(
        accessToken: _token(),
        orderId: orderId,
        amountVnd: next,
      ),
      'RAISE_FAILED',
    );
  }
}
