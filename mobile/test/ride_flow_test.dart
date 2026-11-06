import 'package:dealgo/core/network/api_exception.dart';
import 'package:dealgo/features/ride/data/models/ride_models.dart';
import 'package:dealgo/features/ride/domain/entities/ride_models.dart';
import 'package:dealgo/features/places/data/places_remote_datasource.dart';
import 'package:dealgo/features/places/domain/place.dart';
import 'package:dealgo/features/pricing/data/pricing_remote_datasource.dart';
import 'package:dealgo/core/design_system/components/dealgo_primary_button.dart';
import 'package:dealgo/core/design_system/icons/dealgo_icons.dart';
import 'package:dealgo/core/design_system/components/dealgo_tab_bar.dart';
import 'package:dealgo/features/ride/presentation/widgets/ride_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:dealgo/features/ride/presentation/cubit/ride_session.dart';
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

  testWidgets('fare sheet keeps the offer input and CTA on a phone screen', (
    tester,
  ) async {
    final rides = _negotiatingClient();
    await _openFare(tester, rides);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpAndSettle();

    final bar = find.byKey(const Key('ride-quote-bar'));
    expect(bar, findsOneWidget);
    expect(tester.getRect(bar).bottom, lessThanOrEqualTo(844));
    expect(find.byKey(const Key('ride-fare-plus')), findsOneWidget);
    expect(find.byKey(const Key('ride-submit-fare')), findsOneWidget);

    await tester.tap(find.byKey(const Key('ride-submit-fare')));
    await tester.pumpAndSettle();
    expect(rides.createCalls, hasLength(1));
  });

  testWidgets('a still-open request reopens it instead of a dead end', (
    tester,
  ) async {
    final rides = FakeRideClient();
    final open = _view();
    rides.onGet = (_) => open;
    rides.onCreate = (_) => throw const ApiException(
      statusCode: 409,
      message: 'A negotiating ride is already open',
      errorCode: 'RIDE_ALREADY_OPEN',
    );
    await _openFare(tester, rides);
    tester
        .element(find.byKey(const Key('ride-submit-fare')))
        .read<RideSessionCubit>()
        .remember('ride-1');

    await tester.ensureVisible(find.byKey(const Key('ride-submit-fare')));
    await tester.tap(find.byKey(const Key('ride-submit-fare')));
    await tester.pumpAndSettle();

    expect(rides.createCalls, hasLength(1));
    expect(rides.getCalls, isNotEmpty);
    expect(find.text('Đang thương lượng'), findsWidgets);
  });

  testWidgets('an empty offer list shows the empty state', (tester) async {
    await _openFare(tester, _negotiatingClient());
    await tester.ensureVisible(find.byKey(const Key('ride-submit-fare')));
    await tester.tap(find.byKey(const Key('ride-submit-fare')));
    await tester.pumpAndSettle();

    expect(find.text('Chưa có báo giá'), findsOneWidget);
    expect(find.text('Chưa có tài xế báo giá.'), findsOneWidget);
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
    // The full list (vouchers, details) stays one tap away.
    await tester.ensureVisible(
      find.byKey(const Key('ride-open-offers-from-wait')),
    );
    await tester.tap(find.byKey(const Key('ride-open-offers-from-wait')));
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
    expect(find.text('Giá đã thay đổi'), findsOneWidget);
    expect(find.text('45.000đ'), findsWidgets);
    expect(find.text('42.000đ'), findsWidgets);
  });

  testWidgets('quotes are answered inline on the waiting sheet', (
    tester,
  ) async {
    final offer = _offer(amountVnd: 45000);
    final rides = _negotiatingClient(offers: [offer]);
    rides.onSelect = (request) => _view(
      status: RideStatus.assigned,
      agreedFareVnd: 45000,
      selectedOfferId: request.offerId,
      assignedDriverId: _driverId,
      offers: [offer],
    );
    await _openFare(tester, rides);
    await tester.ensureVisible(find.byKey(const Key('ride-submit-fare')));
    await tester.tap(find.byKey(const Key('ride-submit-fare')));
    await tester.pumpAndSettle();

    final accept = find.byKey(const Key('ride-inline-accept-$_offerId'));
    expect(accept, findsOneWidget);
    expect(find.text('Chấp nhận'), findsOneWidget);
    expect(find.byKey(const Key('ride-inline-raise-10')), findsOneWidget);
    await tester.ensureVisible(accept);
    await tester.pumpAndSettle();
    await tester.tap(accept);
    await tester.pumpAndSettle();
    expect(rides.selectCalls.single.offerId, _offerId);
  });

  testWidgets('waiting for offers opens the sheet near full height', (
    tester,
  ) async {
    final rides = _negotiatingClient(offers: [_offer(amountVnd: 45000)]);
    await _openFare(tester, rides);
    await tester.ensureVisible(find.byKey(const Key('ride-submit-fare')));
    await tester.tap(find.byKey(const Key('ride-submit-fare')));
    await tester.pumpAndSettle();

    final sheet = tester.widget<DraggableScrollableSheet>(
      find.descendant(
        of: find.byKey(const Key('ride-matching-sheet')),
        matching: find.byType(DraggableScrollableSheet),
      ),
    );
    final screen = tester.getSize(find.byType(MaterialApp).first).height;
    final top = tester
        .getTopLeft(find.byKey(const Key('ride-matching-sheet')).last)
        .dy;
    final sheetBox = tester.getRect(
      find
          .descendant(
            of: find.byKey(const Key('ride-matching-sheet')),
            matching: find.byType(RideBottomSheet),
          )
          .first,
    );
    expect(top, 0); // the sheet's layout fills the page...
    // ...and its visible card is expanded to the max size (not 0.46).
    expect(sheetBox.height / screen, closeTo(sheet.maxChildSize, 0.02));
    expect(sheet.maxChildSize, greaterThan(0.7));
    expect(
      find.byKey(const Key('ride-inline-accept-$_offerId')).hitTestable(),
      findsOneWidget,
    );
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
      discountVnd: 4000,
      voucherCode: request.voucherCode,
    );
    await _openFare(tester, rides);
    await tester.ensureVisible(find.byKey(const Key('ride-submit-fare')));
    await tester.tap(find.byKey(const Key('ride-submit-fare')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('ride-open-offers-from-wait')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ride-open-offers-from-wait')));
    await tester.pumpAndSettle();

    final field = find.byKey(const Key('voucher-field'));
    await tester.ensureVisible(field);
    await tester.enterText(field, 'dealgo10');
    await tester.tap(find.byKey(const Key('voucher-apply')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('voucher-applied')), findsOneWidget);
    expect(find.text('Tiền mặt trả tài xế'), findsOneWidget);
    expect(find.text('38.000đ'), findsOneWidget);

    await tester.tap(find.byKey(const Key('ride-select-offer')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ride-offer-confirm')));
    await tester.pumpAndSettle();
    expect(rides.selectCalls.single.voucherCode, 'DEALGO10');
    final paid = tester.widget<RideMoneyLine>(
      find.byKey(const Key('ride-agreed-fare')),
    );
    expect(paid.amount, '38.000đ');
    expect(find.text('Ưu đãi DEALGO10'), findsOneWidget);
  });

  testWidgets('a driver assigned elsewhere shows the taken state (RIDE-003)', (
    tester,
  ) async {
    final offer = _offer(amountVnd: 42000);
    final rides = _negotiatingClient(offers: [offer])
      ..selectError = const ApiException(
        statusCode: 409,
        message: 'server text',
        errorCode: 'RIDE_OFFER_DRIVER_UNAVAILABLE',
      );
    await _openFare(tester, rides);
    await tester.ensureVisible(find.byKey(const Key('ride-submit-fare')));
    await tester.tap(find.byKey(const Key('ride-submit-fare')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('ride-open-offers-from-wait')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ride-open-offers-from-wait')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ride-select-offer')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ride-offer-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('Tài xế đã bận'), findsOneWidget);
    expect(find.textContaining('server text'), findsNothing);
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
    await tester.ensureVisible(
      find.byKey(const Key('ride-open-offers-from-wait')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ride-open-offers-from-wait')));
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

  group('book tab draft', () {
    Finder dropoffField() => find.byKey(const Key('ride-dropoff-label'));
    Finder inDropoff(String text) =>
        find.descendant(of: dropoffField(), matching: find.text(text));

    testWidgets(
      'a created ride clears the draft; the waiting ride stays one tap away',
      (tester) async {
        await _openFare(tester, _negotiatingClient());
        await tester.ensureVisible(find.byKey(const Key('ride-submit-fare')));
        await tester.tap(find.byKey(const Key('ride-submit-fare')));
        await tester.pumpAndSettle();
        expect(find.text('Đang thương lượng'), findsWidgets);

        GoRouter.of(tester.element(find.byType(Scaffold).first))
            .go('/customer/book');
        await tester.pumpAndSettle();
        expect(inDropoff('Chọn điểm đến'), findsOneWidget);
        expect(inDropoff(_airport.label), findsNothing);
        // Recent places are offered, never pre-filled.
        expect(
          find.descendant(
            of: find.byKey(const Key('ride-suggestion-0')),
            matching: find.text(_airport.name),
          ),
          findsOneWidget,
        );
        expect(find.byKey(const Key('ride-open-pending')), findsOneWidget);

        // Cancelled / finished: nothing to resume, the tab stays empty.
        tester.element(dropoffField()).read<RideSessionCubit>().clear();
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('ride-open-pending')), findsNothing);
        expect(inDropoff('Chọn điểm đến'), findsOneWidget);

        // A suggestion is only used when tapped.
        await tester.tap(find.byKey(const Key('ride-suggestion-0')));
        await tester.pumpAndSettle();
        // Prices open on their own; back shows the kept destination.
        await tester.tap(find.byKey(const Key('ride-fare-back')));
        await tester.pumpAndSettle();
        expect(inDropoff(_airport.label), findsOneWidget);
      },
    );

    testWidgets('backing out of the book tab drops the draft', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpSignedIn(
        tester,
        profile: customerProfile,
        rideClient: _negotiatingClient(),
        locationOverride: FakeLocationService(),
        places: FakePlacesRemoteDataSource(recent: [_airport]),
      );
      await tester.tap(navLabel('Đặt'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_airport.name));
      await tester.pumpAndSettle();
      // Prices open by themselves; go back to the map, then leave it.
      await tester.tap(find.byKey(const Key('ride-fare-back')));
      await tester.pumpAndSettle();
      expect(inDropoff(_airport.label), findsOneWidget);

      await tester.tap(find.byKey(const Key('ride-map-back')));
      await tester.pumpAndSettle();
      await tester.tap(navLabel('Đặt'));
      await tester.pumpAndSettle();
      expect(inDropoff('Chọn điểm đến'), findsOneWidget);
      expect(find.byKey(const Key('ride-open-pending')), findsNothing);
    });

    testWidgets('the book tab keeps the app bottom nav and shows km', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(400, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpSignedIn(
        tester,
        profile: customerProfile,
        rideClient: _negotiatingClient(),
        locationOverride: FakeLocationService(),
        places: FakePlacesRemoteDataSource(recent: [_airport]),
      );
      await tester.tap(navLabel('Đặt'));
      await tester.pumpAndSettle();
      // The destination picker opens first (full screen, above the shell).
      await tester.tap(find.text(_airport.name));
      await tester.pumpAndSettle();
      // Prices open on their own; back to the map.
      await tester.tap(find.byKey(const Key('ride-fare-back')));
      await tester.pumpAndSettle();
      expect(find.byType(DealGoTabBar), findsOneWidget);
      expect(find.byKey(const Key('ride-map-distance')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('ride-map-distance')),
          matching: find.textContaining('km'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('going back from the fare sheet keeps the draft to edit', (
      tester,
    ) async {
      await _openFare(tester, _negotiatingClient());
      await tester.tap(find.byKey(const Key('ride-fare-back')));
      await tester.pumpAndSettle();
      expect(inDropoff(_airport.label), findsOneWidget);
    });
  });

  testWidgets('the chosen vehicle and price use the border, not a check', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _openFare(tester, _negotiatingClient());
    expect(find.byIcon(DealGoIcons.check), findsNothing);
    expect(
      tester.getSemantics(find.byKey(const Key('ride-vehicle-bike'))),
      isSemantics(isButton: true, isSelected: true, hasTapAction: true),
    );
    semantics.dispose();
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

    // Pickup sits on top, the destination below it; swap is on the lower row.
    final pickupTop = tester
        .getTopLeft(find.byKey(const Key('ride-pickup-label')))
        .dy;
    final dropoffTop = tester
        .getTopLeft(find.byKey(const Key('ride-dropoff-label')))
        .dy;
    expect(pickupTop, lessThan(dropoffTop));
    expect(
      find.descendant(
        of: find.byKey(const Key('ride-dropoff-label')),
        matching: find.byIcon(DealGoIcons.swapVert),
      ),
      findsOneWidget,
    );
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

    // Destination chosen → class+fare opens automatically.
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
  // Destination chosen → class+fare opens automatically.
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
