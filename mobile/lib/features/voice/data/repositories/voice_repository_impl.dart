import '../../domain/entities/voice_models.dart';
import '../../domain/repositories/voice_repository.dart';
import '../datasources/voice_remote_datasource.dart';

class VoiceRepositoryImpl implements VoiceRepository {
  VoiceRepositoryImpl(this._remote);

  final VoiceRemoteDataSource _remote;

  @override
  Future<VoiceSession> createRideVoiceSession({
    required String accessToken,
    required String rideId,
  }) {
    return _remote.createRideVoiceSession(
      accessToken: accessToken,
      rideId: rideId,
    );
  }

  @override
  Future<VoiceSession> createFoodOrderVoiceSession({
    required String accessToken,
    required String orderId,
  }) {
    return _remote.createFoodOrderVoiceSession(
      accessToken: accessToken,
      orderId: orderId,
    );
  }
}
