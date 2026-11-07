import 'package:dealgo/features/identity/domain/entities/user_profile.dart';
import 'package:dealgo/features/merchant/data/datasources/merchant_offers_remote_datasource.dart';
import 'package:dealgo/features/merchant/domain/merchant_offers.dart';
import 'package:dealgo/features/food/domain/entities/food_models.dart';
import 'package:dealgo/features/rating/data/rating_remote_datasource.dart';
import 'package:dealgo/features/rating/domain/service_rating.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/auth_test_harness.dart';

const _merchant = UserProfile(
  id: 'merchant-1',
  phone: '+84901110001',
  email: null,
  phoneVerifiedAt: '2026-10-13T16:00:00.000Z',
  emailVerifiedAt: null,
  grants: [RoleGrant(role: 'MERCHANT', status: 'ACTIVE')],
);

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<void> _open(WidgetTester tester, String path) async {
  await tester.pumpAndSettle();
  GoRouter.of(tester.element(find.byType(Scaffold).first)).push(path);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('M040 lists offers, pauses, resumes and ends one', (
    tester,
  ) async {
    _tall(tester);
    final repo = FakeMerchantOfferRepository.sample();
    await pumpSignedIn(
      tester,
      profile: _merchant,
      merchantOffers: repo,
      initialLocation: '/merchant',
    );
    await _open(tester, '/merchant/offers');

    expect(find.text('Ưu đãi của quán'), findsWidgets);
    expect(find.byKey(const Key('merchant-offer-offer-1')), findsOneWidget);
    expect(find.text('Đã dùng 46/200'), findsOneWidget);

    await tester.tap(find.byKey(const Key('merchant-offer-toggle-offer-1')));
    await tester.pumpAndSettle();
    expect(repo.statusCalls.single.status, MerchantOfferStatus.paused);
    expect(find.text('Chạy tiếp'), findsNWidgets(2));

    await tester.tap(find.byKey(const Key('merchant-offer-end-offer-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('merchant-offer-end-confirm')));
    await tester.pumpAndSettle();
    expect(repo.statusCalls.last.status, MerchantOfferStatus.ended);
    expect(
      find.byKey(const Key('merchant-offer-toggle-offer-2')),
      findsNothing,
    );
  });

  testWidgets('M041 validates and creates a percent offer', (tester) async {
    _tall(tester);
    final repo = FakeMerchantOfferRepository();
    await pumpSignedIn(
      tester,
      profile: _merchant,
      merchantOffers: repo,
      initialLocation: '/merchant',
    );
    await _open(tester, '/merchant/offers');
    expect(find.byKey(const Key('merchant-offers-empty')), findsOneWidget);

    await tester.tap(find.byKey(const Key('merchant-offer-create')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('merchant-offer-save')));
    await tester.pumpAndSettle();
    expect(repo.created, isEmpty);
    expect(find.text('Bắt buộc'), findsWidgets);

    await tester.enterText(
      find.byKey(const Key('merchant-offer-name')),
      'Giảm 10% trà sữa',
    );
    await tester.enterText(
      find.byKey(const Key('merchant-offer-code')),
      'TRA10',
    );
    await tester.enterText(find.byKey(const Key('merchant-offer-value')), '10');
    await tester.enterText(
      find.byKey(const Key('merchant-offer-max')),
      '20000',
    );
    await tester.ensureVisible(find.byKey(const Key('merchant-offer-save')));
    await tester.tap(find.byKey(const Key('merchant-offer-save')));
    await tester.pumpAndSettle();

    final draft = repo.created.single;
    expect(draft.kind, StoreOfferKind.percentage);
    expect(draft.discountValue, 10);
    expect(draft.maxDiscountVnd, 20000);
    expect(draft.code, 'TRA10');
    expect(find.byKey(const Key('merchant-offers-empty')), findsNothing);
    expect(find.text('Giảm 10% trà sữa'), findsOneWidget);
  });

  testWidgets('M041 create form keeps the final input above the keyboard', (
    tester,
  ) async {
    _tall(tester);
    await pumpSignedIn(
      tester,
      profile: _merchant,
      merchantOffers: FakeMerchantOfferRepository(),
      initialLocation: '/merchant',
    );
    await _open(tester, '/merchant/offers/new');

    final lastField = find.byKey(const Key('merchant-offer-per-user'));
    await tester.ensureVisible(lastField);
    await tester.tap(lastField);
    tester.view.viewInsets = const FakeViewPadding(bottom: 1008);
    await tester.pumpAndSettle();

    const logicalHeight = 2532 / 3;
    const logicalKeyboard = 1008 / 3;
    expect(
      tester.getBottomRight(lastField).dy,
      lessThanOrEqualTo(logicalHeight - logicalKeyboard),
    );
    expect(find.byKey(const Key('merchant-offer-save')), findsOneWidget);
  });

  testWidgets('M031 replies to a review and removes the reply', (tester) async {
    _tall(tester);
    final ratings = FakeRatingRemoteDataSource(
      stores: {
        'store-1': const StoreRating(
          storeId: 'store-1',
          count: 6,
          average: 4.2,
        ),
      },
      reviews: {
        'store-1': [
          StoreReview(
            id: 'r1',
            stars: 4,
            tags: const [],
            comment: 'Ngon nhưng giao hơi lâu',
            createdAt: DateTime(2026, 10, 20),
          ),
          StoreReview(
            id: 'r2',
            stars: 1,
            tags: const [],
            comment: 'Spam',
            createdAt: DateTime(2026, 10, 21),
            hidden: true,
          ),
        ],
      },
    );
    await pumpSignedIn(
      tester,
      profile: _merchant,
      ratings: ratings,
      initialLocation: '/merchant',
    );
    await _open(tester, '/merchant/reviews');

    expect(find.text('Ngon nhưng giao hơi lâu'), findsOneWidget);
    expect(find.byKey(const Key('merchant-review-hidden-r2')), findsOneWidget);

    await tester.tap(find.byKey(const Key('merchant-review-reply-r1')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('merchant-review-reply-text')),
      'Cảm ơn bạn, quán sẽ giao nhanh hơn',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('merchant-review-reply-send')));
    await tester.pumpAndSettle();
    expect(find.text('Cảm ơn bạn, quán sẽ giao nhanh hơn'), findsOneWidget);
    expect(
      ratings.reviews['store-1']!.first.merchantReply,
      'Cảm ơn bạn, quán sẽ giao nhanh hơn',
    );

    await tester.tap(find.byKey(const Key('merchant-review-reply-r1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('merchant-review-reply-remove')));
    await tester.pumpAndSettle();
    expect(find.text('Cảm ơn bạn, quán sẽ giao nhanh hơn'), findsNothing);
  });

  testWidgets('M031 filters reviews by stars, reply status, search and filter sheet', (
    tester,
  ) async {
    _tall(tester);
    final ratings = FakeRatingRemoteDataSource(
      stores: {
        'store-1': const StoreRating(
          storeId: 'store-1',
          count: 3,
          average: 4.0,
        ),
      },
      reviews: {
        'store-1': [
          StoreReview(
            id: 'r1',
            stars: 5,
            tags: const [RatingTag.tastyFood],
            comment: 'Món ăn rất ngon và nóng',
            createdAt: DateTime(2026, 10, 20),
          ),
          StoreReview(
            id: 'r2',
            stars: 2,
            tags: const [RatingTag.coldFood],
            comment: 'Đồ ăn bị nguội',
            createdAt: DateTime(2026, 10, 21),
            merchantReply: 'Quán xin lỗi bạn',
          ),
          StoreReview(
            id: 'r3',
            stars: 1,
            tags: const [],
            comment: 'Giao trễ quá',
            createdAt: DateTime(2026, 10, 22),
            hidden: true,
          ),
        ],
      },
    );
    await pumpSignedIn(
      tester,
      profile: _merchant,
      ratings: ratings,
      initialLocation: '/merchant',
    );
    await _open(tester, '/merchant/reviews');

    // Initial load displays all 3 reviews
    expect(find.text('Món ăn rất ngon và nóng'), findsOneWidget);
    expect(find.text('Đồ ăn bị nguội'), findsOneWidget);
    expect(find.text('Giao trễ quá'), findsOneWidget);

    // Filter by star 5
    await tester.tap(find.byKey(const Key('merchant-reviews-star-5')));
    await tester.pumpAndSettle();
    expect(find.text('Món ăn rất ngon và nóng'), findsOneWidget);
    expect(find.text('Đồ ăn bị nguội'), findsNothing);
    expect(find.text('Giao trễ quá'), findsNothing);

    // Reset star filter back to all
    await tester.tap(find.byKey(const Key('merchant-reviews-tab-all')));
    await tester.pumpAndSettle();
    expect(find.text('Đồ ăn bị nguội'), findsOneWidget);

    // Filter by unreplied
    final unrepliedFinder = find.byKey(const Key('merchant-reviews-tab-unreplied'));
    await tester.ensureVisible(unrepliedFinder);
    await tester.tap(unrepliedFinder);
    await tester.pumpAndSettle();
    expect(find.text('Món ăn rất ngon và nóng'), findsOneWidget);
    expect(find.text('Giao trễ quá'), findsOneWidget);
    expect(find.text('Đồ ăn bị nguội'), findsNothing);

    // Filter by replied
    final repliedFinder = find.byKey(const Key('merchant-reviews-tab-replied'));
    await tester.ensureVisible(repliedFinder);
    await tester.tap(repliedFinder);
    await tester.pumpAndSettle();
    expect(find.text('Đồ ăn bị nguội'), findsOneWidget);
    expect(find.text('Món ăn rất ngon và nóng'), findsNothing);

    // Search query
    final allFinder = find.byKey(const Key('merchant-reviews-tab-all'));
    await tester.ensureVisible(allFinder);
    await tester.tap(allFinder);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('merchant-reviews-search')),
      'nong',
    );
    await tester.tap(find.byKey(const Key('merchant-reviews-search-go')));
    await tester.pumpAndSettle();
    expect(find.text('Món ăn rất ngon và nóng'), findsOneWidget);
    expect(find.text('Đồ ăn bị nguội'), findsNothing);

    // Clear search
    await tester.tap(find.byKey(const Key('merchant-reviews-search-clear')));
    await tester.pumpAndSettle();
    expect(find.text('Đồ ăn bị nguội'), findsOneWidget);

    // Open filter bottom sheet
    final filterSheetButton = find.byKey(const Key('merchant-reviews-open-filter-sheet'));
    await tester.ensureVisible(filterSheetButton);
    await tester.tap(filterSheetButton);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('merchant-reviews-filter-apply')), findsOneWidget);

    // Apply filter in sheet
    final applyButton = find.byKey(const Key('merchant-reviews-filter-apply'));
    await tester.ensureVisible(applyButton);
    await tester.tap(applyButton);
    await tester.pumpAndSettle();
  });
}
