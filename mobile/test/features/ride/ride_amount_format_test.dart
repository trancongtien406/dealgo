import 'package:dealgo/features/ride/domain/entities/ride_models.dart';
import 'package:dealgo/features/ride/domain/entities/ride_money.dart';
import 'package:dealgo/features/ride/presentation/pages/ride_fare_page.dart';
import 'package:flutter_test/flutter_test.dart';

TextEditingValue _type(String text) => const RideAmountInputFormatter()
    .formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: text));

void main() {
  test('formatRideAmount groups thousands with dots, no currency', () {
    expect(formatRideAmount(85000), '85.000');
    expect(formatRideAmount(1250000), '1.250.000');
    expect(formatRideAmount(500), '500');
  });

  test('input formatter regroups while typing and stays parseable', () {
    expect(_type('85000').text, '85.000');
    expect(_type('85.0001').text, '850.001');
    expect(_type('').text, '');
    expect(parseRideFareInput(_type('123456').text), 123456);
    expect(_type('85000').selection.baseOffset, 6);
  });
}
