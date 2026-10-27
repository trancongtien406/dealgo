import 'package:dealgo/core/design_system/components/handover_ref_badge.dart';
import 'package:dealgo/core/format/short_ref.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('order code is the same last-4 code on every screen (OPEN-011)', () {
    const id = '7b1e2f0a-9c3d-4e5f-8a6b-1234c45d81';
    expect(shortRef(id), '#5D81');
    expect(shortRef(id), handoverRef(id));
    expect(shortRef(''), '#—');
  });
}
