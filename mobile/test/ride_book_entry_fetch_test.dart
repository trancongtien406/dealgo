import 'package:dealgo/core/mock/fake_identity_client.dart';
import 'package:dealgo/features/address_book/data/datasources/address_book_remote_datasource.dart';
import 'package:dealgo/features/address_book/domain/entities/saved_address.dart';
import 'package:dealgo/features/address_book/domain/repositories/address_book_repository.dart';
import 'package:dealgo/features/places/data/places_remote_datasource.dart';
import 'package:dealgo/features/places/domain/place.dart';
import 'package:dealgo/features/ride/data/datasources/ride_stops_client_impl.dart';
import 'package:dealgo/features/ride/domain/entities/ride_models.dart';
import 'package:dealgo/features/ride/domain/stops/ride_stops_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/auth_test_harness.dart';

class _CountingPlaces implements PlacesRepository {
  _CountingPlaces(this.delegate);

  final FakePlacesRemoteDataSource delegate;
  var reverseCalls = 0;
  var recentCalls = 0;
  var historyCalls = 0;

  @override
  Future<PlaceSearchResult> search({
    required String accessToken,
    required String query,
    double? nearLat,
    double? nearLng,
  }) => delegate.search(
    accessToken: accessToken,
    query: query,
    nearLat: nearLat,
    nearLng: nearLng,
  );

  @override
  Future<PlaceOption?> reverse({
    required String accessToken,
    required double lat,
    required double lng,
  }) {
    reverseCalls++;
    return delegate.reverse(accessToken: accessToken, lat: lat, lng: lng);
  }

  @override
  Future<List<PlaceOption>> recentDestinations({required String accessToken}) {
    recentCalls++;
    return delegate.recentDestinations(accessToken: accessToken);
  }

  @override
  Future<List<PlaceOption>> history({required String accessToken}) {
    historyCalls++;
    return delegate.history(accessToken: accessToken);
  }

  @override
  Future<PlaceOption?> recordHistory({
    required String accessToken,
    required PlaceOption place,
  }) => delegate.recordHistory(accessToken: accessToken, place: place);

  @override
  Future<void> deleteHistory({
    required String accessToken,
    required String id,
  }) => delegate.deleteHistory(accessToken: accessToken, id: id);

  @override
  Future<void> clearHistory({required String accessToken}) =>
      delegate.clearHistory(accessToken: accessToken);
}

class _CountingAddressBook implements AddressBookRepository {
  _CountingAddressBook(this.delegate);

  final FakeAddressBookRemoteDataSource delegate;
  var listCalls = 0;

  @override
  Future<List<SavedAddress>> list({required String accessToken}) {
    listCalls++;
    return delegate.list(accessToken: accessToken);
  }

  @override
  Future<SavedAddress> create({
    required String accessToken,
    required SavedAddressDraft draft,
  }) => delegate.create(accessToken: accessToken, draft: draft);

  @override
  Future<SavedAddress> update({
    required String accessToken,
    required String id,
    SavedAddressDraft? draft,
    bool makeDefault = false,
  }) => delegate.update(
    accessToken: accessToken,
    id: id,
    draft: draft,
    makeDefault: makeDefault,
  );

  @override
  Future<void> remove({required String accessToken, required String id}) =>
      delegate.remove(accessToken: accessToken, id: id);
}

class _CountingStops implements RideStopsClient {
  _CountingStops(this.delegate);

  final FakeRideStopsClient delegate;
  var configCalls = 0;

  @override
  Future<MultiStopSettings> config({required String accessToken}) {
    configCalls++;
    return delegate.config(accessToken: accessToken);
  }

  @override
  Future<RideView> updateStops({
    required String accessToken,
    required String rideId,
    required List<RidePoint> stops,
    int? offeredFareVnd,
    int? routeVersion,
  }) => delegate.updateStops(
    accessToken: accessToken,
    rideId: rideId,
    stops: stops,
    offeredFareVnd: offeredFareVnd,
    routeVersion: routeVersion,
  );

