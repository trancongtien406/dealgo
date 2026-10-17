import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_exception.dart';
import '../../domain/entities/voice_models.dart';
import '../../domain/params/create_voice_session_params.dart';
import '../../domain/usecases/create_food_order_voice_session.dart';
import '../../domain/usecases/create_ride_voice_session.dart';

sealed class VoiceState {
  const VoiceState();
}

final class VoiceInitial extends VoiceState {
  const VoiceInitial();
}

final class VoiceLoading extends VoiceState {
  const VoiceLoading();
}

final class VoiceReady extends VoiceState {
  const VoiceReady(this.session);

  final VoiceSession session;
}

final class VoiceFailure extends VoiceState {
  const VoiceFailure(this.message);

  final String message;
}

class VoiceCubit extends Cubit<VoiceState> {
  VoiceCubit({
    required CreateRideVoiceSession createRideVoiceSession,
    required CreateFoodOrderVoiceSession createFoodOrderVoiceSession,
    required this.kind,
    required this.resourceId,
  }) : _createRideVoiceSession = createRideVoiceSession,
       _createFoodOrderVoiceSession = createFoodOrderVoiceSession,
       super(const VoiceInitial());

  final CreateRideVoiceSession _createRideVoiceSession;
  final CreateFoodOrderVoiceSession _createFoodOrderVoiceSession;
  final VoiceThreadKind kind;
  final String resourceId;

  Future<void> start({required String? accessToken}) async {
    final token = accessToken?.trim() ?? '';
    if (token.isEmpty) {
      emit(const VoiceFailure('Vui lòng đăng nhập lại'));
      return;
    }
    emit(const VoiceLoading());
    try {
      final session = switch (kind) {
        VoiceThreadKind.ride => await _createRideVoiceSession(
          CreateRideVoiceSessionParams(
            accessToken: token,
            rideId: resourceId,
          ),
        ),
        VoiceThreadKind.foodOrder => await _createFoodOrderVoiceSession(
          CreateFoodOrderVoiceSessionParams(
            accessToken: token,
            orderId: resourceId,
          ),
        ),
      };
      emit(VoiceReady(session));
    } on ApiException catch (error) {
      emit(VoiceFailure(error.message));
    } catch (_) {
      emit(const VoiceFailure('Không mở được cuộc gọi'));
    }
  }
}
