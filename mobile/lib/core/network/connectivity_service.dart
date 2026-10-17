import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class ConnectivityService {
  ConnectivityService() : _connectivity = Connectivity();

  ConnectivityService.withClient(this._connectivity);

  final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  final _controller = StreamController<bool>.broadcast();
  bool _online = true;

  bool get isOnline => _online;

  Stream<bool> get onStatusChanged => _controller.stream;

  Future<void> start() async {
    final initial = await _connectivity.checkConnectivity();
    _apply(initial);
    await _subscription?.cancel();
    _subscription = _connectivity.onConnectivityChanged.listen(_apply);
  }

  Future<bool> checkOnline() async {
    final results = await _connectivity.checkConnectivity();
    _apply(results);
    return _online;
  }

  void _apply(List<ConnectivityResult> results) {
    final next = results.any((r) => r != ConnectivityResult.none);
    if (next == _online) {
      return;
    }
    _online = next;
    if (!_controller.isClosed) {
      _controller.add(_online);
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    await _controller.close();
  }
}
