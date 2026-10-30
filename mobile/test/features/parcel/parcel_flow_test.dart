import 'dart:typed_data';

import 'package:dealgo/features/parcel/data/fake_parcel_client.dart';
import 'package:dealgo/features/parcel/data/parcel_json.dart';
import 'package:dealgo/features/parcel/domain/parcel_models.dart';
import 'package:dealgo/features/parcel/presentation/cubit/parcel_booking_cubit.dart';
import 'package:dealgo/features/parcel/presentation/cubit/parcel_trip_cubit.dart';
import 'package:dealgo/features/presence/domain/entities/driver_service_prefs.dart';
import 'package:dealgo/features/ride/domain/entities/ride_models.dart';
import 'package:flutter_test/flutter_test.dart';

const _places = RidePlaces(
  pickup: RidePoint(lat: 10.77, lng: 106.70, label: 'A'),
  dropoff: RidePoint(lat: 10.80, lng: 106.66, label: 'B'),
);

ParcelDraft _draft({String size = 'S', double? weight}) => ParcelDraft(
  places: _places,
  sizeClass: size,
  weightKg: weight,
  sender: const ParcelContact(name: 'An', phone: '0901234567'),
  recipient: const ParcelContact(name: 'Bình', phone: '0912345678'),
);

final _photo = ParcelPhoto(
  bytes: Uint8List.fromList([1, 2, 3]),
  contentType: 'image/jpeg',
);

void main() {
  group('parcel helpers', () {
    test('phone validation', () {
      expect(isValidParcelPhone('0901 234 567'), isTrue);
      expect(isValidParcelPhone('+84901234567'), isTrue);
      expect(isValidParcelPhone('12345'), isFalse);
    });

    test('weight over size limit', () {
      final s = FakeParcelClient.sizes.first;
      expect(parcelWeightOverLimit(s, 2), isNull);
      expect(parcelWeightOverLimit(s, null), isNull);
      expect(parcelWeightOverLimit(s, 4), s.maxWeightKg);
    });
  });

  group('parcel json', () {
    test('size classes parse and skip rows without code', () {
      final sizes = parseParcelSizeClasses({
        'data': [
          {
            'code': 'M',
            'label': 'Vừa',
            'maxWeightKg': 10,
            'maxDimsCm': [50, 40, 30],
            'surchargeVnd': 5000,
            'vehicleClassCodes': ['MOTORBIKE'],
          },
          {'label': 'broken'},
        ],
      });
      expect(sizes, hasLength(1));
      expect(sizes.single.maxDimsCm, [50, 40, 30]);
      expect(sizes.single.vehicleClassCodes, ['MOTORBIKE']);
    });

    test('create body carries contacts, payer and photo', () {
      final body = parcelCreateBody(
        ParcelDraft(
          places: _places,
          sizeClass: 'S',
          payer: ParcelPayer.recipient,
          itemPhoto: _photo,
          sender: const ParcelContact(name: 'An', phone: '0901234567'),
          recipient: const ParcelContact(name: 'Bình', phone: '0912345678'),
        ),
        vehicleClassCode: 'MOTORBIKE',
        offeredFareVnd: 30000,
      );
      expect(body['vehicleClassCode'], 'MOTORBIKE');
      expect(body.toString(), contains('RECIPIENT'));
      expect(body.toString(), contains('contentBase64'));
    });
  });

  test('presence prefs: missing parcelEnabled decodes false', () {
    expect(
      decodeDriverServicePrefs(<String, Object?>{}).parcelEnabled,
      isFalse,
    );
    expect(
      decodeDriverServicePrefs({'parcelEnabled': true}).parcelEnabled,
      isTrue,
    );
  });

  group('ParcelBookingCubit', () {
    test('load → quote → submit, idempotency key reused on retry', () async {
      final client = FakeParcelClient();
      var keys = 0;
      final cubit = ParcelBookingCubit(
        client: client,
        accessToken: () => 'tok',
        idempotencyKey: () => 'key-${++keys}-padding',
      );
      await cubit.load();
      expect(cubit.state.sizes, hasLength(4));
      expect(cubit.state.sizeCode, 'S');

      await cubit.quote(_draft());
      expect(cubit.state.quote, isNotNull);
      final option = cubit.state.option!;
      expect(cubit.state.fareVnd, option.referenceFareVnd);

      cubit.setFare(option.maxBidVnd + 999999);
      expect(cubit.state.fareVnd, option.maxBidVnd);

      final ride = await cubit.submit(_draft());
      expect(ride, isNotNull);
      expect(ride!.ride.isParcel, isTrue);
      expect(client.calls.where((c) => c.startsWith('create')), hasLength(1));
      expect(keys, 1);

      cubit.invalidateQuote();
      expect(cubit.state.quote, isNull);
      await cubit.close();
    });

    test('no token: nothing is loaded', () async {
      final cubit = ParcelBookingCubit(
        client: FakeParcelClient(),
        accessToken: () => null,
      );
      await cubit.load();
      expect(cubit.state.sizes, isEmpty);
      await cubit.close();
    });
  });

  group('ParcelTripCubit', () {
    Future<(FakeParcelClient, String)> booked() async {
      final client = FakeParcelClient();
      final quote = await client.quote(accessToken: 't', draft: _draft());
      final ride = await client.create(
        accessToken: 't',
        idempotencyKey: 'idem-key-1',
        draft: _draft(),
        vehicleClassCode: quote.options.first.code,
        offeredFareVnd: quote.options.first.referenceFareVnd,
      );
      return (client, ride.ride.id);
    }

    test('pickup then deliver completes the ride', () async {
      final (client, id) = await booked();
      final cubit = ParcelTripCubit(
        client: client,
        accessToken: () => 't',
        rideId: id,
      );
      expect(await cubit.load(), isTrue);
      expect(await cubit.pickup(_photo), isTrue);
      expect(cubit.state.parcel!.ride.status, RideStatus.inTrip);
      expect(await cubit.deliver(_photo, recipientCode: '4321'), isTrue);
      expect(cubit.state.parcel!.parcel.outcome, ParcelOutcome.delivered);
      expect(cubit.state.parcel!.ride.status, RideStatus.completed);
      await cubit.close();
    });

    test('fail then returned', () async {
      final (client, id) = await booked();
      final cubit = ParcelTripCubit(
        client: client,
        accessToken: () => 't',
        rideId: id,
      );
      await cubit.pickup(_photo);
      expect(await cubit.fail(ParcelFailReason.values.first), isTrue);
      expect(cubit.state.parcel!.parcel.outcome, ParcelOutcome.returning);
      expect(await cubit.returned(_photo), isTrue);
      expect(cubit.state.parcel!.parcel.outcome, ParcelOutcome.returned);
      await cubit.close();
    });

    test('unknown ride surfaces an error code', () async {
      final cubit = ParcelTripCubit(
        client: FakeParcelClient(),
        accessToken: () => 't',
        rideId: 'nope',
      );
      expect(await cubit.load(), isFalse);
      expect(cubit.state.errorCode, isNotNull);
      await cubit.close();
    });
  });
}
