import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/request_failure.dart';
import '../domain/driver_history.dart';

enum DriverHistoryStatus { loading, loaded, failed }

class DriverHistoryState {
  const DriverHistoryState({
    this.status = DriverHistoryStatus.loading,
    this.offline = false,
    this.summary,
    this.items = const [],
    this.filter,
    this.nextCursor,
    this.loadingMore = false,
    this.moreFailed = false,
    this.cause,
  });

  final DriverHistoryStatus status;
  final bool offline;
  final Object? cause;
  final DriverHistorySummary? summary;
  final List<DriverHistoryItem> items;
  final DriverHistoryFilter filter;
  final String? nextCursor;
  final bool loadingMore;
  final bool moreFailed;

  bool get hasMore => nextCursor != null;

  DriverHistoryState copyWith({
    DriverHistoryStatus? status,
    bool? offline,
    DriverHistorySummary? summary,
    List<DriverHistoryItem>? items,
    DriverHistoryFilter Function()? filter,
    String? Function()? nextCursor,
    bool? loadingMore,
    bool? moreFailed,
    Object? cause,
    bool clearCause = false,
  }) {
    return DriverHistoryState(
      status: status ?? this.status,
      offline: offline ?? this.offline,
      cause: clearCause ? null : (cause ?? this.cause),
      summary: summary ?? this.summary,
      items: items ?? this.items,
      filter: filter != null ? filter() : this.filter,
      nextCursor: nextCursor != null ? nextCursor() : this.nextCursor,
      loadingMore: loadingMore ?? this.loadingMore,
      moreFailed: moreFailed ?? this.moreFailed,
    );
  }
}

class DriverHistoryCubit extends Cubit<DriverHistoryState> {
  DriverHistoryCubit({required this.repository, required this.accessToken})
    : super(const DriverHistoryState());

  static const pageSize = 20;

  final DriverHistoryRepository repository;
  final String? Function() accessToken;

  /// Loads the summary and the first history page (also pull-to-refresh).
  Future<void> load() async {
    final token = accessToken();
    if (token == null) {
      emit(
        state.copyWith(
          status: DriverHistoryStatus.failed,
          offline: false,
          cause: sessionExpiredFailure,
        ),
      );
      return;
    }
    if (state.status != DriverHistoryStatus.loaded) {
      emit(state.copyWith(status: DriverHistoryStatus.loading));
    }
    try {
      final results = await Future.wait<Object>([
        repository.summary(accessToken: token),
        repository.list(
          accessToken: token,
          kind: state.filter,
          limit: pageSize,
        ),
      ]);
      final page = results[1] as DriverHistoryPage;
      emit(
        state.copyWith(
          status: DriverHistoryStatus.loaded,
          offline: false,
          clearCause: true,
          summary: results[0] as DriverHistorySummary,
          items: page.items,
          nextCursor: () => page.nextCursor,
          moreFailed: false,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: DriverHistoryStatus.failed,
          offline: _isOffline(error),
          cause: error,
        ),
      );
    }
  }

  Future<void> setFilter(DriverHistoryFilter filter) async {
    if (filter == state.filter) {
      return;
    }
    emit(
      state.copyWith(
        filter: () => filter,
        items: const [],
        nextCursor: () => null,
        status: DriverHistoryStatus.loading,
      ),
    );
    await load();
  }

  Future<void> loadMore() async {
    final token = accessToken();
    final cursor = state.nextCursor;
    if (token == null || cursor == null || state.loadingMore) {
      return;
    }
    emit(state.copyWith(loadingMore: true, moreFailed: false));
    try {
      final page = await repository.list(
        accessToken: token,
        kind: state.filter,
        cursor: cursor,
        limit: pageSize,
      );
      emit(
        state.copyWith(
          items: [...state.items, ...page.items],
          nextCursor: () => page.nextCursor,
          loadingMore: false,
        ),
      );
    } catch (_) {
      emit(state.copyWith(loadingMore: false, moreFailed: true));
    }
  }

  bool _isOffline(Object error) =>
      error is ApiException &&
      (error.statusCode == 0 || error.errorCode == 'NETWORK_ERROR');
}
