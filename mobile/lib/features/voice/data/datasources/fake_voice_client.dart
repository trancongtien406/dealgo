import '../../domain/entities/voice_models.dart';
import 'voice_remote_datasource.dart';

class FakeVoiceClient implements VoiceClient {
  FakeVoiceClient({this.session});

  VoiceSession? session;
  final List<String> rideCalls = [];
  final List<String> foodCalls = [];
  Object? error;

  @override
  Future<VoiceSession> createRideVoiceSession({
    required String accessToken,
    required String rideId,
  }) async {
    rideCalls.add(rideId);
    final err = error;
    if (err != null) {
      throw err;
    }
    return session ??
        VoiceSession(
          roomName: 'ride-$rideId',
          token: 'fake-livekit-token',
          url: 'wss://livekit.example/fake',
        );
  }

  @override
  Future<VoiceSession> createFoodOrderVoiceSession({
    required String accessToken,
    required String orderId,
  }) async {
    foodCalls.add(orderId);
    final err = error;
    if (err != null) {
      throw err;
    }
    return session ??
        VoiceSession(
          roomName: 'food-$orderId',
          token: 'fake-livekit-token',
          url: 'wss://livekit.example/fake',
        );
  }
}
