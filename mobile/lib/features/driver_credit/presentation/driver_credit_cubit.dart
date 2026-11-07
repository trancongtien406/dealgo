import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/request_failure.dart';
import '../domain/driver_credit.dart';

enum DriverCreditStatus { loading, loaded, failed }

class DriverCreditState {
  const DriverCreditState({
    this.status = DriverCreditStatus.loading,
    this.credit,
    this.amountVnd = 100_000,
    this.submitting = false,
    this.cancelling = false,
    this.refreshingPending = false,
    this.selected,
    this.selectedLoading = false,
    this.cause,
    this.actionError,
  });

  final DriverCreditStatus status;
  final DriverCredit? credit;

  /// Amount picked on the top-up sheet.
  final int amountVnd;
  final bool submitting;
  final bool cancelling;
  final bool refreshingPending;

  /// Top-up shown in the payment/detail sheet (may already be in [credit]).
  final DriverTopUp? selected;
  final bool selectedLoading;
  final Object? cause;

  /// Error code of the last failed action (`DRIVER_TOP_UP_DAILY_LIMIT`, …).
  final String? actionError;

  bool get busy => submitting || cancelling;
  DriverTopUp? get pending => credit?.pendingTopUp;

  DriverCreditState copyWith({
    DriverCreditStatus? status,
    DriverCredit? credit,
    int? amountVnd,
    bool? submitting,
    bool? cancelling,
    bool? refreshingPending,
    DriverTopUp? selected,
    bool? selectedLoading,
    Object? cause,
    String? actionError,
    bool clearCause = false,
    bool clearActionError = false,
    bool clearSelected = false,
  }) {
    return DriverCreditState(
      status: status ?? this.status,
      credit: credit ?? this.credit,
      amountVnd: amountVnd ?? this.amountVnd,
      submitting: submitting ?? this.submitting,
      cancelling: cancelling ?? this.cancelling,
      refreshingPending: refreshingPending ?? this.refreshingPending,
      selected: clearSelected ? null : (selected ?? this.selected),
      selectedLoading: selectedLoading ?? this.selectedLoading,
      cause: clearCause ? null : (cause ?? this.cause),
      actionError: clearActionError ? null : (actionError ?? this.actionError),
    );
  }
}

class DriverCreditCubit extends Cubit<DriverCreditState> {
  DriverCreditCubit({required this.repository, required this.accessToken})
    : super(const DriverCreditState());

  final DriverCreditRepository repository;
  final String? Function() accessToken;

  Future<void> load() async {
    final token = accessToken();
    if (token == null) {
      emit(
        state.copyWith(
          status: DriverCreditStatus.failed,
          cause: sessionExpiredFailure,
        ),
      );
      return;
    }
    if (state.credit == null) {
      emit(state.copyWith(status: DriverCreditStatus.loading));
    }
    try {
      final credit = await repository.summary(accessToken: token);
      emit(
        state.copyWith(
          status: DriverCreditStatus.loaded,
          credit: credit,
          amountVnd: _clampAmount(state.amountVnd, credit),
          clearCause: true,
          clearActionError: true,
        ),
      );
    } catch (error) {
      emit(state.copyWith(status: DriverCreditStatus.failed, cause: error));
    }
  }

  void selectAmount(int amountVnd) {
    final credit = state.credit;
    emit(
      state.copyWith(
        amountVnd: credit == null ? amountVnd : _clampAmount(amountVnd, credit),
        clearActionError: true,
      ),
    );
  }

  /// Creates the payment link. Returns the top-up so the page can open the
  /// provider page; the driver is credited only by the server-side IPN.
  Future<DriverTopUp?> createTopUp({String? idempotencyKey}) async {
    final token = accessToken();
    if (token == null || state.submitting) {
      emit(state.copyWith(actionError: 'DRIVER_TOP_UP_SESSION_EXPIRED'));
      return null;
    }
    emit(state.copyWith(submitting: true, clearActionError: true));
    try {
      final topUp = await repository.createTopUp(
        accessToken: token,
        amountVnd: state.amountVnd,
        idempotencyKey: idempotencyKey,
      );
      emit(state.copyWith(submitting: false));
      await load();
      return topUp;
    } on ApiException catch (error) {
      emit(
        state.copyWith(
          submitting: false,
          actionError: error.errorCode,
          cause: error,
        ),
      );
      return null;
    } catch (error) {
      emit(
        state.copyWith(submitting: false, actionError: 'UNKNOWN', cause: error),
      );
      return null;
    }
  }

  Future<void> cancelPending() async {
    final token = accessToken();
    final pending = state.pending;
    if (token == null || pending == null || state.cancelling) {
      return;
    }
    emit(state.copyWith(cancelling: true, clearActionError: true));
    try {
      await repository.cancelTopUp(accessToken: token, id: pending.id);
      emit(state.copyWith(cancelling: false));
      await load();
    } on ApiException catch (error) {
      emit(
        state.copyWith(
          cancelling: false,
          actionError: error.errorCode,
          cause: error,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(cancelling: false, actionError: 'UNKNOWN', cause: error),
      );
    }
  }

  /// Re-reads the pending link after the driver returns from the provider page.
  Future<void> refreshPending() async {
    final token = accessToken();
    final pending = state.pending;
    if (token == null || pending == null || state.refreshingPending) {
      return;
    }
    emit(state.copyWith(refreshingPending: true));
    try {
      await repository.topUp(accessToken: token, id: pending.id);
    } catch (_) {
      // The summary below is authoritative; a failed probe must not surface.
    }
    emit(state.copyWith(refreshingPending: false));
    await load();
  }

  /// Opens the payment/detail sheet for one top-up and re-reads it from REST.
  Future<void> selectTopUp(String id, {bool refresh = true}) async {
    DriverTopUp? fallback;
    for (final topUp in state.credit?.recentTopUps ?? const <DriverTopUp>[]) {
      if (topUp.id == id) {
        fallback = topUp;
        break;
      }
    }
    if (fallback == null && state.pending?.id == id) {
      fallback = state.pending;
    }
    emit(
      state.copyWith(
        selected: fallback,
        selectedLoading: fallback == null && refresh,
        clearActionError: true,
      ),
    );
    if (refresh) {
      await refreshSelected();
    }
  }

  void clearSelected() {
    emit(state.copyWith(clearSelected: true, selectedLoading: false));
  }

  /// Re-reads the top-up in the sheet. Safe to call from a polling timer: the
  /// server (IPN or reconcile) decides when money arrives.
  Future<void> refreshSelected() async {
    final token = accessToken();
    final selected = state.selected;
    if (token == null || selected == null) {
      return;
    }
    try {
      final fresh = await repository.topUp(accessToken: token, id: selected.id);
      emit(state.copyWith(selected: fresh, selectedLoading: false));
      if (fresh.status != selected.status) {
        await load();
      }
    } catch (_) {
      emit(state.copyWith(selectedLoading: false));
    }
  }

  /// Fired by the `driverCreditStatus` socket hint: re-read the sheet and list.
  Future<void> onStatusHint(String topUpId) async {
    final selected = state.selected;
    if (selected != null && selected.id == topUpId) {
      await refreshSelected();
      return;
    }
    if (state.pending?.id == topUpId || state.credit != null) {
      await load();
    }
  }

  static int _clampAmount(int amountVnd, DriverCredit credit) {
    final min = credit.minVnd > 0 ? credit.minVnd : 10_000;
    final max = credit.maxVnd > 0 ? credit.maxVnd : min;
    return amountVnd.clamp(min, max);
  }
}
