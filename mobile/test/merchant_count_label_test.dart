import 'package:dealgo/features/merchant/presentation/widgets/merchant_widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('counters are not zero-padded', () {
    expect(merchantCountLabel(0), '0');
    expect(merchantCountLabel(7), '7');
    expect(merchantCountLabel(42), '42');
    expect(merchantCountLabel(1200), '999+');
    expect(merchantCountLabel(-1), '0');
  });
}
