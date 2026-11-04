import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/config/api_base_url.dart';
import '../../../../core/design_system/components/dealgo_chip.dart';
import '../../../../core/design_system/components/dealgo_skeleton.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../domain/entities/food_category.dart';
import '../food_categories_store.dart';
import '../../../../core/design_system/components/dealgo_network_image.dart';

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

/// Maps admin-managed category icon keys to Lucide icons.
IconData foodCategoryIcon(String iconKey) => switch (iconKey) {
  'soup' => LucideIcons.soup,
  'cooking-pot' => LucideIcons.cookingPot,
  'sandwich' || 'croissant' => LucideIcons.sandwich,
  'cup-soda' || 'cake-slice' || 'ice-cream-cone' => LucideIcons.cupSoda,
  'coffee' || 'beer' => LucideIcons.coffee,
  'hamburger' || 'pizza' || 'drumstick' => LucideIcons.hamburger,
  'popcorn' || 'cookie' || 'salad' => LucideIcons.popcorn,
  'shopping-cart' || 'apple' || 'wheat' || 'store' => LucideIcons.shoppingCart,
  _ => LucideIcons.utensils,
};

/// Fallback for dishes without photos — returns null to let UI render clean placeholders.
String? foodDishFallbackImage(String? category, {String? dishName}) => null;

Color foodCategoryColor(String tone) => (_tones[tone] ?? _tones['orange']!).$1;

Color foodCategoryBackground(String tone) =>
    (_tones[tone] ?? _tones['orange']!).$2;

/// Round tile: the uploaded image from server when there is one, else the vector icon.
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
    final fallback = Center(
      child: Icon(
        foodCategoryIcon(category.icon),
        color: color,
        size: size * 0.52,
      ),
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
