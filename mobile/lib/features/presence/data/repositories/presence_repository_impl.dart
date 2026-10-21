import '../../domain/entities/driver_service_prefs.dart';
import '../../domain/repositories/presence_repository.dart';
import '../datasources/presence_remote_datasource.dart';

class PresenceRepositoryImpl implements PresenceRepository {
  PresenceRepositoryImpl(this._remote);

  final PresenceRemoteDataSource _remote;

  @override
  Future<void> setPresence({
    required String accessToken,
    required bool online,
    double? lat,
    double? lng,
    bool? rideEnabled,
    bool? foodEnabled,
  }) {
    return _remote.setPresence(
      accessToken: accessToken,
      online: online,
      lat: lat,
      lng: lng,
      rideEnabled: rideEnabled,
      foodEnabled: foodEnabled,
    );
  }

  @override
  Future<DriverServicePrefs> getServicePrefs({required String accessToken}) {
    return _remote.getServicePrefs(accessToken: accessToken);
  }
}
