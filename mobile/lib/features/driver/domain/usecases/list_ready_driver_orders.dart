import '../../../food/domain/entities/food_models.dart';
import '../repositories/driver_jobs_repository.dart';

class ListReadyDriverOrders {
  const ListReadyDriverOrders(this._repository);

  final DriverJobsRepository _repository;

  Future<List<ReadyFoodJob>> call(String accessToken) {
    return _repository.listReadyOrders(accessToken);
  }
}
