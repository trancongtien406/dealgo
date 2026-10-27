import '../../domain/entities/voice_models.dart';
import '../../domain/repositories/voice_repository.dart';
import '../datasources/voice_remote_datasource.dart';

class VoiceRepositoryImpl implements VoiceRepository {
  VoiceRepositoryImpl(this._remote);

  final VoiceRemoteDataSource _remote;

  @override
  Future<VoiceCallConfig> config({required String accessToken}) =>
      _remote.config(accessToken: accessToken);

  @override
  Future<VoiceCallJoin> start({
    required String accessToken,
    required VoiceThreadKind kind,
    required String resourceId,
  }) => _remote.start(
    accessToken: accessToken,
    kind: kind,
    resourceId: resourceId,
  );

  @override
  Future<VoiceCall> get({
    required String accessToken,
    required String callId,
  }) => _remote.get(accessToken: accessToken, callId: callId);

  @override
  Future<VoiceCallJoin> accept({
    required String accessToken,
    required String callId,
  }) => _remote.accept(accessToken: accessToken, callId: callId);

  @override
  Future<VoiceCall> decline({
    required String accessToken,
    required String callId,
  }) => _remote.decline(accessToken: accessToken, callId: callId);

  @override
  Future<VoiceCall> end({
    required String accessToken,
    required String callId,
  }) => _remote.end(accessToken: accessToken, callId: callId);
}
