import 'package:dealgo/core/maps/map_zoom.dart';
import 'package:dealgo/features/driver/presentation/pages/driver_food_page.dart';
import 'package:dealgo/features/food/data/food_fare_negotiation.dart';
import 'package:dealgo/features/food/presentation/pages/food_order_success_page.dart';
import 'package:dealgo/features/food/domain/entities/food_models.dart';
import 'package:flutter_test/flutter_test.dart';

FoodDeliveryOffers _offers(
  List<FoodDeliveryOfferStatus> statuses, {
  DateTime? agreedAt,
}) => FoodDeliveryOffers(
  orderId: 'o1',
  deliveryFareVnd: 19000,
  suggestedDeliveryFareVnd: 15000,
  raiseCount: 0,
  maxFareRaises: 3,
  fareStepVnd: 1000,
  maxOfferVnd: 50000,
  counterMaxVnd: 30000,
  agreedAt: agreedAt,
  offers: [
    for (final s in statuses)
      FoodDeliveryOffer(id: 'x', driverId: 'd', amountVnd: 23000, status: s),
  ],
);

void main() {
  group('withAgreedFare', () {
    const job = ReadyFoodJob(
      id: 'o1',
      storeId: 's1',
      deliveryFareVnd: 15000,
      subtotalVnd: 60000,
      totalVnd: 75000,
      dropoff: FoodDropoff(lat: 16.0, lng: 108.2, label: 'Hải Châu'),
      lineCount: 1,
    );
    test('agreed counter replaces fee and moves COD', () {
      final j = withAgreedFare(job, 16000);
      expect(j.deliveryFareVnd, 16000);
      expect(j.totalVnd, 76000);
      expect(j.subtotalVnd, 60000);
    });
    test('same or missing fare keeps the job', () {
      expect(identical(withAgreedFare(job, 15000), job), isTrue);
      expect(identical(withAgreedFare(job, 0), job), isTrue);
    });
  });
  group('map zoom limits', () {
    test('min zoom is city level, never country/world', () {
      expect(kMapMinZoom, greaterThanOrEqualTo(10));
      expect(kMapMaxZoom, lessThanOrEqualTo(20));
      expect(kMapFitMaxZoom, lessThanOrEqualTo(kMapMaxZoom));
    });
    test('clampMapZoom keeps zoom inside the range', () {
      expect(clampMapZoom(3), kMapMinZoom);
      expect(clampMapZoom(22), kMapMaxZoom);
      expect(clampMapZoom(15), 15);
    });
  });

  group('driverOfferOutcome', () {
    test('own selected offer → assigned', () {
      expect(
        driverOfferOutcome(_offers([FoodDeliveryOfferStatus.selected])),
        DriverOfferOutcome.selected,
      );
    });
    test('own offer lost → not chosen', () {
      expect(
        driverOfferOutcome(_offers([FoodDeliveryOfferStatus.lost])),
        DriverOfferOutcome.notChosen,
      );
    });
    test('fee agreed with someone else → not chosen', () {
      expect(
        driverOfferOutcome(_offers([], agreedAt: DateTime(2026))),
        DriverOfferOutcome.notChosen,
      );
    });
    test('pending or none → still open', () {
      expect(
        driverOfferOutcome(_offers([FoodDeliveryOfferStatus.pending])),
        DriverOfferOutcome.open,
      );
      expect(driverOfferOutcome(_offers([])), DriverOfferOutcome.open);
    });
  });

  test('success page hands over to tracking once past the kitchen', () {
    expect(foodSuccessShouldOpenTracking('PLACED'), isFalse);
    expect(foodSuccessShouldOpenTracking('PREPARING'), isFalse);
    for (final s in ['READY', 'ASSIGNED', 'PICKED_UP', 'CANCELLED']) {
      expect(foodSuccessShouldOpenTracking(s), isTrue);
    }
  });
}
