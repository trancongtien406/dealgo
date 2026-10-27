import 'dart:convert';
import 'dart:typed_data';

import 'package:dealgo/features/driver/presentation/pages/driver_ride_page.dart';
import 'package:dealgo/features/ride/data/datasources/ride_negotiation_clients.dart';
import 'package:dealgo/features/ride/data/models/ride_models.dart';
import 'package:dealgo/features/ride/domain/entities/ride_models.dart';
import 'package:dealgo/features/ride/domain/negotiation/ride_negotiation_client.dart';
import 'package:dealgo/features/ride/presentation/widgets/ride_negotiation_ui.dart';
import 'package:dealgo/l10n/app_localizations.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_l10n.dart';

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.data);

  final Object? data;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode({'success': true, 'data': data}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, Object?> _offer(String id, String status) => {
  'id': id,
  'driverId': 'drv-$id',
  'amountVnd': 50000,
  'kind': 'ACCEPT',
  'status': status,
  'expiresAt': '2030-01-01T00:00:00.000Z',
};

Map<String, Object?> _rideJson({List<Object?> offers = const []}) => {
  'id': 'ride-1',
  'status': 'NEGOTIATING',
  'pickup': {'lat': 16.05, 'lng': 108.2, 'label': 'A'},
  'dropoff': {'lat': 16.04, 'lng': 108.21, 'label': 'B'},
  'offeredFareVnd': 40000,
  'referenceFareVnd': 40000,
  'expiresAt': '2030-01-01T00:00:00.000Z',
  'offers': offers,
};

OpenRide _openRide({CustomerRatingSummary? rating}) => OpenRide(
  id: 'ride-1',
  status: 'NEGOTIATING',
  pickup: const RidePoint(lat: 16.05, lng: 108.2, label: 'Điểm đón A'),
  dropoff: const RidePoint(lat: 16.04, lng: 108.21, label: 'Điểm đến B'),
  offeredFareVnd: 40000,
  referenceFareVnd: 40000,
  expiresAt: '2030-01-01T00:00:00.000Z',
  offerCount: 0,
  customerRating: rating,
);

Widget _app(Widget child) => MaterialApp(
  locale: testLocale,
  localizationsDelegates: testLocalizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

void main() {
  group('ride models', () {
    test('DECLINED / WITHDRAWN offers parse and drop out of liveOffers', () {
      final view = RideViewModel.fromJson(
        _rideJson(
          offers: [
            _offer('o1', 'PENDING'),
            _offer('o2', 'DECLINED'),
            _offer('o3', 'WITHDRAWN'),
          ],
        ),
      ).toEntity();
      expect(view.offers.map((o) => o.status), [
        RideOfferStatus.pending,
        RideOfferStatus.declined,
        RideOfferStatus.withdrawn,
      ]);
      expect(view.liveOffers.map((o) => o.id), ['o1']);
      expect(rideOfferSelectable(view.offers[1], DateTime(2026)), isFalse);
    });

    test('customerRating summary parses on open and driver views', () {
      final open = OpenRideModel.fromJson({
        ..._rideJson(),
        'offerCount': 2,
        'customerRating': {'average': 4.6, 'count': 12},
      }).toEntity();
      expect(open.customerRating?.average, 4.6);
      expect(open.customerRating?.count, 12);

      final fresh = parseCustomerRatingSummary({'average': null, 'count': 0});
      expect(fresh?.average, isNull);
      expect(parseCustomerRatingSummary('junk'), isNull);
      expect(
        RideViewModel.fromJson(_rideJson()).toEntity().customerRating,
        isNull,
      );
    });
  });

  group('DioRideNegotiationClient', () {
    test(
      'posts each command to its negotiation path with the right body',
      () async {
        final adapter = _RecordingAdapter({'ok': true});
        final client = DioRideNegotiationClient(
          dio: Dio(BaseOptions(baseUrl: 'http://api.test'))
            ..httpClientAdapter = adapter,
        );
        await client.raiseFare(
          accessToken: 'tok',
          rideId: 'r1',
          amountVnd: 45000,
        );
        await client.declineOffer(
          accessToken: 'tok',
          rideId: 'r1',
          offerId: 'o1',
        );
        await client.withdrawOffer(accessToken: 'tok', rideId: 'r1');
        await client.driverCancel(
          accessToken: 'tok',
          rideId: 'r1',
          reason: DriverCancelReason.vehicleProblem,
        );
        await client.markNoShow(accessToken: 'tok', rideId: 'r1');
        await client.rateCustomer(
          accessToken: 'tok',
          rideId: 'r1',
          stars: 5,
          tags: const ['POLITE'],
          comment: '  ',
        );
        await client.releaseFoodOrder(
          accessToken: 'tok',
          orderId: 'f1',
          reason: FoodReleaseReason.storeTooSlow,
        );
        expect(adapter.requests.map((r) => '${r.method} ${r.path}'), [
          'POST /v1/rides/r1/fare',
          'POST /v1/rides/r1/offers/decline',
          'POST /v1/rides/r1/offers/withdraw',
          'POST /v1/rides/r1/driver-cancel',
          'POST /v1/rides/r1/no-show',
          'POST /v1/rides/r1/customer-rating',
          'POST /v1/food/orders/f1/release',
        ]);
        final bodies = adapter.requests.map((r) => r.data).toList();
        expect(bodies[0], {'amountVnd': 45000});
        expect(bodies[1], {'offerId': 'o1'});
        expect(bodies[3], {'reasonCode': 'VEHICLE_PROBLEM'});
        expect(bodies[5], {
          'stars': 5,
          'tags': ['POLITE'],
        });
        expect(bodies[6], {'reasonCode': 'STORE_TOO_SLOW'});
        expect(adapter.requests.first.headers['Authorization'], 'Bearer tok');
      },
    );

    test('reads the driver\'s customer rating (null when not rated)', () async {
      final rated = DioRideNegotiationClient(
        dio: Dio(BaseOptions(baseUrl: 'http://api.test'))
          ..httpClientAdapter = _RecordingAdapter({
            'rating': {
              'stars': 4,
              'tags': ['ON_TIME'],
              'comment': null,
              'createdAt': '2026-10-26T00:00:00.000Z',
            },
            'customer': {'average': 4.0, 'count': 1},
          }),
      );
      final entry = await rated.customerRating(accessToken: 't', rideId: 'r');
      expect(entry?.stars, 4);
      expect(entry?.tags, ['ON_TIME']);
      expect(
        parseCustomerRatingEntry({
          'rating': null,
          'customer': {'average': null, 'count': 0},
        }),
        isNull,
      );
    });
  });

  group('driver UI', () {
    testWidgets('open ride detail shows the customer rating', (tester) async {
      await tester.pumpWidget(
        _app(
          DriverRideDetailPage(
            ride: _openRide(
              rating: const CustomerRatingSummary(average: 4.6, count: 12),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('driver-customer-rating')), findsOneWidget);
      expect(find.text('4.6★ (12 lượt)'), findsOneWidget);

      await tester.pumpWidget(_app(DriverRideDetailPage(ride: _openRide())));
      await tester.pumpAndSettle();
      expect(find.text('Khách mới – chưa có đánh giá'), findsOneWidget);
    });

    testWidgets('driver cancel reason sheet returns the picked reason', (
      tester,
    ) async {
      DriverCancelReason? picked;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  picked = await showReasonSheet(
                    context: context,
                    title: AppLocalizations.of(context).driverCancelReasonTitle,
                    reasons: driverCancelReasons(AppLocalizations.of(context)),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Lý do huỷ chuyến?'), findsOneWidget);
      expect(
        find.byKey(const Key('reason-CUSTOMER_UNREACHABLE')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('reason-PICKUP_TOO_FAR')));
      await tester.pumpAndSettle();
      expect(picked, DriverCancelReason.pickupTooFar);
    });

    testWidgets('rate customer panel sends stars + tags once', (tester) async {
      final client = FakeRideNegotiationClient();
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: SingleChildScrollView(
              child: RateCustomerPanel(
                client: client,
                rideId: 'ride-9',
                accessToken: () => 'tok',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('driver-rate-star-4')));
      await tester.tap(find.byKey(const Key('driver-rate-tag-POLITE')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('driver-rate-submit')));
      await tester.pumpAndSettle();
      expect(client.calls, contains('rateCustomer:ride-9:4'));
      expect(
        find.byKey(const Key('driver-rate-customer-done')),
        findsOneWidget,
      );
      expect(find.text('Bạn đã đánh giá: 4★'), findsOneWidget);
    });
  });
}
