import 'package:dealgo/features/pricing/data/pricing_remote_datasource.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, Object?> base() => {
    'distanceKm': 152.4,
    'referenceFareVnd': 1500000,
    'minFareVnd': 20000,
    'maxFareVnd': 2000000000,
    'durationMin': 180,
  };

  test('t73u: intercity flag is decoded from the quote', () {
    expect(decodeRideQuote({...base(), 'intercity': true}).intercity, isTrue);
    expect(decodeRideQuote(base()).intercity, isFalse);
    final withOption = decodeRideQuote({
      ...base(),
      'intercity': true,
      'options': [
        {
          'code': 'CAR_4',
          'referenceFareVnd': 1,
          'minFareVnd': 1,
          'maxFareVnd': 2,
        },
      ],
    });
    expect(withOption.options.single.intercity, isTrue);
  });
}
