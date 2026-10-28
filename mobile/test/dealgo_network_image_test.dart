import 'package:dealgo/core/design_system/components/dealgo_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DealGoNetworkImage.decodeWidth', () {
    test('wide cover decodes at its own width', () {
      expect(DealGoNetworkImage.decodeWidth(390, 195, 3), 1170);
    });

    test('square thumb decodes wide enough for a 2:1 photo', () {
      expect(DealGoNetworkImage.decodeWidth(56, 56, 3), 336);
    });

    test('caps huge boxes', () {
      expect(
        DealGoNetworkImage.decodeWidth(2000, null, 3),
        DealGoNetworkImage.maxDecodeWidth,
      );
    });
  });

  testWidgets('uses cover fit and a decode width', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(
            width: 100,
            height: 100,
            child: DealGoNetworkImage('https://example.invalid/a.jpg'),
          ),
        ),
      ),
    );
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.fit, BoxFit.cover);
    expect(image.image, isA<ResizeImage>());
  });
}
