import 'package:dealgo/features/pricing/data/pricing_remote_datasource.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('offline ride quotes are whole thousands, like the server', () async {
    final pricing = FakePricingRemoteDataSource();
    // Hải Châu → Mỹ Khê: an odd raw distance fare (~58.036đ for the bike).
    final quote = await pricing.quoteRide(
      accessToken: 'token',
      pickup: (lat: 16.0544, lng: 108.2022, label: 'Hải Châu'),
      dropoff: (lat: 16.0618, lng: 108.2468, label: 'Mỹ Khê'),
    );
    expect(quote.referenceFareVnd % 1000, 0);
    for (final option in quote.options) {
      expect(
        option.referenceFareVnd % 1000,
        0,
        reason: option.vehicleClassCode,
      );
    }
  });
}
