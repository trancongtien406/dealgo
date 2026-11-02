import 'package:dealgo/features/pricing/data/pricing_remote_datasource.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, Object?> quote([Map<String, Object?> extra = const {}]) => {
    'distanceKm': 5,
    'referenceFareVnd': 30000,
    'minFareVnd': 10000,
    'maxFareVnd': 90000,
    ...extra,
  };

  test('MOB-001: fare step comes from the server quote', () {
    expect(decodeRideQuote(quote({'fareStepVnd': 2000})).fareStepVnd, 2000);
    expect(
      decodeRideQuote(
        quote({
          'options': [
            {'fareStepVnd': 5000},
          ],
        }),
      ).fareStepVnd,
      5000,
    );
  });

  test('MOB-001: falls back to 1.000đ for older servers', () {
    expect(decodeRideQuote(quote()).fareStepVnd, 1000);
    expect(decodeRideQuote(quote({'fareStepVnd': 0})).fareStepVnd, 1000);
  });
}
