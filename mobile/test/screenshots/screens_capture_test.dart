// Visual review harness (not a golden gate). Renders key screens with real
// fonts and writes PNGs. Skipped unless run with:
//   flutter test test/screenshots --dart-define=SCREENSHOTS=true \
//     --dart-define=SHOT_DIR=/abs/output/dir
// Optional `--dart-define=SHOT_SIZE=320x568` (logical px, default 390x844).
// Every shot also appends cut-off text (ellipsis, fade, clip) to
// `<SHOT_DIR>/truncated.tsv` for a small-screen text audit.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dealgo/features/address_book/data/datasources/address_book_remote_datasource.dart';
import 'package:dealgo/features/driver_history/data/driver_history_remote_datasource.dart';
import 'package:dealgo/features/food/domain/entities/food_models.dart';
import 'package:dealgo/features/food/presentation/cubit/food_cart_cubit.dart';
import 'package:dealgo/features/food/presentation/utils/food_routes.dart';
import 'package:dealgo/features/inbox/data/datasources/inbox_remote_datasource.dart';
import 'package:dealgo/features/rating/data/rating_remote_datasource.dart';
import 'package:dealgo/features/rating/domain/service_rating.dart';
import 'package:dealgo/features/rating/presentation/rate_service_card.dart';
import 'package:dealgo/features/ride/domain/entities/ride_models.dart';
import 'package:dealgo/app/dealgo_app.dart';
import 'package:dealgo/core/auth/token_store.dart';
import 'package:dealgo/features/identity/domain/auth_redirect.dart';
import 'package:dealgo/features/identity/domain/entities/user_profile.dart';
import 'package:dealgo/features/places/data/places_remote_datasource.dart';
import 'package:dealgo/features/pricing/domain/pricing.dart';
import 'package:dealgo/features/ride/presentation/utils/ride_routes.dart';

import '../support/fake_location.dart';

import 'package:dealgo/features/driver_card/data/driver_card_remote_datasource.dart';
import 'package:dealgo/features/driver_card/domain/driver_card.dart';
import 'package:dealgo/features/support/data/support_remote_datasource.dart';
import 'package:dealgo/features/support/domain/support_ticket.dart';
import 'package:dealgo/features/live_location/data/driver_location_remote_datasource.dart';
import 'package:dealgo/features/live_location/domain/driver_location.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:dealgo/features/merchant/data/datasources/merchant_offers_remote_datasource.dart';

import '../support/auth_test_harness.dart';
import '../support/fake_food_client.dart';
import '../support/fake_identity_client.dart';
import '../support/fake_ride_client.dart';

const _enabled = bool.fromEnvironment('SCREENSHOTS');
const _outDir = String.fromEnvironment(
  'SHOT_DIR',
  defaultValue: 'build/screenshots',
);
const _shotSize = String.fromEnvironment('SHOT_SIZE', defaultValue: '390x844');

Size get _logicalSize {
  final parts = _shotSize.split('x').map(double.parse).toList();
  return Size(parts[0], parts[1]);
}

const _customer = UserProfile(
  id: 'user-customer',
  phone: '+84911111111',
  email: null,
  phoneVerifiedAt: '2026-10-13T16:00:00.000Z',
  emailVerifiedAt: null,
  grants: [RoleGrant(role: 'CUSTOMER', status: 'ACTIVE')],
);

const _merchant = UserProfile(
  id: 'merchant-1',
  phone: '+84901110001',
  email: null,
  phoneVerifiedAt: '2026-10-13T16:00:00.000Z',
  emailVerifiedAt: null,
  grants: [RoleGrant(role: 'MERCHANT', status: 'ACTIVE')],
);

const _storeId = '5b0f6c9e-1d2a-4e3b-8c4d-000000000001';

/// DEC-PROD-033 shot fixture: Size (required) + Topping (up to 2).
const _shotOptionGroups = [
  FoodOptionGroup(
    id: 'g-size',
    title: 'Size',
    minSelect: 1,
    maxSelect: 1,
    choices: [
      FoodOptionChoice(id: 'o-std', label: 'Thường'),
      FoodOptionChoice(id: 'o-large', label: 'Lớn', extraVnd: 10000),
    ],
  ),
  FoodOptionGroup(
    id: 'g-top',
    title: 'Topping',
    minSelect: 0,
    maxSelect: 2,
    choices: [
      FoodOptionChoice(id: 'o-cha', label: 'Thêm chả cá', extraVnd: 12000),
      FoodOptionChoice(id: 'o-trung', label: 'Thêm trứng', extraVnd: 5000),
      FoodOptionChoice(id: 'o-rau', label: 'Rau sống', available: false),
    ],
  ),
];

