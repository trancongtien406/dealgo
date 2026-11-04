import 'package:dealgo/features/food/domain/entities/food_models.dart';
import 'package:dealgo/features/food/domain/repositories/food_repository.dart';
import 'package:dealgo/features/food/domain/usecases/list_food_stores.dart';
import 'package:dealgo/features/food/presentation/cubit/food_cart_cubit.dart';
import 'package:dealgo/features/food/presentation/cubit/food_discovery_cubit.dart';
import 'package:dealgo/features/ride/presentation/pages/ride_map_page.dart';
import 'package:dealgo/features/ride/presentation/widgets/ride_widgets.dart';
import 'package:dealgo/features/ride/presentation/utils/ride_distance.dart';
import 'package:dealgo/l10n/app_localizations_vi.dart';
import 'package:dealgo/core/maps/map_markers.dart';
import 'package:dealgo/features/food/data/datasources/dio_food_remote_datasource.dart';
import 'package:dealgo/features/food/presentation/pages/food_tracking_page.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _FoodRepo implements FoodRepository {
  final searches = <String?>[];
  @override
  Future<FoodStorePageResult> listStores(
    String accessToken, {
    double? lat,
    double? lng,
    String? search,
    String? sortBy,
    int? maxKm,
    String? category,
    int page = 1,
    int limit = 20,
  }) async {
    searches.add(search);
    return FoodStorePageResult(
      items: const [],
      total: 0,
      page: page,
      limit: limit,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('C1: cart is emptied after a successful order, dropoff kept', () {
    final cart = FoodCartCubit();
    cart.setDropoff(label: '12 Lê Duẩn', lat: 16.07, lng: 108.22);
    cart.addItem(
      storeId: 's1',
      storeName: 'Quán',
      item: const FoodMenuItem(
        id: 'i1',
        name: 'Phở',
        priceVnd: 40000,
        available: true,
      ),
    );
    expect(cart.state.lines, isNotEmpty);
    final key = cart.state.idempotencyKey;
    cart.clearAfterOrder();
    expect(cart.state.lines, isEmpty);
    expect(cart.state.dropoffLabel, '12 Lê Duẩn');
    expect(cart.state.idempotencyKey, isNot(key));
  });

  test('C3: food search asks the server with ?search=', () async {
    final repo = _FoodRepo();
    final cubit = FoodDiscoveryCubit(listFoodStores: ListFoodStores(repo));
    await cubit.load('tok', search: 'phở');
    expect(repo.searches, ['phở']);
    await cubit.close();
  });

  test('ride chip shows km and ETA from the road route', () {
    final l10n = AppLocalizationsVi();
    expect(
      rideDistanceText(
        l10n,
        const RideDistance(km: 3.2, road: true, minutes: 9),
      ),
      contains('9 phút'),
    );
    expect(
      rideDistanceText(l10n, const RideDistance(km: 3.2, road: false)),
      startsWith('~'),
    );
  });

  test('C11: a PLACED order reads "Chờ quán xác nhận", not cooking', () {
    final l10n = AppLocalizationsVi();
    expect(
      foodTrackingTitle(l10n, FoodTrackingStage.preparing, status: 'PLACED'),
      'Chờ quán xác nhận',
    );
    expect(
      foodTrackingTitle(l10n, FoodTrackingStage.preparing, status: 'PREPARING'),
      l10n.foodStagePreparing,
    );
  });

  test('M3: merchant queue shows dishes by quantity (itemCount)', () {
    Map<String, Object?> row(Map<String, Object?> extra) => {
      'id': 'o1',
      'storeId': 's1',
      'status': 'PLACED',
      'deliveryFareVnd': 1,
      'subtotalVnd': 1,
      'totalVnd': 2,
      'dropoff': {'lat': 16.0, 'lng': 108.0, 'label': 'x'},
      'lineCount': 1,
      'createdAt': '2026-10-28T00:00:00Z',
      ...extra,
    };
    expect(decodeMerchantQueueOrder(row({'itemCount': 2}))!.lineCount, 2);
    expect(decodeMerchantQueueOrder(row({}))!.lineCount, 1);
  });

  test('C8: the expanded ride sheet stops under the floating back button', () {
    const media = MediaQueryData(
      size: Size(402, 874),
      padding: EdgeInsets.only(top: 62),
    );
    final max = rideSheetMaxSize(media);
    // Sheet top edge (px from the top) clears status bar + 44pt back button.
    expect(874 * (1 - max), greaterThanOrEqualTo(62 + 44));
    expect(max, lessThanOrEqualTo(0.86));
  });

  test('ride price sheet: snaps stay below the capped max on small phones', () {
    const se = MediaQueryData(
      size: Size(375, 667),
      padding: EdgeInsets.only(top: 20),
    );
    final max = rideSheetMaxSize(se);
    expect(667 * (1 - max), greaterThanOrEqualTo(20 + 44));
    final snaps = rideSheetSnapSizes(const [0.32, 0.56, 0.78], max);
    expect(snaps, everyElement(lessThan(max)));
    expect(snaps, containsAll(<double>[0.32, 0.56]));
  });

  test('C7: destination-only map labels the stop "Đến", not "Đón"', () {
    expect(
      mapPinKindFor(0, firstMarkerIsPickup: false),
      DealGoMapPinKind.dropoff,
    );
    expect(
      mapPinKindFor(0, firstMarkerIsPickup: true),
      DealGoMapPinKind.pickup,
    );
  });
}
