import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_exception.dart';
import '../../domain/entities/voice_models.dart';
import '../../domain/params/create_voice_session_params.dart';
import '../../domain/usecases/create_food_order_voice_session.dart';
import '../../domain/usecases/create_ride_voice_session.dart';
import '../../../../core/l10n/ui_message.dart';

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

  final UiMessage message;
}

class VoiceCubit extends Cubit<VoiceState> {
  VoiceCubit({
    required this._createRideVoiceSession,
    required this._createFoodOrderVoiceSession,
    required this.kind,
    required this.resourceId,
  }) : super(const VoiceInitial());

  final CreateRideVoiceSession _createRideVoiceSession;
  final CreateFoodOrderVoiceSession _createFoodOrderVoiceSession;
  final VoiceThreadKind kind;
  final String resourceId;

  Future<void> start({required String? accessToken}) async {
    final token = accessToken?.trim() ?? '';
    if (token.isEmpty) {
      emit(VoiceFailure(UiMessage((l10n) => l10n.errorSessionExpired)));
      return;
    }
    emit(const VoiceLoading());
    try {
      final session = switch (kind) {
        VoiceThreadKind.ride => await _createRideVoiceSession(
          CreateRideVoiceSessionParams(accessToken: token, rideId: resourceId),
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
      emit(VoiceFailure(UiMessage.error(error)));
    } catch (error) {
      emit(VoiceFailure(UiMessage.error(error, fallback: (l10n) => l10n.voiceOpenFailed)));
    }
  }
}
