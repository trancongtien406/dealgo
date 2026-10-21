import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/food_models.dart';
import '../../domain/params/get_food_store_params.dart';
import '../../domain/params/place_food_order_params.dart';
import '../../domain/usecases/get_food_store.dart';
import '../../domain/usecases/place_food_order.dart';

class FoodCheckoutCubit extends Cubit<int> {
  FoodCheckoutCubit({
    required this._getFoodStore,
    required this._placeFoodOrder,
  }) : super(0);

  final GetFoodStore _getFoodStore;
  final PlaceFoodOrder _placeFoodOrder;

  Future<FoodStoreDetail> loadStore({
    required String accessToken,
    required String storeId,
  }) {
    return _getFoodStore(
      GetFoodStoreParams(accessToken: accessToken, storeId: storeId),
    );
  }

  Future<PlacedFoodOrder> placeOrder(PlaceFoodOrderParams request) {
    return _placeFoodOrder(request);
  }
}
