/// Store category managed in Admin › Danh mục (`GET /v1/public/food-categories`).
/// [icon] and [tone] are keys the app maps to its own icon set and colours.
class FoodCategory {
  const FoodCategory({
    required this.code,
    required this.nameVi,
    required this.nameEn,
    required this.icon,
    required this.tone,
    this.imageUrl,
  });

  final String code;
  final String nameVi;
  final String nameEn;
  final String icon;
  final String tone;

  /// Relative API path (`/v1/public/food-categories/images/...`) or null.
  final String? imageUrl;

  String name(String languageCode) => languageCode == 'vi' ? nameVi : nameEn;

  static FoodCategory? fromJson(Object? json) {
    if (json is! Map) return null;
    final code = json['code'];
    final nameVi = json['nameVi'];
    if (code is! String || code.isEmpty || nameVi is! String) return null;
    final nameEn = json['nameEn'];
    final image = json['imageUrl'];
    return FoodCategory(
      code: code,
      nameVi: nameVi,
      nameEn: nameEn is String && nameEn.isNotEmpty ? nameEn : nameVi,
      icon: json['icon'] is String ? json['icon'] as String : '',
      tone: json['tone'] is String ? json['tone'] as String : '',
      imageUrl: image is String && image.isNotEmpty ? image : null,
    );
  }

  Map<String, Object?> toJson() => {
    'code': code,
    'nameVi': nameVi,
    'nameEn': nameEn,
    'icon': icon,
    'tone': tone,
    'imageUrl': imageUrl,
  };

  @override
  bool operator ==(Object other) =>
      other is FoodCategory &&
      other.code == code &&
      other.nameVi == nameVi &&
      other.nameEn == nameEn &&
      other.icon == icon &&
      other.tone == tone &&
      other.imageUrl == imageUrl;

  @override
  int get hashCode => Object.hash(code, nameVi, nameEn, icon, tone, imageUrl);
}

List<FoodCategory> decodeFoodCategories(Object? data) {
  final items = data is Map ? data['items'] : null;
  if (items is! List) return const [];
  return [for (final item in items) ?FoodCategory.fromJson(item)];
}

abstract class FoodCategoryRepository {
  /// Active categories in Admin order.
  Future<List<FoodCategory>> list();
}
