import 'package:flutter_bloc/flutter_bloc.dart';

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
  final String? actionError;
  final String? busyItemId;

  MerchantCatalogReady copyWith({
    FoodStoreDetail? store,
    String? actionError,
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

  final String message;
}

class MerchantCatalogCubit extends Cubit<MerchantCatalogState> {
  MerchantCatalogCubit({
    required GetMerchantCatalog getMerchantCatalog,
    required CreateMerchantCatalogItem createMerchantCatalogItem,
    required SetMerchantItemAvailability setMerchantItemAvailability,
  }) : _getMerchantCatalog = getMerchantCatalog,
       _createMerchantCatalogItem = createMerchantCatalogItem,
       _setMerchantItemAvailability = setMerchantItemAvailability,
       super(const MerchantCatalogLoading());

  final GetMerchantCatalog _getMerchantCatalog;
  final CreateMerchantCatalogItem _createMerchantCatalogItem;
  final SetMerchantItemAvailability _setMerchantItemAvailability;

  Future<void> load(String? accessToken) async {
    final token = accessToken?.trim() ?? '';
    if (token.isEmpty) {
      emit(const MerchantCatalogFailed('Bạn cần đăng nhập lại.'));
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
        emit(MerchantCatalogFailed(error.message));
      }
    } catch (_) {
      if (!isClosed) {
        emit(const MerchantCatalogFailed('Không thể kết nối máy chủ'));
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
      emit(ready.copyWith(actionError: 'Bạn cần đăng nhập lại.'));
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
            actionError: error.message,
            clearBusyItemId: true,
          ),
        );
      }
    } catch (_) {
      if (!isClosed && state is MerchantCatalogReady) {
        emit(
          (state as MerchantCatalogReady).copyWith(
            actionError: 'Không thể cập nhật trạng thái món',
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
  }) async {
    final ready = state;
    if (ready is! MerchantCatalogReady || ready.busyItemId != null) {
      return;
    }
    final token = accessToken?.trim() ?? '';
    if (token.isEmpty) {
      emit(ready.copyWith(actionError: 'Bạn cần đăng nhập lại.'));
      return;
    }
    final trimmed = name.trim();
    if (trimmed.isEmpty || priceVnd < 1) {
      emit(ready.copyWith(actionError: 'Tên món và giá không hợp lệ.'));
      return;
    }
    emit(ready.copyWith(busyItemId: '_create', clearActionError: true));
    try {
      final created = await _createMerchantCatalogItem(
        CreateMerchantCatalogItemParams(
          accessToken: token,
          name: trimmed,
          priceVnd: priceVnd,
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
          FoodStoreDetail(
            id: current.store.id,
            name: current.store.name,
            items: List.unmodifiable([...current.store.items, created]),
          ),
        ),
      );
    } on ApiException catch (error) {
      if (!isClosed && state is MerchantCatalogReady) {
        emit(
          (state as MerchantCatalogReady).copyWith(
            actionError: error.message,
            clearBusyItemId: true,
          ),
        );
      }
    } catch (_) {
      if (!isClosed && state is MerchantCatalogReady) {
        emit(
          (state as MerchantCatalogReady).copyWith(
            actionError: 'Không thể thêm món',
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
    return FoodStoreDetail(
      id: store.id,
      name: store.name,
      items: List.unmodifiable([
        for (final item in store.items)
          if (item.id == updated.id) updated else item,
      ]),
    );
  }
}
