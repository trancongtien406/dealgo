import '../../../food/domain/entities/food_models.dart';
import '../entities/merchant_menu_models.dart';

class CreateMerchantCatalogItemParams {
  const CreateMerchantCatalogItemParams({
    required this.accessToken,
    required this.name,
    required this.priceVnd,
    this.available,
    this.description,
    this.prepMinutes,
    this.menuCategoryId,
    this.originalPriceVnd,
    this.newImages,
    this.optionGroups,
  });

  final String accessToken;
  final String name;
  final int priceVnd;
  final bool? available;
  final String? description;
  final int? prepMinutes;
  final String? menuCategoryId;
  final int? originalPriceVnd;
  final List<MerchantItemImageUpload>? newImages;
  final List<FoodOptionGroup>? optionGroups;
}
