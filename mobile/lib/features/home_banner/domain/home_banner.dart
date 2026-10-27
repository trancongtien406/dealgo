import '../../identity/domain/entities/app_role.dart';

/// Where a banner tap goes: an in-app page or a web page.
enum HomeBannerCtaKind { app, web }

class HomeBannerCta {
  const HomeBannerCta({required this.kind, required this.target});

  final HomeBannerCtaKind kind;

  /// App path (`/customer/book`) or an absolute `https://` URL.
  final String target;
}

/// One admin-managed home banner, as served by `GET /v1/public/home-banners`.
class HomeBanner {
  const HomeBanner({
    required this.id,
    required this.title,
    required this.imageUrl,
    this.subtitle,
    this.cta,
    this.service = 'ALL',
  });

  final String id;
  final String title;
  final String? subtitle;

  /// Server path or absolute URL of the 2:1 image (text-free art).
  final String imageUrl;
  final HomeBannerCta? cta;
  final String service;
}

enum HomeBannerEventType { impression, click }

class HomeBannerEvent {
  const HomeBannerEvent(this.bannerId, this.type);

  final String bannerId;
  final HomeBannerEventType type;

  Map<String, Object?> toJson() => {
    'bannerId': bannerId,
    'type': type == HomeBannerEventType.click ? 'CLICK' : 'IMPRESSION',
  };
}

abstract interface class HomeBannerRepository {
  /// Live banners for [role], nearest region first when [lat]/[lng] are known.
  Future<List<HomeBanner>> list({
    required AppRole role,
    double? lat,
    double? lng,
  });

  /// Best effort; the server takes at most 50 events per call.
  Future<void> record(List<HomeBannerEvent> events);
}

/// Lenient decode of the `data` payload: bad rows are skipped, never thrown.
List<HomeBanner> decodeHomeBanners(Map<String, Object?>? data) {
  final items = data?['items'];
  if (items is! List) {
    return const [];
  }
  final out = <HomeBanner>[];
  for (final raw in items) {
    if (raw is! Map) {
      continue;
    }
    final id = raw['id'];
    final title = raw['title'];
    final image = raw['imageUrl'];
    if (id is! String || title is! String || image is! String) {
      continue;
    }
    if (id.isEmpty || image.isEmpty) {
      continue;
    }
    final subtitle = raw['subtitle'];
    final service = raw['service'];
    out.add(
      HomeBanner(
        id: id,
        title: title,
        subtitle: subtitle is String && subtitle.trim().isNotEmpty
            ? subtitle
            : null,
        imageUrl: image,
        cta: _decodeCta(raw['cta']),
        service: service is String ? service : 'ALL',
      ),
    );
  }
  return out;
}

HomeBannerCta? _decodeCta(Object? raw) {
  if (raw is! Map) {
    return null;
  }
  final kind = raw['kind'];
  final target = raw['target'];
  if (target is! String || target.isEmpty) {
    return null;
  }
  if (kind == 'app' && target.startsWith('/')) {
    return HomeBannerCta(kind: HomeBannerCtaKind.app, target: target);
  }
  if (kind == 'web' && target.startsWith('https://')) {
    return HomeBannerCta(kind: HomeBannerCtaKind.web, target: target);
  }
  return null;
}
