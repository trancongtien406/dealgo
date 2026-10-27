import 'package:dio/dio.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/network/api_paths.dart';
import '../../../core/network/dio_mapper.dart';
import '../../identity/domain/entities/app_role.dart';
import '../domain/home_banner.dart';

/// Public endpoints: no Authorization header is needed.
class DioHomeBannerRepository implements HomeBannerRepository {
  DioHomeBannerRepository({required this.dio});

  final Dio dio;

  @override
  Future<List<HomeBanner>> list({
    required AppRole role,
    double? lat,
    double? lng,
  }) async {
    try {
      final response = await dio.get<Object?>(
        ApiPaths.publicHomeBanners,
        queryParameters: {
          'role': role.grantName,
          if (lat != null && lng != null) ...{'lat': lat, 'lng': lng},
        },
      );
      return decodeHomeBanners(requireSuccessData(response.data));
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }

  @override
  Future<void> record(List<HomeBannerEvent> events) async {
    if (events.isEmpty) {
      return;
    }
    try {
      for (var i = 0; i < events.length; i += 50) {
        final end = i + 50 < events.length ? i + 50 : events.length;
        await dio.post<Object?>(
          ApiPaths.publicHomeBannerEvents,
          data: {
            'events': [for (final e in events.sublist(i, end)) e.toJson()],
          },
        );
      }
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }
}

/// Tests and mock builds: no banners unless seeded, events kept in memory.
class FakeHomeBannerRepository implements HomeBannerRepository {
  FakeHomeBannerRepository({this.banners = const [], this.error});

  final List<HomeBanner> banners;
  final Object? error;
  final List<HomeBannerEvent> recorded = [];
  int listCalls = 0;

  @override
  Future<List<HomeBanner>> list({
    required AppRole role,
    double? lat,
    double? lng,
  }) async {
    listCalls++;
    final failure = error;
    if (failure != null) {
      throw failure;
    }
    return banners;
  }

  @override
  Future<void> record(List<HomeBannerEvent> events) async {
    recorded.addAll(events);
  }
}
