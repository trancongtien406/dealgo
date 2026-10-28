import 'dart:async';

import '../../../core/drafts/draft_store.dart';
import '../../../core/drafts/text_draft.dart';
import 'cubit/food_cart_cubit.dart';

/// T85 — keeps the food cart (lines, drop-off, voucher code, idempotency key)
/// across app kills in secure storage, per signed-in user. Drafts are off
/// until DI configures [FormDrafts], so tests are unaffected.
FoodCartCubit attachFoodCartDraft(
  FoodCartCubit cubit, {
  Stream<Object?>? ownerChanges,
  Duration maxAge = const Duration(hours: 24),
}) {
  FoodCartDraftSync(cubit, ownerChanges: ownerChanges, maxAge: maxAge).start();
  return cubit;
}

class FoodCartDraftSync {
  FoodCartDraftSync(
    this.cubit, {
    this.ownerChanges,
    this.maxAge = const Duration(hours: 24),
  });

  final FoodCartCubit cubit;
  final Stream<Object?>? ownerChanges;
  final Duration maxAge;

  DraftKeeper? _keeper;
  String? _keeperOwner;
  final Set<String> _restoredFor = {};

  /// Lines of the cart that was just ordered; not saved again until changed.
  List<FoodCartLine>? _placedLines;

  void start() {
    // Sync: fires inside rotateIdempotencyKey, before the state emission.
    cubit.orderPlaced.listen((_) {
      _placedLines = cubit.state.lines;
      unawaited(_currentKeeper()?.clear());
    });
    cubit.stream.listen(_onState);
    ownerChanges?.listen((_) => unawaited(_tryRestore()));
    unawaited(_tryRestore());
  }

  DraftKeeper? _currentKeeper() {
    final owner = FormDrafts.owner?.call()?.trim() ?? '';
    if (owner.isEmpty) {
      return null;
    }
    if (_keeper == null || _keeperOwner != owner) {
      _keeper = FormDrafts.keeper('food.cart', maxAge: maxAge);
      _keeperOwner = owner;
    }
    return _keeper;
  }

  Future<void> _tryRestore() async {
    final keeper = _currentKeeper();
    final owner = _keeperOwner;
    if (keeper == null || owner == null || !_restoredFor.add(owner)) {
      return;
    }
    try {
      final saved = await keeper.load();
      if (saved == null || cubit.isClosed) {
        return;
      }
      final snapshot = foodCartFromDraft(saved);
      if (snapshot != null) {
        cubit.restoreDraft(snapshot);
      }
    } catch (_) {}
  }

  void _onState(FoodCartState next) {
    final keeper = _currentKeeper();
    if (keeper == null) {
      return;
    }
    if (_placedLines != null && _sameLines(_placedLines!, next.lines)) {
      return;
    }
    _placedLines = null;
    if (next.lines.isEmpty) {
      unawaited(keeper.clear());
      return;
    }
    keeper.schedule(foodCartToDraft(next));
  }
}

bool _sameLines(List<FoodCartLine> a, List<FoodCartLine> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

Map<String, Object?> foodCartToDraft(FoodCartState s) => {
  'storeId': s.storeId,
  'storeName': s.storeName,
  'lines': [
    for (final l in s.lines)
      {
        'itemId': l.itemId,
        'name': l.name,
        'unitPriceVnd': l.unitPriceVnd,
        'quantity': l.quantity,
        'catalogItemId': l.catalogItemId,
        'optionIds': l.optionIds,
        'imageUrl': l.imageUrl,
      },
  ],
  'deliveryFareVnd': s.deliveryFareVnd,
  'dropoffLabel': s.dropoffLabel,
  'dropoffLat': s.dropoffLat,
  'dropoffLng': s.dropoffLng,
  'idempotencyKey': s.idempotencyKey,
  'voucherCode': s.voucherCode,
  'voucherDiscountVnd': s.voucherDiscountVnd,
  'minOrderVnd': s.minOrderVnd,
  'prepMinutes': s.prepMinutes,
  'storeDistanceKm': s.storeDistanceKm,
};

FoodCartState? foodCartFromDraft(Map<String, Object?> m) {
  final rawLines = m['lines'];
  final key = m['idempotencyKey'];
  if (rawLines is! List || key is! String || key.isEmpty) {
    return null;
  }
  final lines = <FoodCartLine>[];
  for (final raw in rawLines) {
    if (raw is! Map) continue;
    final itemId = raw['itemId'];
    final name = raw['name'];
    final price = raw['unitPriceVnd'];
    final qty = raw['quantity'];
    if (itemId is! String || name is! String || price is! int || qty is! int) {
      continue;
    }
    if (qty < 1) continue;
    final options = raw['optionIds'];
    lines.add(
      FoodCartLine(
        itemId: itemId,
        name: name,
        unitPriceVnd: price,
        quantity: qty,
        catalogItemId: raw['catalogItemId'] as String?,
        optionIds: options is List ? options.whereType<String>().toList() : [],
        imageUrl: raw['imageUrl'] as String?,
      ),
    );
  }
  if (lines.isEmpty) {
    return null;
  }
  double? asDouble(Object? v) => v is num ? v.toDouble() : null;
  return FoodCartState(
    storeId: m['storeId'] as String?,
    storeName: m['storeName'] as String?,
    lines: lines,
    deliveryFareVnd: m['deliveryFareVnd'] as int?,
    dropoffLabel: (m['dropoffLabel'] as String?) ?? '',
    dropoffLat: asDouble(m['dropoffLat']),
    dropoffLng: asDouble(m['dropoffLng']),
    idempotencyKey: key,
    voucherCode: m['voucherCode'] as String?,
    voucherDiscountVnd: (m['voucherDiscountVnd'] as int?) ?? 0,
    minOrderVnd: (m['minOrderVnd'] as int?) ?? 0,
    prepMinutes: m['prepMinutes'] as int?,
    storeDistanceKm: asDouble(m['storeDistanceKm']),
  );
}
