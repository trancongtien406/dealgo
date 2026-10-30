import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_exception.dart';
import '../../domain/parcel_client.dart';
import '../../domain/parcel_models.dart';

class ParcelTripState {
  const ParcelTripState({this.parcel, this.busy = false, this.errorCode});

  final ParcelRide? parcel;
  final bool busy;
  final String? errorCode;
}

/// Parcel proof steps for the assigned driver, and the package card for both sides.
class ParcelTripCubit extends Cubit<ParcelTripState> {
  ParcelTripCubit({
    required this._client,
    required String? Function() accessToken,
    required this.rideId,
  }) : _token = accessToken,
       super(const ParcelTripState());

  final ParcelClient _client;
  final String? Function() _token;
  final String rideId;

  String? get _accessToken {
    final t = _token()?.trim() ?? '';
    return t.isEmpty ? null : t;
  }

  Future<bool> _run(Future<ParcelRide> Function(String token) call) async {
    final token = _accessToken;
    if (token == null || state.busy) return false;
    emit(ParcelTripState(parcel: state.parcel, busy: true));
    try {
      final next = await call(token);
      if (!isClosed) emit(ParcelTripState(parcel: next));
      return true;
    } catch (error) {
      if (!isClosed) {
        emit(
          ParcelTripState(
            parcel: state.parcel,
            errorCode: error is ApiException ? error.errorCode : 'NETWORK',
          ),
        );
      }
      return false;
    }
  }

  Future<bool> load() =>
      _run((t) => _client.get(accessToken: t, rideId: rideId));

  Future<bool> pickup(ParcelPhoto photo, {String? pickupCode}) => _run(
    (t) => _client.pickup(
      accessToken: t,
      rideId: rideId,
      photo: photo,
      pickupCode: pickupCode,
    ),
  );

  Future<bool> deliver(ParcelPhoto photo, {String? recipientCode}) => _run(
    (t) => _client.deliver(
      accessToken: t,
      rideId: rideId,
      photo: photo,
      recipientCode: recipientCode,
    ),
  );

  Future<bool> fail(ParcelFailReason reason, {String? note}) => _run(
    (t) => _client.fail(
      accessToken: t,
      rideId: rideId,
      reason: reason,
      note: note,
    ),
  );

  Future<bool> returned(ParcelPhoto photo) => _run(
    (t) => _client.returned(accessToken: t, rideId: rideId, photo: photo),
  );
}
