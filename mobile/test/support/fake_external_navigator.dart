import 'package:dealgo/core/navigation/external_navigator.dart';

class FakeExternalNavigator implements ExternalNavigator {
  FakeExternalNavigator({this.result = true});

  bool result;
  final List<(NavigationApp, double, double)> calls = [];

  @override
  Future<bool> open(NavigationApp app, {required double lat, required double lng}) async {
    calls.add((app, lat, lng));
    return result;
  }
}
