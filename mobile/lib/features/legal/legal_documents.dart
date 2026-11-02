import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/network/api_envelope.dart';
import '../../core/network/api_paths.dart';
import '../onboarding/domain/entities/partner_application.dart';

export '../onboarding/domain/entities/partner_application.dart'
    show AcceptedLegalDocument;

/// pt5u: slugs of the documents a driver/shop applicant must accept.
abstract final class LegalSlug {
  static const terms = 'terms';
  static const regulations = 'regulations';
  static const privacy = 'privacy';
  static const partnerApplication = [regulations, privacy];
}

class LegalSection {
  const LegalSection({required this.title, required this.content});

  final String title;
  final String content;
}

/// One admin-managed public page (Quy chế sử dụng, privacy, ...).
class LegalDocument {
  const LegalDocument({
    required this.slug,
    required this.title,
    required this.version,
    this.summary,
    this.badge,
    this.sections = const [],
  });

  final String slug;
  final String title;
  final String? summary;
  final String? badge;
  final int version;
  final List<LegalSection> sections;

  static LegalDocument? fromJson(Map<String, Object?> json) {
    final slug = json['slug'];
    final title = json['title'];
    if (slug is! String || title is! String) return null;
    final content = asJsonMap(json['content']) ?? const {};
    final sections = content['sections'];
    final source = json['source'];
    final version = json['version'];
    return LegalDocument(
      slug: slug,
      title: title,
      summary: json['summary'] is String ? json['summary'] as String : null,
      badge: content['badge'] is String ? content['badge'] as String : null,
      // Built-in default text counts as version 0 (same rule as the server).
      version: source == 'cms' && version is num ? version.toInt() : 0,
      sections: [
        if (sections is List)
          for (final item in sections)
            if (item is Map &&
                item['title'] is String &&
                item['content'] is String)
              LegalSection(
                title: item['title'] as String,
                content: item['content'] as String,
              ),
      ],
    );
  }
}

/// pt5u: reads Quy chế sử dụng / privacy and the versions to accept.
abstract class LegalDocumentsSource {
  Future<LegalDocument> page(String slug, {String locale = 'vi'});

  Future<List<AcceptedLegalDocument>> partnerApplicationDocuments();
}

class DioLegalDocumentsSource implements LegalDocumentsSource {
  DioLegalDocumentsSource(this._dio);

  final Dio _dio;

  @override
  Future<LegalDocument> page(String slug, {String locale = 'vi'}) async {
    final response = await _dio.get<Object?>(
      ApiPaths.publicPage(slug),
      queryParameters: {'locale': locale},
    );
    final doc = LegalDocument.fromJson(requireSuccessData(response.data));
    if (doc == null) throw const FormatException('Invalid legal page');
    return doc;
  }

  @override
  Future<List<AcceptedLegalDocument>> partnerApplicationDocuments() async {
    final response = await _dio.get<Object?>(
      ApiPaths.partnerApplicationLegalDocuments,
    );
    final data = readSuccessPayload(response.data);
    if (data is! List) throw const FormatException('Invalid legal documents');
    final out = [
      for (final item in data)
        if (item is Map && item['slug'] is String && item['version'] is num)
          AcceptedLegalDocument(
            slug: item['slug'] as String,
            version: (item['version'] as num).toInt(),
          ),
    ];
    if (out.isEmpty) throw const FormatException('Empty legal documents');
    return out;
  }
}

/// Offline answer for mock mode and tests (built-in text, version 0).
class FixedLegalDocumentsSource implements LegalDocumentsSource {
  const FixedLegalDocumentsSource();

  static const _titles = {
    LegalSlug.terms: 'Điều khoản sử dụng',
    LegalSlug.regulations: 'Quy chế sử dụng dành cho tài xế và cửa hàng',
    LegalSlug.privacy: 'Chính sách bảo mật',
  };

  @override
  Future<LegalDocument> page(String slug, {String locale = 'vi'}) async =>
      LegalDocument(
        slug: slug,
        title: _titles[slug] ?? slug,
        version: 0,
        sections: const [
          LegalSection(
            title: 'Nội dung',
            content: 'Nội dung đầy đủ được tải từ máy chủ DealGo.',
          ),
        ],
      );

  @override
  Future<List<AcceptedLegalDocument>> partnerApplicationDocuments() async => [
    for (final slug in LegalSlug.partnerApplication)
      AcceptedLegalDocument(slug: slug, version: 0),
  ];
}

/// The app's source when provided above [context]; offline text otherwise.
LegalDocumentsSource legalDocumentsSourceOf(BuildContext context) {
  try {
    return RepositoryProvider.of<LegalDocumentsSource>(context);
  } on Object {
    return const FixedLegalDocumentsSource();
  }
}
