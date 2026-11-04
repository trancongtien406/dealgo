import 'package:dealgo/core/format/text_case.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('capitalizes the first letter and keeps the rest', () {
    expect(capitalizeFirstLetter('món chính'), 'Món chính');
    expect(capitalizeFirstLetter('đồ uống'), 'Đồ uống');
    expect(capitalizeFirstLetter('Cơm'), 'Cơm');
    expect(capitalizeFirstLetter('BÚN BÒ'), 'BÚN BÒ');
  });

  test('keeps leading/trailing whitespace out of the label', () {
    expect(capitalizeFirstLetter('  tráng miệng  '), 'Tráng miệng');
  });

  test('leaves empty labels empty', () {
    expect(capitalizeFirstLetter(''), '');
    expect(capitalizeFirstLetter('   '), '');
  });
}