FakeFoodClient _food() =>
    FakeFoodClient(
        stores: [
          FoodStoreSummary(
            id: _storeId,
            name: 'Bún chả cá Bà Lữ',
            category: 'noodles',
            distanceKm: 0.8,
            etaMinutes: 22,
            deliveryFeeFromVnd: 12000,
            ratingAverage: 4.6,
            ratingCount: 12,
            minOrderVnd: 40000,
            offers: [_shotOffers.first],
            featuredItems: [
              const FoodFeaturedItem(
                id: 'i1',
                name: 'Bún chả cá đặc biệt',
                priceVnd: 55000,
                originalPriceVnd: 65000,
                soldCount: 320,
              ),
              FoodFeaturedItem(
                id: 'i5',
                name: 'Bún chả cá trộn',
                priceVnd: 49000,
                addedAt: DateTime.now().subtract(const Duration(days: 2)),
              ),
            ],
          ),
          FoodStoreSummary(
            id: '5b0f6c9e-1d2a-4e3b-8c4d-000000000002',
            name: 'Trà sữa Mây',
            category: 'tea',
            distanceKm: 1.6,
            etaMinutes: 28,
            deliveryFeeFromVnd: 0,
            ratingCount: 2,
            featuredItems: const [
              FoodFeaturedItem(
                id: 't1',
                name: 'Trà sữa trân châu',
                priceVnd: 32000,
                originalPriceVnd: 40000,
                soldCount: 210,
              ),
            ],
            offers: [
              StoreOffer(
                id: 'offer-tea',
                code: 'MAY15',
                name: 'Giảm 15K',
                kind: StoreOfferKind.fixedAmount,
                discountValue: 15000,
                minOrderVnd: 60000,
                endsAt: DateTime(2026, 11, 30),
              ),
            ],
          ),
          FoodStoreSummary(
            id: '5b0f6c9e-1d2a-4e3b-8c4d-000000000003',
            name: 'Cơm gà Hội An',
            category: 'rice',
            distanceKm: 2.3,
            etaMinutes: 35,
            deliveryFeeFromVnd: 18000,
            ratingAverage: 4.8,
            ratingCount: 56,
            featuredItems: [
              FoodFeaturedItem(
                id: 'c1',
                name: 'Cơm gà xé',
                priceVnd: 45000,
                soldCount: 180,
                addedAt: DateTime.now().subtract(const Duration(days: 5)),
              ),
            ],
          ),
        ],
        details: {
          _storeId: FoodStoreDetail(
            id: _storeId,
            name: 'Bún chả cá Bà Lữ',
            category: 'noodles',
            addressLabel: '319 Hùng Vương, Hải Châu, Đà Nẵng',
            lat: 16.0601,
            lng: 108.2137,
            description:
                'Chả cá thu làm mỗi sáng, nước dùng ngọt xương, '
                'ăn kèm rau sống Đà Nẵng.',
            offers: _shotOffers,
            minOrderVnd: 40000,
            estimatedPrepMinutes: 15,
            schedule: StoreSchedule(
              hoursConfigured: true,
              weekly: [
                for (var d = 1; d <= 6; d++)
                  StoreDayHours(
                    weekday: d,
                    opensAt: '07:00',
                    closesAt: '21:00',
                  ),
              ],
            ),
            menuSections: const [
              FoodMenuSection(id: 'sec-bun', name: 'Bún & bánh canh'),
              FoodMenuSection(id: 'sec-side', name: 'Món thêm'),
              FoodMenuSection(id: 'sec-drink', name: 'Đồ uống'),
            ],
            items: [
              const FoodMenuItem(
                id: 'i1',
                name: 'Bún chả cá đặc biệt',
                description: 'Chả cá thu, chả hấp, bánh canh, nước dùng xương',
                priceVnd: 55000,
                originalPriceVnd: 65000,
                available: true,
                soldCount: 320,
                menuCategoryId: 'sec-bun',
                optionGroups: _shotOptionGroups,
              ),
              const FoodMenuItem(
                id: 'i2',
                name: 'Bánh canh chả cá',
                priceVnd: 45000,
                available: true,
                soldCount: 140,
                menuCategoryId: 'sec-bun',
              ),
              FoodMenuItem(
                id: 'i5',
                name: 'Bún chả cá trộn',
                description: 'Bún trộn mắm nêm, chả cá chiên giòn',
                priceVnd: 49000,
                available: true,
                menuCategoryId: 'sec-bun',
                addedAt: DateTime.now().subtract(const Duration(days: 2)),
              ),
              const FoodMenuItem(
                id: 'i3',
                name: 'Chả cá chiên',
                priceVnd: 30000,
                available: false,
                menuCategoryId: 'sec-side',
              ),
              const FoodMenuItem(
                id: 'i4',
                name: 'Trà chanh',
                priceVnd: 15000,
                available: true,
                soldCount: 95,
                menuCategoryId: 'sec-drink',
              ),
            ],
          ),
        },
      )
      ..readyOrders = const [
        ReadyFoodJob(
          id: '9a8b7c6d-0000-4000-8000-00000004b2c4',
          storeId: _storeId,
          storeName: 'Bún chả cá Bà Lữ',
          storeAddress: '319 Hùng Vương, Hải Châu, Đà Nẵng',
          pickup: FoodDropoff(
            lat: 16.0678,
            lng: 108.2208,
            label: '319 Hùng Vương, Hải Châu, Đà Nẵng',
          ),
          deliveryFareVnd: 18000,
          subtotalVnd: 100000,
          totalVnd: 118000,
          dropoff: FoodDropoff(
            lat: 16.0544,
            lng: 108.2022,
            label: '45 Lê Duẩn, Hải Châu',
          ),
          lineCount: 2,
        ),
      ]
      ..orderDetail = const FoodOrderDetail(
        id: '9a8b7c6d-0000-4000-8000-00000004a1f3',
        status: 'PLACED',
        storeName: 'Bún chả cá Bà Lữ',
        subtotalVnd: 100000,
        deliveryFareVnd: 15000,
        totalVnd: 115000,
        dropoff: FoodDropoff(
          lat: 16.07,
          lng: 108.22,
          label: '45 Lê Duẩn, Hải Châu',
        ),
        lines: [
          FoodOrderLine(
            itemId: 'i1',
            name: 'Bún chả cá đặc biệt',
            unitPriceVnd: 77000,
            quantity: 1,
            options: [
              FoodLineOption(
                groupName: 'Size',
                name: 'Lớn',
                priceDeltaVnd: 10000,
              ),
              FoodLineOption(
                groupName: 'Topping',
                name: 'Thêm chả cá',
                priceDeltaVnd: 12000,
              ),
            ],
          ),
          FoodOrderLine(
            itemId: 'i2',
            name: 'Bánh canh chả cá',
            unitPriceVnd: 23000,
            quantity: 1,
          ),
        ],
      )
      ..queueOrders = [
        MerchantQueueOrder(
          id: '9a8b7c6d-0000-4000-8000-00000004a1f3',
          storeId: _storeId,
          status: 'PLACED',
          deliveryFareVnd: 15000,
          subtotalVnd: 100000,
          totalVnd: 115000,
          dropoff: const FoodDropoff(
            lat: 16.07,
            lng: 108.22,
            label: '45 Lê Duẩn, Hải Châu',
          ),
          lineCount: 2,
          createdAt: DateTime.now()
              .subtract(const Duration(minutes: 3))
              .toUtc()
              .toIso8601String(),
        ),
      ];

