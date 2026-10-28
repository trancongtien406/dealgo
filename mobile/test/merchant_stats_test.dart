import 'package:dealgo/core/auth/token_store.dart';
import 'package:dealgo/core/network/api_exception.dart';
import 'package:dealgo/features/identity/domain/entities/auth_state.dart';
import 'package:dealgo/features/identity/domain/entities/user_profile.dart';
import 'package:dealgo/features/identity/presentation/cubit/auth_cubit.dart';
import 'package:dealgo/features/food/domain/entities/food_models.dart';
import 'package:dealgo/features/merchant/data/datasources/dio_merchant_stats_remote_datasource.dart';
import 'package:dealgo/features/merchant/data/datasources/fake_merchant_stats_remote_datasource.dart';
import 'package:dealgo/features/merchant/domain/merchant_stats.dart';
import 'package:dealgo/features/merchant/presentation/cubit/merchant_stats_cubit.dart';
import 'package:dealgo/features/merchant/presentation/pages/merchant_stats_page.dart';
import 'package:dealgo/features/merchant/data/datasources/fake_merchant_orders_client.dart';
import 'package:dealgo/features/merchant/data/repositories/merchant_orders_repository_impl.dart';
import 'package:dealgo/features/merchant/domain/usecases/get_merchant_catalog.dart';
import 'package:dealgo/features/rating/domain/service_rating.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_l10n.dart';

const _payload = {
  'timezone': 'Asia/Ho_Chi_Minh',
  'days': 2,
  'today': {
    'date': '2026-10-19',
    'deliveredCount': 3,
    'cancelledCount': 1,
    'salesVnd': 185000,
    'openCount': 2,
  },
  'totals': {'deliveredCount': 5, 'cancelledCount': 1, 'salesVnd': 300000},
  'series': [
    {
      'date': '2026-10-18',
      'deliveredCount': 2,
      'cancelledCount': 0,
      'salesVnd': 115000,
    },
    {
      'date': '2026-10-19',
      'deliveredCount': 3,
      'cancelledCount': 1,
      'salesVnd': 185000,
    },
  ],
  'topItems': [
    {'name': 'Bún bò', 'quantity': 4},
    {'name': 'Trà đá', 'quantity': 2},
  ],
};

