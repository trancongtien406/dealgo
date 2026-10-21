import 'package:dio/dio.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_paths.dart';
import '../../../core/network/dio_mapper.dart';
import '../domain/service_rating.dart';

class DioRatingRemoteDataSource implements RatingRepository {
  DioRatingRemoteDataSource({required this.dio});

  final Dio dio;

  Options _auth(String token) =>
      Options(headers: {'Authorization': 'Bearer $token'});

  @override
  Future<Map<String, StoreRating>> storeRatings({
    required String accessToken,
    required List<String> storeIds,
  }) async {
    final ids = storeIds.toSet().take(50).toList();
    if (ids.isEmpty) {
      return const {};
    }
    try {
      final response = await dio.get<Object?>(
        ApiPaths.storeRatings,
        queryParameters: {'ids': ids.join(',')},
        options: _auth(accessToken),
      );
      final data = readSuccessPayload(response.data);
      if (data is! List) {
        throw const ApiException(
          statusCode: 200,
          message: 'Invalid response',
          errorCode: 'INVALID_RESPONSE',
        );
      }
      final ratings = [for (final raw in data) ?decodeStoreRating(raw)];
      return {for (final rating in ratings) rating.storeId: rating};
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }

  @override
  Future<StoreReviews> storeReviews({
    required String accessToken,
    required String storeId,
  }) async {
    try {
      final response = await dio.get<Object?>(
        ApiPaths.storeReviews(storeId),
        options: _auth(accessToken),
      );
      final data = requireSuccessData(response.data);
      final summary = decodeStoreRating(data['summary']);
      if (summary == null) {
        throw const ApiException(
          statusCode: 200,
          message: 'Invalid response',
          errorCode: 'INVALID_RESPONSE',
        );
      }
      final rawItems = data['items'];
      return StoreReviews(
        summary: summary,
        items: [
          if (rawItems is List)
            for (final raw in rawItems) ?decodeStoreReview(raw),
        ],
      );
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }

  @override
  Future<RatingStatus> status({
    required String accessToken,
    required RatingSubjectType type,
    required String subjectId,
  }) async {
    try {
      final response = await dio.get<Object?>(
        ApiPaths.rating(type.wire, subjectId),
        options: _auth(accessToken),
      );
      final data = requireSuccessData(response.data);
      return RatingStatus(
        rating: decodeServiceRating(data['rating']),
        canRate: data['canRate'] == true,
        rateableUntil: DateTime.tryParse('${data['rateableUntil'] ?? ''}')
            ?.toLocal(),
      );
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }

  @override
  Future<ServiceRating> submit({
    required String accessToken,
    required RatingSubmission submission,
  }) async {
    try {
      final response = await dio.post<Object?>(
        ApiPaths.ratings,
        data: submission.toJson(),
        options: _auth(accessToken),
      );
      final rating = decodeServiceRating(requireSuccessData(response.data));
      if (rating == null) {
        throw const ApiException(
          statusCode: 200,
          message: 'Invalid response',
          errorCode: 'INVALID_RESPONSE',
        );
      }
      return rating;
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }
}

StoreReview? decodeStoreReview(Object? raw) {
  final map = asJsonMap(raw);
  final stars = map?['stars'];
  final createdAt = DateTime.tryParse('${map?['createdAt'] ?? ''}');
  if (map == null || stars is! num || createdAt == null) {
    return null;
  }
  final tags = map['tags'];
  final comment = map['comment'];
  return StoreReview(
    stars: stars.toInt(),
    tags: [
      if (tags is List)
        for (final tag in tags) ?RatingTag.fromWire(tag),
    ],
    comment: comment is String && comment.trim().isNotEmpty ? comment : null,
    createdAt: createdAt.toLocal(),
  );
}

StoreRating? decodeStoreRating(Object? raw) {
  final map = asJsonMap(raw);
  final id = map?['storeId'];
  if (map == null || id is! String || id.isEmpty) {
    return null;
  }
  final count = map['count'];
  final average = map['average'];
  return StoreRating(
    storeId: id,
    count: count is num ? count.toInt() : 0,
    average: average is num ? average.toDouble() : null,
  );
}

ServiceRating? decodeServiceRating(Object? raw) {
  final map = asJsonMap(raw);
  if (map == null) {
    return null;
  }
  int? stars(String key) {
    final value = map[key];
    return value is num ? value.toInt() : null;
  }

  final tags = map['tags'];
  final comment = map['comment'];
  return ServiceRating(
    driverStars: stars('driverStars'),
    storeStars: stars('storeStars'),
    tags: [
      if (tags is List)
        for (final tag in tags) ?RatingTag.fromWire(tag),
    ],
    comment: comment is String && comment.isNotEmpty ? comment : null,
  );
}

/// In-memory ratings for tests, screenshots and mock builds.
class FakeRatingRemoteDataSource implements RatingRepository {
  FakeRatingRemoteDataSource({
    this.rateable = true,
    this.rateableUntil,
    Map<String, StoreRating>? stores,
    Map<String, List<StoreReview>>? reviews,
  }) : stores = stores ?? {},
       reviews = reviews ?? {};

  /// Reviews returned by [storeReviews] when the store's average is visible.
  final Map<String, List<StoreReview>> reviews;

  /// Store summaries returned by [storeRatings]; missing ids report count 0.
  final Map<String, StoreRating> stores;

  /// When false, subjects report `canRate: false` (e.g. unfinished trips).
  final bool rateable;

  /// Simulated rating window end; null = no deadline shown.
  final DateTime? rateableUntil;

  bool get _expired {
    final until = rateableUntil;
    return until != null && DateTime.now().isAfter(until);
  }

  final Map<String, ServiceRating> _ratings = {};

  @override
  Future<Map<String, StoreRating>> storeRatings({
    required String accessToken,
    required List<String> storeIds,
  }) async {
    return {
      for (final id in storeIds)
        id: stores[id] ?? StoreRating(storeId: id, count: 0),
    };
  }

  @override
  Future<StoreReviews> storeReviews({
    required String accessToken,
    required String storeId,
  }) async {
    final summary = stores[storeId] ?? StoreRating(storeId: storeId, count: 0);
    return StoreReviews(
      summary: summary,
      items: summary.average == null ? const [] : reviews[storeId] ?? const [],
    );
  }

  @override
  Future<RatingStatus> status({
    required String accessToken,
    required RatingSubjectType type,
    required String subjectId,
  }) async {
    final rating = _ratings['${type.wire}:$subjectId'];
    return RatingStatus(
      rating: rating,
      canRate: rating == null && rateable && !_expired,
      rateableUntil: rateableUntil,
    );
  }

  @override
  Future<ServiceRating> submit({
    required String accessToken,
    required RatingSubmission submission,
  }) async {
    final key = '${submission.type.wire}:${submission.subjectId}';
    if (_expired) {
      throw const ApiException(
        statusCode: 422,
        message: 'RATING_WINDOW_EXPIRED',
        errorCode: 'RATING_WINDOW_EXPIRED',
      );
    }
    if (_ratings.containsKey(key)) {
      throw const ApiException(
        statusCode: 409,
        message: 'RATING_ALREADY_SUBMITTED',
        errorCode: 'RATING_ALREADY_SUBMITTED',
      );
    }
    final rating = ServiceRating(
      driverStars: submission.driverStars,
      storeStars: submission.storeStars,
      tags: submission.tags,
      comment: submission.comment,
    );
    _ratings[key] = rating;
    return rating;
  }
}
