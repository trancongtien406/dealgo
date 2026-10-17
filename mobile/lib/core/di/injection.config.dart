// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:connectivity_plus/connectivity_plus.dart' as _i895;
import 'package:dealgo/core/di/third_party_module.dart' as _i619;
import 'package:dealgo/core/location/location_service.dart' as _i417;
import 'package:dealgo/core/network/connectivity_service.dart' as _i102;
import 'package:dealgo/core/permissions/app_permission_service.dart' as _i609;
import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  _i174.GetIt init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    final thirdPartyModule = _$ThirdPartyModule();
    gh.lazySingleton<_i895.Connectivity>(() => thirdPartyModule.connectivity);
    gh.lazySingleton<_i102.ConnectivityService>(
      () => _i102.ConnectivityService(),
    );
    gh.lazySingleton<_i609.AppPermissionService>(
      () => _i609.AppPermissionService(),
    );
    gh.lazySingleton<_i417.LocationService>(
      () => _i417.LocationService(gh<_i609.AppPermissionService>()),
    );
    return this;
  }
}

class _$ThirdPartyModule extends _i619.ThirdPartyModule {}