final _shotOffers = [
  StoreOffer(
    id: 'offer-1',
    code: 'BUNBO20',
    name: 'Giảm 20%',
    kind: StoreOfferKind.percentage,
    discountValue: 20,
    maxDiscountVnd: 30000,
    minOrderVnd: 80000,
    endsAt: DateTime(2026, 11, 30),
    remainingUses: 12,
  ),
  StoreOffer(
    id: 'offer-2',
    code: 'SHIP15',
    name: 'Giảm 15K',
    kind: StoreOfferKind.fixedAmount,
    discountValue: 15000,
    minOrderVnd: 120000,
    endsAt: DateTime(2026, 11, 15),
  ),
];

FakeRatingRemoteDataSource _ratings() {
  final now = DateTime.now();
  return FakeRatingRemoteDataSource(
    stores: {
      _storeId: const StoreRating(
        storeId: _storeId,
        count: 12,
        average: 4.6,
        distribution: [0, 0, 1, 3, 8],
      ),
      '5b0f6c9e-1d2a-4e3b-8c4d-000000000002': const StoreRating(
        storeId: '5b0f6c9e-1d2a-4e3b-8c4d-000000000002',
        count: 2,
      ),
    },
    reviews: {
      _storeId: [
        StoreReview(
          id: 'review-1',
          stars: 5,
          tags: const [RatingTag.tastyFood, RatingTag.wellPacked],
          comment: 'Chả cá dai, nước dùng ngọt thanh. Giao nhanh.',
          createdAt: now.subtract(const Duration(days: 1)),
          merchantReply: 'Cảm ơn bạn đã ủng hộ quán!',
          repliedAt: now.subtract(const Duration(hours: 20)),
        ),
        StoreReview(
          id: 'review-2',
          stars: 4,
          tags: const [RatingTag.tastyFood, RatingTag.onTime],
          comment: 'Ngon, hơi nhiều hành.',
          createdAt: now.subtract(const Duration(days: 3)),
        ),
        StoreReview(
          stars: 5,
          tags: const [RatingTag.wellPacked, RatingTag.tastyFood],
          createdAt: now.subtract(const Duration(days: 4)),
        ),
      ],
    },
  );
}

const _driver = UserProfile(
  id: 'user-driver',
  phone: '+84944444444',
  email: null,
  phoneVerifiedAt: '2026-10-13T16:00:00.000Z',
  emailVerifiedAt: null,
  grants: [RoleGrant(role: 'DRIVER', status: 'ACTIVE')],
);

Future<void> _loadFonts() async {
  Future<void> family(String name, List<String> paths) async {
    final loader = FontLoader(name);
    for (final p in paths) {
      final bytes = File(p).readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }

  await family('BeVietnamPro', [
    for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold'])
      'assets/fonts/BeVietnamPro-$w.ttf',
  ]);
  // Material Icons (solid rating stars) are not loaded by flutter_tester.
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  final materialIcons = File(
    '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (flutterRoot != null && materialIcons.existsSync()) {
    await family('MaterialIcons', [materialIcons.path]);
  }
  final config = jsonDecode(
    File('.dart_tool/package_config.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  for (final pkg in (config['packages'] as List).cast<Map<String, dynamic>>()) {
    if (pkg['name'] == 'lucide_icons_flutter') {
      final root = Uri.parse(pkg['rootUri'] as String);
      final dir = root.isAbsolute
          ? root.toFilePath()
          : File('.dart_tool/${pkg['rootUri']}').absolute.path;
      await family('packages/lucide_icons_flutter/Lucide', [
        '$dir/assets/lucide.ttf',
      ]);
    }
  }
}

Future<void> _settleImages(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      final image = element.widget as Image;
      await precacheImage(image.image, element);
    }
  });
  await tester.pumpAndSettle();
}

Future<void> _fillDeleteForm(WidgetTester tester) async {
  final list = find
      .descendant(
        of: find.byKey(const ValueKey('delete-account-form')),
        matching: find.byType(Scrollable),
      )
      .first;
  final backup = find.byKey(const ValueKey('delete-check-backup'));
  await tester.scrollUntilVisible(backup, 120, scrollable: list);
  await tester.ensureVisible(backup);
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(of: backup, matching: find.byType(Checkbox)),
  );
  await tester.pump();
  final word = find.byKey(const ValueKey('delete-confirm-word'));
  await tester.scrollUntilVisible(word, 120, scrollable: list);
  await tester.ensureVisible(word);
  await tester.pumpAndSettle();
  await tester.enterText(word, 'XÓA');
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

Future<void> _shoot(WidgetTester tester, String name) async {
  await _settleImages(tester);
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('shot-root')),
  );
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1.5);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  });
  Directory(_outDir).createSync(recursive: true);
  File('$_outDir/$name.png').writeAsBytesSync(bytes!);
  final cut = _truncatedTexts(boundary);
  if (cut.isNotEmpty) {
    File('$_outDir/truncated.tsv').writeAsStringSync(
      cut.map((t) => '$name\t$t\n').join(),
      mode: FileMode.append,
    );
  }
}

/// Visible text that does not fit its box: more lines than `maxLines`, or a
/// single line wider than its paragraph.
List<String> _truncatedTexts(RenderObject root) {
  final out = <String>[];
  void visit(RenderObject node) {
    if (node is RenderParagraph && node.hasSize && node.size.width > 0) {
      final singleLine = node.maxLines == 1 || !node.softWrap;
      final tooWide =
          singleLine &&
          node.getMaxIntrinsicWidth(double.infinity) > node.size.width + 0.5;
      if (node.didExceedMaxLines || tooWide) {
        out.add(node.text.toPlainText().replaceAll('\n', ' '));
      }
    }
    node.visitChildren(visit);
  }

  visit(root);
  return out;
}

