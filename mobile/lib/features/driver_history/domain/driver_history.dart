enum DriverJobKind {
  ride('RIDE'),
  food('FOOD_ORDER');

  const DriverJobKind(this.wire);

  final String wire;

  static DriverJobKind? fromWire(Object? raw) {
    for (final kind in values) {
      if (kind.wire == raw) {
        return kind;
      }
    }
    return null;
  }
}

enum DriverJobOutcome {
  completed('COMPLETED'),
  cancelled('CANCELLED'),
  failed('FAILED');

  const DriverJobOutcome(this.wire);

  final String wire;

  static DriverJobOutcome fromWire(Object? raw) => values.firstWhere(
    (outcome) => outcome.wire == raw,
    orElse: () => DriverJobOutcome.cancelled,
  );
}

/// `null` filter = all jobs.
typedef DriverHistoryFilter = DriverJobKind?;

class DriverHistoryItem {
  const DriverHistoryItem({
    required this.kind,
    required this.id,
    required this.outcome,
    required this.fareVnd,
    required this.earningsVnd,
    required this.dropoffLabel,
    required this.finishedAt,
    this.feeVnd = 0,
    this.feePercent,
    this.pickupLabel,
    this.storeName,
    this.driverStars,
  });

  final DriverJobKind kind;
  final String id;
  final DriverJobOutcome outcome;
  final int fareVnd;

  /// Platform fee withheld, snapshotted at completion (DEC-PROD-014).
  final int feeVnd;

  /// Fee rate in force at completion; null when the job did not complete.
  final double? feePercent;

  /// Net = fareVnd − feeVnd for completed jobs, else 0.
  final int earningsVnd;
  final String? pickupLabel;
  final String dropoffLabel;
  final String? storeName;
  final DateTime finishedAt;
  final int? driverStars;
}

class DriverHistoryPage {
  const DriverHistoryPage({required this.items, this.nextCursor});

  final List<DriverHistoryItem> items;
  final String? nextCursor;
}

class DriverDaySummary {
  const DriverDaySummary({
    required this.date,
    required this.completedJobs,
    required this.earningsVnd,
    this.grossVnd = 0,
    this.feeVnd = 0,
  });

  /// Calendar day in Asia/Ho_Chi_Minh.
  final DateTime date;
  final int completedJobs;
  final int grossVnd;
  final int feeVnd;

  /// Net earnings (gross − platform fee).
  final int earningsVnd;
}

class DriverHistorySummary {
  const DriverHistorySummary({
    required this.today,
    required this.days,
    required this.weekCompletedJobs,
    required this.weekCancelledJobs,
    required this.weekEarningsVnd,
    required this.weekRideEarningsVnd,
    required this.weekFoodEarningsVnd,
    required this.ratingCount,
    this.weekGrossVnd = 0,
    this.weekFeeVnd = 0,
    this.ratingAverage,
  });

  final DriverDaySummary today;
  final List<DriverDaySummary> days;
  final int weekCompletedJobs;
  final int weekCancelledJobs;
  final int weekGrossVnd;
  final int weekFeeVnd;

  /// Net earnings for the week (gross − platform fee).
  final int weekEarningsVnd;
  final int weekRideEarningsVnd;
  final int weekFoodEarningsVnd;
  final double? ratingAverage;
  final int ratingCount;
}

abstract interface class DriverHistoryRepository {
  Future<DriverHistorySummary> summary({required String accessToken});

  Future<DriverHistoryPage> list({
    required String accessToken,
    DriverHistoryFilter kind,
    String? cursor,
    int limit,
  });
}
