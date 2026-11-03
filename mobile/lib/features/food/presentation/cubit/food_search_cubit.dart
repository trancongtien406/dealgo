import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/l10n/ui_message.dart';
import '../../../../core/network/api_exception.dart';
import '../../domain/entities/food_models.dart';
import '../../domain/repositories/food_repository.dart';

sealed class FoodSearchState {
  const FoodSearchState();
}

final class FoodSearchIdle extends FoodSearchState {
  const FoodSearchIdle();
}

final class FoodSearchLoading extends FoodSearchState {
  const FoodSearchLoading({this.previous});

  /// Rows from the last query, kept on screen while the next page refreshes.
  final FoodSearchReady? previous;
}

final class FoodSearchReady extends FoodSearchState {
  const FoodSearchReady({
    required this.dishes,
    required this.stores,
    this.dishTotal = 0,
    this.storeTotal = 0,
    this.page = 1,
    this.isRefreshing = false,
    this.loadingMore = false,
    this.loadMoreFailed = false,
  });

  final List<FoodDishHit> dishes;
  final List<FoodStoreSummary> stores;
  final int dishTotal;
  final int storeTotal;
  final int page;

  /// A newer first-page request is in flight; current rows stay visible.
  final bool isRefreshing;

  final bool loadingMore;

  /// The last [FoodSearchCubit.loadMore] failed; rows above stay usable.
  final bool loadMoreFailed;

  bool get hasMoreDishes => dishes.length < dishTotal;
  bool get hasMoreStores => stores.length < storeTotal;
  bool get hasMore => hasMoreDishes || hasMoreStores;

  FoodSearchReady copyWith({
    List<FoodDishHit>? dishes,
    List<FoodStoreSummary>? stores,
    int? dishTotal,
    int? storeTotal,
    int? page,
    bool? isRefreshing,
    bool? loadingMore,
    bool? loadMoreFailed,
  }) {
    return FoodSearchReady(
      dishes: dishes ?? this.dishes,
      stores: stores ?? this.stores,
      dishTotal: dishTotal ?? this.dishTotal,
      storeTotal: storeTotal ?? this.storeTotal,
      page: page ?? this.page,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      loadingMore: loadingMore ?? this.loadingMore,
      loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
    );
  }
}

final class FoodSearchFailed extends FoodSearchState {
  const FoodSearchFailed(this.message);

  final UiMessage message;
}

class FoodSearchCubit extends Cubit<FoodSearchState> {
  FoodSearchCubit(this._search) : super(const FoodSearchIdle());

  static const pageSize = 20;

  final FoodRepository _search;

  var _generation = 0;
  var _page = 1;
  var _loadingMore = false;
  String? _token;
  String _q = '';
  double? _lat;
  double? _lng;
  String? _sortBy;

  Future<void> load(
    String token, {
    required String q,
    double? lat,
    double? lng,
    String? sortBy,
  }) async {
    final generation = ++_generation;
    final trimmed = q.trim();
    if (trimmed.isEmpty) {
      emit(const FoodSearchIdle());
      return;
    }
    if (token.trim().isEmpty) {
      emit(FoodSearchFailed(UiMessage((l10n) => l10n.errorUnauthorized)));
      return;
    }
    _token = token.trim();
    _q = trimmed;
    _lat = lat;
    _lng = lng;
    _sortBy = sortBy;
    _page = 1;

    final previous = _readyOf(state);
    emit(
      FoodSearchLoading(
        previous: previous?.copyWith(
          isRefreshing: true,
          loadingMore: false,
          loadMoreFailed: false,
        ),
      ),
    );
    try {
      final page = await _fetch(1);
      if (isClosed || generation != _generation) {
        return;
      }
      emit(
        FoodSearchReady(
          dishes: List.unmodifiable(page.dishes),
          stores: List.unmodifiable(page.stores),
          dishTotal: page.dishTotal,
          storeTotal: page.storeTotal,
        ),
      );
    } on ApiException catch (error) {
      if (isClosed || generation != _generation) {
        return;
      }
      emit(FoodSearchFailed(UiMessage.error(error)));
    } catch (error) {
      if (isClosed || generation != _generation) {
        return;
      }
      emit(
        FoodSearchFailed(
          UiMessage.error(error, fallback: (l10n) => l10n.errorNetwork),
        ),
      );
    }
  }

  Future<void> loadMore() async {
    final current = _readyOf(state);
    final token = _token;
    if (current == null ||
        token == null ||
        current.isRefreshing ||
        current.loadingMore ||
        !current.hasMore ||
        _loadingMore) {
      return;
    }
    final generation = _generation;
    _loadingMore = true;
    emit(current.copyWith(loadingMore: true, loadMoreFailed: false));
    try {
      final next = _page + 1;
      final page = await _fetch(next);
      if (isClosed || generation != _generation) {
        return;
      }
      _page = next;
      emit(
        FoodSearchReady(
          dishes: List.unmodifiable(_mergeDishes(current.dishes, page.dishes)),
          stores: List.unmodifiable(_mergeStores(current.stores, page.stores)),
          dishTotal: page.dishTotal,
          storeTotal: page.storeTotal,
          page: next,
        ),
      );
    } on ApiException {
      if (isClosed || generation != _generation) {
        return;
      }
      emit(current.copyWith(loadingMore: false, loadMoreFailed: true));
    } catch (_) {
      if (isClosed || generation != _generation) {
        return;
      }
      emit(current.copyWith(loadingMore: false, loadMoreFailed: true));
    } finally {
      _loadingMore = false;
    }
  }

  Future<FoodSearchResult> _fetch(int page) {
    return _search.searchFood(
      _token!,
      q: _q,
      lat: _lat,
      lng: _lng,
      sortBy: _sortBy,
      page: page,
      limit: pageSize,
    );
  }

  static FoodSearchReady? _readyOf(FoodSearchState state) {
    return switch (state) {
      FoodSearchReady ready => ready,
      FoodSearchLoading(:final previous) => previous,
      _ => null,
    };
  }

  static List<FoodDishHit> _mergeDishes(
    List<FoodDishHit> current,
    List<FoodDishHit> next,
  ) {
    final seen = {for (final hit in current) hit.item.id};
    return [
      ...current,
      for (final hit in next)
        if (seen.add(hit.item.id)) hit,
    ];
  }

  static List<FoodStoreSummary> _mergeStores(
    List<FoodStoreSummary> current,
    List<FoodStoreSummary> next,
  ) {
    final seen = {for (final store in current) store.id};
    return [
      ...current,
      for (final store in next)
        if (seen.add(store.id)) store,
    ];
  }
}
