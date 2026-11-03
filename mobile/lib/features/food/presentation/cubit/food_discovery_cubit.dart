import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/location/location_service.dart';
import '../../../../core/network/api_exception.dart';
import '../../../rating/domain/service_rating.dart';
import '../../domain/entities/food_models.dart';
import '../../domain/usecases/list_food_stores.dart';
import '../../../../core/l10n/ui_message.dart';

sealed class FoodDiscoveryState {
  const FoodDiscoveryState();
}

final class FoodDiscoveryLoading extends FoodDiscoveryState {
  const FoodDiscoveryLoading();
}

final class FoodDiscoveryReady extends FoodDiscoveryState {
  const FoodDiscoveryReady(
    this.stores, {
    this.ratings = const {},
    this.isRefreshing = false,
    this.isLoadingMore = false,
    this.hasMore = false,
    this.total = 0,
    this.loadMoreFailed = false,
  });

  final List<FoodStoreSummary> stores;

  /// Real store ratings by store id; empty until loaded (or if unavailable).
  final Map<String, StoreRating> ratings;

  /// A newer first-page request is in flight; current stores stay on screen.
  final bool isRefreshing;

  /// The next page is in flight.
  final bool isLoadingMore;

  /// The server reported more rows than the client holds.
  final bool hasMore;

  /// Server count for the active filter.
  final int total;

  /// The last `loadMore` failed; the rows above stay usable.
  final bool loadMoreFailed;

  FoodDiscoveryReady copyWith({
    List<FoodStoreSummary>? stores,
    Map<String, StoreRating>? ratings,
    bool? isRefreshing,
    bool? isLoadingMore,
    bool? hasMore,
    int? total,
    bool? loadMoreFailed,
  }) {
    return FoodDiscoveryReady(
      stores ?? this.stores,
      ratings: ratings ?? this.ratings,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      total: total ?? this.total,
      loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
    );
  }
}

final class FoodDiscoveryFailed extends FoodDiscoveryState {
  const FoodDiscoveryFailed(this.message);

  final UiMessage message;
}

class FoodDiscoveryCubit extends Cubit<FoodDiscoveryState> {
  FoodDiscoveryCubit({
    required this._listFoodStores,
    this._ratings,
    this._location,
  }) : super(const FoodDiscoveryLoading());

  static const pageSize = 20;

  final ListFoodStores _listFoodStores;
  final RatingRepository? _ratings;

  /// Optional GPS fix so the backend can sort by real distance.
  final LocationService? _location;

  var _generation = 0;
  var _page = 1;
  var _loadingMore = false;
  String? _token;
  String? _search;
  double? _lat;
  double? _lng;
  String? _sortBy;
  int? _maxKm;
  String? _category;

  Future<void> load(
    String? accessToken, {
    String? search,
    double? lat,
    double? lng,
    String? sortBy,
    int? maxKm,
    String? category,
  }) async {
    final generation = ++_generation;
    final token = accessToken?.trim() ?? '';
    if (token.isEmpty) {
      emit(FoodDiscoveryFailed(UiMessage((l10n) => l10n.errorUnauthorized)));
      return;
    }
    _token = token;
    _search = search;
    _sortBy = sortBy;
    _maxKm = maxKm;
    _category = category;
    _page = 1;
    _loadingMore = false;

    final previous = state;
    if (previous is FoodDiscoveryReady) {
      emit(
        previous.copyWith(
          isRefreshing: true,
          isLoadingMore: false,
          loadMoreFailed: false,
        ),
      );
    } else {
      emit(const FoodDiscoveryLoading());
    }
    try {
      final fix = lat != null && lng != null
          ? (lat: lat, lng: lng)
          : await _position();
      if (isClosed || generation != _generation) {
        return;
      }
      _lat = fix?.lat;
      _lng = fix?.lng;
      final page = await _fetch(1);
      if (isClosed || generation != _generation) {
        return;
      }
      emit(
        FoodDiscoveryReady(
          List.unmodifiable(page.items),
          total: page.total,
          hasMore: page.hasMore,
        ),
      );
      await _loadRatings(token, generation);
    } on ApiException catch (error) {
      if (isClosed || generation != _generation) {
        return;
      }
      emit(FoodDiscoveryFailed(UiMessage.error(error)));
    } catch (error) {
      if (isClosed || generation != _generation) {
        return;
      }
      emit(
        FoodDiscoveryFailed(
          UiMessage.error(error, fallback: (l10n) => l10n.errorNetwork),
        ),
      );
    }
  }

  Future<void> loadMore() async {
    final current = state;
    final token = _token;
    if (current is! FoodDiscoveryReady ||
        !current.hasMore ||
        current.isLoadingMore ||
        current.isRefreshing ||
        _loadingMore ||
        token == null) {
      return;
    }
    final generation = _generation;
    _loadingMore = true;
    emit(current.copyWith(isLoadingMore: true, loadMoreFailed: false));
    try {
      final page = await _fetch(_page + 1);
      if (isClosed || generation != _generation) {
        return;
      }
      final seen = {for (final store in current.stores) store.id};
      final merged = <FoodStoreSummary>[
        ...current.stores,
        for (final store in page.items)
          if (seen.add(store.id)) store,
      ];
      _page += 1;
      emit(
        FoodDiscoveryReady(
          List.unmodifiable(merged),
          ratings: current.ratings,
          total: page.total,
          hasMore: page.hasMore,
        ),
      );
      await _loadRatings(token, generation);
    } on ApiException {
      if (isClosed || generation != _generation) {
        return;
      }
      emit(current.copyWith(isLoadingMore: false, loadMoreFailed: true));
    } catch (_) {
      if (isClosed || generation != _generation) {
        return;
      }
      emit(current.copyWith(isLoadingMore: false, loadMoreFailed: true));
    } finally {
      _loadingMore = false;
    }
  }

  Future<FoodStorePageResult> _fetch(int page) {
    return _listFoodStores(
      _token!,
      lat: _lat,
      lng: _lng,
      search: _search,
      sortBy: _sortBy,
      maxKm: _maxKm,
      category: _category,
      page: page,
      limit: pageSize,
    );
  }

  Future<({double lat, double lng})?> _position() async {
    final location = _location;
    if (location == null) {
      return null;
    }
    try {
      final position = await location.currentPosition().timeout(
        const Duration(seconds: 5),
      );
      return position == null
          ? null
          : (lat: position.latitude, lng: position.longitude);
    } catch (_) {
      return null;
    }
  }

  /// Best effort: cards show no rating line when this fails.
  Future<void> _loadRatings(String token, int generation) async {
    final ratings = _ratings;
    final current = state;
    if (ratings == null ||
        current is! FoodDiscoveryReady ||
        current.stores.isEmpty) {
      return;
    }
    try {
      final byStore = await ratings.storeRatings(
        accessToken: token,
        storeIds: [for (final store in current.stores.take(50)) store.id],
      );
      if (isClosed || generation != _generation) {
        return;
      }
      final latest = state;
      if (latest is FoodDiscoveryReady) {
        emit(latest.copyWith(ratings: Map.unmodifiable(byStore)));
      }
    } on ApiException {
      return;
    }
  }
}
