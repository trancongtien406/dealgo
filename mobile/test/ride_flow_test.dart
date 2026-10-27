import 'package:dealgo/core/network/api_exception.dart';
import 'package:dealgo/features/ride/data/models/ride_models.dart';
import 'package:dealgo/features/ride/domain/entities/ride_models.dart';
import 'package:dealgo/features/places/data/places_remote_datasource.dart';
import 'package:dealgo/features/places/domain/place.dart';
import 'package:dealgo/features/pricing/data/pricing_remote_datasource.dart';
import 'package:dealgo/core/design_system/components/dealgo_primary_button.dart';
import 'package:dealgo/features/ride/presentation/widgets/ride_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/auth_test_harness.dart';
import 'support/fake_identity_client.dart';
import 'support/fake_location.dart';
import 'support/fake_ride_client.dart';

const _offerId = '6f1b6c2a-1a2b-4c3d-8e9f-0123456789ab';
const _driverId = 'driver-hung';

void main() {
  test(
    'ride view reads the success envelope and omits a client agreed fare',
    () {
      final ride = RideViewModel.fromResponseBody({
        'success': true,
        'statusCode': 200,
        'message': 'OK',
        'data': {
          'id': 'ride-1',
          'status': 'NEGOTIATING',
          'pickup': {'lat': 16.0544, 'lng': 108.2022, 'label': 'Hải Châu'},
          'dropoff': {'lat': 16.0471, 'lng': 108.2062, 'label': 'Sân bay'},
          'offeredFareVnd': 42000,
          'referenceFareVnd': 40000,
          'agreedFareVnd': null,
          'assignedDriverId': null,
          'selectedOfferId': null,
          'expiresAt': '2030-01-01T00:00:00.000Z',
          'offers': [
            {
              'id': _offerId,
              'driverId': _driverId,
              'amountVnd': 45000,
              'kind': 'COUNTER',
              'status': 'PENDING',
              'expiresAt': '2030-01-01T00:00:00.000Z',
            },
          ],
        },
      }).toEntity();
      expect(ride.status, RideStatus.negotiating);
      expect(ride.offers.single.amountVnd, 45000);
      expect(ride.agreedFareVnd, isNull);

      final json = CreateRideBody(
        pickup: RidePointModel.fromEntity(ride.pickup),
        dropoff: RidePointModel.fromEntity(ride.dropoff),
        offeredFareVnd: 42000,
        vehicleClassCode: 'MOTORBIKE',
      ).toJson();
      expect(json['vehicleClassCode'], 'MOTORBIKE');
      expect(json['offeredFareVnd'], 42000);
      expect(json.containsKey('agreedFareVnd'), isFalse);
      expect(rideNegotiationExpired(ride, DateTime.utc(2029)), isFalse);
      expect(
        rideNegotiationExpired(
          RideView(
            id: ride.id,
            status: RideStatus.negotiating,
            pickup: ride.pickup,
            dropoff: ride.dropoff,
            offeredFareVnd: ride.offeredFareVnd,
            referenceFareVnd: ride.referenceFareVnd,
            agreedFareVnd: null,
            assignedDriverId: null,
            selectedOfferId: null,
            expiresAt: '2020-01-01T00:00:00.000Z',
            offers: ride.offers,
          ),
          DateTime.utc(2024),
        ),
        isTrue,
      );
    },
  );

  testWidgets('creating a ride sends offeredFareVnd and shows NEGOTIATING', (
    tester,
  ) async {
    final rides = _negotiatingClient();
    await _openFare(tester, rides);

    await tester.ensureVisible(find.byKey(const Key('ride-submit-fare')));
    await tester.tap(find.byKey(const Key('ride-submit-fare')));
    await tester.pumpAndSettle();

    expect(rides.createCalls, hasLength(1));
    final request = rides.createCalls.single;
    expect(request.offeredFareVnd, 42000);
    expect(
      CreateRideBody(
        pickup: RidePointModel.fromEntity(request.pickup),
        dropoff: RidePointModel.fromEntity(request.dropoff),
        offeredFareVnd: request.offeredFareVnd,
        vehicleClassCode: request.vehicleClassCode,
      ).toJson().containsKey('agreedFareVnd'),
      isFalse,
    );
    expect(request.vehicleClassCode, 'MOTORBIKE');
    // Pickup is the device GPS fix; drop-off is the chosen place's coordinates.
    expect(request.pickup.lat, testPickupLat);
    expect(request.pickup.lng, testPickupLng);
    expect(request.pickup.label, 'Vị trí hiện tại');
    expect(request.dropoff.lat, _airport.lat);
    expect(request.dropoff.lng, _airport.lng);
    expect(request.dropoff.label, _airport.label);
    expect(request.accessToken, 'access-token');
    expect(request.idempotencyKey.length, inInclusiveRange(8, 200));
    expect(rides.getCalls, isNotEmpty);
    expect(find.text('Đang thương lượng'), findsWidgets);
    expect(find.textContaining('Xe 4 chỗ'), findsNothing);
  });

  testWidgets('an empty offer list shows the empty state', (tester) async {
    await _openFare(tester, _negotiatingClient());
    await tester.ensureVisible(find.byKey(const Key('ride-submit-fare')));
    await tester.tap(find.byKey(const Key('ride-submit-fare')));
    await tester.pumpAndSettle();

    expect(find.text('Chưa có tài xế chào giá'), findsOneWidget);
    expect(
      find.text(
        'Trong khu vực này chưa có báo giá hợp lệ cho yêu cầu hiện tại.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('selecting an offer shows agreedFareVnd from the server', (
    tester,
  ) async {
    final offer = _offer(amountVnd: 42000);
    final rides = _negotiatingClient(offers: [offer]);
    rides.onSelect = (request) {
      return _view(
        status: RideStatus.assigned,
        offeredFareVnd: 42000,
        agreedFareVnd: 45000,
        selectedOfferId: request.offerId,
        assignedDriverId: _driverId,
        offers: [offer],
      );
    };
    await _openFare(tester, rides);
    await tester.ensureVisible(find.byKey(const Key('ride-submit-fare')));
    await tester.tap(find.byKey(const Key('ride-submit-fare')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('ride-select-offer')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ride-offer-confirm')));
    await tester.pumpAndSettle();

    expect(rides.selectCalls, hasLength(1));
    expect(rides.selectCalls.single.offerId, _offerId);
    expect(
      SelectRideOfferBody(offerId: rides.selectCalls.single.offerId)
          .toJson()
          .containsKey('agreedFareVnd'),
      isFalse,
    );
    expect(find.text('Giá chuyến vừa thay đổi'), findsOneWidget);
    expect(find.text('45.000đ'), findsWidgets);
    expect(find.text('42.000đ'), findsWidgets);
  });

  test(
    'DEC-PROD-024: the selection body carries the voucher only when set',
    () {
      expect(
        const SelectRideOfferBody(
          offerId: 'o',
          voucherCode: ' dealgo10 ',
        ).toJson(),
        {'offerId': 'o', 'voucherCode': 'DEALGO10'},
      );
      expect(const SelectRideOfferBody(offerId: 'o').toJson(), {
        'offerId': 'o',
      });
      expect(
        const SelectRideOfferBody(offerId: 'o', voucherCode: '  ').toJson(),
        {'offerId': 'o'},
      );
    },
  );

  test('DEC-PROD-024: the ride view decodes the discount and the cash due', () {
    final view = RideViewModel.fromJson({
      ...RideViewModel.fromEntity(
        _view(agreedFareVnd: 40000, status: RideStatus.assigned),
      ).toJson(),
      'discountVnd': 15000,
      'voucherCode': 'RIDE15K',
    }).toEntity();
    expect(view.discountVnd, 15000);
    expect(view.voucherCode, 'RIDE15K');
    expect(view.cashDueVnd, 25000);
    final legacy = RideViewModel.fromJson(
      RideViewModel.fromEntity(_view(agreedFareVnd: 40000)).toJson()
        ..remove('discountVnd')
        ..remove('voucherCode'),
    ).toEntity();
    expect(legacy.discountVnd, 0);
    expect(legacy.cashDueVnd, 40000);
    expect(_view().cashDueVnd, isNull);
  });

  testWidgets('a voucher quoted on the chosen offer goes with the selection', (
    tester,
  ) async {
    final offer = _offer(amountVnd: 42000);
    final rides = _negotiatingClient(offers: [offer]);
    rides.onSelect = (request) => _view(
      status: RideStatus.assigned,
      agreedFareVnd: 42000,
      selectedOfferId: request.offerId,
      assignedDriverId: _driverId,
      offers: [offer],
      discountVnd: 4200,
      voucherCode: request.voucherCode,
    );
    await _openFare(tester, rides);
    await tester.ensureVisible(find.byKey(const Key('ride-submit-fare')));
    await tester.tap(find.byKey(const Key('ride-submit-fare')));
    await tester.pumpAndSettle();

    final field = find.byKey(const Key('voucher-field'));
    await tester.ensureVisible(field);
    await tester.enterText(field, 'dealgo10');
    await tester.tap(find.byKey(const Key('voucher-apply')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('voucher-applied')), findsOneWidget);
    expect(find.text('Tiền mặt trả tài xế'), findsOneWidget);
    expect(find.text('37.800đ'), findsOneWidget);

    await tester.tap(find.byKey(const Key('ride-select-offer')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ride-offer-confirm')));
    await tester.pumpAndSettle();
    expect(rides.selectCalls.single.voucherCode, 'DEALGO10');
    final paid = tester.widget<RideMoneyLine>(
      find.byKey(const Key('ride-agreed-fare')),
    );
    expect(paid.amount, '37.800đ');
    expect(find.text('Ưu đãi DEALGO10'), findsOneWidget);
  });

  testWidgets('a voucher refused at selection is dropped and the offer stays', (
    tester,
  ) async {
    final offer = _offer(amountVnd: 42000);
    final rides = _negotiatingClient(offers: [offer])
      ..selectError = const ApiException(
        statusCode: 422,
        message: 'server text',
        errorCode: 'VOUCHER_USAGE_EXHAUSTED',
      );
    rides.onSelect = (request) => _view(
      status: RideStatus.assigned,
      agreedFareVnd: 42000,
      selectedOfferId: request.offerId,
      assignedDriverId: _driverId,
      offers: [offer],
    );
    await _openFare(tester, rides);
    await tester.ensureVisible(find.byKey(const Key('ride-submit-fare')));
    await tester.tap(find.byKey(const Key('ride-submit-fare')));
    await tester.pumpAndSettle();
    final field = find.byKey(const Key('voucher-field'));
    await tester.ensureVisible(field);
    await tester.enterText(field, 'DEALGO10');
    await tester.tap(find.byKey(const Key('voucher-apply')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('ride-select-offer')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ride-offer-confirm')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Bạn có thể chọn lại không kèm mã.'),
      findsOneWidget,
    );
    expect(find.textContaining('server text'), findsNothing);
    expect(find.byKey(const Key('voucher-applied')), findsNothing);

    rides.selectError = null;
    await tester.tap(find.byKey(const Key('ride-select-offer')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ride-offer-confirm')));
    await tester.pumpAndSettle();
    expect(rides.selectCalls, hasLength(2));
    expect(rides.selectCalls.first.voucherCode, 'DEALGO10');
    expect(rides.selectCalls.last.voucherCode, isNull);
    expect(
      rides.selectCalls.last.idempotencyKey,
      isNot(rides.selectCalls.first.idempotencyKey),
    );
  });

  testWidgets('a failed client does not show success', (tester) async {
    final rides = _negotiatingClient()
      ..createError = const ApiException(
        statusCode: 0,
        message: 'Không thể kết nối máy chủ',
        errorCode: 'NETWORK_ERROR',
      );
    await _openFare(tester, rides);

    await tester.ensureVisible(find.byKey(const Key('ride-submit-fare')));
    await tester.tap(find.byKey(const Key('ride-submit-fare')));
    await tester.pumpAndSettle();

    expect(find.text('Bạn đang ngoại tuyến'), findsOneWidget);
    expect(
      find.text('Chưa gửi được đề xuất. Chuyến xe chưa được tạo.'),
      findsOneWidget,
    );
    expect(find.text('NEGOTIATING'), findsNothing);
    expect(find.textContaining('thành công'), findsNothing);
    expect(find.text('Xác nhận chuyến xe'), findsNothing);
    expect(rides.createCalls, hasLength(1));
    expect(rides.getCalls, isEmpty);
  });

  testWidgets('the book tab opens the ride map', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpSignedIn(
      tester,
      profile: customerProfile,
      rideClient: _negotiatingClient(),
      locationOverride: FakeLocationService.denied(),
    );

    await tester.tap(navLabel('Đặt'));
    await tester.pumpAndSettle();

    // Destination-first: dropoff picker opens; dismiss to reach the map.
    expect(find.text('Bạn muốn đi đâu?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('header-back')));
    await tester.pumpAndSettle();
    // No GPS fix: pickup waits for a choice and nothing is faked.
    expect(find.text('Chọn điểm đón'), findsOneWidget);
    expect(find.text('Chọn điểm đến'), findsOneWidget);
    expect(find.textContaining('mẫu'), findsNothing);
  });

  testWidgets('the place picker searches and returns real coordinates', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final rides = _negotiatingClient();
    await pumpSignedIn(
      tester,
      profile: customerProfile,
      rideClient: rides,
      locationOverride: FakeLocationService(),
      places: FakePlacesRemoteDataSource(
        catalog: FakePlacesRemoteDataSource.sampleCatalog,
      ),
      pricing: FakePricingRemoteDataSource(fixedReferenceVnd: 42000),
    );
    await tester.tap(navLabel('Đặt'));
    await tester.pumpAndSettle();

    // Dropoff picker already open (destination-first).
    expect(find.text('Bạn muốn đi đâu?'), findsOneWidget);
    expect(find.text('Vị trí hiện tại của bạn'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('place-search-field')),
      'chợ hàn',
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Chợ Hàn'), findsOneWidget);
    await tester.tap(find.byKey(const Key('place-result-0')));
    await tester.pumpAndSettle();

    // Map sheet → CTA → class+fare (inDrive confirm step, no silent skip).
    expect(find.byKey(const Key('ride-open-route-overview')), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const Key('ride-open-route-overview')),
    );
    await tester.tap(find.byKey(const Key('ride-open-route-overview')));
    await tester.pumpAndSettle();
    expect(find.text('Đề xuất của bạn'), findsOneWidget);
    expect(find.byKey(const Key('ride-vehicle-bike')), findsOneWidget);
    expect(find.text('42.000đ'), findsWidgets);
  });

  testWidgets('denied location keeps pickup unset and explains why', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpSignedIn(
      tester,
      profile: customerProfile,
      rideClient: _negotiatingClient(),
      locationOverride: FakeLocationService.denied(),
    );
    await tester.tap(navLabel('Đặt'));
    await tester.pumpAndSettle();
    expect(find.text('Bạn muốn đi đâu?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('header-back')));
    await tester.pumpAndSettle();
    expect(find.text('Chọn điểm đón'), findsOneWidget);
    final overview = tester.widget<DealGoPrimaryButton>(
      find.byKey(const Key('ride-open-route-overview')),
    );
    expect(overview.enabled, isFalse);

    await tester.tap(find.byKey(const Key('ride-pickup-label')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('place-current-location')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('place-location-error')), findsOneWidget);
  });
}

FakeRideClient _negotiatingClient({List<RideOffer> offers = const []}) {
  final client = FakeRideClient();
  client.onCreate = (request) {
    final ride = _view(
      offeredFareVnd: request.offeredFareVnd,
      pickup: request.pickup,
      dropoff: request.dropoff,
      offers: offers,
    );
    client.onGet = (_) => ride;
    return ride;
  };
  return client;
}

RideView _view({
  RideStatus status = RideStatus.negotiating,
  int offeredFareVnd = 42000,
  int? agreedFareVnd,
  String? selectedOfferId,
  String? assignedDriverId,
  RidePoint? pickup,
  RidePoint? dropoff,
  List<RideOffer> offers = const [],
  String expiresAt = '2030-01-01T00:00:00.000Z',
  int discountVnd = 0,
  String? voucherCode,
}) {
  return RideView(
    discountVnd: discountVnd,
    voucherCode: voucherCode,
    id: 'ride-1',
    status: status,
    pickup:
        pickup ??
        const RidePoint(
          lat: testPickupLat,
          lng: testPickupLng,
          label: 'Vị trí hiện tại',
        ),
    dropoff:
        dropoff ??
        RidePoint(lat: _airport.lat, lng: _airport.lng, label: _airport.label),
    offeredFareVnd: offeredFareVnd,
    referenceFareVnd: 40000,
    agreedFareVnd: agreedFareVnd,
    assignedDriverId: assignedDriverId,
    selectedOfferId: selectedOfferId,
    expiresAt: expiresAt,
    offers: offers,
  );
}

RideOffer _offer({required int amountVnd}) {
  return RideOffer(
    id: _offerId,
    driverId: _driverId,
    amountVnd: amountVnd,
    kind: RideOfferKind.accept,
    status: RideOfferStatus.pending,
    expiresAt: '2030-01-01T00:00:00.000Z',
  );
}

const _airport = PlaceOption(
  name: 'Sân bay Quốc tế Đà Nẵng',
  address: 'Nguyễn Văn Linh, Hải Châu, Đà Nẵng',
  lat: 16.0439,
  lng: 108.1994,
  source: PlaceSource.recent,
);

Future<void> _openFare(WidgetTester tester, FakeRideClient rides) async {
  await tester.binding.setSurfaceSize(const Size(400, 1800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await pumpSignedIn(
    tester,
    profile: customerProfile,
    rideClient: rides,
    locationOverride: FakeLocationService(),
    places: FakePlacesRemoteDataSource(recent: [_airport]),
    pricing: FakePricingRemoteDataSource(fixedReferenceVnd: 42000),
  );

  await tester.tap(navLabel('Đặt'));
  await tester.pumpAndSettle();
  // Destination-first: dropoff place picker opens on book-tab entry.
  expect(find.text('Bạn muốn đi đâu?'), findsOneWidget);
  await tester.tap(find.text(_airport.name));
  await tester.pumpAndSettle();
  // Map sheet with A/B — tap CTA to class+fare (no silent auto-advance).
  expect(find.text('Chọn xe & đề xuất giá'), findsOneWidget);
  await tester.ensureVisible(find.byKey(const Key('ride-open-route-overview')));
  await tester.tap(find.byKey(const Key('ride-open-route-overview')));
  await tester.pumpAndSettle();
  // Sheet may start partially collapsed — drag up / ensureVisible.
  final fareSheet = find.text('Đề xuất của bạn');
  expect(fareSheet, findsOneWidget);
  await tester.ensureVisible(fareSheet);
  await tester.pumpAndSettle();
  expect(find.text('42.000đ'), findsWidgets);
  expect(find.byKey(const Key('ride-vehicle-bike')), findsOneWidget);
  expect(find.byKey(const Key('ride-vehicle-CAR_4')), findsOneWidget);
  expect(find.byKey(const Key('ride-vehicle-CAR_7')), findsOneWidget);
  expect(find.byKey(const Key('ride-fare-plus')), findsOneWidget);
  expect(find.byKey(const Key('ride-submit-fare')), findsOneWidget);
  await tester.tap(find.byKey(const Key('ride-vehicle-bike')));
  await tester.pump();
  expect(find.text('Xe máy'), findsWidgets);
  expect(find.textContaining('Toyota'), findsNothing);
}
