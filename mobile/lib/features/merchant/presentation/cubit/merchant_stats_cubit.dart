import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/request_failure.dart';
import '../../../food/domain/entities/food_models.dart';
import '../../../rating/domain/service_rating.dart';
import '../../domain/merchant_stats.dart';
import '../../domain/usecases/get_merchant_catalog.dart';

sealed class MerchantStatsState {
  const MerchantStatsState();
}

final class MerchantStatsLoading extends MerchantStatsState {
  const MerchantStatsLoading();
}

final class MerchantStatsReady extends MerchantStatsState {
  const MerchantStatsReady({
    required this.stats,
    this.store,
    this.rating,
    this.reviews,
    this.reviewsFailure,
    this.statement,
  });

  final MerchantStats stats;

  /// Commission statement for the same window; null when it failed to load.
  final MerchantStatement? statement;
  final FoodStoreDetail? store;

  /// Public store rating; [StoreRating.average] stays null below the
  /// RATING_STORE_MIN_COUNT threshold.
  final StoreRating? rating;

  /// Newest reviews for [store]. Null when the store id is unavailable.
  final StoreReviews? reviews;

  /// Review-list load error. The stats figures still render.
  final Object? reviewsFailure;
}

final class MerchantStatsIneligible extends MerchantStatsState {
  const MerchantStatsIneligible();
}

final class MerchantStatsFailed extends MerchantStatsState {
  const MerchantStatsFailed({this.cause});

  final Object? cause;
}

/// Loads the merchant stats endpoint, plus the store (name) and its public
/// rating; the extras are best-effort and never block the numbers.
class MerchantStatsCubit extends Cubit<MerchantStatsState> {
  MerchantStatsCubit({required this._stats, this._catalog, this._ratings})
    : super(const MerchantStatsLoading());

  final MerchantStatsRepository _stats;
  final GetMerchantCatalog? _catalog;
  final RatingRepository? _ratings;
  var _generation = 0;

  Future<void> load(
    String? accessToken, {
    int days = 7,
    bool includeStatement = true,
  }) async {
    final generation = ++_generation;
    final token = accessToken?.trim() ?? '';
    if (token.isEmpty) {
      emit(const MerchantStatsFailed(cause: sessionExpiredFailure));
      return;
    }
    emit(const MerchantStatsLoading());
    final statementFuture = includeStatement
        ? () async {
            try {
              final range = statementRange(days, DateTime.now());
              return await _stats.statement(
                accessToken: token,
                from: range.$1,
                to: range.$2,
              );
            } catch (_) {
              // The statement is an extra card; sales figures still render.
              return null;
            }
          }()
        : Future<MerchantStatement?>.value(null);
    final storeFuture = () async {
      try {
        return await _catalog?.call(token);
      } catch (_) {
        // Name and rating are decoration; the figures still render.
        return null;
      }
    }();
    try {
      final stats = await _stats.stats(accessToken: token, days: days);
      final statement = await statementFuture;
      final store = await storeFuture;
      StoreRating? rating;
      StoreReviews? reviews;
      Object? reviewsFailure;
      final ratings = _ratings;
      final storeId = store?.id;
      if (ratings != null && storeId != null && storeId.isNotEmpty) {
        try {
          reviews = await ratings.storeReviews(
            accessToken: token,
            storeId: storeId,
          );
          rating = reviews.summary;
        } catch (error) {
          reviewsFailure = error;
          try {
            rating = (await ratings.storeRatings(
              accessToken: token,
              storeIds: [storeId],
            ))[storeId];
          } catch (_) {
            // Rating summary stays optional when both endpoints fail.
          }
        }
      }
      if (isClosed || generation != _generation) {
        return;
      }
      emit(
        MerchantStatsReady(
          stats: stats,
          store: store,
          rating: rating,
          reviews: reviews,
          reviewsFailure: reviewsFailure,
          statement: statement,
        ),
      );
    } on ApiException catch (error) {
      if (isClosed || generation != _generation) {
        return;
      }
      emit(
        error.statusCode == 403
            ? const MerchantStatsIneligible()
            : MerchantStatsFailed(cause: error),
      );
    } catch (error) {
      if (!isClosed && generation == _generation) {
        emit(MerchantStatsFailed(cause: error));
      }
    }
  }
}

/// `[from, to]` Vietnam days covering the last [days] days including today.
(String, String) statementRange(int days, DateTime now) {
  final vn = now.toUtc().add(const Duration(hours: 7));
  String key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  final span = days.clamp(1, 31);
  return (key(vn.subtract(Duration(days: span - 1))), key(vn));
}
