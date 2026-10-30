import 'package:dealgo/core/mock/fake_ride_client.dart';
import 'package:dealgo/core/mock/mock_seed.dart';
import 'package:dealgo/features/parcel/data/fake_parcel_client.dart';
import 'package:dealgo/features/parcel/domain/parcel_models.dart';
import 'package:dealgo/features/parcel/presentation/widgets/parcel_labels.dart';
import 'package:dealgo/features/ride/domain/entities/ride_models.dart';
import 'package:dealgo/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _places = RidePlaces(
  pickup: RidePoint(lat: 10.77, lng: 106.70, label: 'A'),
  dropoff: RidePoint(lat: 10.80, lng: 106.66, label: 'B'),
);

Future<String> _book(FakeParcelClient parcels) async {
  final created = await parcels.create(
    accessToken: 't',
    idempotencyKey: 'k',
    draft: const ParcelDraft(
      places: _places,
      sizeClass: 'M',
      sender: ParcelContact(name: 'An', phone: '0901234567'),
      recipient: ParcelContact(name: 'Bình', phone: '0912345678'),
    ),
    vehicleClassCode: 'MOTORBIKE',
    offeredFareVnd: 35000,
  );
  return created.ride.id;
}

void main() {
  test('mock ride client resolves parcel ids with demo offers', () async {
    final rides = createSeededMockClients().ride;
    final parcels = FakeParcelClient()..bridgeInto(rides);
    final id = await _book(parcels);
    final view = await rides.getRide(accessToken: 't', rideId: id);
    final ride = view.toEntity();
    expect(ride.id, id);
    expect(ride.isParcel, isTrue);
    expect(ride.pickup.label, 'A');
    expect(ride.offers, isNotEmpty);
    // Other ids still go to the seeded ride handler.
    expect(
      (await rides.getRide(
        accessToken: 't',
        rideId: 'ride-x',
      )).toEntity().isParcel,
      isFalse,
    );
  });

  test(
    'customer cancel of a waiting parcel goes through the ride cancel path',
    () async {
      final rides = FakeRideClient();
      final parcels = FakeParcelClient()..bridgeInto(rides);
      final id = await _book(parcels);
      final cancelled = (await rides.cancelRide(
        accessToken: 't',
        rideId: id,
      )).toEntity();
      expect(cancelled.status, RideStatus.cancelled);
      expect(
        (await parcels.get(accessToken: 't', rideId: id)).ride.status,
        RideStatus.cancelled,
      );
      expect(rides.cancelCalls, [id]);
    },
  );

  test('driver badge text shows size and weight', () {
    final l10n = lookupAppLocalizations(const Locale('vi'));
    expect(
      parcelBadgeText(l10n, 'M', 2.5),
      'Gói hàng · ${l10n.parcelSizeM} · 2.5 kg',
    );
    expect(parcelBadgeText(l10n, null, null), 'Gói hàng');
  });
}
