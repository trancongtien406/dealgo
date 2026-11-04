import 'package:flutter/widgets.dart';
import 'package:dealgo/l10n/app_localizations.dart';
import 'package:dealgo/core/network/api_exception.dart';
import 'package:dealgo/features/food/data/datasources/dio_food_remote_datasource.dart';
import 'package:dealgo/features/food/domain/entities/food_models.dart';
import 'package:dealgo/features/merchant/data/datasources/fake_merchant_orders_client.dart';
import 'package:dealgo/features/merchant/data/repositories/merchant_orders_repository_impl.dart';
import 'package:dealgo/features/merchant/domain/usecases/get_merchant_catalog.dart';
import 'package:dealgo/features/merchant/domain/usecases/create_merchant_catalog_item.dart';
import 'package:dealgo/features/merchant/domain/usecases/set_merchant_item_availability.dart';
import 'package:dealgo/features/merchant/presentation/cubit/merchant_catalog_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

MerchantCatalogCubit _catalogCubit(FakeMerchantOrdersClient orders) {
  final repo = MerchantOrdersRepositoryImpl(orders);
  return MerchantCatalogCubit(
    getMerchantCatalog: GetMerchantCatalog(repo),
    createMerchantCatalogItem: CreateMerchantCatalogItem(repo),
    setMerchantItemAvailability: SetMerchantItemAvailability(repo),
  );
}

