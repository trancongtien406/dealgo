import 'package:flutter_test/flutter_test.dart';
import 'package:dealgo/features/food/domain/entities/food_models.dart';
import 'package:dealgo/features/food/presentation/cubit/food_cart_cubit.dart';

void main() {
  const order = FoodOrderDetail(
    id: 'o1',
    status: 'DELIVERED',
    storeId: 's1',
    storeName: 'Bún Bò Huế',
    subtotalVnd: 200000,
    deliveryFareVnd: 15000,
    totalVnd: 215000,
    dropoff: FoodDropoff(lat: 16.07, lng: 108.22, label: '45 Lê Duẩn'),
    lines: [
      FoodOrderLine(
        itemId: 'i1',
        name: 'Bún bò',
        unitPriceVnd: 50000,
        quantity: 2,
      ),
      FoodOrderLine(
        itemId: 'gone',
        name: 'Hết bán',
        unitPriceVnd: 10000,
        quantity: 1,
      ),
    ],
  );
  const store = FoodStoreDetail(
    id: 's1',
    name: 'Bún Bò Huế',
    items: [
      FoodMenuItem(id: 'i1', name: 'Bún bò', priceVnd: 60000, available: true),
    ],
  );

  test('reorder rebuilds the cart from the live menu price and drops missing items', () {
    final cart = FoodCartCubit();
    final dropped = cart.reorder(order, store);
    expect(dropped, 1);
    expect(cart.state.storeId, 's1');
    expect(cart.state.lines.single.quantity, 2);
    // The live menu price, never the old order price; server reprices on place.
    expect(cart.state.lines.single.unitPriceVnd, 60000);
  });
}
