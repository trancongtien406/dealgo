import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/l10n/ui_message.dart';
import '../../../../core/network/api_exception.dart';
import '../../../food/domain/entities/food_models.dart';
import '../../domain/entities/merchant_menu_models.dart';
import '../../domain/params/create_merchant_catalog_item_params.dart';
import '../../domain/params/set_merchant_item_availability_params.dart';
import '../../domain/repositories/merchant_orders_repository.dart';
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
  const MerchantCatalogReady(
    this.store, {
    this.categories = const [],
    this.actionError,
    this.busyItemId,
  });

  final FoodStoreDetail store;
  final List<MerchantMenuCategory> categories;
  final UiMessage? actionError;
  final String? busyItemId;

  MerchantCatalogReady copyWith({
    FoodStoreDetail? store,
    List<MerchantMenuCategory>? categories,
    UiMessage? actionError,
    String? busyItemId,
    bool clearActionError = false,
    bool clearBusyItemId = false,
  }) {
    return MerchantCatalogReady(
      store ?? this.store,
      categories: categories ?? this.categories,
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
    this._repository,
  }) : super(const MerchantCatalogLoading());

  final GetMerchantCatalog _getMerchantCatalog;
  final CreateMerchantCatalogItem _createMerchantCatalogItem;
  final SetMerchantItemAvailability _setMerchantItemAvailability;
  final MerchantOrdersRepository? _repository;

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
      List<MerchantMenuCategory> categories = const [];
      if (_repository != null) {
        try {
          categories = await _repository.listMenuCategories(token);
        } on Object {
          categories = const [];
        }
      }
      if (!isClosed) {
        emit(MerchantCatalogReady(store, categories: categories));
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
      emit(
        MerchantCatalogReady(
          _replaceItem(current.store, updated),
          categories: current.categories,
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
    bool? available,
    String? description,
    int? prepMinutes,
    String? menuCategoryId,
    int? originalPriceVnd,
    List<MerchantItemImageUpload>? newImages,
    List<FoodOptionGroup>? optionGroups,
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
          available: available,
          description: description,
          prepMinutes: prepMinutes,
          menuCategoryId: menuCategoryId,
          originalPriceVnd: originalPriceVnd,
          newImages: newImages,
          optionGroups: optionGroups,
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
          categories: current.categories,
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

  Future<bool> deleteItem({
    required String? accessToken,
    required String itemId,
  }) async {
    final ready = state;
    final repo = _repository;
    if (ready is! MerchantCatalogReady ||
        ready.busyItemId != null ||
        repo == null) {
      return false;
    }
    final token = accessToken?.trim() ?? '';
    if (token.isEmpty) {
      emit(
        ready.copyWith(
          actionError: UiMessage((l10n) => l10n.errorSessionExpired),
        ),
      );
      return false;
    }
    emit(ready.copyWith(busyItemId: itemId, clearActionError: true));
    try {
      await repo.deleteCatalogItem(accessToken: token, itemId: itemId);
      if (isClosed) {
        return false;
      }
      final current = state;
      if (current is! MerchantCatalogReady) {
        return false;
      }
      emit(
        MerchantCatalogReady(
          current.store.copyWith(
            items: List.unmodifiable([
              for (final item in current.store.items)
                if (item.id != itemId) item,
            ]),
          ),
          categories: current.categories,
        ),
      );
      return true;
    } on ApiException catch (error) {
      if (!isClosed && state is MerchantCatalogReady) {
        emit(
          (state as MerchantCatalogReady).copyWith(
            actionError: UiMessage.error(error),
            clearBusyItemId: true,
          ),
        );
      }
      return false;
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
      return false;
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
