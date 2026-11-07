enum RatingSubjectType {
  ride('RIDE'),
  foodOrder('FOOD_ORDER');

  const RatingSubjectType(this.wire);

  final String wire;
}

/// Quick-pick tags; wire values match the API.
enum RatingTag {
  onTime('ON_TIME', positive: true),
  friendly('FRIENDLY', positive: true),
  safeDriving('SAFE_DRIVING', positive: true, ride: true),
  cleanVehicle('CLEAN_VEHICLE', positive: true, ride: true),
  tastyFood('TASTY_FOOD', positive: true, food: true),
  wellPacked('WELL_PACKED', positive: true, food: true),
  late('LATE'),
  rude('RUDE'),
  unsafeDriving('UNSAFE_DRIVING', ride: true),
  wrongItems('WRONG_ITEMS', food: true),
  coldFood('COLD_FOOD', food: true);

  const RatingTag(
    this.wire, {
    this.positive = false,
    bool ride = false,
    bool food = false,
  }) : rideOnly = ride,
       foodOnly = food;

  final String wire;
  final bool positive;
  final bool rideOnly;
  final bool foodOnly;

  bool appliesTo(RatingSubjectType type) => switch (type) {
    RatingSubjectType.ride => !foodOnly,
    RatingSubjectType.foodOrder => !rideOnly,
  };

  static RatingTag? fromWire(Object? value) {
    for (final tag in values) {
      if (tag.wire == value) {
        return tag;
      }
    }
    return null;
  }
}

class ServiceRating {
  const ServiceRating({
    required this.driverStars,
    required this.storeStars,
    required this.tags,
    this.comment,
  });

  final int? driverStars;
  final int? storeStars;
  final List<RatingTag> tags;
  final String? comment;
}

class RatingStatus {
  const RatingStatus({
    required this.rating,
    required this.canRate,
    this.rateableUntil,
  });

  final ServiceRating? rating;
  final bool canRate;

  /// Last moment a rating is accepted (completion + RATING_WINDOW_DAYS).
  final DateTime? rateableUntil;
}

class RatingSubmission {
  const RatingSubmission({
    required this.type,
    required this.subjectId,
    this.driverStars,
    this.storeStars,
    this.tags = const [],
    this.comment,
  });

  final RatingSubjectType type;
  final String subjectId;
  final int? driverStars;
  final int? storeStars;
  final List<RatingTag> tags;
  final String? comment;

  Map<String, Object?> toJson() => {
    'subjectType': type.wire,
    'subjectId': subjectId,
    'driverStars': ?driverStars,
    'storeStars': ?storeStars,
    if (tags.isNotEmpty) 'tags': [for (final tag in tags) tag.wire],
    if (comment != null && comment!.trim().isNotEmpty)
      'comment': comment!.trim(),
  };
}

/// Public rating of a store. [average] stays null until the backend has
/// enough ratings (RATING_STORE_MIN_COUNT), so one customer's stars stay private.
class StoreRating {
  const StoreRating({
    required this.storeId,
    required this.count,
    this.average,
    this.distribution,
  });

  final String storeId;
  final int count;
  final double? average;

  /// Count per star (index 0 = 1 star); null while the average is hidden.
  final List<int>? distribution;
}

class StoreReview {
  const StoreReview({
    required this.stars,
    required this.tags,
    required this.createdAt,
    this.id = '',
    this.comment,
    this.merchantReply,
    this.repliedAt,
    this.hidden = false,
  });

  final String id;
  final int stars;
  final List<RatingTag> tags;
  final String? comment;
  final DateTime createdAt;

  /// The store's public answer; null = not answered.
  final String? merchantReply;
  final DateTime? repliedAt;

  /// Hidden by DealGo moderation (merchant view only).
  final bool hidden;

  StoreReview withReply(String? reply, DateTime? at) => StoreReview(
    id: id,
    stars: stars,
    tags: tags,
    createdAt: createdAt,
    comment: comment,
    merchantReply: reply,
    repliedAt: at,
    hidden: hidden,
  );
}

class StoreReviews {
  const StoreReviews({
    required this.summary,
    required this.items,
    this.page = 1,
    this.hasMore = false,
  });

  final StoreRating summary;

  /// Empty until the store has enough ratings to be shown.
  final List<StoreReview> items;
  final int page;
  final bool hasMore;
}

/// The merchant's own review inbox (includes hidden reviews, flagged).
class MerchantReviews {
  const MerchantReviews({
    required this.summary,
    required this.items,
    required this.total,
    required this.page,
  });

  final StoreRating summary;
  final List<StoreReview> items;
  final int total;
  final int page;

  bool get hasMore => page * 20 < total;
}

enum MerchantReviewReplyFilter {
  all,
  replied,
  unreplied;

  String? get wire => switch (this) {
    MerchantReviewReplyFilter.all => null,
    MerchantReviewReplyFilter.replied => 'REPLIED',
    MerchantReviewReplyFilter.unreplied => 'UNREPLIED',
  };
}

enum MerchantReviewVisibilityFilter {
  all,
  visible,
  hidden;

  String? get wire => switch (this) {
    MerchantReviewVisibilityFilter.all => null,
    MerchantReviewVisibilityFilter.visible => 'VISIBLE',
    MerchantReviewVisibilityFilter.hidden => 'HIDDEN',
  };
}

enum MerchantReviewSort {
  newest,
  oldest,
  lowestStars,
  highestStars;

  String get wire => switch (this) {
    MerchantReviewSort.newest => 'NEWEST',
    MerchantReviewSort.oldest => 'OLDEST',
    MerchantReviewSort.lowestStars => 'LOWEST_STARS',
    MerchantReviewSort.highestStars => 'HIGHEST_STARS',
  };
}

abstract interface class RatingRepository {
  Future<StoreReviews> storeReviews({
    required String accessToken,
    required String storeId,
    int page = 1,
    int? stars,
  });

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
  });

  /// Empty [text] clears the reply.
  Future<StoreReview> replyToReview({
    required String accessToken,
    required String reviewId,
    required String text,
  });

  /// Summaries for up to 50 stores; unknown ids come back with count 0.
  Future<Map<String, StoreRating>> storeRatings({
    required String accessToken,
    required List<String> storeIds,
  });

  Future<RatingStatus> status({
    required String accessToken,
    required RatingSubjectType type,
    required String subjectId,
  });

  Future<ServiceRating> submit({
    required String accessToken,
    required RatingSubmission submission,
  });
}
