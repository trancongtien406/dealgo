/// One published help entry (Admin › FAQ, audience CUSTOMER/DRIVER/MERCHANT).
class HelpFaq {
  const HelpFaq({
    required this.id,
    required this.question,
    required this.answer,
  });

  final String id;
  final String question;
  final String answer;
}

abstract interface class HelpFaqRepository {
  /// [audience] is CUSTOMER, DRIVER or MERCHANT (the shell the user is in).
  Future<List<HelpFaq>> list({required String audience});

  /// Messenger chat link set in Admin Web › Settings › Website; null when unset.
  Future<Uri?> messengerUrl();
}

const _messengerHosts = {'m.me', 'messenger.com', 'www.messenger.com'};

/// Reads `socials.messenger` from the public site config, accepting only
/// https links on Messenger hosts (same allowlist as the server).
Uri? messengerUrlFromSiteConfig(Object? siteConfig) {
  if (siteConfig is! Map) return null;
  final socials = siteConfig['socials'];
  if (socials is! Map) return null;
  final raw = socials['messenger'];
  if (raw is! String) return null;
  final uri = Uri.tryParse(raw.trim());
  if (uri == null ||
      uri.scheme != 'https' ||
      !_messengerHosts.contains(uri.host.toLowerCase())) {
    return null;
  }
  return uri;
}
