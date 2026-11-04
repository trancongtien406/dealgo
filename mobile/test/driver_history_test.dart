import 'package:dealgo/core/network/api_exception.dart';
import 'package:dealgo/features/driver_history/data/driver_history_remote_datasource.dart';
import 'package:dealgo/features/driver_history/domain/driver_history.dart';
import 'package:dealgo/features/identity/domain/entities/user_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/auth_test_harness.dart';

const _driverProfile = UserProfile(
  id: 'driver-1',
  phone: '+84933333333',
  email: null,
  phoneVerifiedAt: '2026-10-13T16:00:00.000Z',
  emailVerifiedAt: null,
  grants: [RoleGrant(role: 'DRIVER', status: 'ACTIVE')],
);

Future<void> _openEarnings(
  WidgetTester tester,
  FakeDriverHistoryRemoteDataSource history,
) async {
  await pumpSignedIn(tester, profile: _driverProfile, driverHistory: history);
  await tester.tap(navLabel('Thu nhập'));
  await tester.pumpAndSettle();
}

List<DriverHistoryItem> _many(int count, DateTime now) => [
  for (var i = 0; i < count; i++)
    DriverHistoryItem(
      kind: i.isEven ? DriverJobKind.ride : DriverJobKind.food,
      id: 'job-$i',
      outcome: DriverJobOutcome.completed,
      fareVnd: 10000,
      earningsVnd: 10000,
      pickupLabel: 'Điểm $i',
      dropoffLabel: 'Đích $i',
      finishedAt: now.subtract(Duration(minutes: i)),
    ),
];

final _list = find
    .descendant(
      of: find.byKey(const Key('driver-history-list')),
      matching: find.byType(Scrollable),
    )
    .first;

