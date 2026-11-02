import 'package:dealgo/core/network/api_exception.dart';
import 'package:dealgo/features/pricing/data/pricing_remote_datasource.dart';
import 'package:dealgo/features/ride/presentation/cubit/vehicle_class_catalog_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'loads the admin catalog and finds classes case-insensitively',
    () async {
      final cubit = VehicleClassCatalogCubit(
        repository: FakePricingRemoteDataSource(),
        accessToken: () => 'token',
      );
      addTearDown(cubit.close);

      await cubit.load();

      expect(cubit.state.map((c) => c.code), ['MOTORBIKE', 'CAR_4', 'CAR_7']);
      expect(cubit.find('car_4')?.name, 'Xe 4 chỗ');
      expect(cubit.find(null), isNull);
      expect(cubit.find('BUS'), isNull);
    },
  );

  test('a failed refresh keeps the last catalog', () async {
    final pricing = FakePricingRemoteDataSource();
    final cubit = VehicleClassCatalogCubit(
      repository: pricing,
      accessToken: () => 'token',
    );
    addTearDown(cubit.close);
    await cubit.load();

    pricing.failNext = const ApiException(
      statusCode: 503,
      message: 'down',
      errorCode: 'UNAVAILABLE',
    );
    await cubit.load(force: true);

    expect(cubit.state, hasLength(3));
  });

  test('does not call the API without a session', () async {
    final pricing = FakePricingRemoteDataSource()
      ..failNext = StateError('must not be called');
    final cubit = VehicleClassCatalogCubit(
      repository: pricing,
      accessToken: () => null,
    );
    addTearDown(cubit.close);

    await cubit.load();

    expect(cubit.state, isEmpty);
    expect(pricing.failNext, isNotNull);
  });
}
