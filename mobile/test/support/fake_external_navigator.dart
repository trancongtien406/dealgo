import 'package:dealgo/core/navigation/external_navigator.dart';

class FakeExternalNavigator implements ExternalNavigator {
  FakeExternalNavigator({this.result = true, Set<NavigationApp>? installed})
    : installed =
          installed ??
          {
            NavigationApp.googleMaps,
            NavigationApp.appleMaps,
            NavigationApp.waze,
            NavigationApp.web,
          };

  bool result;

  /// What [available] reports (web is always added).
  Set<NavigationApp> installed;
  final List<(NavigationApp, double, double)> calls = [];

  @override
  Future<Set<NavigationApp>> available() async => {
    ...installed,
    NavigationApp.web,
  };

  @override
  Future<bool> open(
    NavigationApp app, {
    required double lat,
    required double lng,
  }) async {
    calls.add((app, lat, lng));
    return result;
  }
}
