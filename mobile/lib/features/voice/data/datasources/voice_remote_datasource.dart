import '../../domain/repositories/voice_repository.dart';

/// HTTP side of in-app calls; same contract as the repository.
abstract interface class VoiceRemoteDataSource implements VoiceRepository {}

/// Alias used by DI overrides and tests.
typedef VoiceClient = VoiceRemoteDataSource;
