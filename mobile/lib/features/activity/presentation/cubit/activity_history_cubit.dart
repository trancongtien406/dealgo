import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_exception.dart';
import '../../domain/entities/history_models.dart';
import '../../domain/usecases/list_food_history.dart';
import '../../domain/usecases/list_ride_history.dart';
import '../../../../core/l10n/ui_message.dart';

sealed class ActivityHistoryState {
  const ActivityHistoryState({
    this.rides = const [],
    this.food = const [],
    this.busy = false,
  });

  final List<HistoryItem> rides;
  final List<HistoryItem> food;
  final bool busy;
}

final class ActivityHistoryInitial extends ActivityHistoryState {
  const ActivityHistoryInitial() : super();
}

final class ActivityHistoryLoading extends ActivityHistoryState {
  const ActivityHistoryLoading({super.rides, super.food}) : super(busy: true);
}

final class ActivityHistoryReady extends ActivityHistoryState {
  const ActivityHistoryReady({required super.rides, required super.food});
}

final class ActivityHistoryFailure extends ActivityHistoryState {
  const ActivityHistoryFailure({
    required this.message,
    super.rides,
    super.food,
  });

  final UiMessage message;
}

class ActivityHistoryCubit extends Cubit<ActivityHistoryState> {
  ActivityHistoryCubit({
    required this._listRideHistory,
    required this._listFoodHistory,
  }) : super(const ActivityHistoryInitial());

  final ListRideHistory _listRideHistory;
  final ListFoodHistory _listFoodHistory;

  Future<void> load({required String? accessToken}) async {
    final token = accessToken?.trim() ?? '';
    if (token.isEmpty) {
      emit(
        ActivityHistoryFailure(
          message: UiMessage((l10n) => l10n.errorSessionExpired),
        ),
      );
      return;
    }
    emit(ActivityHistoryLoading(rides: state.rides, food: state.food));
    try {
      final results = await Future.wait([
        _listRideHistory(token),
        _listFoodHistory(token),
      ]);
      emit(ActivityHistoryReady(rides: results[0], food: results[1]));
    } on ApiException catch (error) {
      emit(
        ActivityHistoryFailure(
          message: UiMessage.error(error),
          rides: state.rides,
          food: state.food,
        ),
      );
    } catch (error) {
      emit(
        ActivityHistoryFailure(
          message: UiMessage.error(
            error,
            fallback: (l10n) => l10n.stateErrorBody,
          ),
          rides: state.rides,
          food: state.food,
        ),
      );
    }
  }
}
