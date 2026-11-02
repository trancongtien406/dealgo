import 'package:flutter/material.dart';

import '../../core/design_system/components/dealgo_card.dart';
import '../../core/design_system/tokens/dealgo_tokens.dart';
import '../../l10n/app_localizations.dart';
import 'legal_document_page.dart';
import 'legal_documents.dart';

/// pt5u: required "Quy chế sử dụng" + "Chính sách bảo mật" checkboxes on the
/// driver/shop review step. Writes the accepted versions into [consent] only
/// when both are ticked and the current versions loaded; null otherwise.
class PartnerLegalConsent extends StatefulWidget {
  const PartnerLegalConsent({super.key, required this.consent});

  final ValueNotifier<List<AcceptedLegalDocument>?> consent;

  @override
  State<PartnerLegalConsent> createState() => _PartnerLegalConsentState();
}

class _PartnerLegalConsentState extends State<PartnerLegalConsent> {
  final Set<String> _checked = {};
  List<AcceptedLegalDocument>? _documents;
  bool _failed = false;
  late LegalDocumentsSource _source;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _source = legalDocumentsSourceOf(context);
    final prior = widget.consent.value;
    if (prior != null) {
      _documents = prior;
      _checked.addAll(LegalSlug.partnerApplication);
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final docs = await _source.partnerApplicationDocuments();
      if (!mounted) return;
      setState(() => _documents = docs);
      _sync();
    } on Object {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  void _toggle(String slug, bool value) {
    setState(() => value ? _checked.add(slug) : _checked.remove(slug));
    _sync();
  }

  void _sync() {
    final docs = _documents;
    final all = LegalSlug.partnerApplication.every(_checked.contains);
    widget.consent.value = docs != null && all ? docs : null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return DealGoCard(
      key: const Key('partner-legal-consent'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.partnerConsentTitle, style: text.titleMedium),
          const SizedBox(height: DealGoSpacing.s8),
          _row(context, LegalSlug.regulations, l10n.partnerConsentRegulations),
          _row(context, LegalSlug.privacy, l10n.partnerConsentPrivacy),
          if (_failed)
            TextButton(
              key: const Key('partner-legal-consent-retry'),
              onPressed: _load,
              child: Text(l10n.partnerConsentLoadError),
            )
          else
            Text(l10n.partnerConsentHint, style: text.bodySmall),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String slug, String label) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Checkbox(
          key: Key('partner-consent-$slug'),
          value: _checked.contains(slug),
          onChanged: (v) => _toggle(slug, v ?? false),
        ),
        Expanded(
          child: GestureDetector(
            onTap: () => _toggle(slug, !_checked.contains(slug)),
            child: Text(label),
          ),
        ),
        TextButton(
          key: Key('partner-consent-view-$slug'),
          onPressed: () => LegalDocumentPage.open(context, slug),
          child: Text(l10n.partnerConsentView),
        ),
      ],
    );
  }
}
