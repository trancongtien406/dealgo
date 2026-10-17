import 'presence_remote_datasource.dart';

class FakePresenceClient implements PresenceClient {
  final List<({bool online, double? lat, double? lng})> calls = [];

  @override
  Future<void> setPresence({
    required String accessToken,
    required bool online,
    double? lat,
    double? lng,
  }) async {
    calls.add((online: online, lat: lat, lng: lng));
  }
}
