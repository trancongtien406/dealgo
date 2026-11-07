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
    int? stars,
    MerchantReviewReplyFilter replied = MerchantReviewReplyFilter.all,
    bool? hasComment,
    MerchantReviewVisibilityFilter visibility =
        MerchantReviewVisibilityFilter.all,
    RatingTag? tag,
    String? q,
    DateTime? from,
    DateTime? to,
    MerchantReviewSort sort = MerchantReviewSort.newest,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        if (page > 1) 'page': page,
        'stars': ?stars,
        'replied': ?replied.wire,
        'hasComment': ?hasComment,
        'visibility': ?visibility.wire,
        'tag': ?tag?.wire,
        if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
        'from': ?from?.toIso8601String(),
        'to': ?to?.toIso8601String(),
        if (sort != MerchantReviewSort.newest) 'sort': sort.wire,
      };
      final response = await dio.get<Object?>(
        ApiPaths.foodMerchantReviews,
        queryParameters: queryParams,
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

String _foldText(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[àáạảãâầấậẩẫăằắặẳẵ]'), 'a')
      .replaceAll(RegExp(r'[èéẹẻẽêềếệểễ]'), 'e')
      .replaceAll(RegExp(r'[ìíịỉĩ]'), 'i')
      .replaceAll(RegExp(r'[òóọỏõôồốộổỗơờớợởỡ]'), 'o')
      .replaceAll(RegExp(r'[ùúụủũưừứựửữ]'), 'u')
      .replaceAll(RegExp(r'[ỳýỵỷỹ]'), 'y')
      .replaceAll('đ', 'd');
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
    int? stars,
    MerchantReviewReplyFilter replied = MerchantReviewReplyFilter.all,
    bool? hasComment,
    MerchantReviewVisibilityFilter visibility =
        MerchantReviewVisibilityFilter.all,
    RatingTag? tag,
    String? q,
    DateTime? from,
    DateTime? to,
    MerchantReviewSort sort = MerchantReviewSort.newest,
  }) async {
    var all = List<StoreReview>.from(
      reviews[merchantStoreId] ?? const <StoreReview>[],
    );
    if (stars != null) {
      all = all.where((r) => r.stars == stars).toList();
    }
    if (replied == MerchantReviewReplyFilter.replied) {
      all = all
          .where((r) => r.merchantReply != null && r.merchantReply!.trim().isNotEmpty)
          .toList();
    } else if (replied == MerchantReviewReplyFilter.unreplied) {
      all = all
          .where((r) => r.merchantReply == null || r.merchantReply!.trim().isEmpty)
          .toList();
    }
    if (hasComment == true) {
      all = all
          .where((r) => r.comment != null && r.comment!.trim().isNotEmpty)
          .toList();
    } else if (hasComment == false) {
      all = all
          .where((r) => r.comment == null || r.comment!.trim().isEmpty)
          .toList();
    }
    if (visibility == MerchantReviewVisibilityFilter.visible) {
      all = all.where((r) => !r.hidden).toList();
    } else if (visibility == MerchantReviewVisibilityFilter.hidden) {
      all = all.where((r) => r.hidden).toList();
    }
    if (tag != null) {
      all = all.where((r) => r.tags.contains(tag)).toList();
    }
    if (q != null && q.trim().isNotEmpty) {
      final needle = _foldText(q.trim());
      all = all
          .where(
            (r) =>
                (r.comment != null && _foldText(r.comment!).contains(needle)) ||
                (r.merchantReply != null &&
                    _foldText(r.merchantReply!).contains(needle)),
          )
          .toList();
    }
    if (from != null) {
      all = all
          .where((r) => r.createdAt.isAfter(from) || r.createdAt.isAtSameMomentAs(from))
          .toList();
    }
    if (to != null) {
      all = all
          .where((r) => r.createdAt.isBefore(to) || r.createdAt.isAtSameMomentAs(to))
          .toList();
    }
    switch (sort) {
      case MerchantReviewSort.newest:
        all.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case MerchantReviewSort.oldest:
        all.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      case MerchantReviewSort.lowestStars:
        all.sort((a, b) {
          final cmp = a.stars.compareTo(b.stars);
          return cmp != 0 ? cmp : b.createdAt.compareTo(a.createdAt);
        });
      case MerchantReviewSort.highestStars:
        all.sort((a, b) {
          final cmp = b.stars.compareTo(a.stars);
          return cmp != 0 ? cmp : b.createdAt.compareTo(a.createdAt);
        });
    }
    return MerchantReviews(
      summary:
          stores[merchantStoreId] ??
          StoreRating(
            storeId: merchantStoreId,
            count: (reviews[merchantStoreId] ?? const <StoreReview>[]).length,
          ),
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
