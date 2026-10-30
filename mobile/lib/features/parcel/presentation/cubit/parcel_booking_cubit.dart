import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_exception.dart';
import '../../domain/parcel_client.dart';
import '../../domain/parcel_models.dart';

enum ParcelBookingStatus { idle, loading, ready, quoting, submitting, failed }

class ParcelBookingState {
  const ParcelBookingState({
    this.status = ParcelBookingStatus.idle,
    this.sizes = const [],
    this.sizeCode,
    this.quote,
    this.optionCode,
    this.fareVnd,
    this.errorCode,
  });

  final ParcelBookingStatus status;
  final List<ParcelSizeClass> sizes;
  final String? sizeCode;
  final ParcelQuote? quote;
  final String? optionCode;
  final int? fareVnd;

  /// Server error code (e.g. `PARCEL_NO_VEHICLE`) or `NETWORK` for the last failure.
  final String? errorCode;

  ParcelSizeClass? get size {
    for (final s in sizes) {
      if (s.code == sizeCode) return s;
    }
    return null;
  }

  ParcelQuoteOption? get option {
    for (final o in quote?.options ?? const <ParcelQuoteOption>[]) {
      if (o.code == optionCode) return o;
    }
    return null;
  }

  bool get busy =>
      status == ParcelBookingStatus.loading ||
      status == ParcelBookingStatus.quoting ||
      status == ParcelBookingStatus.submitting;

  ParcelBookingState copyWith({
    ParcelBookingStatus? status,
    List<ParcelSizeClass>? sizes,
    String? sizeCode,
    ParcelQuote? quote,
    bool clearQuote = false,
    String? optionCode,
    int? fareVnd,
    String? errorCode,
  }) => ParcelBookingState(
    status: status ?? this.status,
    sizes: sizes ?? this.sizes,
    sizeCode: sizeCode ?? this.sizeCode,
    quote: clearQuote ? null : (quote ?? this.quote),
    optionCode: clearQuote ? null : (optionCode ?? this.optionCode),
    fareVnd: clearQuote ? null : (fareVnd ?? this.fareVnd),
    errorCode: errorCode,
  );
}

/// Package sheet → quote → class/fare → POST /v1/parcels. Matching then reuses the ride flow.
class ParcelBookingCubit extends Cubit<ParcelBookingState> {
  ParcelBookingCubit({
    required this._client,
    required String? Function() accessToken,
    String Function()? idempotencyKey,
  }) : _token = accessToken,
       _newKey = idempotencyKey ?? _defaultKey,
       super(const ParcelBookingState());

  final ParcelClient _client;
  final String? Function() _token;
  final String Function() _newKey;

  /// Reused while the same request is retried so a lost response never books twice.
  String? _pendingKey;
  String? _pendingSignature;

  static String _defaultKey() {
    final t = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final salt = identityHashCode(Object()).toUnsigned(32).toRadixString(16);
    return 'parcel-$t-$salt';
  }

  String? get _accessToken {
    final t = _token()?.trim() ?? '';
    return t.isEmpty ? null : t;
  }

  static String _code(Object error) =>
      error is ApiException ? error.errorCode : 'NETWORK';

  Future<void> load() async {
    final token = _accessToken;
    if (token == null || state.busy) return;
    emit(state.copyWith(status: ParcelBookingStatus.loading));
    try {
      final sizes = await _client.sizeClasses(accessToken: token);
      if (isClosed) return;
      emit(
        state.copyWith(
          status: ParcelBookingStatus.ready,
          sizes: sizes,
          sizeCode: sizes.isEmpty ? null : (state.sizeCode ?? sizes.first.code),
        ),
      );
    } catch (error) {
      if (!isClosed) {
        emit(
          state.copyWith(
            status: ParcelBookingStatus.failed,
            errorCode: _code(error),
          ),
        );
      }
    }
  }

  void selectSize(String code) {
    if (code == state.sizeCode) return;
    emit(
      state.copyWith(
        sizeCode: code,
        clearQuote: true,
        status: ParcelBookingStatus.ready,
      ),
    );
  }

  /// Package details changed after a quote: price again before booking.
  void invalidateQuote() {
    if (state.quote == null || state.busy) return;
    emit(state.copyWith(clearQuote: true, status: ParcelBookingStatus.ready));
  }

  /// Quotes the draft; picks the cheapest class and its reference fare.
  Future<void> quote(ParcelDraft draft) async {
    final token = _accessToken;
    if (token == null || state.busy) return;
    emit(state.copyWith(status: ParcelBookingStatus.quoting, clearQuote: true));
    try {
      final quote = await _client.quote(accessToken: token, draft: draft);
      if (isClosed) return;
      final first = quote.options.isEmpty ? null : quote.options.first;
      emit(
        state.copyWith(
          status: ParcelBookingStatus.ready,
          quote: quote,
          optionCode: first?.code,
          fareVnd: first?.referenceFareVnd,
          errorCode: first == null ? 'PARCEL_NO_VEHICLE' : null,
        ),
      );
    } catch (error) {
      if (!isClosed) {
        emit(
          state.copyWith(
            status: ParcelBookingStatus.failed,
            errorCode: _code(error),
          ),
        );
      }
    }
  }

  void selectOption(String code) {
    final option = state.quote?.options
        .where((o) => o.code == code)
        .firstOrNull;
    if (option == null) return;
    emit(
      state.copyWith(
        optionCode: code,
        fareVnd: option.referenceFareVnd,
        status: ParcelBookingStatus.ready,
      ),
    );
  }

  void setFare(int fareVnd) {
    final option = state.option;
    if (option == null) return;
    emit(
      state.copyWith(
        fareVnd: option.clamp(fareVnd),
        status: ParcelBookingStatus.ready,
      ),
    );
  }

  /// Books the parcel; null when it did not go through (see [ParcelBookingState.errorCode]).
  Future<ParcelRide?> submit(ParcelDraft draft) async {
    final token = _accessToken;
    final option = state.option;
    final fare = state.fareVnd;
    if (token == null || option == null || fare == null || state.busy) {
      return null;
    }
    final signature = [
      draft.places.pickup.label,
      draft.places.dropoff.label,
      draft.sizeClass,
      draft.weightKg,
      draft.sender.phone,
      draft.recipient.phone,
      draft.payer.wire,
      option.code,
      fare,
    ].join('|');
    if (signature != _pendingSignature) {
      _pendingSignature = signature;
      _pendingKey = _newKey();
    }
    emit(state.copyWith(status: ParcelBookingStatus.submitting));
    try {
      final ride = await _client.create(
        accessToken: token,
        idempotencyKey: _pendingKey!,
        draft: draft,
        vehicleClassCode: option.code,
        offeredFareVnd: fare,
      );
      _pendingKey = null;
      _pendingSignature = null;
      if (!isClosed) emit(state.copyWith(status: ParcelBookingStatus.ready));
      return ride;
    } catch (error) {
      if (!isClosed) {
        emit(
          state.copyWith(
            status: ParcelBookingStatus.failed,
            errorCode: _code(error),
          ),
        );
      }
      return null;
    }
  }
}
