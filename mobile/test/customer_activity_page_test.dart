import 'package:dealgo/core/design_system/components/dealgo_banner.dart';
import 'package:dealgo/core/design_system/components/dealgo_segmented_control.dart';
import 'package:dealgo/core/design_system/components/dealgo_state_view.dart';
import 'package:dealgo/core/network/api_exception.dart';
import 'package:dealgo/features/activity/data/datasources/fake_history_client.dart';
import 'package:dealgo/features/activity/domain/entities/history_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/auth_test_harness.dart';
import 'support/fake_identity_client.dart';

class FailingHistoryClient extends FakeHistoryClient {
  FailingHistoryClient({required this.error});

  final Object error;

  @override
  Future<List<HistoryItem>> listRideHistory(String accessToken) async {
    throw error;
  }

  @override
  Future<List<HistoryItem>> listFoodHistory(String accessToken) async {
    throw error;
  }
}

void main() {
  testWidgets('activity page uses segmented control with all, rides, food and no shopping', (
    tester,
  ) async {
    final historyClient = FakeHistoryClient();
    await pumpSignedIn(
      tester,
      profile: customerProfile,
      historyClient: historyClient,
    );
    await tester.tap(navLabel('Chuyến'));
    await tester.pumpAndSettle();

    // Verify segmented control is present
    expect(find.byType(DealGoSegmentedControl), findsOneWidget);
    expect(find.byKey(const Key('activity-filter-all')), findsOneWidget);
    expect(find.byKey(const Key('activity-filter-rides')), findsOneWidget);
    expect(find.byKey(const Key('activity-filter-food')), findsOneWidget);
    expect(find.byKey(const Key('activity-filter-shopping')), findsNothing);

    // Initial filter is 'all' - both ride and food items shown
    expect(find.text('Chuyến đi đến sân bay'), findsOneWidget);
    expect(find.text('Bún Bò Huế Ô Cồ'), findsOneWidget);

    // Switch to 'rides'
    await tester.tap(find.byKey(const Key('activity-filter-rides')));
    await tester.pumpAndSettle();
    expect(find.text('Chuyến đi đến sân bay'), findsOneWidget);
    expect(find.text('Bún Bò Huế Ô Cồ'), findsNothing);

    // Switch to 'food'
    await tester.tap(find.byKey(const Key('activity-filter-food')));
    await tester.pumpAndSettle();
    expect(find.text('Chuyến đi đến sân bay'), findsNothing);
    expect(find.text('Bún Bò Huế Ô Cồ'), findsOneWidget);
  });

  testWidgets('activity page shows DealGoStateView on offline failure without ad-hoc banner', (
    tester,
  ) async {
    final historyClient = FailingHistoryClient(
      error: const ApiException(statusCode: 0, errorCode: 'NETWORK_ERROR', message: ''),
    );
    await pumpSignedIn(
      tester,
      profile: customerProfile,
      historyClient: historyClient,
    );
    await tester.tap(navLabel('Chuyến'));
    await tester.pumpAndSettle();

    // State view with offline art is displayed
    expect(find.byType(DealGoStateView), findsOneWidget);
    expect(find.text('Bạn đang ngoại tuyến'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);

    // Ad-hoc banner should NOT exist
    expect(find.byType(DealGoBanner), findsNothing);
  });
}
