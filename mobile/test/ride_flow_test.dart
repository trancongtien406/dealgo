import 'package:dealgo/core/network/api_exception.dart';
import 'package:dealgo/features/ride/data/models/ride_models.dart';
import 'package:dealgo/features/ride/domain/entities/ride_models.dart';
import 'package:dealgo/features/ride/domain/entities/ride_money.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/auth_test_harness.dart';
import 'support/fake_identity_client.dart';
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
      ).toJson();
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
      ).toJson().containsKey('agreedFareVnd'),
      isFalse,
    );
    expect(request.pickup.lat, rideSamplePickupLat);
    expect(request.pickup.lng, rideSamplePickupLng);
    expect(request.pickup.label, rideSamplePickupLabel);
    expect(request.dropoff.lat, rideSampleDropoffLat);
    expect(request.dropoff.lng, rideSampleDropoffLng);
    expect(request.dropoff.label, rideSampleDropoffLabel);
    expect(request.accessToken, 'access-token');
    expect(request.idempotencyKey.length, inInclusiveRange(8, 200));
    expect(rides.getCalls, isNotEmpty);
    expect(find.text('NEGOTIATING'), findsWidgets);
    expect(find.textContaining('Xe 4 chỗ'), findsNothing);
  });

  testWidgets('an empty offer list shows the empty state', (tester) async {
    await _openFare(tester, _negotiatingClient());
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
    await tester.tap(find.byKey(const Key('ride-submit-fare')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('ride-select-offer')));
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

  testWidgets('a failed client does not show success', (tester) async {
    final rides = _negotiatingClient()
      ..createError = const ApiException(
        statusCode: 0,
        message: 'Không thể kết nối máy chủ',
        errorCode: 'NETWORK_ERROR',
      );
    await _openFare(tester, rides);

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
    );

    await tester.tap(navLabel('Đặt'));
    await tester.pumpAndSettle();

    expect(find.text('Bản đồ đặt xe'), findsOneWidget);
    expect(find.text('Đang tải bản đồ...'), findsOneWidget);
    expect(find.text('Nhập địa chỉ thủ công'), findsOneWidget);
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
}) {
  return RideView(
    id: 'ride-1',
    status: status,
    pickup:
        pickup ??
        const RidePoint(
          lat: rideSamplePickupLat,
          lng: rideSamplePickupLng,
          label: rideSamplePickupLabel,
        ),
    dropoff:
        dropoff ??
        const RidePoint(
          lat: rideSampleDropoffLat,
          lng: rideSampleDropoffLng,
          label: rideSampleDropoffLabel,
        ),
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

Future<void> _openFare(WidgetTester tester, FakeRideClient rides) async {
  await tester.binding.setSurfaceSize(const Size(400, 1800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await pumpSignedIn(tester, profile: customerProfile, rideClient: rides);

  await tester.tap(find.text('Đặt xe').hitTestable().first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Nhập địa chỉ thủ công'));
  await tester.pumpAndSettle();

  await tester.ensureVisible(find.byKey(const Key('ride-suggestion-airport')));
  await tester.tap(find.byKey(const Key('ride-suggestion-airport')));
  await tester.pump();

  final overview = find.byKey(const Key('ride-open-route-overview'));
  await tester.ensureVisible(overview);
  await tester.tap(overview);
  await tester.pumpAndSettle();
  expect(find.textContaining('hành trình'), findsWidgets);
  final vehicle = find.byKey(const Key('ride-open-vehicle'));
  await tester.ensureVisible(vehicle);
  await tester.tap(vehicle);
  await tester.pumpAndSettle();
  expect(find.text('Chọn loại xe'), findsOneWidget);
  await tester.tap(find.byKey(const Key('ride-confirm-vehicle')));
  await tester.pumpAndSettle();
  expect(find.text('Chi tiết giá cước'), findsOneWidget);
  await tester.tap(find.byKey(const Key('ride-open-fare-bid')));
  await tester.pumpAndSettle();
  expect(find.text('Tự đề xuất giá chuyến'), findsOneWidget);
  expect(find.text(rideFareRangeLabel()), findsOneWidget);
  expect(find.text('Xe 4 chỗ'), findsOneWidget);
}
