import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../../config/api_base_url.dart';

/// Disk-backed cache shared by every remote photo in the app.
///
/// Flutter's [ImageCache] only keeps decoded frames in memory and is empty
/// after a cold start, so without this every launch re-downloads the same
/// photos. Entries are content-addressed by URL, which is safe because the
/// backend gives every uploaded file its own immutable name.
class DealGoImageCache {
  DealGoImageCache._();

  static const String cacheKey = 'dealgo_images';
  static const Duration stalePeriod = Duration(days: 30);
  static const int maxObjects = 300;

  static final CacheManager manager = CacheManager(
    Config(cacheKey, stalePeriod: stalePeriod, maxNrOfCacheObjects: maxObjects),
  );

  /// Provider for [url], decoded at [decodeWidth] physical pixels when given.
  ///
  /// The disk entry is keyed by URL only, so the same photo is downloaded once
  /// and merely decoded at the size the current widget needs. When the server
  /// exposes width variants the request asks for one, so the wire payload also
  /// matches the widget instead of the full upload.
  static ImageProvider<Object> provider(String url, {int? decodeWidth}) {
    return ResizeImage.resizeIfNeeded(
      decodeWidth,
      null,
      CachedNetworkImageProvider(
        withImageWidth(url, decodeWidth),
        cacheManager: manager,
      ),
    );
  }
}
