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
    int page = 1,
    int? stars,
  }) async {
    try {
      final response = await dio.get<Object?>(
        ApiPaths.storeReviews(storeId),
        queryParameters: {if (page > 1) 'page': page, 'stars': ?stars},
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
      final rawPage = data['page'];
      return StoreReviews(
        summary: summary,
        items: [
          if (rawItems is List)
            for (final raw in rawItems) ?decodeStoreReview(raw),
        ],
        page: rawPage is num ? rawPage.toInt() : page,
        hasMore: data['hasMore'] == true,
      );
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }

  @override
  Future<MerchantReviews> merchantReviews({
    required String accessToken,
    int page = 1,
  }) async {
    try {
      final response = await dio.get<Object?>(
        ApiPaths.foodMerchantReviews,
        queryParameters: {if (page > 1) 'page': page},
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
      final total = data['total'];
      return MerchantReviews(
        summary: summary,
        items: [
          if (rawItems is List)
            for (final raw in rawItems) ?decodeStoreReview(raw),
        ],
        total: total is num ? total.toInt() : 0,
        page: page,
      );
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }

  @override
  Future<StoreReview> replyToReview({
    required String accessToken,
    required String reviewId,
    required String text,
  }) async {
    try {
      final response = await dio.put<Object?>(
        ApiPaths.foodMerchantReviewReply(reviewId),
        data: {'text': text},
        options: _auth(accessToken),
      );
      final review = decodeStoreReview(requireSuccessData(response.data));
      if (review == null) {
        throw const ApiException(
          statusCode: 200,
          message: 'Invalid response',
          errorCode: 'INVALID_RESPONSE',
        );
      }
      return review;
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
  final id = map['id'];
  final reply = map['merchantReply'];
  return StoreReview(
    id: id is String ? id : '',
    merchantReply: reply is String && reply.trim().isNotEmpty ? reply : null,
    repliedAt: DateTime.tryParse('${map['repliedAt'] ?? ''}')?.toLocal(),
    hidden: map['hidden'] == true,
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
  final distribution = map['distribution'];
  return StoreRating(
    storeId: id,
    count: count is num ? count.toInt() : 0,
    average: average is num ? average.toDouble() : null,
    distribution: distribution is List && distribution.length == 5
        ? [for (final n in distribution) n is num ? n.toInt() : 0]
        : null,
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
    int page = 1,
    int? stars,
  }) async {
    final summary = stores[storeId] ?? StoreRating(storeId: storeId, count: 0);
    final all = summary.average == null
        ? const <StoreReview>[]
        : [
            for (final r in reviews[storeId] ?? const <StoreReview>[])
              if (!r.hidden && (stars == null || r.stars == stars)) r,
          ];
    final start = (page - 1) * 20;
    return StoreReviews(
      summary: summary,
      items: all.skip(start).take(20).toList(growable: false),
      page: page,
      hasMore: all.length > start + 20,
    );
  }

  /// Store whose inbox [merchantReviews] serves.
  String merchantStoreId = 'store-1';

  @override
  Future<MerchantReviews> merchantReviews({
    required String accessToken,
    int page = 1,
  }) async {
    final all = reviews[merchantStoreId] ?? const <StoreReview>[];
    return MerchantReviews(
      summary:
          stores[merchantStoreId] ??
          StoreRating(storeId: merchantStoreId, count: all.length),
      items: all.skip((page - 1) * 20).take(20).toList(growable: false),
      total: all.length,
      page: page,
    );
  }

  @override
  Future<StoreReview> replyToReview({
    required String accessToken,
    required String reviewId,
    required String text,
  }) async {
    final list = reviews[merchantStoreId] ?? <StoreReview>[];
    final index = list.indexWhere((r) => r.id == reviewId);
    if (index < 0) {
      throw const ApiException(
        statusCode: 404,
        message: 'RATING_NOT_FOUND',
        errorCode: 'RATING_NOT_FOUND',
      );
    }
    final trimmed = text.trim();
    final updated = list[index].withReply(
      trimmed.isEmpty ? null : trimmed,
      trimmed.isEmpty ? null : DateTime.now(),
    );
    reviews[merchantStoreId] = [...list]..[index] = updated;
    return updated;
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
