// PNG evidence for widget tests. Writes nothing unless run with
//   --dart-define=SHOT_DIR=/abs/output/dir
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart' show RepaintBoundary;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const visualShotDir = String.fromEnvironment('SHOT_DIR');

/// Real app fonts (Be Vietnam Pro + Lucide icons) so shots are readable.
Future<void> loadShotFonts(WidgetTester tester) async {
  if (visualShotDir.isEmpty) return;
  await tester.runAsync(() async {
    final be = FontLoader('BeVietnamPro');
    for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
      final bytes = File('assets/fonts/BeVietnamPro-$w.ttf').readAsBytesSync();
      be.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await be.load();
    final lucide = FontLoader('packages/lucide_icons_flutter/Lucide')
      ..addFont(
        rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf'),
      );
    await lucide.load();
  });
}

/// Saves the first [RepaintBoundary] above [finder] (default: the whole app)
/// as `<SHOT_DIR>/<name>.png`.
Future<void> saveShot(
  WidgetTester tester,
  String name, {
  Finder? finder,
}) async {
  if (visualShotDir.isEmpty) return;
  final target = finder ?? find.byType(RepaintBoundary).first;
  final boundary = tester.renderObject<RenderObject>(target);
  final repaint = boundary is RenderRepaintBoundary
      ? boundary
      : _ancestorBoundary(boundary);
  final bytes = await tester.runAsync(() async {
    final image = await repaint.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  });
  File('$visualShotDir/$name.png')
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!);
}

RenderRepaintBoundary _ancestorBoundary(RenderObject node) {
  RenderObject? current = node;
  while (current != null && current is! RenderRepaintBoundary) {
    current = current.parent;
  }
  return current! as RenderRepaintBoundary;
}
