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
  });

  final List<FoodStoreSummary> stores;

  /// Real store ratings by store id; empty until loaded (or if unavailable).
  final Map<String, StoreRating> ratings;

  /// A newer request is in flight; the current stores stay on screen.
  final bool isRefreshing;
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

  final ListFoodStores _listFoodStores;
  final RatingRepository? _ratings;

  /// Optional GPS fix so the backend can sort by real distance.
  final LocationService? _location;
  var _generation = 0;

  Future<void> load(
    String? accessToken, {
    String? search,
    double? lat,
    double? lng,
    String? sortBy,
    int? maxKm,
  }) async {
    final generation = ++_generation;
    final token = accessToken?.trim() ?? '';
    if (token.isEmpty) {
      emit(FoodDiscoveryFailed(UiMessage((l10n) => l10n.errorUnauthorized)));
      return;
    }
    final previous = state;
    if (previous is FoodDiscoveryReady) {
      emit(
        FoodDiscoveryReady(
          previous.stores,
          ratings: previous.ratings,
          isRefreshing: true,
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
      final page = await _listFoodStores(
        token,
        lat: fix?.lat,
        lng: fix?.lng,
        search: search,
        sortBy: sortBy,
        maxKm: maxKm,
      );
      if (isClosed || generation != _generation) {
        return;
      }
      final ready = List<FoodStoreSummary>.unmodifiable(page.items);
      emit(FoodDiscoveryReady(ready));
      await _loadRatings(token, ready, generation);
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
  Future<void> _loadRatings(
    String token,
    List<FoodStoreSummary> stores,
    int generation,
  ) async {
    final ratings = _ratings;
    if (ratings == null || stores.isEmpty) {
      return;
    }
    try {
      final byStore = await ratings.storeRatings(
        accessToken: token,
        storeIds: [for (final store in stores.take(50)) store.id],
      );
      if (isClosed || generation != _generation) {
        return;
      }
      emit(FoodDiscoveryReady(stores, ratings: Map.unmodifiable(byStore)));
    } on ApiException {
      return;
    }
  }
}