void main() {
  test('decodes the merchant stats payload', () {
    final stats = decodeMerchantStats(Map<String, Object?>.from(_payload));
    expect(stats.today.salesVnd, 185000);
    expect(stats.openCount, 2);
    expect(stats.totals.deliveredCount, 5);
    expect(stats.series.map((d) => d.date), ['2026-10-18', '2026-10-19']);
    expect(stats.topItems.first.name, 'Bún bò');
    expect(
      () => decodeMerchantStats(const {'days': 7}),
      throwsA(isA<ApiException>()),
    );
  });

  test('fake stats are empty, never invented', () {
    final stats = FakeMerchantStatsRemoteDataSource.empty(
      7,
      DateTime.utc(2026, 10, 19, 3),
    );
    expect(stats.series, hasLength(7));
    expect(stats.series.last.date, '2026-10-19');
    expect(stats.totals.salesVnd, 0);
    expect(stats.topItems, isEmpty);
  });

  test('cubit maps 403 to ineligible', () async {
    final cubit = MerchantStatsCubit(
      stats: FakeMerchantStatsRemoteDataSource(
        error: const ApiException(
          statusCode: 403,
          message: 'role',
          errorCode: 'ROLE_NOT_ACTIVE',
        ),
      ),
    );
    await cubit.load('token');
    expect(cubit.state, isA<MerchantStatsIneligible>());
    await cubit.load('');
    expect(cubit.state, isA<MerchantStatsFailed>());
  });

  testWidgets('stats page renders server figures, store and rating', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final stats = FakeMerchantStatsRemoteDataSource(
      result: decodeMerchantStats(Map<String, Object?>.from(_payload)),
    );
    final orders = FakeMerchantOrdersClient(
      onGetCatalog: () =>
          const FoodStoreDetail(id: 'store-1', name: 'Quán Hà', items: []),
    );
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<MerchantStatsRepository>.value(value: stats),
          RepositoryProvider<GetMerchantCatalog>.value(
            value: GetMerchantCatalog(MerchantOrdersRepositoryImpl(orders)),
          ),
          RepositoryProvider<RatingRepository>.value(value: _Ratings()),
        ],
        child: BlocProvider<AuthCubit>.value(
          value: _SignedIn(),
          child: const MaterialApp(
            localizationsDelegates: testLocalizationsDelegates,
            supportedLocales: [testLocale],
            locale: testLocale,
            home: MerchantStatsPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(stats.calls, [7]);
    expect(find.text('Quán Hà'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('4.6'), findsOneWidget);
    expect(find.text('Bún bò'), findsOneWidget);
    expect(find.text('Ngon'), findsOneWidget);
    expect(find.text('4 phần'), findsOneWidget);
    expect(find.textContaining('Tổng 5 đơn'), findsOneWidget);
    expect(find.text('2,45 triệu'), findsNothing);
    expect(stats.statementCalls, hasLength(1));
    expect(find.byKey(const Key('merchant-statement')), findsOneWidget);
  });

  test('statement window is Vietnam days including today', () {
    // 2026-10-26 18:30 UTC = 2026-10-27 01:30 ICT
    final now = DateTime.utc(2026, 10, 26, 18, 30);
    expect(statementRange(7, now), ('2026-10-21', '2026-10-27'));
    expect(statementRange(90, now).$1, '2026-09-27');
  });

  test('decodes the merchant statement', () {
    final statement = decodeMerchantStatement({
      'from': '2026-10-20',
      'to': '2026-10-26',
      'commissionPercentNow': 15,
      'totals': {
        'orderCount': 3,
        'cashReceivedVnd': 300000,
        'commissionVnd': 45000,
        'netVnd': 255000,
      },
      'unsettledCommissionVnd': 15000,
      'settlementCycleDays': 7,
      'settlements': [
        {
          'periodStart': '2026-10-20',
          'periodEnd': '2026-10-22',
          'commissionVnd': 30000,
          'createdAt': '2026-10-23T03:00:00.000Z',
        },
      ],
    });
    expect(statement.orderCount, 3);
    expect(statement.unsettledCommissionVnd, 15000);
    expect(statement.settlementCycleDays, 7);
    expect(statement.settlements.single.periodEnd, '2026-10-22');
    expect(
      () => decodeMerchantStatement(const {'from': 'x'}),
      throwsA(isA<ApiException>()),
    );
  });

  testWidgets('statement card shows unpaid commission', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final stats = FakeMerchantStatsRemoteDataSource(
      result: decodeMerchantStats(Map<String, Object?>.from(_payload)),
      statementResult: const MerchantStatement(
        from: '2026-10-20',
        to: '2026-10-26',
        commissionPercentNow: 15,
        orderCount: 3,
        cashReceivedVnd: 300000,
        commissionVnd: 45000,
        netVnd: 255000,
        unsettledCommissionVnd: 15000,
        settlementCycleDays: 7,
        settlements: [
          MerchantSettlement(
            periodStart: '2026-10-20',
            periodEnd: '2026-10-22',
            commissionVnd: 30000,
            createdAt: null,
          ),
        ],
      ),
    );
    final orders = FakeMerchantOrdersClient(
      onGetCatalog: () =>
          const FoodStoreDetail(id: 'store-1', name: 'Quán Hà', items: []),
    );
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<MerchantStatsRepository>.value(value: stats),
          RepositoryProvider<GetMerchantCatalog>.value(
            value: GetMerchantCatalog(MerchantOrdersRepositoryImpl(orders)),
          ),
          RepositoryProvider<RatingRepository>.value(value: _Ratings()),
        ],
        child: BlocProvider<AuthCubit>.value(
          value: _SignedIn(),
          child: const MaterialApp(
            localizationsDelegates: testLocalizationsDelegates,
            supportedLocales: [testLocale],
            locale: testLocale,
            home: MerchantStatsPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('merchant-statement-unsettled')),
      200,
    );
    expect(find.text('Hoa hồng (15%)'), findsOneWidget);
    expect(find.text('Đối soát mỗi 7 ngày'), findsOneWidget);
    expect(
      find.textContaining('Lần nộp gần nhất: 20/10–22/10'),
      findsOneWidget,
    );
  });
}

class _Ratings implements RatingRepository {
  @override
  Future<Map<String, StoreRating>> storeRatings({
    required String accessToken,
    required List<String> storeIds,
  }) async => {
    for (final id in storeIds)
      id: StoreRating(storeId: id, count: 12, average: 4.6),
  };

  @override
  Future<StoreReviews> storeReviews({
    required String accessToken,
    required String storeId,
    int page = 1,
    int? stars,
  }) async {
    return StoreReviews(
      summary: StoreRating(storeId: storeId, count: 12, average: 4.6),
      items: [
        StoreReview(
          stars: 5,
          tags: const [],
          createdAt: DateTime.utc(2026, 10, 1),
          comment: 'Ngon',
        ),
      ],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SignedIn extends Cubit<AuthState> implements AuthCubit {
  _SignedIn()
    : super(
        const AuthSignedIn(
          tokens: StoredTokens(accessToken: 'token', refreshToken: 'r'),
          profile: UserProfile(
            id: 'm1',
            phone: '+84900000000',
            email: null,
            phoneVerifiedAt: null,
            emailVerifiedAt: null,
            grants: [],
            displayName: 'Hà',
          ),
        ),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
