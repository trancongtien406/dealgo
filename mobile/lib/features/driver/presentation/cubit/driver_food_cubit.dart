import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../food/domain/entities/food_models.dart';
import '../../domain/params/claim_food_order_params.dart';
import '../../domain/usecases/claim_food_order.dart';

class DriverFoodCubit extends Cubit<int> {
  DriverFoodCubit({required this._claimFoodOrder}) : super(0);

  final ClaimFoodOrder _claimFoodOrder;

  Future<ClaimedFoodDelivery> claim({
    required String accessToken,
    required String orderId,
  }) {
    return _claimFoodOrder(
      ClaimFoodOrderParams(accessToken: accessToken, orderId: orderId),
    );
  }
}
