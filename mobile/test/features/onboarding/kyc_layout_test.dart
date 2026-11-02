import 'package:dealgo/features/onboarding/domain/entities/partner_documents.dart';
import 'package:dealgo/features/onboarding/presentation/capture/camera_cover_preview.dart';
import 'package:dealgo/features/onboarding/presentation/cubit/partner_document_draft.dart';
import 'package:dealgo/features/onboarding/presentation/document_image_source.dart';
import 'package:dealgo/features/onboarding/presentation/widgets/partner_kyc_widgets.dart';
import 'package:dealgo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const _sizes = <String, Size>{
  'iPhone SE': Size(320, 568),
  'small Android': Size(360, 640),
  'iPhone 17 Pro Max': Size(440, 956),
};

Widget _slot(Locale locale, double width, {double textScale = 1}) =>
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 900),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: PartnerDocumentSlot(
              kind: PartnerDocumentKind.idFront,
              draft: const PartnerDocumentDraft(),
              source: FakeDocumentImageSource(),
              onPicked: (_) {},
              onRemove: () {},
            ),
          ),
        ),
      ),
    );

/// True when any Text under [finder] is cut off (ellipsis or clipped lines).
bool _anyTextTruncated(WidgetTester tester, Finder finder) {
  for (final element
      in find
          .descendant(of: finder, matching: find.byType(RichText))
          .evaluate()) {
    final render = element.renderObject! as RenderParagraph;
    if (render.didExceedMaxLines) return true;
    final painter = TextPainter(
      text: render.text,
      textDirection: TextDirection.ltr,
      textScaler: render.textScaler,
      maxLines: 1,
    )..layout();
    // A one-line label wider than its box would be clipped, not wrapped,
    // only when softWrap is off.
    if (!render.softWrap && painter.width > render.size.width + 0.5) {
      return true;
    }
  }
  return false;
}

void main() {
  for (final locale in const [Locale('vi'), Locale('en')]) {
    for (final entry in _sizes.entries) {
      for (final scale in const [1.0, 1.3]) {
        testWidgets('doc slot buttons never truncate: ${locale.languageCode} '
            '${entry.key} x$scale', (tester) async {
          tester.view.physicalSize = entry.value;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            _slot(locale, entry.value.width, textScale: scale),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          for (final key in const ['doc-camera-', 'doc-gallery-']) {
            final button = find.byKey(
              Key('$key${PartnerDocumentKind.idFront}'),
            );
            expect(button, findsOneWidget);
            expect(_anyTextTruncated(tester, button), isFalse);
          }
        });
      }
    }
  }

  test('portraitPreviewSize swaps landscape sensor sizes', () {
    expect(portraitPreviewSize(const Size(1920, 1080)), const Size(1080, 1920));
    expect(portraitPreviewSize(const Size(480, 640)), const Size(480, 640));
  });

  test('coverCrop keeps the centred visible part of the frame', () {
    // iOS low preset upright 288×352 in a 3:4 oval: sides are cropped.
    final crop = coverCrop(const Size(288, 352), 3 / 4);
    expect(crop.top, 0);
    expect(crop.height, 1);
    expect(crop.width, closeTo((3 / 4) / (288 / 352), 1e-9));
    expect(crop.left, closeTo((1 - crop.width) / 2, 1e-9));
    // Tall 9:16 frame in a 3:4 box: top/bottom are cropped.
    final tall = coverCrop(const Size(1080, 1920), 3 / 4);
    expect(tall.left, 0);
    expect(tall.height, closeTo((1080 / 1920) / (3 / 4), 1e-9));
  });

  for (final entry in _sizes.entries) {
    testWidgets('cover preview keeps camera aspect in a 3:4 oval '
        '(${entry.key})', (tester) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      const preview = Size(288, 352);
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: CameraCoverPreview(
                previewSize: preview,
                child: Container(
                  key: const Key('fake-camera'),
                  color: Colors.red,
                ),
              ),
            ),
          ),
        ),
      );
      final box = tester.getSize(find.byType(AspectRatio));
      final cam = tester.getSize(find.byKey(const Key('fake-camera')));
      // Same aspect as the stream (not stretched to 3:4)…
      expect(
        cam.width / cam.height,
        closeTo(preview.width / preview.height, 1e-6),
      );
      // …and it covers the oval box (no empty bands).
      final scale = (box.width / cam.width) > (box.height / cam.height)
          ? box.width / cam.width
          : box.height / cam.height;
      expect(cam.width * scale, greaterThanOrEqualTo(box.width - 0.01));
      expect(cam.height * scale, greaterThanOrEqualTo(box.height - 0.01));
    });
  }
}
