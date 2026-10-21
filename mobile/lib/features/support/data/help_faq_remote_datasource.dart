import 'package:dio/dio.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/network/api_paths.dart';
import '../../../core/network/dio_mapper.dart';
import '../domain/help_faq.dart';

class DioHelpFaqRemoteDataSource implements HelpFaqRepository {
  DioHelpFaqRemoteDataSource({required this.dio});

  final Dio dio;

  @override
  Future<List<HelpFaq>> list({required String audience}) async {
    try {
      final response = await dio.get<Object?>(
        ApiPaths.helpFaqs,
        queryParameters: {'audience': audience},
      );
      return decodeHelpFaqs(readSuccessPayload(response.data));
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }
}

List<HelpFaq> decodeHelpFaqs(Object? data) => [
  if (data is List)
    for (final raw in data)
      if (raw is Map &&
          raw['id'] is String &&
          raw['question'] is String &&
          raw['answer'] is String)
        HelpFaq(
          id: raw['id'] as String,
          question: raw['question'] as String,
          answer: raw['answer'] as String,
        ),
];

/// Mock/test help desk; empty unless seeded so screens never show invented answers.
class FakeHelpFaqRepository implements HelpFaqRepository {
  FakeHelpFaqRepository({this.items = const [], this.error});

  List<HelpFaq> items;
  Object? error;
  final calls = <String>[];

  @override
  Future<List<HelpFaq>> list({required String audience}) async {
    calls.add(audience);
    final failure = error;
    if (failure != null) {
      throw failure;
    }
    return List.unmodifiable(items);
  }
}
