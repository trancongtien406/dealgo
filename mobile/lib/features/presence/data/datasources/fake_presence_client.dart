import '../../domain/entities/driver_service_prefs.dart';
import 'presence_remote_datasource.dart';

class FakePresenceClient implements PresenceClient {
  FakePresenceClient({this.prefs = DriverServicePrefs.defaults});

  final List<
    ({
      bool online,
      double? lat,
      double? lng,
      bool? rideEnabled,
      bool? foodEnabled,
      bool? parcelEnabled,
    })
  >
  calls = [];
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
    bool? parcelEnabled,
  }) async {
    calls.add((
      online: online,
      lat: lat,
      lng: lng,
      rideEnabled: rideEnabled,
      foodEnabled: foodEnabled,
      parcelEnabled: parcelEnabled,
    ));
    final error = saveError;
    if (error != null) {
      throw error;
    }
    prefs = prefs.copyWith(
      rideEnabled: rideEnabled,
      foodEnabled: foodEnabled,
      parcelEnabled: parcelEnabled,
    );
  }

  @override
  Future<DriverServicePrefs> getServicePrefs({
    required String accessToken,
  }) async => prefs;
}
