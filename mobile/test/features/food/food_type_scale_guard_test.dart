import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('food presentation has no ad-hoc font sizes', () {
    final root = Directory('lib/features/food/presentation');
    expect(root.existsSync(), isTrue, reason: 'run from mobile/');

    final offenders = <String>[];
    for (final entity in root.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].contains('copyWith(fontSize:')) {
          offenders.add('${entity.path}:${i + 1}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Use DealGoType instead of copyWith(fontSize:):\n'
          '${offenders.join('\n')}',
    );
  });
}
