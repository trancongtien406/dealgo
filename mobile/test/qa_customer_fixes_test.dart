import 'package:dealgo/features/food/domain/entities/food_models.dart';
import 'package:dealgo/features/food/domain/repositories/food_repository.dart';
import 'package:dealgo/features/food/domain/usecases/list_food_stores.dart';
import 'package:dealgo/features/food/presentation/cubit/food_cart_cubit.dart';
import 'package:dealgo/features/food/presentation/cubit/food_discovery_cubit.dart';
import 'package:dealgo/features/ride/presentation/pages/ride_map_page.dart';
import 'package:dealgo/features/ride/presentation/utils/ride_distance.dart';
import 'package:dealgo/l10n/app_localizations_vi.dart';
import 'package:flutter_test/flutter_test.dart';

class _FoodRepo implements FoodRepository {
  final searches = <String?>[];
  @override
  Future<List<FoodStoreSummary>> listStores(
    String accessToken, {
    double? lat,
    double? lng,
    String? search,
  }) async {
    searches.add(search);
    return const [];
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
}
