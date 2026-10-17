import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_exception.dart';
import '../../domain/entities/food_models.dart';
import '../../domain/usecases/list_food_stores.dart';

sealed class FoodDiscoveryState {
  const FoodDiscoveryState();
}

final class FoodDiscoveryLoading extends FoodDiscoveryState {
  const FoodDiscoveryLoading();
}

final class FoodDiscoveryReady extends FoodDiscoveryState {
  const FoodDiscoveryReady(this.stores);

  final List<FoodStoreSummary> stores;
}

final class FoodDiscoveryFailed extends FoodDiscoveryState {
  const FoodDiscoveryFailed(this.message);

  final String message;
}

class FoodDiscoveryCubit extends Cubit<FoodDiscoveryState> {
  FoodDiscoveryCubit({required ListFoodStores listFoodStores})
    : _listFoodStores = listFoodStores,
      super(const FoodDiscoveryLoading());

  final ListFoodStores _listFoodStores;
  var _generation = 0;

  Future<void> load(String? accessToken) async {
    final generation = ++_generation;
    final token = accessToken?.trim() ?? '';
    if (token.isEmpty) {
      emit(const FoodDiscoveryFailed('UNAUTHORIZED'));
      return;
    }
    emit(const FoodDiscoveryLoading());
    try {
      final stores = await _listFoodStores(token);
      if (isClosed || generation != _generation) {
        return;
      }
      emit(FoodDiscoveryReady(List.unmodifiable(stores)));
    } on ApiException catch (error) {
      if (isClosed || generation != _generation) {
        return;
      }
      emit(FoodDiscoveryFailed(error.message));
    } catch (_) {
      if (isClosed || generation != _generation) {
        return;
      }
      emit(const FoodDiscoveryFailed('NETWORK_ERROR'));
    }
  }
}
