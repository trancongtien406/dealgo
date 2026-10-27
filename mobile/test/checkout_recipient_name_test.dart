import 'package:dealgo/features/food/presentation/widgets/food_checkout_widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('checkout shows the recipient name before the phone', () {
    final line = checkoutRecipientLine(
      displayName: 'Trần Minh Anh',
      phone: '+84909990101',
      fallback: 'Người nhận',
    );
    expect(line, startsWith('Trần Minh Anh · '));
    expect(line, endsWith('909 990 101'));
  });

  test('falls back to phone, then label', () {
    expect(
      checkoutRecipientLine(
        displayName: ' ',
        phone: null,
        fallback: 'Người nhận',
      ),
      'Người nhận',
    );
    expect(
      checkoutRecipientLine(displayName: 'An', phone: null, fallback: 'x'),
      'An',
    );
  });
}