void main() {
  group('merchant catalog decode', () {
    test('reads store catalog envelope', () {
      final store = decodeFoodStoreDetail({
        'success': true,
        'data': {
          'id': 'store-1',
          'name': 'My Store',
          'ownerId': 'owner-1',
          'sandboxSeed': false,
          'items': [
            {
              'id': 'item-1',
              'name': 'Mì Quảng',
              'priceVnd': 45000,
              'available': true,
            },
          ],
        },
      });
      expect(store.id, 'store-1');
      expect(store.name, 'My Store');
      expect(store.items.single.name, 'Mì Quảng');
      expect(store.items.single.available, isTrue);
    });

    test('reads menu item write envelope', () {
      final item = decodeFoodMenuItem({
        'success': true,
        'data': {
          'id': 'item-1',
          'name': 'Mì Quảng',
          'priceVnd': 48000,
          'available': false,
        },
      });
      expect(item.id, 'item-1');
      expect(item.priceVnd, 48000);
      expect(item.available, isFalse);
    });
  });

  group('MerchantCatalogCubit', () {
    test('loads owner catalog without store id', () async {
      final orders = FakeMerchantOrdersClient(
        onGetCatalog: () => const FoodStoreDetail(
          id: 'store-owned',
          name: 'My Store',
          items: [
            FoodMenuItem(
              id: 'item-1',
              name: 'Bún',
              priceVnd: 60000,
              available: true,
            ),
          ],
        ),
      );
      final cubit = _catalogCubit(orders);
      await cubit.load('access-token');
      expect(orders.catalogCalls, ['access-token']);
      final state = cubit.state;
      expect(state, isA<MerchantCatalogReady>());
      expect((state as MerchantCatalogReady).store.id, 'store-owned');
      await cubit.close();
    });

    test('toggles availability and keeps catalog ready', () async {
      var available = true;
      final orders = FakeMerchantOrdersClient(
        onGetCatalog: () => FoodStoreDetail(
          id: 'store-owned',
          name: 'My Store',
          items: [
            FoodMenuItem(
              id: 'item-1',
              name: 'Bún',
              priceVnd: 60000,
              available: available,
            ),
          ],
        ),
        onSetAvailability: (itemId, next) {
          available = next;
          return FoodMenuItem(
            id: itemId,
            name: 'Bún',
            priceVnd: 60000,
            available: next,
          );
        },
      );
      final cubit = _catalogCubit(orders);
      await cubit.load('access-token');
      await cubit.setAvailability(
        accessToken: 'access-token',
        itemId: 'item-1',
        available: false,
      );
      expect(orders.availabilityCalls, [(itemId: 'item-1', available: false)]);
      final state = cubit.state as MerchantCatalogReady;
      expect(state.store.items.single.available, isFalse);
      expect(state.busyItemId, isNull);
      expect(state.actionError, isNull);
      await cubit.close();
    });

    test('create item appends to catalog', () async {
      final orders = FakeMerchantOrdersClient(
        onGetCatalog: () => const FoodStoreDetail(
          id: 'store-owned',
          name: 'My Store',
          items: [],
        ),
        onCreateItem: (name, priceVnd, available) {
          return FoodMenuItem(
            id: 'item-new',
            name: name,
            priceVnd: priceVnd,
            available: available ?? true,
          );
        },
      );
      final cubit = _catalogCubit(orders);
      await cubit.load('access-token');
      await cubit.createItem(
        accessToken: 'access-token',
        name: 'Trà tắc',
        priceVnd: 25000,
      );
      expect(orders.createCalls.single.name, 'Trà tắc');
      final state = cubit.state as MerchantCatalogReady;
      expect(state.store.items.single.id, 'item-new');
      await cubit.close();
    });

    test('create item forwards the chosen category and details', () async {
      final orders = FakeMerchantOrdersClient(
        onGetCatalog: () => const FoodStoreDetail(
          id: 'store-owned',
          name: 'My Store',
          items: [],
        ),
        onCreateItem: (name, priceVnd, available) => FoodMenuItem(
          id: 'item-new',
          name: name,
          priceVnd: priceVnd,
          available: available ?? true,
        ),
      );
      final cubit = _catalogCubit(orders);
      await cubit.load('access-token');
      await cubit.createItem(
        accessToken: 'access-token',
        name: 'Mì Quảng',
        priceVnd: 40000,
        description: 'Mì Quảng gà ta',
        prepMinutes: 12,
        menuCategoryId: 'cat-main',
      );
      final call = orders.createCalls.single;
      expect(call.menuCategoryId, 'cat-main');
      expect(call.description, 'Mì Quảng gà ta');
      expect(call.prepMinutes, 12);
      await cubit.close();
    });

    test('putting an unapproved item on sale explains the review', () async {
      final orders = FakeMerchantOrdersClient(
        onGetCatalog: () => const FoodStoreDetail(
          id: 'store-owned',
          name: 'My Store',
          items: [
            FoodMenuItem(
              id: 'item-1',
              name: 'Bún',
              priceVnd: 60000,
              available: false,
            ),
          ],
        ),
        availabilityError: const ApiException(
          statusCode: 409,
          message: 'Item is not approved',
          errorCode: 'FOOD_ITEM_NOT_APPROVED',
        ),
      );
      final cubit = _catalogCubit(orders);
      await cubit.load('access-token');
      await cubit.setAvailability(
        accessToken: 'access-token',
        itemId: 'item-1',
        available: true,
      );
      final state = cubit.state as MerchantCatalogReady;
      expect(state.store.items.single.available, isFalse);
      expect(
        state.actionError!.resolve(lookupAppLocalizations(const Locale('vi'))),
        'Món này đang chờ duyệt nên chưa thể mở bán.',
      );
      await cubit.close();
    });

    test('availability failure keeps ready and sets actionError', () async {
      final orders = FakeMerchantOrdersClient(
        onGetCatalog: () => const FoodStoreDetail(
          id: 'store-owned',
          name: 'My Store',
          items: [
            FoodMenuItem(
              id: 'item-1',
              name: 'Bún',
              priceVnd: 60000,
              available: true,
            ),
          ],
        ),
        availabilityError: const ApiException(
          statusCode: 403,
          message: 'Not store owner',
          errorCode: 'FOOD_NOT_STORE_OWNER',
        ),
      );
      final cubit = _catalogCubit(orders);
      await cubit.load('access-token');
      await cubit.setAvailability(
        accessToken: 'access-token',
        itemId: 'item-1',
        available: false,
      );
      final state = cubit.state as MerchantCatalogReady;
      expect(state.store.items.single.available, isTrue);
      expect(
        (state.actionError!.error! as ApiException).message,
        'Not store owner',
      );
      expect(
        state.actionError!.resolve(lookupAppLocalizations(const Locale('vi'))),
        'Tài khoản không quản lý cửa hàng này.',
      );
      await cubit.close();
    });
  });
}
