class CreateMerchantCatalogItemParams {
  const CreateMerchantCatalogItemParams({
    required this.accessToken,
    required this.name,
    required this.priceVnd,
    this.available,
  });

  final String accessToken;
  final String name;
  final int priceVnd;
  final bool? available;
}
