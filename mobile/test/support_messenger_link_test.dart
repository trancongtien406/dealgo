import 'package:dealgo/features/support/domain/help_faq.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads the admin Messenger link from the public site config', () {
    expect(
      messengerUrlFromSiteConfig({
        'socials': {'messenger': 'https://m.me/dealgo'},
      }),
      Uri.parse('https://m.me/dealgo'),
    );
  });

  test('ignores missing, insecure or foreign Messenger links', () {
    expect(messengerUrlFromSiteConfig(null), isNull);
    expect(messengerUrlFromSiteConfig({'socials': {}}), isNull);
    expect(
      messengerUrlFromSiteConfig({
        'socials': {'messenger': 'http://m.me/dealgo'},
      }),
      isNull,
    );
    expect(
      messengerUrlFromSiteConfig({
        'socials': {'messenger': 'https://m.me.evil.com/x'},
      }),
      isNull,
    );
  });
}