/// DEC-PROD-024 shots: a negotiating ride with one offer, and a finished discounted ride.
RideView? _voucherShotRide(String id) {
  const pickup = RidePoint(
    lat: 16.0544,
    lng: 108.2022,
    label: '123 Lê Lợi, Hải Châu',
  );
  const dropoff = RidePoint(
    lat: 16.0439,
    lng: 108.1994,
    label: 'Sân bay Quốc tế Đà Nẵng',
  );
  if (id == 'ride-voucher') {
    return const RideView(
      id: 'ride-voucher',
      status: RideStatus.negotiating,
      pickup: pickup,
      dropoff: dropoff,
      offeredFareVnd: 42000,
      referenceFareVnd: 40000,
      agreedFareVnd: null,
      assignedDriverId: null,
      selectedOfferId: null,
      expiresAt: '2030-01-01T00:00:00.000Z',
      offers: [
        RideOffer(
          id: 'offer-v1',
          driverId: 'driver-1',
          amountVnd: 45000,
          kind: RideOfferKind.counter,
          status: RideOfferStatus.pending,
          expiresAt: '2030-01-01T00:00:00.000Z',
        ),
      ],
    );
  }
  if (id == 'ride-done-voucher') {
    return const RideView(
      id: 'ride-done-voucher',
      status: RideStatus.completed,
      pickup: pickup,
      dropoff: dropoff,
      offeredFareVnd: 42000,
      referenceFareVnd: 40000,
      agreedFareVnd: 45000,
      assignedDriverId: 'driver-1',
      selectedOfferId: 'offer-v1',
      expiresAt: '2030-01-01T00:00:00.000Z',
      offers: [],
      updatedAt: '2026-10-19T09:30:00.000Z',
      discountVnd: 4500,
      voucherCode: 'DEALGO10',
    );
  }
  return null;
}

