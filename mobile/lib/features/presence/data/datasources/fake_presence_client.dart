import '../../domain/entities/driver_service_prefs.dart';
import 'presence_remote_datasource.dart';

class FakePresenceClient implements PresenceClient {
  FakePresenceClient({this.prefs = DriverServicePrefs.defaults});

  final List<({bool online, double? lat, double? lng, bool? rideEnabled, bool? foodEnabled})> calls =
      [];
  DriverServicePrefs prefs;
  Object? saveError;

  @override
  Future<void> setPresence({
    required String accessToken,
    required bool online,
    double? lat,
    double? lng,
    bool? rideEnabled,
    bool? foodEnabled,
  }) async {
    calls.add((online: online, lat: lat, lng: lng, rideEnabled: rideEnabled, foodEnabled: foodEnabled));
    final error = saveError;
    if (error != null) {
      throw error;
    }
    prefs = prefs.copyWith(rideEnabled: rideEnabled, foodEnabled: foodEnabled);
  }

  @override
  Future<DriverServicePrefs> getServicePrefs({required String accessToken}) async => prefs;
}
