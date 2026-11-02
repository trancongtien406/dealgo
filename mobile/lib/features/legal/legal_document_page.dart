import 'package:flutter/material.dart';

import '../../core/design_system/components/dealgo_app_header.dart';
import '../../core/design_system/components/dealgo_skeleton.dart';
import '../../core/design_system/components/dealgo_state_view.dart';
import '../../core/design_system/tokens/dealgo_tokens.dart';
import '../../l10n/app_localizations.dart';
import 'legal_documents.dart';

/// In-app reader for Điều khoản sử dụng / Chính sách bảo mật / Quy chế sử dụng.
class LegalDocumentPage extends StatefulWidget {
  const LegalDocumentPage({super.key, required this.slug, this.source});

  final String slug;
  final LegalDocumentsSource? source;

  /// Full-screen above any tab shell, so the role bottom navigation is hidden.
  static Future<void> open(BuildContext context, String slug) {
    final source = legalDocumentsSourceOf(context);
    return Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => LegalDocumentPage(slug: slug, source: source),
      ),
    );
  }

  static String fallbackTitle(AppLocalizations l10n, String slug) =>
      switch (slug) {
        LegalSlug.terms => l10n.legalTermsTitle,
        LegalSlug.privacy => l10n.legalPrivacyTitle,
        _ => l10n.legalRegulationsTitle,
      };

  @override
  State<LegalDocumentPage> createState() => _LegalDocumentPageState();
}

class _LegalDocumentPageState extends State<LegalDocumentPage> {
  Future<LegalDocument>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<LegalDocument> _load() {
    final source = widget.source ?? const FixedLegalDocumentsSource();
    return source.page(
      widget.slug,
      locale: Localizations.localeOf(context).languageCode == 'en' ? 'en' : 'vi',
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: DealGoColors.card,
      appBar: DealGoAppHeader(
        title: LegalDocumentPage.fallbackTitle(l10n, widget.slug),
        applySafeArea: true,
      ),
      body: FutureBuilder<LegalDocument>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const DealGoSkeletonList(itemCount: 4);
          }
          final doc = snap.data;
          if (doc == null) {
            return DealGoStateView.failure(
              context,
              key: const Key('legal-doc-error'),
              cause: snap.error,
              message: l10n.legalLoadError,
              onRetry: () => setState(() => _future = _load()),
            );
          }
          return ListView(
            key: Key('legal-doc-${doc.slug}'),
            padding: EdgeInsets.fromLTRB(
              DealGoDimensions.pageGutter,
              DealGoSpacing.s16,
              DealGoDimensions.pageGutter,
              DealGoSpacing.s24 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              Text(doc.title, style: text.titleLarge),
              if (doc.summary != null && doc.summary!.isNotEmpty) ...[
                const SizedBox(height: DealGoSpacing.s8),
                Text(doc.summary!, style: text.bodyMedium),
              ],
              for (final section in doc.sections) ...[
                const SizedBox(height: DealGoSpacing.s16),
                Text(section.title, style: text.titleMedium),
                const SizedBox(height: DealGoSpacing.s8),
                Text(section.content, style: text.bodyMedium),
              ],
            ],
          );
        },
      ),
    );
  }
}