Future<void> _pump(
  WidgetTester tester, {
  required String location,
  UserProfile? profile,
  FakeFoodClient? food,
}) async {
  tester.view.physicalSize = _logicalSize * 3;
  tester.view.devicePixelRatio = 3;
  final store = MemoryTokenStore();
  if (profile != null) {
    await store.write(
      const StoredTokens(accessToken: 'access', refreshToken: 'refresh'),
    );
  }
  await tester.pumpWidget(
    RepaintBoundary(
      key: const Key('shot-root'),
      child: DealGoApp(
        identityClient: profile == null
            ? FakeIdentityClient()
            : FakeIdentityClient(profile: profile),
        tokenStore: store,
        foodClient: food ?? _food(),
        rideClient: FakeRideClient()
          ..onGet = ((id) =>
              _voucherShotRide(id) ??
              RideView(
                id: id,
                status: RideStatus.driverEnRoute,
                pickup: const RidePoint(
                  lat: 16.0544,
                  lng: 108.2022,
                  label: '123 Lê Lợi, Hải Châu',
                ),
                dropoff: const RidePoint(
                  lat: 16.0439,
                  lng: 108.1994,
                  label: 'Sân bay Quốc tế Đà Nẵng',
                ),
                offeredFareVnd: 42000,
                referenceFareVnd: 40000,
                agreedFareVnd: 45000,
                assignedDriverId: 'driver-1',
                selectedOfferId: null,
                expiresAt: '2030-01-01T00:00:00.000Z',
                offers: const [],
                pickupCode: '4821',
              ))
          ..openRides = const [
            OpenRide(
              id: 'ride-open-1',
              status: 'NEGOTIATING',
              pickup: RidePoint(
                lat: 16.0544,
                lng: 108.2022,
                label: '123 Lê Lợi',
              ),
              dropoff: RidePoint(
                lat: 16.0471,
                lng: 108.2062,
                label: 'Sân bay Đà Nẵng',
              ),
              offeredFareVnd: 42000,
              referenceFareVnd: 40000,
              expiresAt: '2030-01-01T00:00:00.000Z',
              offerCount: 1,
            ),
          ],
        inboxRemote: FakeInboxRemoteDataSource(),
        addressBook: FakeAddressBookRemoteDataSource(
          seed: FakeAddressBookRemoteDataSource.sample(),
        ),
        ratings: _ratings()..merchantStoreId = _storeId,
        merchantOffers: FakeMerchantOfferRepository.sample(),
        driverHistory: FakeDriverHistoryRemoteDataSource(
          seed: FakeDriverHistoryRemoteDataSource.sample(DateTime.now()),
        ),
        locationOverride: FakeLocationService(),
        driverLocation: FakeDriverLocationRemoteDataSource(
          location: DriverLiveLocation(
            lat: 16.0561,
            lng: 108.2035,
            at: DateTime(2026, 10, 20, 9, 41),
          ),
        ),
        support: FakeSupportRepository(seed: _supportSamples()),
        driverCard: FakeDriverCardRemoteDataSource(
          card: const DriverCard(
            driverId: 'driver-1',
            displayName: 'Lê Văn Tài',
            vehiclePlate: '43B1-678.90',
            vehicleType: 'Xe máy',
            ratingAverage: 4.8,
            ratingCount: 37,
          ),
        ),
        places: FakePlacesRemoteDataSource(
          catalog: FakePlacesRemoteDataSource.sampleCatalog,
          recent: FakePlacesRemoteDataSource.sampleRecent,
        ),
        postAuthGate: profile == null
            ? incompletePostAuthGate()
            : completedPostAuthGate(),
        initialLocation: location,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

List<SupportTicket> _supportSamples() {
  final opened = DateTime.now().subtract(const Duration(hours: 5));
  return [
    SupportTicket(
      id: 'ticket-replied',
      code: 'DG-261019-0042',
      category: SupportCategory.ride,
      subject: 'Tài xế thu thêm tiền mặt',
      status: SupportStatus.inProgress,
      priority: SupportPriority.normal,
      awaitingRequester: true,
      lastMessageAt: opened.add(const Duration(hours: 1)),
      createdAt: opened,
      relatedType: SupportRelatedType.ride,
      relatedId: '7f3c2a10-5b1e-4c3d-9a8b-2e4f6a1c9d07',
      preview: 'DealGo đã liên hệ tài xế để xác minh.',
      messages: [
        SupportMessage(
          id: 'm1',
          fromStaff: false,
          body: 'Tài xế thu 45.000 đ trong khi ứng dụng hiển thị 35.000 đ.',
          createdAt: opened,
        ),
        SupportMessage(
          id: 'm2',
          fromStaff: true,
          body: 'DealGo đã liên hệ tài xế để xác minh. Phần chênh lệch sẽ được hoàn nếu đúng.',
          createdAt: opened.add(const Duration(hours: 1)),
        ),
      ],
    ),
    SupportTicket(
      id: 'ticket-done',
      code: 'DG-261012-0007',
      category: SupportCategory.payment,
      subject: 'Chưa nhận được tiền hoàn',
      status: SupportStatus.resolved,
      priority: SupportPriority.normal,
      awaitingRequester: true,
      lastMessageAt: opened.subtract(const Duration(days: 6)),
      createdAt: opened.subtract(const Duration(days: 7)),
      resolvedAt: opened.subtract(const Duration(days: 6)),
      preview: 'Tiền hoàn đã được chuyển.',
    ),
  ];
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/connectivity'),
          (call) async => <String>['wifi'],
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/connectivity_status'),
          (call) async => null,
        );
    await _loadFonts();
  });

  // name -> (start location, profile, tab label to tap, route to push).
  final shots = <String, (String, UserProfile?, String?, String?)>{
    '01_login': (AuthRoutes.login, null, null, null),
    '02_phone_login': (AuthRoutes.phoneLogin, null, null, null),
    '03_email_login': (AuthRoutes.emailLogin, null, null, null),
    '04_onboarding': (AuthRoutes.onboarding, null, null, null),
    '05_customer_home': ('/customer', _customer, null, null),
    '06_customer_trips': ('/customer', _customer, 'Chuyến', null),
    '07_customer_shop': ('/customer', _customer, 'Mua', null),
    '08_customer_account': ('/customer', _customer, 'Tôi', null),
    '09_ride_route': ('/customer', _customer, null, null),
    '10_ride_fare': ('/customer', _customer, null, null),
    '11_food_search': ('/customer', _customer, null, '/customer/food/search'),
    '12_driver_home': ('/driver', _driver, null, null),
    '13_driver_jobs': ('/driver', _driver, 'Việc nhận', null),
    '14_driver_earnings': ('/driver', _driver, 'Thu nhập', null),
    '15_account_addresses': ('/customer', _customer, 'Tôi', 'addresses'),
    '16_notifications': ('/customer', _customer, 'Tôi', 'notifications'),
    '17_driver_active_ride': (
      '/driver',
      _driver,
      null,
      '/driver/rides/ride-1/active',
    ),
    '18_rating_sheet': ('/customer', _customer, null, null),
    '19_checkout_voucher': ('/customer', _customer, null, null),
    '20_driver_jobs_online': ('/driver', _driver, null, null),
    '53_driver_food_map': ('/driver', _driver, null, null),
    '40_driver_home_online': ('/driver', _driver, null, null),
    '41_driver_services': ('/driver', _driver, null, '/driver/services'),
    '21_place_picker': ('/customer', _customer, null, '/customer/places/pick'),
    '22_food_cart_address': ('/customer', _customer, null, null),
    '23_ride_book': ('/customer', _customer, 'Đặt', null),
    '24_ride_tracking': (
      '/customer',
      _customer,
      null,
      '/customer/ride/tracking/ride-track',
    ),
    '25_payment_history': ('/customer', _customer, 'Tôi', 'payments'),
    '26_help_center': ('/customer', _customer, 'Tôi', 'help'),
    '27_support_tickets': ('/customer', _customer, 'Tôi', 'help/tickets'),
    '28_support_ticket_detail': (
      '/customer',
      _customer,
      'Tôi',
      'help/tickets/ticket-replied',
    ),
    '29_support_ticket_new': (
      '/customer',
      _customer,
      'Tôi',
      'help/tickets/new',
    ),
    '30_food_store': (
      '/customer',
      _customer,
      null,
      '/customer/food/stores/$_storeId',
    ),
    '31_food_store_reviews': (
      '/customer',
      _customer,
      null,
      '/customer/food/stores/$_storeId',
    ),
    '32_merchant_order_new': ('/merchant', _merchant, 'Đơn hàng', null),
    '42_merchant_products': ('/merchant', _merchant, 'Thực đơn', null),
    '43_merchant_home': ('/merchant', _merchant, null, null),
    '80_food_home': ('/customer', _customer, 'Mua', null),
    '81_food_store_offers': (
      '/customer',
      _customer,
      null,
      '/customer/food/stores/$_storeId',
    ),
    '82_food_store_search': (
      '/customer',
      _customer,
      null,
      '/customer/food/stores/$_storeId',
    ),
    '83_food_store_reviews': (
      '/customer',
      _customer,
      null,
      '/customer/food/stores/$_storeId',
    ),
    '84_food_rating_sheet': ('/customer', _customer, null, null),
    '85_merchant_offers': ('/merchant', _merchant, null, '/merchant/offers'),
    '94_food_store_cart': (
      '/customer',
      _customer,
      null,
      '/customer/food/stores/$_storeId',
    ),
    '95_food_store_offers_sheet': (
      '/customer',
      _customer,
      null,
      '/customer/food/stores/$_storeId',
    ),
    '96_food_options_cart': (
      '/customer',
      _customer,
      null,
      '/customer/food/stores/$_storeId',
    ),
    '97_checkout_voucher_sheet': ('/customer', _customer, null, null),
    '98_merchant_profile': (
      '/merchant',
      _merchant,
      null,
      '/merchant/settings/profile',
    ),
    '86_merchant_offer_new': (
      '/merchant',
      _merchant,
      null,
      '/merchant/offers/new',
    ),
    '87_merchant_reviews': ('/merchant', _merchant, null, '/merchant/reviews'),
    '90_food_tracking': (
      '/customer',
      _customer,
      null,
      '/customer/food/orders/9a8b7c6d-0000-4000-8000-00000004a1f3',
    ),
    '92_food_search_results': (
      '/customer',
      _customer,
      null,
      '/customer/food/search',
    ),
    '93_food_order_history': ('/customer', _customer, 'Chuyến', null),
    '44_ride_offers_voucher': (
      '/customer',
      _customer,
      null,
      '/customer/ride/offers/ride-voucher',
    ),
    '45_ride_receipt_voucher': (
      '/customer',
      _customer,
      null,
      '/customer/ride/receipt/ride-done-voucher',
    ),
    '47_merchant_busy_paused': (
      '/merchant',
      _merchant,
      null,
      '/merchant/settings/busy',
    ),
    '48_merchant_hours': (
      '/merchant',
      _merchant,
      null,
      '/merchant/settings/hours',
    ),
    '49_merchant_accept': (
      '/merchant',
      _merchant,
      null,
      '/merchant/settings/accept',
    ),
    '51_home_search_choice': ('/customer', _customer, null, null),
    '50_merchant_busy_extra': (
      '/merchant',
      _merchant,
      null,
      '/merchant/settings/busy',
    ),
    '46_driver_cash_voucher': (
      '/driver',
      _driver,
      null,
      '/driver/rides/ride-done-voucher/active',
    ),
    '33_driver_job_completed': ('/driver', _driver, 'Thu nhập', null),
    '52_food_item_options': (
      '/customer',
      _customer,
      null,
      '/customer/food/stores/$_storeId',
    ),
    '53_merchant_item_options': (
      '/merchant',
      _merchant,
      null,
      '/merchant/products/i1/variants?name=B%C3%BAn%20ch%E1%BA%A3%20c%C3%A1',
    ),
    '54_food_invoice_options': (
      '/customer',
      _customer,
      null,
      '/customer/food/orders/9a8b7c6d-0000-4000-8000-00000004a1f3/invoice',
    ),
    '34_driver_notifications': ('/driver', _driver, 'Thông báo', null),
    '55_food_delivery_code': (
      '/customer',
      _customer,
      null,
      '/customer/food/orders/9a8b7c6d-0000-4000-8000-00000004a1f3',
    ),
    '56_driver_delivery_code': ('/driver', _driver, null, null),
    '57_merchant_handover_code': ('/merchant', _merchant, 'Đơn hàng', null),
    '58_delete_account': ('/customer', _customer, 'Tôi', 'delete-account'),
    '59_delete_account_filled': (
      '/customer',
      _customer,
      'Tôi',
      'delete-account',
    ),
    '60_delete_account_verify': (
      '/customer',
      _customer,
      'Tôi',
      'delete-account',
    ),
    '61_delete_account_done': ('/customer', _customer, 'Tôi', 'delete-account'),
    '62_food_category_tea': (
      '/customer',
      _customer,
      null,
      '/customer/food/category?category=tea',
    ),
    '63_merchant_store_category': (
      '/merchant',
      _merchant,
      null,
      '/merchant/settings/profile',
    ),
  };

  // DEC-PROD-036 shots need their own order state.
  final foodSetups = <String, void Function(FakeFoodClient food)>{
    '55_food_delivery_code': (food) {
      final base = food.orderDetail!;
      food.orderDetail = FoodOrderDetail(
        id: base.id,
        status: 'PICKED_UP',
        storeName: base.storeName,
        subtotalVnd: base.subtotalVnd,
        deliveryFareVnd: base.deliveryFareVnd,
        totalVnd: base.totalVnd,
        dropoff: base.dropoff,
        lines: base.lines,
        assignedDriverId: 'driver-1',
        deliveryCode: '4821',
      );
    },
    '56_driver_delivery_code': (food) {
      food
        ..claimed = const ClaimedFoodDelivery(
          id: '9a8b7c6d-0000-4000-8000-00000004b2c4',
          status: 'ASSIGNED',
        )
        ..expectedDeliveryCode = '4821';
    },
    '57_merchant_handover_code': (food) {
      final order = food.queueOrders.first;
      food.queueOrders = [
        MerchantQueueOrder(
          id: order.id,
          storeId: order.storeId,
          status: 'ASSIGNED',
          deliveryFareVnd: order.deliveryFareVnd,
          subtotalVnd: order.subtotalVnd,
          totalVnd: order.totalVnd,
          dropoff: order.dropoff,
          lineCount: order.lineCount,
          createdAt: order.createdAt,
          driverName: 'Minh A.',
        ),
      ];
      final base = food.orderDetail!;
      food.orderDetail = FoodOrderDetail(
        id: base.id,
        status: 'ASSIGNED',
        storeName: base.storeName,
        subtotalVnd: base.subtotalVnd,
        deliveryFareVnd: base.deliveryFareVnd,
        totalVnd: base.totalVnd,
        dropoff: base.dropoff,
        lines: base.lines,
        handoverCode: '2891',
      );
    },
  };

  const ridePlaces = RidePlaces(
    pickup: RidePoint(lat: 16.0544, lng: 108.2022, label: 'Vị trí hiện tại'),
    dropoff: RidePoint(
      lat: 16.0439,
      lng: 108.1994,
      label: 'Sân bay Quốc tế Đà Nẵng, Nguyễn Văn Linh, Hải Châu',
    ),
  );
  void addStoreItem(BuildContext context) {
    context.read<FoodCartCubit>().addItem(
      storeId: _storeId,
      storeName: 'Bún chả cá Bà Lữ',
      minOrderVnd: 40000,
      item: const FoodMenuItem(
        id: 'i2',
        name: 'Bún chả cá thường',
        priceVnd: 35000,
        available: true,
      ),
    );
  }

  void addSampleItem(BuildContext context) {
    context.read<FoodCartCubit>()
      ..addItem(
        storeId: 'store-1',
        storeName: 'Bún chả cá Bà Lữ',
        item: const FoodMenuItem(
          id: 'item-1',
          name: 'Bún chả cá đặc biệt',
          priceVnd: 55000,
          available: true,
        ),
      )
      ..setDropoff(
        label: 'Nhà, 45 Lê Duẩn, Hải Châu, Đà Nẵng',
        lat: 16.0717,
        lng: 108.2207,
      );
  }

  // Extra interaction after navigation, for screens without a direct route.
  final setups = <String, Future<void> Function(WidgetTester)>{
    '94_food_store_cart': (tester) async {
      addStoreItem(tester.element(find.byType(Scaffold).last));
      await tester.pumpAndSettle();
    },
    '95_food_store_offers_sheet': (tester) async {
      final all = find.byKey(const Key('food-store-offers-all'));
      await _reveal(tester, all);
      await tester.ensureVisible(all);
      await tester.pumpAndSettle();
      await tester.tap(all);
      await tester.pumpAndSettle();
    },
    '96_food_options_cart': (tester) async {
      addStoreItem(tester.element(find.byType(Scaffold).last));
      await tester.pumpAndSettle();
      await _revealStoreBar(tester);
      final price = find.byKey(const Key('food-price-i1')).last;
      await _reveal(tester, price);
      for (var i = 0; i < 10; i++) {
        final dy = tester.getCenter(price).dy;
        if (dy >= 260 && dy <= 600) break;
        await tester.dragFrom(
          const Offset(195, 400),
          Offset(0, dy > 600 ? -160 : 160),
        );
        await tester.pumpAndSettle();
      }
      await tester.tap(price);
      await tester.pumpAndSettle();
      await _tapInList(tester, find.byKey(const Key('food-option-o-large')));
    },
    '97_checkout_voucher_sheet': (tester) async {
      final context = tester.element(find.byType(Scaffold).first);
      addSampleItem(context);
      context.read<FoodCartCubit>().setDeliveryFare(15000);
      GoRouter.of(context).push(FoodRoutes.checkout);
      await tester.pumpAndSettle();
      final open = find.byKey(const Key('checkout-voucher-picker'));
      await _reveal(tester, open);
      await tester.ensureVisible(open);
      await tester.pumpAndSettle();
      await tester.tap(open);
      await tester.pumpAndSettle();
    },
    '63_merchant_store_category': (tester) async {
      final tea = find.byKey(const Key('food-category-pick-tea'));
      await _reveal(tester, tea);
      await tester.pumpAndSettle();
    },
    '18_rating_sheet': (tester) async {
      showModalBottomSheet<ServiceRating>(
        context: tester.element(find.byType(Scaffold).first),
        isScrollControlled: true,
        builder: (_) => const RatingSheet(
          type: RatingSubjectType.ride,
          subjectId: 'ride-1',
          hasDriver: true,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('rate-driver-stars-5')));
      await tester.pumpAndSettle();
    },
    '19_checkout_voucher': (tester) async {
      final context = tester.element(find.byType(Scaffold).first);
      addSampleItem(context);
      context.read<FoodCartCubit>()
        ..setDeliveryFare(15000)
        ..applyVoucher(code: 'DEALGO10', discountVnd: 10000);
      GoRouter.of(context).push(FoodRoutes.checkout);
      await tester.pumpAndSettle();
    },
    '22_food_cart_address': (tester) async {
      final context = tester.element(find.byType(Scaffold).first);
      addSampleItem(context);
      GoRouter.of(context).push(FoodRoutes.cart);
      await tester.pumpAndSettle();
    },
    '09_ride_route': (tester) async {
      GoRouter.of(tester.element(find.byType(Scaffold).first))
          .push(RideRoutes.routeOverview, extra: ridePlaces);
      await tester.pumpAndSettle();
    },
    '10_ride_fare': (tester) async {
      GoRouter.of(tester.element(find.byType(Scaffold).first)).push(
        RideRoutes.fare,
        extra: ridePlaces.withQuote(
          const RideQuote(
            distanceKm: 1.2,
            referenceFareVnd: 15000,
            minFareVnd: 15000,
            maxFareVnd: 1000000,
          ),
        ),
      );
      await tester.pumpAndSettle();
    },
    '92_food_search_results': (tester) async {
      await tester.enterText(find.byKey(const Key('food-search-field')), 'bún');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
    },
    '30_food_store': (tester) async {
      await _revealStoreBar(tester);
    },
    '82_food_store_search': (tester) async {
      await _revealStoreBar(tester);
      await tester.enterText(
        find.byKey(const Key('food-store-search')),
        'chả cá',
      );
      await tester.pumpAndSettle();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
    },
    '83_food_store_reviews': (tester) async {
      await _revealStoreBar(tester);
      await tester.tap(find.byKey(const Key('food-store-tab-reviews')));
      await tester.pumpAndSettle();
    },
    '84_food_rating_sheet': (tester) async {
      showModalBottomSheet<ServiceRating>(
        context: tester.element(find.byType(Scaffold).first),
        isScrollControlled: true,
        builder: (_) => const RatingSheet(
          type: RatingSubjectType.foodOrder,
          subjectId: 'order-1',
          hasDriver: true,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('rate-driver-stars-5')));
      await tester.pumpAndSettle();
    },
    '31_food_store_reviews': (tester) async {
      await _revealStoreBar(tester);
      await tester.tap(find.byKey(const Key('food-store-tab-reviews')));
      await tester.pumpAndSettle();
    },
    '32_merchant_order_new': (tester) async {
      final card = find.byKey(
        const Key('merchant-order-9a8b7c6d-0000-4000-8000-00000004a1f3'),
      );
      await tester.ensureVisible(card);
      await tester.tap(card);
      await tester.pumpAndSettle();
    },
    '33_driver_job_completed': (tester) async {
      final row = find.byKey(
        const Key('driver-history-item-7d1f0c2a-0000-4000-8000-000000000001'),
      );
      await _reveal(tester, row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();
    },
    '47_merchant_busy_paused': (tester) async {
      final paused = find.byKey(const Key('merchant-busy-paused'));
      await tester.ensureVisible(paused);
      await tester.tap(paused);
      await tester.pumpAndSettle();
    },
    '51_home_search_choice': (tester) async {
      await tester.enterText(
        find.byKey(const Key('home-search-field')),
        'bún bò',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
    },
    '50_merchant_busy_extra': (tester) async {
      final busy = find.byKey(const Key('merchant-busy-busy'));
      await tester.ensureVisible(busy);
      await tester.tap(busy);
      await tester.pumpAndSettle();
      final extra = find.byKey(const Key('merchant-busy-extra-30'));
      await Scrollable.ensureVisible(tester.element(extra), alignment: 0.5);
      await tester.pumpAndSettle();
      await tester.tap(extra);
      await tester.pumpAndSettle();
    },
    '44_ride_offers_voucher': (tester) async {
      final field = find.byKey(const Key('voucher-field'));
      await _reveal(tester, field);
      await tester.enterText(field, 'DEALGO10');
      await tester.tap(find.byKey(const Key('voucher-apply')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('voucher-applied')));
      await tester.pumpAndSettle();
    },
    '52_food_item_options': (tester) async {
      await _revealStoreBar(tester);
      await _reveal(tester, find.byKey(const Key('food-add-i1')));
      final add = find.byKey(const Key('food-add-i1')).last;
      // The pinned tabs/search bar covers the top of the menu viewport, so an
      // item aligned to its leading edge would be tapped through the bar.
      for (var i = 0; i < 6 && tester.getCenter(add).dy < 260; i++) {
        await tester.dragFrom(const Offset(195, 500), const Offset(0, 120));
        await tester.pumpAndSettle();
      }
      await tester.tap(add);
      await tester.pumpAndSettle();
      await _tapInList(tester, find.byKey(const Key('food-option-o-large')));
      await _tapInList(tester, find.byKey(const Key('food-option-o-cha')));
    },
    '40_driver_home_online': (tester) async {
      await tester.tap(find.byKey(const Key('driver-go-online')));
      await tester.pumpAndSettle();
    },
    '53_driver_food_map': (tester) async {
      await tester.tap(find.byKey(const Key('driver-go-online')));
      await tester.pumpAndSettle();
      await tester.tap(navLabel('Việc nhận').first);
      await tester.pumpAndSettle();
      final job = find.byKey(
        const Key('driver-food-9a8b7c6d-0000-4000-8000-00000004b2c4'),
      );
      await _reveal(tester, job);
      await tester.pumpAndSettle();
      await tester.tap(job);
      await tester.pumpAndSettle();
    },
    '56_driver_delivery_code': (tester) async {
      await tester.tap(find.byKey(const Key('driver-go-online')));
      await tester.pumpAndSettle();
      await tester.tap(navLabel('Việc nhận').first);
      await tester.pumpAndSettle();
      final job = find.byKey(
        const Key('driver-food-9a8b7c6d-0000-4000-8000-00000004b2c4'),
      );
      await _reveal(tester, job);
      await tester.pumpAndSettle();
      await tester.tap(job);
      await tester.pumpAndSettle();
      for (final key in [
        'driver-claim-job',
        'driver-food-pickup',
        'driver-food-complete',
      ]) {
        await tester.tap(find.byKey(Key(key)));
        await tester.pumpAndSettle();
      }
      await tester.enterText(
        find.byKey(const Key('driver-food-code-input')),
        '48',
      );
      await tester.pumpAndSettle();
    },
    '57_merchant_handover_code': (tester) async {
      final card = find.byKey(
        const Key('merchant-order-9a8b7c6d-0000-4000-8000-00000004a1f3'),
      );
      await tester.ensureVisible(card);
      await tester.tap(card);
      await tester.pumpAndSettle();
      final code = find.byKey(const Key('merchant-handover-code'));
      await Scrollable.ensureVisible(tester.element(code), alignment: 0.4);
      await tester.pumpAndSettle();
    },
    '59_delete_account_filled': _fillDeleteForm,
    '60_delete_account_verify': (tester) async {
      await _fillDeleteForm(tester);
      await tester.tap(find.byKey(const ValueKey('delete-continue')));
      await tester.pumpAndSettle();
    },
    '61_delete_account_done': (tester) async {
      await _fillDeleteForm(tester);
      await tester.tap(find.byKey(const ValueKey('delete-continue')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('delete-secret')),
        '123456',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('delete-confirm')));
      await tester.pumpAndSettle();
    },
    '55_food_delivery_code': (tester) async {
      final code = find.byKey(const Key('food-delivery-code-panel'));
      await Scrollable.ensureVisible(tester.element(code), alignment: 0.6);
      await tester.pumpAndSettle();
    },
    '20_driver_jobs_online': (tester) async {
      await tester.tap(find.byKey(const Key('driver-go-online')));
      await tester.pumpAndSettle();
      await tester.tap(navLabel('Việc nhận').first);
      await tester.pumpAndSettle();
    },
  };

  for (final entry in shots.entries) {
    testWidgets('screenshot ${entry.key}', (tester) async {
      final (location, profile, tab, push) = entry.value;
      final food = _food();
      foodSetups[entry.key]?.call(food);
      await _pump(tester, location: location, profile: profile, food: food);
      if (tab != null) {
        await tester.tap(navLabel(tab).first);
        await tester.pumpAndSettle();
      }
      if (push != null) {
        final router = GoRouter.of(tester.element(find.byType(Scaffold).last));
        final current = router.routeInformationProvider.value.uri.path;
        router.push(push.startsWith('/') ? push : '$current/$push');
        await tester.pumpAndSettle();
      }
      await setups[entry.key]?.call(tester);
      await _shoot(tester, entry.key);
      addTearDown(tester.view.reset);
    }, skip: !_enabled);
  }
}

/// Lazy lists on a 320x568 viewport do not build rows below the fold, so
/// [WidgetTester.ensureVisible] cannot find them. Scroll until built.
Future<void> _tapInList(WidgetTester tester, Finder target) async {
  for (var i = 0; i < 8; i++) {
    final built = target.evaluate().isNotEmpty;
    if (built && tester.getCenter(target.first).dy < 700) break;
    await tester.dragFrom(const Offset(195, 480), const Offset(0, -160));
    await tester.pumpAndSettle();
  }
  await tester.tap(target.first);
  await tester.pumpAndSettle();
}

Future<void> _revealStoreBar(WidgetTester tester) async {
  final bar = find.byKey(const Key('food-store-search'));
  for (var i = 0; i < 10; i++) {
    if (bar.evaluate().isNotEmpty && tester.getTopLeft(bar.first).dy <= 120) {
      break;
    }
    await tester.dragFrom(const Offset(210, 620), const Offset(0, -220));
    await tester.pumpAndSettle();
  }
}

Future<void> _reveal(WidgetTester tester, Finder target) async {
  for (var i = 0; i < 20 && target.evaluate().isEmpty; i++) {
    final view = tester.view.physicalSize / tester.view.devicePixelRatio;
    await tester.dragFrom(
      Offset(view.width / 2, view.height * 0.6),
      const Offset(0, -240),
    );
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(target);
}