void main() {
  testWidgets('shows today earnings, rating and the job history', (
    tester,
  ) async {
    // Fixed clock: the summary windows must not depend on the device date.
    final now = DateTime(2026, 10, 21, 15);
    final history = FakeDriverHistoryRemoteDataSource(
      seed: FakeDriverHistoryRemoteDataSource.sample(now),
      now: now,
    );
    await _openEarnings(tester, history);

    expect(find.text('Thu nhập & lịch sử'), findsOneWidget);
    expect(find.text('Thu nhập hôm nay'), findsOneWidget);
    // 42.000đ ride + 18.000đ delivery today at a 10% snapshot fee; the
    // cancelled one earns nothing.
    final hero = find.byKey(const Key('driver-history-hero-amount'));
    expect(tester.widget<Text>(hero).data, '54.000đ');
    final breakdown = find.byKey(const Key('driver-history-hero-breakdown'));
    expect(
      tester.widget<Text>(breakdown).data,
      'Tổng cước 60.000đ · Hoa hồng DealGo −6.000đ',
    );
    expect(find.textContaining('trước phí'), findsNothing);
    expect(find.text('2 công việc'), findsOneWidget);
    expect(find.text('4.5/5'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.textContaining('Sân bay Đà Nẵng'),
      200,
      scrollable: _list,
    );
    expect(find.textContaining('5/5 sao'), findsWidgets);
    expect(find.textContaining('Hoa hồng 10% −4.200đ'), findsOneWidget);
    expect(find.text('+37.800đ'), findsOneWidget);

    await Scrollable.ensureVisible(
      tester.element(find.byKey(const Key('driver-history-filter-food'))),
      alignment: 0.5,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('driver-history-filter-food')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Sân bay Đà Nẵng'), findsNothing);
    expect(find.textContaining('Bún chả cá Bà Lữ'), findsOneWidget);
    // Food commission is on the delivery fee, labelled as such.
    expect(
      find.textContaining('Hoa hồng 10% phí giao −1.800đ'),
      findsOneWidget,
    );
    expect(find.textContaining('Đã huỷ'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('7 ngày'),
      -300,
      scrollable: _list,
    );
    // Scroll the segmented control fully back to the top before tapping.
    await tester.drag(_list, const Offset(0, 2000));
    await tester.pumpAndSettle();
    await tester.tap(find.text('7 ngày'));
    await tester.pumpAndSettle();
    final week = tester.widget<Text>(hero).data;
    // 95.000đ gross this week minus the 10% snapshots.
    expect(week, '85.500đ');
    expect(
      tester.widget<Text>(breakdown).data,
      'Tổng cước 95.000đ · Hoa hồng DealGo −9.500đ',
    );
  });

  testWidgets('pages through a long history', (tester) async {
    final history = FakeDriverHistoryRemoteDataSource(
      seed: _many(25, DateTime.now()),
    );
    await _openEarnings(tester, history);
    final more = find.byKey(const Key('driver-history-more'));
    await tester.scrollUntilVisible(more, 400, scrollable: _list);
    expect(find.byKey(const Key('driver-history-item-job-24')), findsNothing);
    // History rows are tappable now: bring the button fully on screen first.
    await tester.drag(_list, const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.tap(more);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('driver-history-item-job-24')),
      400,
      scrollable: _list,
    );
    expect(more, findsNothing);
  });

  testWidgets('shows the empty state for a new driver', (tester) async {
    await _openEarnings(tester, FakeDriverHistoryRemoteDataSource());
    expect(find.text('0đ'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('Chưa có công việc nào'),
      300,
      scrollable: _list,
    );
    expect(find.text('Chưa có đánh giá'), findsOneWidget);
  });

  testWidgets('recovers from a failed load', (tester) async {
    final history =
        FakeDriverHistoryRemoteDataSource(
            seed: FakeDriverHistoryRemoteDataSource.sample(DateTime.now()),
          )
          ..failNext = const ApiException(
            statusCode: 500,
            message: 'boom',
            errorCode: 'INTERNAL',
          );
    await _openEarnings(tester, history);
    expect(find.text('Thu nhập hôm nay'), findsNothing);
    final retry = find.text('Thử lại');
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(find.text('Thu nhập hôm nay'), findsOneWidget);
  });

  test('decodes the server payloads', () {
    final item = decodeDriverHistoryItem({
      'kind': 'FOOD_ORDER',
      'id': 'o1',
      'status': 'FAILED',
      'outcome': 'FAILED',
      'fareVnd': 15000,
      'earningsVnd': 0,
      'pickupLabel': 'Quán A',
      'dropoffLabel': 'Nhà B',
      'storeName': 'Quán A',
      'finishedAt': '2026-10-19T02:00:00.000Z',
      'driverStars': null,
      'feePercent': null,
      'feeVnd': 0,
    })!;
    expect(item.kind, DriverJobKind.food);
    expect(item.outcome, DriverJobOutcome.failed);
    expect(item.driverStars, isNull);
    expect(item.feePercent, isNull);
    expect(decodeDriverHistoryItem({'kind': 'BUS'}), isNull);
    final ride = decodeDriverHistoryItem({
      'kind': 'RIDE',
      'id': 'r1',
      'outcome': 'COMPLETED',
      'fareVnd': 50000,
      'feePercent': 12.5,
      'feeVnd': 6250,
      'earningsVnd': 43750,
      'dropoffLabel': 'Nhà B',
      'finishedAt': '2026-10-19T02:00:00.000Z',
    })!;
    expect(ride.feePercent, 12.5);
    expect(ride.feeVnd, 6250);
    expect(ride.earningsVnd, 43750);
    final summary = decodeDriverHistorySummary({
      'today': {
        'date': '2026-10-19',
        'completedJobs': 2,
        'grossVnd': 66000,
        'feeVnd': 6000,
        'earningsVnd': 60000,
      },
      'days': [
        {'date': '2026-10-19', 'completedJobs': 2, 'earningsVnd': 60000},
      ],
      'week': {
        'completedJobs': 3,
        'cancelledJobs': 1,
        'grossVnd': 100000,
        'feeVnd': 5000,
        'earningsVnd': 95000,
        'rideEarningsVnd': 77000,
        'foodEarningsVnd': 18000,
      },
      'rating': {
        'average': 4.5,
        'count': 2,
        'distribution': [0, 0, 0, 1, 1],
      },
    });
    expect(summary.today.earningsVnd, 60000);
    expect(summary.today.grossVnd, 66000);
    expect(summary.today.feeVnd, 6000);
    expect(summary.weekGrossVnd, 100000);
    expect(summary.weekFeeVnd, 5000);
    expect(summary.weekFoodEarningsVnd, 18000);
    expect(summary.ratingAverage, 4.5);
  });

  testWidgets('history row opens the real completed-job detail', (
    tester,
  ) async {
    final history = FakeDriverHistoryRemoteDataSource(
      seed: _many(3, DateTime.now()),
    );
    await _openEarnings(tester, history);
    final row = find.byKey(const Key('driver-history-item-job-0'));
    await tester.scrollUntilVisible(row, 300, scrollable: _list);
    await Scrollable.ensureVisible(tester.element(row), alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('driver-completed-ref')), findsOneWidget);
    expect(find.text('Chuyến #JOB0'), findsOneWidget);
    expect(find.text('Thực nhận'), findsOneWidget);
    expect(find.text('45.000đ'), findsNothing);
  });
}
