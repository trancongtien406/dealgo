import 'package:dio/dio.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_paths.dart';
import '../../../core/network/dio_mapper.dart';
import '../domain/parcel_client.dart';
import '../domain/parcel_models.dart';
import 'parcel_json.dart';

class DioParcelClient implements ParcelClient {
  DioParcelClient({required this.dio});

  final Dio dio;

  Options _bearer(String token, {String? idempotencyKey}) => Options(
    headers: {
      'Authorization': 'Bearer $token',
      'Idempotency-Key': ?idempotencyKey,
    },
  );

  Future<T> _send<T>(
    Future<Response<Object?>> Function() send,
    T Function(Object?) parse,
  ) async {
    try {
      final response = await send();
      return parse(response.data);
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }

  @override
  Future<List<ParcelSizeClass>> sizeClasses({required String accessToken}) =>
      _send(
        () => dio.get<Object?>(
          ApiPaths.parcelSizeClasses,
          options: _bearer(accessToken),
        ),
        parseParcelSizeClasses,
      );

  @override
  Future<ParcelQuote> quote({
    required String accessToken,
    required ParcelDraft draft,
  }) => _send(
    () => dio.post<Object?>(
      ApiPaths.parcelQuote,
      data: parcelQuoteBody(draft),
      options: _bearer(accessToken),
    ),
    (body) => parseParcelQuote(requireSuccessData(body)),
  );

  @override
  Future<ParcelRide> create({
    required String accessToken,
    required String idempotencyKey,
    required ParcelDraft draft,
    required String vehicleClassCode,
    required int offeredFareVnd,
  }) {
    final key = idempotencyKey.trim();
    if (key.length < 8 || key.length > 200) {
      throw const ApiException(
        statusCode: 400,
        message: 'Idempotency-Key must be 8 to 200 characters',
        errorCode: 'VALIDATION_ERROR',
      );
    }
    return _send(
      () => dio.post<Object?>(
        ApiPaths.parcels,
        data: parcelCreateBody(
          draft,
          vehicleClassCode: vehicleClassCode,
          offeredFareVnd: offeredFareVnd,
        ),
        options: _bearer(accessToken, idempotencyKey: key),
      ),
      parseParcelRide,
    );
  }

  @override
  Future<ParcelRide> get({
    required String accessToken,
    required String rideId,
  }) => _send(
    () => dio.get<Object?>(
      ApiPaths.parcel(rideId),
      options: _bearer(accessToken),
    ),
    parseParcelRide,
  );

  Future<ParcelRide> _action(
    String accessToken,
    String rideId,
    String action,
    Map<String, Object?> body,
  ) => _send(
    () => dio.post<Object?>(
      ApiPaths.parcelAction(rideId, action),
      data: body,
      options: _bearer(accessToken),
    ),
    parseParcelRide,
  );

  @override
  Future<ParcelRide> pickup({
    required String accessToken,
    required String rideId,
    required ParcelPhoto photo,
    String? pickupCode,
  }) => _action(accessToken, rideId, 'pickup', {
    'photo': photo.toJson(),
    if ((pickupCode ?? '').trim().isNotEmpty) 'pickupCode': pickupCode!.trim(),
  });

  @override
  Future<ParcelRide> deliver({
    required String accessToken,
    required String rideId,
    required ParcelPhoto photo,
    String? recipientCode,
  }) => _action(accessToken, rideId, 'deliver', {
    'photo': photo.toJson(),
    if ((recipientCode ?? '').trim().isNotEmpty)
      'recipientCode': recipientCode!.trim(),
  });

  @override
  Future<ParcelRide> fail({
    required String accessToken,
    required String rideId,
    required ParcelFailReason reason,
    String? note,
  }) => _action(accessToken, rideId, 'fail', {
    'reason': reason.wire,
    if ((note ?? '').trim().isNotEmpty) 'note': note!.trim(),
  });

  @override
  Future<ParcelRide> returned({
    required String accessToken,
    required String rideId,
    required ParcelPhoto photo,
  }) => _action(accessToken, rideId, 'returned', {'photo': photo.toJson()});
}
