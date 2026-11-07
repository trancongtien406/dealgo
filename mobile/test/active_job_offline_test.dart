import 'package:dealgo/core/auth/token_store.dart';
import 'package:dealgo/core/network/api_exception.dart';
import 'package:dealgo/features/active_job/data/active_job_snapshot_store.dart';
import 'package:dealgo/features/active_job/domain/active_job_snapshot.dart';
import 'package:dealgo/features/active_job/presentation/active_job_cache.dart';
import 'package:dealgo/features/driver_card/domain/driver_card.dart';
import 'package:dealgo/features/identity/data/models/user_profile_model.dart';
import 'package:dealgo/features/identity/data/profile_cache.dart';
import 'package:dealgo/features/identity/data/repositories/identity_repository_impl.dart';
import 'package:dealgo/features/identity/domain/entities/app_role.dart';
import 'package:dealgo/features/identity/domain/entities/auth_state.dart';
import 'package:dealgo/features/identity/domain/usecases/fetch_me.dart';
import 'package:dealgo/features/identity/presentation/cubit/auth_cubit.dart';
import 'package:dealgo/features/ride/data/datasources/customer_active_trip_client.dart';
import 'package:dealgo/features/ride/presentation/utils/customer_trip_resumer.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_identity_client.dart';

const _driver = DriverCard(
  driverId: 'd1',
  displayName: 'Lê Văn Tài',
  vehicleName: 'Honda Vision',
  vehiclePlate: '43B1-678.90',
  phone: '+84901234567',
);

ActiveJobSnapshot _ride({
  String id = 'r1',
  String status = 'DRIVER_EN_ROUTE',
  String? code = '4821',
}) => ActiveJobSnapshot(
  kind: ActiveJobKind.ride,
  id: id,
  status: status,
  savedAt: DateTime(2026),
  pickupLabel: 'Hải Châu',
  dropoffLabel: 'Sân bay',
  amountVnd: 45000,
  code: code,
);

