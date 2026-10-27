import 'package:dealgo/core/design_system/components/handover_ref_badge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('handoverRef shows the last 4 alphanumerics uppercased (OPEN-011)', () {
    expect(handoverRef('order-ab12cd'), '#12CD');
    expect(handoverRef('a-b-c-d-e'), '#BCDE');
  });
}
