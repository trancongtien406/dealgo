import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../presence/domain/entities/driver_service_prefs.dart';
import '../../../presence/domain/repositories/presence_repository.dart';

enum DriverServicesStatus { idle, loading, ready, saving, saved, failed }

class DriverServicesState {
  const DriverServicesState({
    this.prefs = DriverServicePrefs.defaults,
    this.saved = DriverServicePrefs.defaults,
    this.status = DriverServicesStatus.idle,
  });

  /// What the switches show (may differ from [saved] until the driver saves).
  final DriverServicePrefs prefs;

  /// What the server last confirmed.
  final DriverServicePrefs saved;
  final DriverServicesStatus status;

  bool get dirty => prefs != saved;
  bool get busy =>
      status == DriverServicesStatus.loading ||
      status == DriverServicesStatus.saving;

  DriverServicesState copyWith({
    DriverServicePrefs? prefs,
    DriverServicePrefs? saved,
    DriverServicesStatus? status,
  }) => DriverServicesState(
    prefs: prefs ?? this.prefs,
    saved: saved ?? this.saved,
    status: status ?? this.status,
  );
}

/// D017 service toggles (DEC-PROD-023). The server stores them on driver presence and leaves
/// the job lists empty for a service that is switched off.
class DriverServicesCubit extends Cubit<DriverServicesState> {
  DriverServicesCubit({
    this._repository,
    required this._accessToken,
    required this._online,
  }) : super(const DriverServicesState());

  final PresenceRepository? _repository;
  final String? Function() _accessToken;
  final bool Function() _online;

  String? get _token {
    final token = _accessToken()?.trim() ?? '';
    return token.isEmpty ? null : token;
  }

  Future<void> load() async {
    final repository = _repository;
    final token = _token;
    if (repository == null || token == null || state.busy) {
      return;
    }
    emit(state.copyWith(status: DriverServicesStatus.loading));
    try {
      final prefs = await repository.getServicePrefs(accessToken: token);
      if (!isClosed) {
        emit(
          DriverServicesState(
            prefs: prefs,
            saved: prefs,
            status: DriverServicesStatus.ready,
          ),
        );
      }
    } catch (_) {
      if (!isClosed) {
        emit(state.copyWith(status: DriverServicesStatus.failed));
      }
    }
  }

  void setRide(bool value) => emit(
    state.copyWith(
      prefs: state.prefs.copyWith(rideEnabled: value),
      status: DriverServicesStatus.ready,
    ),
  );

  void setFood(bool value) => emit(
    state.copyWith(
      prefs: state.prefs.copyWith(foodEnabled: value),
      status: DriverServicesStatus.ready,
    ),
  );

  /// Sends the switches with the current online state; returns false when it did not stick.
  Future<bool> save() async {
    final repository = _repository;
    final token = _token;
    if (repository == null ||
        token == null ||
        state.status == DriverServicesStatus.saving) {
      return false;
    }
    final wanted = state.prefs;
    emit(state.copyWith(status: DriverServicesStatus.saving));
    try {
      await repository.setPresence(
        accessToken: token,
        online: _online(),
        rideEnabled: wanted.rideEnabled,
        foodEnabled: wanted.foodEnabled,
      );
      if (!isClosed) {
        emit(
          DriverServicesState(
            prefs: state.prefs,
            saved: wanted,
            status: DriverServicesStatus.saved,
          ),
        );
      }
      return true;
    } catch (_) {
      if (!isClosed) {
        emit(state.copyWith(status: DriverServicesStatus.failed));
      }
      return false;
    }
  }
}
