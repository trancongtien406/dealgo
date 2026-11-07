import '../../../food/domain/entities/food_models.dart';
import '../params/create_merchant_catalog_item_params.dart';
import '../repositories/merchant_orders_repository.dart';

class CreateMerchantCatalogItem {
  const CreateMerchantCatalogItem(this._repository);

  final MerchantOrdersRepository _repository;

  Future<FoodMenuItem> call(CreateMerchantCatalogItemParams params) {
    return _repository.createCatalogItem(
      accessToken: params.accessToken,
      name: params.name,
      priceVnd: params.priceVnd,
      available: params.available,
      description: params.description,
      prepMinutes: params.prepMinutes,
      menuCategoryId: params.menuCategoryId,
      originalPriceVnd: params.originalPriceVnd,
      newImages: params.newImages,
      optionGroups: params.optionGroups,
    );
  }
}
