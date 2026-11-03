import 'package:flutter/material.dart';

import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import 'food_widgets.dart';

/// Swipeable dish photos with a photo counter. A single photo keeps the
/// plain cover so short menus do not get a dead-end pager.
class FoodDishGallery extends StatefulWidget {
  const FoodDishGallery({
    required this.imageUrls,
    required this.placeholderAsset,
    this.fallbackImageUrl,
    this.aspectRatio = 4 / 3,
    super.key,
  });

  final List<String> imageUrls;
  final String? fallbackImageUrl;
  final String placeholderAsset;
  final double aspectRatio;

  @override
  State<FoodDishGallery> createState() => _FoodDishGalleryState();
}

class _FoodDishGalleryState extends State<FoodDishGallery> {
  final PageController _controller = PageController();
  var _index = 0;

  /// Cover first, then the gallery, without blank or repeated entries.
  List<String> get _images {
    final seen = <String>{};
    return [
      for (final url in [?widget.fallbackImageUrl, ...widget.imageUrls])
        if (url.trim().isNotEmpty && seen.add(url.trim())) url.trim(),
    ];
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = _images;
    if (images.length <= 1) {
      return FoodCoverImage(
        imageUrl: images.isEmpty ? null : images.first,
        aspectRatio: widget.aspectRatio,
        placeholderAsset: widget.placeholderAsset,
      );
    }
    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(DealGoRadius.card),
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              key: const Key('food-dish-gallery'),
              controller: _controller,
              itemCount: images.length,
              onPageChanged: (index) => setState(() => _index = index),
              itemBuilder: (context, index) => FoodCoverImage(
                imageUrl: images[index],
                aspectRatio: widget.aspectRatio,
                placeholderAsset: widget.placeholderAsset,
              ),
            ),
            Positioned(
              right: DealGoSpacing.s12,
              bottom: DealGoSpacing.s12,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: DealGoColors.scrim,
                  borderRadius: BorderRadius.circular(DealGoRadius.pill),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DealGoSpacing.s8,
                    vertical: DealGoSpacing.s4,
                  ),
                  child: Text(
                    AppLocalizations.of(context).foodDishPhotoCount(
                      _index + 1,
                      images.length,
                    ),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
