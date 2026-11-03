import 'package:flutter/material.dart';

import '../../../../core/config/api_base_url.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import 'food_widgets.dart';

/// Cover first, then the gallery, without blank or repeated photos.
///
/// Returns the values as given (trimmed) so callers keep the original URLs;
/// deduplication runs on the resolved form, because the same photo can arrive
/// as a relative path on the cover and as an absolute URL in the gallery.
List<String> foodDishGalleryImages({
  required List<String> imageUrls,
  String? fallbackImageUrl,
}) {
  final seen = <String>{};
  final images = <String>[];
  for (final url in [?fallbackImageUrl, ...imageUrls]) {
    final value = url.trim();
    if (value.isEmpty) continue;
    if (seen.add(resolveMediaUrl(value) ?? value)) images.add(value);
  }
  return images;
}

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

  List<String> get _images => foodDishGalleryImages(
    imageUrls: widget.imageUrls,
    fallbackImageUrl: widget.fallbackImageUrl,
  );

  @override
  void didUpdateWidget(FoodDishGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncIndex();
  }

  /// The page count changes when another dish is picked; a stale index would
  /// print a counter the pager can never reach.
  void _syncIndex() {
    if (_index < _images.length) return;
    _index = 0;
    if (_controller.hasClients) _controller.jumpToPage(0);
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
    final index = _index.clamp(0, images.length - 1);
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
                    AppLocalizations.of(context)
                        .foodDishPhotoCount(index + 1, images.length),
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
