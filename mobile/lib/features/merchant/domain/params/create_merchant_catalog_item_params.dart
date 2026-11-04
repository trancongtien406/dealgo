class CreateMerchantCatalogItemParams {
  const CreateMerchantCatalogItemParams({
    required this.accessToken,
    required this.name,
    required this.priceVnd,
    this.available,
    this.description,
    this.prepMinutes,
    this.menuCategoryId,
  });

  final String accessToken;
  final String name;
  final int priceVnd;
  final bool? available;
  final String? description;
  final int? prepMinutes;
  final String? menuCategoryId;
}
