import 'package:dio/dio.dart';

import '../../../../core/network/api_envelope.dart';
import '../../../../core/network/api_paths.dart';
import '../../../../core/network/dio_mapper.dart';
import '../../domain/negotiation/ride_negotiation_client.dart';

/// REST commands for the negotiation/lifecycle actions.
class DioRideNegotiationClient implements RideNegotiationClient {
  DioRideNegotiationClient({required this.dio});

  final Dio dio;

  Options _bearer(String token) =>
      Options(headers: {'Authorization': 'Bearer $token'});

  Future<Object?> _post(String path, String token, [Object? body]) async {
    try {
      final response = await dio.post<Object?>(
        path,
        data: body,
        options: _bearer(token),
      );
      return response.data;
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }

  @override
  Future<void> raiseFare({
    required String accessToken,
    required String rideId,
    required int amountVnd,
  }) async {
    await _post(ApiPaths.rideFare(rideId), accessToken, {
      'amountVnd': amountVnd,
    });
  }

  @override
  Future<void> declineOffer({
    required String accessToken,
    required String rideId,
    required String offerId,
  }) async {
    await _post(ApiPaths.rideOfferDecline(rideId), accessToken, {
      'offerId': offerId,
    });
  }

  @override
  Future<void> withdrawOffer({
    required String accessToken,
    required String rideId,
  }) async {
    await _post(ApiPaths.rideOfferWithdraw(rideId), accessToken);
  }

  @override
  Future<void> driverCancel({
    required String accessToken,
    required String rideId,
    required DriverCancelReason reason,
  }) async {
    await _post(ApiPaths.rideDriverCancel(rideId), accessToken, {
      'reasonCode': reason.wire,
    });
  }

  @override
  Future<void> markNoShow({
    required String accessToken,
    required String rideId,
  }) async {
    await _post(ApiPaths.rideNoShow(rideId), accessToken);
  }

  @override
  Future<CustomerRatingEntry?> customerRating({
    required String accessToken,
    required String rideId,
  }) async {
    try {
      final response = await dio.get<Object?>(
        ApiPaths.rideCustomerRating(rideId),
        options: _bearer(accessToken),
      );
      return parseCustomerRatingEntry(readSuccessPayload(response.data));
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }

  @override
  Future<void> rateCustomer({
    required String accessToken,
    required String rideId,
    required int stars,
    List<String> tags = const [],
    String? comment,
  }) async {
    final note = comment?.trim();
    await _post(ApiPaths.rideCustomerRating(rideId), accessToken, {
      'stars': stars,
      if (tags.isNotEmpty) 'tags': tags,
      if (note != null && note.isNotEmpty) 'comment': note,
    });
  }

  @override
  Future<void> releaseFoodOrder({
    required String accessToken,
    required String orderId,
    required FoodReleaseReason reason,
  }) async {
    await _post(ApiPaths.foodOrderRelease(orderId), accessToken, {
      'reasonCode': reason.wire,
    });
  }
}

/// `{rating: {stars, tags, comment} | null, customer: {...}}` → the driver's entry.
CustomerRatingEntry? parseCustomerRatingEntry(Object? data) {
  final map = asJsonMap(data);
  final rating = asJsonMap(map?['rating']);
  if (rating == null) {
    return null;
  }
  final stars = rating['stars'];
  if (stars is! num) {
    return null;
  }
  final tags = rating['tags'];
  final comment = rating['comment'];
  return CustomerRatingEntry(
    stars: stars.toInt(),
    tags: tags is List
        ? [
            for (final t in tags)
              if (t is String) t,
          ]
        : const [],
    comment: comment is String ? comment : null,
  );
}

/// Offline/mock client: records calls, never fails unless [failWith] is set.
class FakeRideNegotiationClient implements RideNegotiationClient {
  FakeRideNegotiationClient({this.failWith});

  Object? failWith;
  final calls = <String>[];
  final _ratings = <String, CustomerRatingEntry>{};

  void _record(String call) {
    calls.add(call);
    final failure = failWith;
    if (failure != null) {
      throw failure;
    }
  }

  @override
  Future<void> raiseFare({
    required String accessToken,
    required String rideId,
    required int amountVnd,
  }) async => _record('raiseFare:$rideId:$amountVnd');

  @override
  Future<void> declineOffer({
    required String accessToken,
    required String rideId,
    required String offerId,
  }) async => _record('declineOffer:$rideId:$offerId');

  @override
  Future<void> withdrawOffer({
    required String accessToken,
    required String rideId,
  }) async => _record('withdrawOffer:$rideId');

  @override
  Future<void> driverCancel({
    required String accessToken,
    required String rideId,
    required DriverCancelReason reason,
  }) async => _record('driverCancel:$rideId:${reason.wire}');

  @override
  Future<void> markNoShow({
    required String accessToken,
    required String rideId,
  }) async => _record('markNoShow:$rideId');

  @override
  Future<CustomerRatingEntry?> customerRating({
    required String accessToken,
    required String rideId,
  }) async {
    _record('customerRating:$rideId');
    return _ratings[rideId];
  }

  @override
  Future<void> rateCustomer({
    required String accessToken,
    required String rideId,
    required int stars,
    List<String> tags = const [],
    String? comment,
  }) async {
    _record('rateCustomer:$rideId:$stars');
    _ratings[rideId] = CustomerRatingEntry(
      stars: stars,
      tags: tags,
      comment: comment,
    );
  }

  @override
  Future<void> releaseFoodOrder({
    required String accessToken,
    required String orderId,
    required FoodReleaseReason reason,
  }) async => _record('releaseFoodOrder:$orderId:${reason.wire}');
}
