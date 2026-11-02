import 'package:dealgo/features/legal/legal_document_page.dart';
import 'package:dealgo/features/onboarding/domain/entities/partner_application.dart';
import 'package:dealgo/features/legal/legal_documents.dart';
import 'package:dealgo/features/legal/partner_legal_consent.dart';
import 'package:dealgo/features/onboarding/data/models/partner_application_body.dart';
import 'package:dealgo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/auth_test_harness.dart';
import 'support/fake_identity_client.dart';

class _Source implements LegalDocumentsSource {
  _Source({this.fail = false});

  bool fail;

  @override
  Future<List<AcceptedLegalDocument>> partnerApplicationDocuments() async {
    if (fail) throw StateError('offline');
    return const [
      AcceptedLegalDocument(slug: 'regulations', version: 3),
      AcceptedLegalDocument(slug: 'privacy', version: 0),
    ];
  }

  @override
  Future<LegalDocument> page(String slug, {String locale = 'vi'}) async =>
      LegalDocument(
        slug: slug,
        title: 'Quy chế sử dụng dành cho tài xế và cửa hàng',
        version: 3,
        sections: const [
          LegalSection(title: 'Điều 1', content: 'Tài xế phải có GPLX.'),
        ],
      );
}

Widget _host(LegalDocumentsSource source, Widget child) => MaterialApp(
  locale: const Locale('vi'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: RepositoryProvider<LegalDocumentsSource>.value(
    value: source,
    child: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

void main() {
  test('pt5u submit body carries the accepted legal versions', () {
    final body = partnerApplicationBodyJson(
      const SubmitPartnerApplicationRequest(
        accessToken: 't',
        role: 'DRIVER',
        metadata: {},
        acceptedLegalDocuments: [
          AcceptedLegalDocument(slug: 'regulations', version: 2),
          AcceptedLegalDocument(slug: 'privacy', version: 0),
        ],
      ),
    );
    expect(body['acceptedLegalDocuments'], [
      {'slug': 'regulations', 'version': 2},
      {'slug': 'privacy', 'version': 0},
    ]);
  });

  test('pt5u built-in default page counts as version 0', () {
    final def = LegalDocument.fromJson({
      'slug': 'regulations',
      'title': 'Quy chế',
      'version': 1,
      'source': 'default',
      'content': {
        'sections': [
          {'id': 'a', 'title': 'Điều 1', 'content': 'x'},
        ],
      },
    })!;
    expect(def.version, 0);
    expect(def.sections.single.title, 'Điều 1');
    final cms = LegalDocument.fromJson({
      'slug': 'regulations',
      'title': 'Quy chế',
      'version': 4,
      'source': 'cms',
    })!;
    expect(cms.version, 4);
  });

  testWidgets('pt5u consent stays null until both boxes are ticked', (
    tester,
  ) async {
    final consent = ValueNotifier<List<AcceptedLegalDocument>?>(null);
    await tester.pumpWidget(
      _host(_Source(), PartnerLegalConsent(consent: consent)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tôi đã đọc và đồng ý với Quy chế sử dụng'), findsOne);
    expect(consent.value, isNull);
    await tester.tap(find.byKey(const Key('partner-consent-regulations')));
    await tester.pump();
    expect(consent.value, isNull, reason: 'privacy still unticked');
    await tester.tap(find.byKey(const Key('partner-consent-privacy')));
    await tester.pump();
    expect(consent.value, const [
      AcceptedLegalDocument(slug: 'regulations', version: 3),
      AcceptedLegalDocument(slug: 'privacy', version: 0),
    ]);
    await tester.tap(find.byKey(const Key('partner-consent-privacy')));
    await tester.pump();
    expect(consent.value, isNull, reason: 'unticking blocks submit again');
  });

  testWidgets('pt5u failed version load keeps submit blocked', (tester) async {
    final source = _Source(fail: true);
    final consent = ValueNotifier<List<AcceptedLegalDocument>?>(null);
    await tester.pumpWidget(
      _host(source, PartnerLegalConsent(consent: consent)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('partner-consent-regulations')));
    await tester.tap(find.byKey(const Key('partner-consent-privacy')));
    await tester.pump();
    expect(consent.value, isNull);
    source.fail = false;
    await tester.tap(find.byKey(const Key('partner-legal-consent-retry')));
    await tester.pumpAndSettle();
    expect(consent.value, hasLength(2));
  });

  testWidgets('pt5u "Xem" opens the in-app document viewer', (tester) async {
    final consent = ValueNotifier<List<AcceptedLegalDocument>?>(null);
    await tester.pumpWidget(
      _host(_Source(), PartnerLegalConsent(consent: consent)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('partner-consent-view-regulations')));
    await tester.pumpAndSettle();
    expect(find.byType(LegalDocumentPage), findsOneWidget);
    expect(find.text('Tài xế phải có GPLX.'), findsOneWidget);
  });

  testWidgets('pt5u account page lists Quy chế sử dụng and privacy', (
    tester,
  ) async {
    await pumpSignedIn(tester, profile: customerProfile);
    await tester.tap(navLabel('Tôi'));
    await tester.pumpAndSettle();
    final row = find.byKey(const ValueKey('account-regulations-row'));
    await tester.ensureVisible(row);
    expect(find.byKey(const ValueKey('account-privacy-row')), findsOneWidget);
    await tester.tap(row);
    await tester.pumpAndSettle();
    final page = tester.widget<LegalDocumentPage>(
      find.byType(LegalDocumentPage),
    );
    expect(page.slug, LegalSlug.regulations);
    expect(find.text('Quy chế sử dụng'), findsWidgets);
  });
}
