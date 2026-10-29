import 'package:dealgo/features/places/presentation/map_pin_picker_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('secondary line drops the số nhà + đường already on the first line', () {
    expect(
      pinAddressSecondary(
        '34 Đường Mỹ Đa Đông 7',
        '34 Đường Mỹ Đa Đông 7, Mỹ An, Ngũ Hành Sơn, Đà Nẵng',
      ),
      'Mỹ An, Ngũ Hành Sơn, Đà Nẵng',
    );
  });

  test('keeps the full address when it does not start with the name', () {
    expect(
      pinAddressSecondary('Chợ Hàn', '119 Trần Phú, Hải Châu'),
      '119 Trần Phú, Hải Châu',
    );
    expect(pinAddressSecondary('X', ''), '');
    expect(pinAddressSecondary('Đà Nẵng', 'Đà Nẵng'), 'Đà Nẵng');
  });
}