  @override
  Future<RideView> arriveStop({
    required String accessToken,
    required String rideId,
    required int seq,
  }) => delegate.arriveStop(accessToken: accessToken, rideId: rideId, seq: seq);

  @override
  Future<RideView> departStop({
    required String accessToken,
    required String rideId,
    required int seq,
  }) => delegate.departStop(accessToken: accessToken, rideId: rideId, seq: seq);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('opening the book tab reads each place lookup once', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final places = _CountingPlaces(FakePlacesRemoteDataSource());
    final book = _CountingAddressBook(FakeAddressBookRemoteDataSource());
    final stops = _CountingStops(FakeRideStopsClient());

    await pumpSignedIn(
      tester,
      profile: customerProfile,
      places: places,
      addressBook: book,
      rideStopsClient: stops,
      initialLocation: '/customer',
    );

    await tester.tap(navLabel('Đặt'));
    await tester.pumpAndSettle();

    expect(places.recentCalls, 1);
    expect(book.listCalls, 1);
    expect(stops.configCalls, 1);
    expect(places.reverseCalls, 1);
    expect(places.historyCalls, 1);
  });

  testWidgets('reopening the book tab reads nothing again', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final places = _CountingPlaces(FakePlacesRemoteDataSource());
    final book = _CountingAddressBook(FakeAddressBookRemoteDataSource());
    final stops = _CountingStops(FakeRideStopsClient());

    await pumpSignedIn(
      tester,
      profile: customerProfile,
      places: places,
      addressBook: book,
      rideStopsClient: stops,
      initialLocation: '/customer',
    );
    await tester.tap(navLabel('Đặt'));
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
    router.go('/customer');
    await tester.pumpAndSettle();
    router.go('/customer/book');
    await tester.pumpAndSettle();

    expect(places.recentCalls, 1);
    expect(book.listCalls, 1);
    expect(stops.configCalls, 1);
    expect(places.reverseCalls, lessThanOrEqualTo(1));
    expect(places.historyCalls, 1);
  });

  testWidgets('abandoning a draft reads no recent destinations', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final places = _CountingPlaces(FakePlacesRemoteDataSource());
    final book = _CountingAddressBook(FakeAddressBookRemoteDataSource());
    final stops = _CountingStops(FakeRideStopsClient());

    await pumpSignedIn(
      tester,
      profile: customerProfile,
      places: places,
      addressBook: book,
      rideStopsClient: stops,
      initialLocation: '/customer',
    );
    await tester.tap(navLabel('Đặt'));
    await tester.pumpAndSettle();
    expect(places.recentCalls, 1);

    final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
    router.pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ride-map-back')));
    await tester.pumpAndSettle();

    expect(places.recentCalls, 1);
    expect(find.text('Gần đây'), findsWidgets);
  });

  testWidgets('a deleted saved address reaches the booking list at once', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final places = _CountingPlaces(FakePlacesRemoteDataSource());
    final book = _CountingAddressBook(
      FakeAddressBookRemoteDataSource(
        seed: FakeAddressBookRemoteDataSource.sample(),
      ),
    );
    final stops = _CountingStops(FakeRideStopsClient());

    await pumpSignedIn(
      tester,
      profile: customerProfile,
      places: places,
      addressBook: book,
      rideStopsClient: stops,
      initialLocation: '/customer',
    );
    await tester.tap(navLabel('Đặt'));
    await tester.pumpAndSettle();
    expect(book.listCalls, 1);

    final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
    router.go('/customer');
    await tester.pumpAndSettle();
    router.push('/customer/account/addresses');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('address-menu-addr-work')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xóa').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('address-delete-confirm')));
    await tester.pumpAndSettle();
    final beforeBooking = book.listCalls;
    router.go('/customer/book');
    await tester.pumpAndSettle();

    expect(book.listCalls, beforeBooking);
    expect(places.recentCalls, 1);
    expect(find.text('Công ty'), findsNothing);
  });
}
