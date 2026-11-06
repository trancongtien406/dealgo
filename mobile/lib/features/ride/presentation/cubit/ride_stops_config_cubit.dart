import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/ride_models.dart';
import '../../domain/stops/ride_stops_client.dart';

/// Admin multi-stop limits (`GET /v1/rides/multi-stop-config`).
///
/// The flags are an operator setting, not a per-booking value, so they are
/// read once per app session; every booking reuses the same answer and a
/// failed read leaves the stop controls hidden.
class RideStopsConfigCubit extends Cubit<MultiStopSettings> {
  RideStopsConfigCubit({required this._client, required this._accessToken})
    : super(MultiStopSettings.disabled);

  final RideStopsClient _client;
  final String? Function() _accessToken;
  var _loaded = false;
  Future<void>? _inFlight;

  Future<void> load({bool force = false}) {
    if (!force && _loaded) {
      return Future.value();
    }
    return _inFlight ??= _fetch().whenComplete(() => _inFlight = null);
  }

  Future<void> _fetch() async {
    final token = _accessToken()?.trim() ?? '';
    if (token.isEmpty) {
      return;
    }
    try {
      final settings = await _client.config(accessToken: token);
      _loaded = true;
      if (!isClosed) {
        emit(settings);
      }
    } catch (_) {
      // Keep the stop controls hidden; an explicit reload can retry.
    }
  }
}
