import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/l10n/ui_message.dart';
import '../../../../core/network/api_exception.dart';
import '../../../food/domain/entities/food_models.dart';
import '../../domain/params/create_merchant_catalog_item_params.dart';
import '../../domain/params/set_merchant_item_availability_params.dart';
import '../../domain/usecases/create_merchant_catalog_item.dart';
import '../../domain/usecases/get_merchant_catalog.dart';
import '../../domain/usecases/set_merchant_item_availability.dart';

sealed class MerchantCatalogState {
  const MerchantCatalogState();
}

final class MerchantCatalogLoading extends MerchantCatalogState {
  const MerchantCatalogLoading();
}

final class MerchantCatalogReady extends MerchantCatalogState {
  const MerchantCatalogReady(this.store, {this.actionError, this.busyItemId});

  final FoodStoreDetail store;
  final UiMessage? actionError;
  final String? busyItemId;

  MerchantCatalogReady copyWith({
    FoodStoreDetail? store,
    UiMessage? actionError,
    String? busyItemId,
    bool clearActionError = false,
    bool clearBusyItemId = false,
  }) {
    return MerchantCatalogReady(
      store ?? this.store,
      actionError: clearActionError ? null : (actionError ?? this.actionError),
      busyItemId: clearBusyItemId ? null : (busyItemId ?? this.busyItemId),
    );
  }
}

final class MerchantCatalogFailed extends MerchantCatalogState {
  const MerchantCatalogFailed(this.message);

  final UiMessage message;
}

class MerchantCatalogCubit extends Cubit<MerchantCatalogState> {
  MerchantCatalogCubit({
    required this._getMerchantCatalog,
    required this._createMerchantCatalogItem,
    required this._setMerchantItemAvailability,
  }) : super(const MerchantCatalogLoading());

  final GetMerchantCatalog _getMerchantCatalog;
  final CreateMerchantCatalogItem _createMerchantCatalogItem;
  final SetMerchantItemAvailability _setMerchantItemAvailability;

  Future<void> load(String? accessToken) async {
    final token = accessToken?.trim() ?? '';
    if (token.isEmpty) {
      emit(
        MerchantCatalogFailed(UiMessage((l10n) => l10n.errorSessionExpired)),
      );
      return;
    }
    emit(const MerchantCatalogLoading());
    try {
      final store = await _getMerchantCatalog(token);
      if (!isClosed) {
        emit(MerchantCatalogReady(store));
      }
    } on ApiException catch (error) {
      if (!isClosed) {
        emit(MerchantCatalogFailed(UiMessage.error(error)));
      }
    } catch (error) {
      if (!isClosed) {
        emit(MerchantCatalogFailed(UiMessage.error(error)));
      }
    }
  }

  Future<void> setAvailability({
    required String? accessToken,
    required String itemId,
    required bool available,
  }) async {
    final ready = state;
    if (ready is! MerchantCatalogReady || ready.busyItemId != null) {
      return;
    }
    final token = accessToken?.trim() ?? '';
    if (token.isEmpty) {
      emit(
        ready.copyWith(
          actionError: UiMessage((l10n) => l10n.errorSessionExpired),
        ),
      );
      return;
    }
    emit(ready.copyWith(busyItemId: itemId, clearActionError: true));
    try {
      final updated = await _setMerchantItemAvailability(
        SetMerchantItemAvailabilityParams(
          accessToken: token,
          itemId: itemId,
          available: available,
        ),
      );
      if (isClosed) {
        return;
      }
      final current = state;
      if (current is! MerchantCatalogReady) {
        return;
      }
      emit(MerchantCatalogReady(_replaceItem(current.store, updated)));
    } on ApiException catch (error) {
      if (!isClosed && state is MerchantCatalogReady) {
        emit(
          (state as MerchantCatalogReady).copyWith(
            actionError: UiMessage.error(error),
            clearBusyItemId: true,
          ),
        );
      }
    } catch (error) {
      if (!isClosed && state is MerchantCatalogReady) {
        emit(
          (state as MerchantCatalogReady).copyWith(
            actionError: UiMessage.error(
              error,
              fallback: (l10n) => l10n.merchantItemUpdateFailed,
            ),
            clearBusyItemId: true,
          ),
        );
      }
    }
  }

  Future<void> createItem({
    required String? accessToken,
    required String name,
    required int priceVnd,
    String? description,
    int? prepMinutes,
    String? menuCategoryId,
  }) async {
    final ready = state;
    if (ready is! MerchantCatalogReady || ready.busyItemId != null) {
      return;
    }
    final token = accessToken?.trim() ?? '';
    if (token.isEmpty) {
      emit(
        ready.copyWith(
          actionError: UiMessage((l10n) => l10n.errorSessionExpired),
        ),
      );
      return;
    }
    final trimmed = name.trim();
    if (trimmed.isEmpty || priceVnd < 1) {
      emit(
        ready.copyWith(
          actionError: UiMessage((l10n) => l10n.merchantItemInvalid),
        ),
      );
      return;
    }
    emit(ready.copyWith(busyItemId: '_create', clearActionError: true));
    try {
      final created = await _createMerchantCatalogItem(
        CreateMerchantCatalogItemParams(
          accessToken: token,
          name: trimmed,
          priceVnd: priceVnd,
          description: description,
          prepMinutes: prepMinutes,
          menuCategoryId: menuCategoryId,
        ),
      );
      if (isClosed) {
        return;
      }
      final current = state;
      if (current is! MerchantCatalogReady) {
        return;
      }
      emit(
        MerchantCatalogReady(
          current.store.copyWith(
            items: List.unmodifiable([...current.store.items, created]),
          ),
        ),
      );
    } on ApiException catch (error) {
      if (!isClosed && state is MerchantCatalogReady) {
        emit(
          (state as MerchantCatalogReady).copyWith(
            actionError: UiMessage.error(error),
            clearBusyItemId: true,
          ),
        );
      }
    } catch (error) {
      if (!isClosed && state is MerchantCatalogReady) {
        emit(
          (state as MerchantCatalogReady).copyWith(
            actionError: UiMessage.error(
              error,
              fallback: (l10n) => l10n.merchantItemCreateFailed,
            ),
            clearBusyItemId: true,
          ),
        );
      }
    }
  }

  void clearActionError() {
    final ready = state;
    if (ready is MerchantCatalogReady && ready.actionError != null) {
      emit(ready.copyWith(clearActionError: true));
    }
  }

  FoodStoreDetail _replaceItem(FoodStoreDetail store, FoodMenuItem updated) {
    return store.copyWith(
      items: List.unmodifiable([
        for (final item in store.items)
          if (item.id == updated.id) updated else item,
      ]),
    );
  }
}