void main() {
  group('ActiveJobCache', () {
    late DateTime now;
    late MemoryActiveJobSnapshotStore store;
    late ActiveJobCache cache;

    setUp(() {
      now = DateTime(2026, 11, 1, 14, 30);
      store = MemoryActiveJobSnapshotStore();
      cache = ActiveJobCache(store: store, clock: () => now)..bindUser('u1');
    });

    test('keeps the running job with its driver phone and code', () async {
      await cache.recordJob(_ride(), terminal: false, assignedDriverId: 'd1');
      await cache.recordDriver(
        kind: ActiveJobKind.ride,
        jobId: 'r1',
        card: _driver,
      );
      await cache.recordJob(
        _ride(status: 'DRIVER_ARRIVED'),
        terminal: false,
        assignedDriverId: 'd1',
      );

      final saved = await cache.lookup(id: 'r1');
      expect(saved?.status, 'DRIVER_ARRIVED');
      expect(saved?.savedAt, now);
      expect(saved?.driver?.phone, '+84901234567');
      expect(saved?.code, '4821');
      expect(store.value?.userId, 'u1');
      expect(await cache.lookup(id: 'other'), isNull);
    });

    test('drops a driver that is no longer assigned', () async {
      await cache.recordJob(_ride(), terminal: false, assignedDriverId: 'd1');
      await cache.recordDriver(
        kind: ActiveJobKind.ride,
        jobId: 'r1',
        card: _driver,
      );
      await cache.recordJob(
        _ride(status: 'NEGOTIATING'),
        terminal: false,
        assignedDriverId: null,
      );
      expect((await cache.lookup())?.driver, isNull);
    });

    test('a finished job loses phone and code, then expires', () async {
      await cache.recordJob(_ride(), terminal: false, assignedDriverId: 'd1');
      await cache.recordDriver(
        kind: ActiveJobKind.ride,
        jobId: 'r1',
        card: _driver,
      );
      await cache.recordJob(
        _ride(status: 'COMPLETED'),
        terminal: true,
        assignedDriverId: 'd1',
      );

      final ended = await cache.lookup();
      expect(ended?.ended, isTrue);
      expect(ended?.driver?.displayName, 'Lê Văn Tài');
      expect(ended?.driver?.phone, isNull);
      expect(ended?.code, isNull);
      expect(store.value?.snapshot.driver?.phone, isNull);

      now = now.add(const Duration(minutes: 31));
      expect(await cache.lookup(), isNull);
      expect(store.value, isNull);
    });

    test('an old finished job never replaces the running one', () async {
      await cache.recordJob(_ride(), terminal: false, assignedDriverId: 'd1');
      await cache.recordJob(
        _ride(id: 'old', status: 'COMPLETED'),
        terminal: true,
        assignedDriverId: 'd9',
      );
      expect((await cache.lookup())?.id, 'r1');
    });

    test('expires six hours after the last server copy', () async {
      await cache.recordJob(_ride(), terminal: false, assignedDriverId: null);
      now = now.add(const Duration(hours: 6, minutes: 1));
      expect(await cache.lookup(), isNull);
    });

    test('is private to its user and wiped by clear()', () async {
      await cache.recordJob(_ride(), terminal: false, assignedDriverId: null);
      final other = ActiveJobCache(store: store, clock: () => now)
        ..bindUser('u2');
      expect(await other.lookup(), isNull);
      cache.bindUser(null);
      expect(await cache.lookup(), isNull);

      cache.bindUser('u1');
      expect((await cache.lookup())?.id, 'r1');
      await cache.clear();
      expect(store.value, isNull);
    });

    test('clearIfMatches does not erase a newer job', () async {
      await cache.recordJob(_ride(), terminal: false, assignedDriverId: null);
      await cache.clearIfMatches('old-id');
      expect((await cache.lookup())?.id, 'r1');

      await cache.clearIfMatches('r1');
      expect(await cache.lookup(), isNull);
      expect(store.value, isNull);
    });

    test('survives a JSON round trip', () {
      final snapshot = _ride().withDriver(_driver);
      final decoded = ActiveJobSnapshot.fromJson(snapshot.toJson());
      expect(decoded?.id, 'r1');
      expect(decoded?.driver?.phone, '+84901234567');
      expect(decoded?.driver?.vehicleLine, 'Honda Vision · 43B1-678.90');
      expect(decoded?.code, '4821');
      expect(ActiveJobSnapshot.fromJson({'kind': 'X'}), isNull);
    });
  });

  group('AuthCubit offline restore', () {
    const tokens = StoredTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token-1234567890',
    );

    AuthCubit make(FakeIdentityClient identity, ProfileCache cache) {
      final repo = IdentityRepositoryImpl(identity);
      return AuthCubit(
        fetchMe: FetchMe(repo),
        tokens: MemoryTokenStore(tokens),
        identityRepository: repo,
        profileCache: cache,
      );
    }

    test('keeps the session on the cached profile without network', () async {
      final cache = MemoryProfileCache(customerProfile);
      final identity = _MeFails(
        const ApiException(
          statusCode: 0,
          message: 'Network error',
          errorCode: 'NETWORK_ERROR',
        ),
      );
      final auth = make(identity, cache);
      await auth.restore();
      expect(auth.state, isA<AuthSignedIn>());
      expect((auth.state as AuthSignedIn).profile.id, customerProfile.id);
    });

    test('still signs out on 401 and forgets the profile', () async {
      final cache = MemoryProfileCache(customerProfile);
      final identity = _MeFails(
        const ApiException(
          statusCode: 401,
          message: 'Authentication required',
          errorCode: 'UNAUTHORIZED',
        ),
      );
      final auth = make(identity, cache);
      await auth.restore();
      expect(auth.state, isA<AuthSignedOut>());
      expect(cache.value, isNull);
    });

    test('remembers the profile after an online restore', () async {
      final cache = MemoryProfileCache();
      final auth = make(FakeIdentityClient(), cache);
      await auth.restore();
      await Future<void>.delayed(Duration.zero);
      expect(auth.state, isA<AuthSignedIn>());
      expect(cache.value?.id, customerProfile.id);
    });
  });

  test('resume opens the saved trip when the lookup fails', () async {
    final source = FakeCustomerActiveTripSource()..failures = 1;
    final routes = <String>[];
    final resumer = CustomerTripResumer(
      source: source,
      navigate: routes.add,
      currentLocation: () => '/customer/home',
      baseDelay: const Duration(milliseconds: 1),
      cachedRoute: () async => '/customer/ride/tracking/r1',
    );
    await resumer.onSignedIn(
      userId: 'u1',
      roles: const [AppRole.customer],
      profileDone: true,
    );
    expect(routes, ['/customer/ride/tracking/r1']);
    resumer.reset();
  });
}

class _MeFails extends FakeIdentityClient {
  _MeFails(this.error);

  final ApiException error;

  @override
  Future<UserProfileModel> fetchMe(String accessToken) async => throw error;
}
