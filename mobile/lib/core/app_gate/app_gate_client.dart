import 'package:dio/dio.dart';

import '../network/api_envelope.dart';
import '../network/dio_mapper.dart';
import 'app_gate_models.dart';

abstract interface class AppGateClient {
  Future<AppUpdateInfo> versionPolicy({
    required String platform,
    required int build,
  });
  Future<List<PendingConsent>> pendingConsents();
  Future<void> acceptConsent(String id);
}

/// Uses the shared DealGo [Dio] (auth + app build headers come from it).
class DioAppGateClient implements AppGateClient {
  DioAppGateClient({required this.dio});

  final Dio dio;

  @override
  Future<AppUpdateInfo> versionPolicy({
    required String platform,
    required int build,
  }) async {
    try {
      final res = await dio.get<Object?>(
        '/v1/app/version-policy',
        queryParameters: {'platform': platform, 'build': '$build'},
      );
      final data = asJsonMap(readSuccessPayload(res.data)) ?? const {};
      return AppUpdateInfo(
        verdict: AppUpdateInfo.parseVerdict(data['verdict']),
        latestVersion: data['latestVersion'] is String
            ? data['latestVersion']! as String
            : '',
        storeUrl: data['storeUrl'] is String ? data['storeUrl']! as String : '',
        message: data['message'] is String ? data['message']! as String : '',
      );
    } on DioException catch (e) {
      throw apiExceptionFromDio(e);
    }
  }

  @override
  Future<List<PendingConsent>> pendingConsents() async {
    try {
      final res = await dio.get<Object?>('/v1/me/legal-consents/pending');
      final data = readSuccessPayload(res.data);
      if (data is! List) return const [];
      final out = <PendingConsent>[];
      for (final item in data) {
        final m = asJsonMap(item);
        final id = m?['id'];
        final version = m?['version'];
        if (m == null || id is! String || version is! num) continue;
        final eff = m['effectiveAt'];
        out.add(
          PendingConsent(
            id: id,
            slug: m['slug'] is String ? m['slug']! as String : '',
            version: version.toInt(),
            title: m['title'] is String ? m['title']! as String : '',
            changelog: m['changelog'] is String
                ? m['changelog']! as String
                : '',
            url: m['url'] is String ? m['url']! as String : '',
            effectiveAt: eff is String ? DateTime.tryParse(eff) : null,
          ),
        );
      }
      return List.unmodifiable(out);
    } on DioException catch (e) {
      throw apiExceptionFromDio(e);
    }
  }

  @override
  Future<void> acceptConsent(String id) async {
    try {
      await dio.post<Object?>('/v1/me/legal-consents/$id/accept');
    } on DioException catch (e) {
      throw apiExceptionFromDio(e);
    }
  }
}
