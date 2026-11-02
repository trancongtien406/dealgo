import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../pricing/domain/pricing.dart';

/// Admin-managed ride vehicle classes (name, seats, photo) from
/// `GET /v1/rides/vehicle-classes`. Empty until the first successful load;
/// a failed refresh keeps the last catalog so screens never lose names/photos.
class VehicleClassCatalogCubit extends Cubit<List<RideVehicleClassOption>> {
  VehicleClassCatalogCubit({
    required this._repository,
    required this._accessToken,
  }) : super(const []);

  final PricingRepository _repository;
  final String? Function() _accessToken;
  Future<void>? _inFlight;

  RideVehicleClassOption? find(String? code) {
    final normalized = code?.trim().toUpperCase() ?? '';
    if (normalized.isEmpty) {
      return null;
    }
    for (final option in state) {
      if (option.code.toUpperCase() == normalized) {
        return option;
      }
    }
    return null;
  }

  /// Loads once per session; pass [force] to pick up admin edits.
  Future<void> load({bool force = false}) {
    if (!force && state.isNotEmpty) {
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
      final classes = await _repository.listVehicleClasses(accessToken: token);
      if (!isClosed && classes.isNotEmpty) {
        emit(classes);
      }
    } catch (_) {
      // Callers fall back to the built-in label/icon for the vehicle code.
    }
  }
}
