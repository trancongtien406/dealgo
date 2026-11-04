import 'package:flutter/material.dart';

import '../../../../core/config/api_base_url.dart';
import '../../../../core/design_system/components/dealgo_chip.dart';
import '../../../../core/design_system/components/dealgo_skeleton.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../domain/entities/food_category.dart';
import '../food_categories_store.dart';
import '../../../../core/design_system/components/dealgo_network_image.dart';
import '../../../places/domain/place.dart' show foldVietnamese;

/// Tone keys → (foreground, background); same palette as the Admin swatches.
const Map<String, (Color, Color)> _tones = {
  'orange': (Color(0xFFEA580C), Color(0xFFFFF1E6)),
  'amber': (Color(0xFFD97706), Color(0xFFFFF7E0)),
  'red': (Color(0xFFDC2626), Color(0xFFFFECEC)),
  'pink': (Color(0xFFDB2777), Color(0xFFFFEEF6)),
  'purple': (Color(0xFF7C3AED), Color(0xFFF3EAFF)),
  'indigo': (Color(0xFF4F46E5), Color(0xFFEEF2FF)),
  'blue': (Color(0xFF2563EB), Color(0xFFE8F1FF)),
  'green': (Color(0xFF16A34A), Color(0xFFE8F7EE)),
  'brown': (Color(0xFF92400E), Color(0xFFF6EDE4)),
};

/// Bundled photo when a dish has no picture yet.
const String foodPlaceholderImage = 'assets/images/food_dish_placeholder.jpg';

/// Bundled cover when a store has no picture yet.
const String foodStoreCoverImage = 'assets/images/food_store_cover.jpg';

/// Dish without a picture: a bundled photo that suits the dish itself, else its
/// store's category photo, else the plate. The store category alone is too
/// coarse — a tea sold by a rice shop must not show fried chicken.
String foodDishFallbackImage(String? category, {String? dishName}) {
  final dish = _dishPhotoCode(dishName);
  if (dish != null) return 'assets/images/food_cat_$dish.jpg';
  final code = category?.trim() ?? '';
  return _photoCodes.contains(code)
      ? 'assets/images/food_cat_$code.jpg'
      : foodPlaceholderImage;
}

/// First hint that matches wins, so the more specific words come first.
const List<(String, List<String>)> _dishPhotoHints = [
  ('banh_mi', ['banh mi']),
  ('pho', ['pho', 'canh ']),
  ('noodles', ['bun', 'mi quang', 'mi ', 'hu tieu', 'mien', 'banh canh']),
  ('rice', ['com ', 'xoi']),
  ('cafe', ['ca phe', 'bac xiu', 'cold brew', 'espresso', 'latte']),
  (
    'tea',
    ['tra ', 'nuoc mia', 'sinh to', 'nuoc ep', 'sua chua', 'che ', 'nuoc '],
  ),
  ('snack', ['cha ', 'nem', 'banh ', 'flan', 'croissant', 'khoai']),
  ('fast_food', ['ga ran', 'pizza', 'burger']),
];

String? _dishPhotoCode(String? dishName) {
  final text = foldVietnamese(dishName ?? '');
  if (text.isEmpty) return null;
  for (final (code, hints) in _dishPhotoHints) {
    if (hints.any(text.contains)) return code;
  }
  return null;
}

/// Seeded category codes that ship their own photo (same set as Admin).
const Set<String> _photoCodes = {
  'pho',
  'noodles',
  'rice',
  'banh_mi',
  'tea',
  'cafe',
  'fast_food',
  'snack',
  'mart',
};

/// Admin default-image key → bundled photo, mirroring the Admin picker.
String _iconPhoto(String key) => switch (key) {
  'soup' => 'pho',
  'cooking-pot' => 'noodles',
  'sandwich' || 'croissant' => 'banh_mi',
  'cup-soda' || 'cake-slice' || 'ice-cream-cone' => 'tea',
  'coffee' || 'beer' => 'cafe',
  'hamburger' || 'pizza' || 'drumstick' => 'fast_food',
  'popcorn' || 'cookie' || 'salad' => 'snack',
  'shopping-cart' || 'apple' || 'wheat' || 'store' => 'mart',
  _ => 'rice',
};

/// Picture used until the category has its own uploaded image — tiles
/// always show a photo, never an icon.
String foodCategoryFallbackImage(String code, String iconKey) {
  final photo = _photoCodes.contains(code) ? code : _iconPhoto(iconKey);
  return 'assets/images/food_cat_$photo.jpg';
}

Color foodCategoryColor(String tone) => (_tones[tone] ?? _tones['orange']!).$1;

Color foodCategoryBackground(String tone) =>
    (_tones[tone] ?? _tones['orange']!).$2;

/// Round tile: the uploaded image when there is one, else a bundled photo.
class FoodCategoryAvatar extends StatelessWidget {
  const FoodCategoryAvatar({
    required this.category,
    this.size = 56,
    this.selected = false,
    super.key,
  });

  final FoodCategory category;
  final double size;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = foodCategoryColor(category.tone);
    final fallback = Image.asset(
      foodCategoryFallbackImage(category.code, category.icon),
      fit: BoxFit.cover,
      width: size,
      height: size,
    );
    final image = resolveMediaUrl(category.imageUrl);
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: foodCategoryBackground(category.tone),
        shape: BoxShape.circle,
        border: selected ? Border.all(color: color, width: 1.5) : null,
      ),
      child: image == null
          ? fallback
          : DealGoNetworkImage(image, fit: BoxFit.cover, fallback: fallback),
    );
  }
}

/// Shimmering circle + label bar while the list loads.
class FoodCategoryTileSkeleton extends StatelessWidget {
  const FoodCategoryTileSkeleton({this.size = 56, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return DealGoShimmer(
      child: Column(
        children: [
          DealGoSkeletonBox(width: size, height: size, radius: size / 2),
          const SizedBox(height: DealGoSpacing.s8),
          DealGoSkeletonBox(width: size * 0.8, height: 10),
        ],
      ),
    );
  }
}

/// One-tap category choice for merchants (store profile, onboarding):
/// chips from the Admin-managed list, shimmer while it loads.
class FoodCategoryPicker extends StatelessWidget {
  const FoodCategoryPicker({
    required this.selected,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  final String? selected;
  final ValueChanged<String> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final store = maybeFoodCategories(context);
    final categories = store?.items ?? const <FoodCategory>[];
    final language = Localizations.localeOf(context).languageCode;
    if (categories.isEmpty) {
      return DealGoShimmer(
        child: Wrap(
          spacing: DealGoSpacing.s8,
          runSpacing: DealGoSpacing.s8,
          children: [
            for (var i = 0; i < 6; i++)
              const DealGoSkeletonBox(width: 84, height: 30, radius: 15),
          ],
        ),
      );
    }
    return Wrap(
      spacing: DealGoSpacing.s8,
      runSpacing: DealGoSpacing.s8,
      children: [
        for (final category in categories)
          DealGoChip(
            key: Key('food-category-pick-${category.code}'),
            label: category.name(language),
            size: DealGoChipSize.md,
            selected: selected == category.code,
            enabled: enabled,
            leading: FoodCategoryAvatar(category: category, size: 20),
            onTap: enabled ? () => onChanged(category.code) : null,
          ),
      ],
    );
  }
}
