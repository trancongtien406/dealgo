import 'package:dealgo/features/rating/data/rating_remote_datasource.dart';
import 'package:dealgo/features/rating/domain/service_rating.dart';
import 'package:dealgo/features/rating/presentation/rate_service_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/auth_test_harness.dart';
import 'support/fake_identity_client.dart';

Future<FakeRatingRemoteDataSource> _openSheet(
  WidgetTester tester,
  RatingSubjectType type, {
  DateTime? rateableUntil,
}) async {
  final ratings = FakeRatingRemoteDataSource(rateableUntil: rateableUntil);
  await pumpSignedIn(tester, profile: customerProfile, ratings: ratings);
  showModalBottomSheet<ServiceRating>(
    context: tester.element(find.byType(Scaffold).first),
    isScrollControlled: true,
    builder: (_) =>
        RatingSheet(type: type, subjectId: 'subject-1', hasDriver: true),
  );
  await tester.pumpAndSettle();
  return ratings;
}

void main() {
  testWidgets('a ride rating needs driver stars and saves tags', (
    tester,
  ) async {
    final ratings = await _openSheet(tester, RatingSubjectType.ride);
    expect(find.text('Đánh giá chuyến đi'), findsOneWidget);
    expect(find.byKey(const Key('rate-store-stars')), findsNothing);
    // Food-only tags are hidden on a ride.
    expect(find.byKey(const Key('rate-tag-COLD_FOOD')), findsNothing);

    await tester.tap(find.byKey(const Key('rate-submit')));
    await tester.pumpAndSettle();
    expect(find.byType(RatingSheet), findsOneWidget);

    await tester.tap(find.byKey(const Key('rate-driver-stars-5')));
    await tester.tap(find.byKey(const Key('rate-tag-SAFE_DRIVING')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('rate-submit')));
    await tester.tap(find.byKey(const Key('rate-submit')));
    await tester.pumpAndSettle();

    expect(find.byType(RatingSheet), findsNothing);
    final status = await ratings.status(
      accessToken: 't',
      type: RatingSubjectType.ride,
      subjectId: 'subject-1',
    );
    expect(status.canRate, isFalse);
    expect(status.rating?.driverStars, 5);
    expect(status.rating?.tags, [RatingTag.safeDriving]);
  });

  testWidgets('a food rating also needs store stars', (tester) async {
    final ratings = await _openSheet(tester, RatingSubjectType.foodOrder);
    await tester.tap(find.byKey(const Key('rate-driver-stars-4')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('rate-submit')));
    await tester.tap(find.byKey(const Key('rate-submit')));
    await tester.pumpAndSettle();
    expect(find.byType(RatingSheet), findsOneWidget);

    await tester.tap(find.byKey(const Key('rate-store-stars-3')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('rate-submit')));
    await tester.tap(find.byKey(const Key('rate-submit')));
    await tester.pumpAndSettle();
    final status = await ratings.status(
      accessToken: 't',
      type: RatingSubjectType.foodOrder,
      subjectId: 'subject-1',
    );
    expect(status.rating?.storeStars, 3);
  });

  testWidgets('explains when the rating window has closed', (tester) async {
    final ratings = await _openSheet(
      tester,
      RatingSubjectType.ride,
      rateableUntil: DateTime.now().subtract(const Duration(hours: 1)),
    );
    await tester.tap(find.byKey(const Key('rate-driver-stars-5')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('rate-submit')));
    await tester.tap(find.byKey(const Key('rate-submit')));
    await tester.pumpAndSettle();
    expect(
      find.text('Đã quá hạn đánh giá cho chuyến/đơn này.'),
      findsOneWidget,
    );
    final status = await ratings.status(
      accessToken: 't',
      type: RatingSubjectType.ride,
      subjectId: 'subject-1',
    );
    expect(status.canRate, isFalse);
    expect(status.rating, isNull);
  });
}
