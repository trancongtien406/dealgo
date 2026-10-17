import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/food_models.dart';
import '../../domain/params/get_food_store_params.dart';
import '../../domain/usecases/get_food_store.dart';

class FoodStoreCubit extends Cubit<int> {
  FoodStoreCubit({required GetFoodStore getFoodStore})
    : _getFoodStore = getFoodStore,
      super(0);

  final GetFoodStore _getFoodStore;

  Future<FoodStoreDetail> load({
    required String accessToken,
    required String storeId,
  }) {
    return _getFoodStore(
      GetFoodStoreParams(accessToken: accessToken, storeId: storeId),
    );
  }
}
