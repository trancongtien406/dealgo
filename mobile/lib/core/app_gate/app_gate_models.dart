/// t82u (DEC-PROD-089 / DEC-PROD-090): app update + legal consent gate.
enum AppUpdateVerdict { none, optional, required }

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.verdict,
    this.latestVersion = '',
    this.storeUrl = '',
    this.message = '',
  });

  final AppUpdateVerdict verdict;
  final String latestVersion;
  final String storeUrl;
  final String message;

  static const none = AppUpdateInfo(verdict: AppUpdateVerdict.none);

  static AppUpdateVerdict parseVerdict(Object? raw) => switch (raw) {
    'REQUIRED' => AppUpdateVerdict.required,
    'OPTIONAL' => AppUpdateVerdict.optional,
    _ => AppUpdateVerdict.none,
  };
}

/// A legal document version the signed-in user still has to accept.
class PendingConsent {
  const PendingConsent({
    required this.id,
    required this.slug,
    required this.version,
    required this.title,
    required this.changelog,
    required this.url,
    this.effectiveAt,
  });

  final String id;
  final String slug;
  final int version;
  final String title;
  final String changelog;
  final String url;
  final DateTime? effectiveAt;
}
