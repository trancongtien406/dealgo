import 'dart:typed_data';

import 'package:dealgo/features/onboarding/presentation/document_image_source.dart';
import 'package:dealgo/features/parcel/data/fake_parcel_client.dart';
import 'package:dealgo/features/parcel/domain/parcel_client.dart';
import 'package:dealgo/features/parcel/domain/parcel_models.dart';
import 'package:dealgo/features/parcel/presentation/widgets/parcel_trip_panel.dart';
import 'package:dealgo/features/ride/domain/entities/ride_models.dart';
import 'package:dealgo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

const _places = RidePlaces(
  pickup: RidePoint(lat: 10.77, lng: 106.70, label: 'A'),
  dropoff: RidePoint(lat: 10.80, lng: 106.66, label: 'B'),
);

Future<(FakeParcelClient, String)> _booked() async {
  final client = FakeParcelClient();
  const draft = ParcelDraft(
    places: _places,
    sizeClass: 'S',
    sender: ParcelContact(name: 'An', phone: '0901234567'),
    recipient: ParcelContact(name: 'Bình', phone: '0912345678'),
  );
  final ride = await client.create(
    accessToken: 't',
    idempotencyKey: 'idem-key-1',
    draft: draft,
    vehicleClassCode: 'MOTORBIKE',
    offeredFareVnd: 30000,
  );
  final r = ride.ride;
  client.seed(
    ParcelRide(
      ride: RideView(
        id: r.id,
        status: RideStatus.driverArrived,
        pickup: r.pickup,
        dropoff: r.dropoff,
        offeredFareVnd: r.offeredFareVnd,
        referenceFareVnd: r.referenceFareVnd,
        agreedFareVnd: r.offeredFareVnd,
        assignedDriverId: 'drv-1',
        selectedOfferId: null,
        expiresAt: r.expiresAt,
        offers: r.offers,
        vehicleClassCode: r.vehicleClassCode,
        serviceKind: 'PARCEL',
      ),
      parcel: ride.parcel,
    ),
  );
  return (client, r.id);
}

Widget _app(FakeParcelClient client, Widget child) => MultiRepositoryProvider(
  providers: [
    RepositoryProvider<ParcelClient>.value(value: client),
    RepositoryProvider<DocumentImageSource>.value(
      value: FakeDocumentImageSource(
        nextImage: PickedDocumentImage(
          bytes: Uint8List.fromList([1, 2, 3]),
          contentType: 'image/jpeg',
        ),
      ),
    ),
  ],
  child: MaterialApp(
    locale: const Locale('vi'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

void main() {
  testWidgets('customer sees recipient code, no driver actions', (
    tester,
  ) async {
    final (client, id) = await _booked();
    await tester.pumpWidget(
      _app(
        client,
        ParcelTripPanel(rideId: id, accessToken: () => 't', driver: false),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('parcel-panel')), findsOneWidget);
    expect(find.byKey(const Key('parcel-recipient-code')), findsOneWidget);
    expect(find.byKey(const Key('parcel-pickup')), findsNothing);
  });

  testWidgets('driver picks up with a photo, then delivers', (tester) async {
    final (client, id) = await _booked();
    var picked = 0;
    var finished = 0;
    await tester.pumpWidget(
      _app(
        client,
        ParcelTripPanel(
          rideId: id,
          accessToken: () => 't',
          driver: true,
          onPickedUp: () => picked++,
          onFinished: () => finished++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('parcel-pickup')));
    await tester.pumpAndSettle();
    expect(picked, 1);
    expect(client.calls, contains('pickup:$id'));

    await tester.enterText(
      find.byKey(const Key('parcel-recipient-code-input')),
      '4321',
    );
    await tester.ensureVisible(find.byKey(const Key('parcel-deliver')));
    await tester.tap(find.byKey(const Key('parcel-deliver')));
    await tester.pumpAndSettle();
    expect(finished, 1);
    expect(client.calls, contains('deliver:$id:4321'));
  });

  testWidgets('customer sees the service fee and the return-fee hint', (
    tester,
  ) async {
    final (client, id) = await _booked();
    await tester.pumpWidget(
      _app(
        client,
        ParcelTripPanel(rideId: id, accessToken: () => 't', driver: false),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('parcel-service-fee')), findsOneWidget);
    expect(find.byKey(const Key('parcel-return-fee-hint')), findsOneWidget);
    expect(find.byKey(const Key('parcel-return-fee')), findsNothing);
  });

  testWidgets('mock deliver refuses a wrong recipient code', (tester) async {
    final (client, id) = await _booked();
    var finished = 0;
    await tester.pumpWidget(
      _app(
        client,
        ParcelTripPanel(
          rideId: id,
          accessToken: () => 't',
          driver: true,
          onFinished: () => finished++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('parcel-pickup')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('parcel-recipient-code-input')),
      '0000',
    );
    await tester.ensureVisible(find.byKey(const Key('parcel-deliver')));
    await tester.tap(find.byKey(const Key('parcel-deliver')));
    await tester.pumpAndSettle();
    expect(finished, 0);
    expect(find.byKey(const Key('parcel-error')), findsOneWidget);
    final p = (await client.get(accessToken: 't', rideId: id)).parcel;
    expect(p.outcome, ParcelOutcome.pending);
  });

  test('return fee applies once the package is coming back', () async {
    final (client, id) = await _booked();
    await client.pickup(
      accessToken: 't',
      rideId: id,
      photo: ParcelPhoto(bytes: Uint8List.fromList([1])),
    );
    final failed = await client.fail(
      accessToken: 't',
      rideId: id,
      reason: ParcelFailReason.recipientUnreachable,
    );
    expect(failed.parcel.returnFeeApplies, isTrue);
    expect(failed.parcel.returnFeeVnd, 15000);
    expect(failed.parcel.serviceFeeVnd, 5000);
  });
}
