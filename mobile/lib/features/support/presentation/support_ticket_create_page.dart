import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design_system/components/dealgo_card.dart';
import '../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../core/design_system/components/dealgo_text_field.dart';
import '../../../core/design_system/icons/dealgo_icons.dart';
import '../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../core/drafts/text_draft.dart';
import '../../../core/format/short_ref.dart';
import '../../../core/motion/dealgo_sheet.dart';
import '../../../core/network/api_exception.dart';
import '../../../l10n/app_localizations.dart';
import '../../activity/domain/entities/history_models.dart';
import '../../activity/domain/usecases/list_food_history.dart';
import '../../activity/domain/usecases/list_ride_history.dart';
import '../../identity/domain/entities/auth_state.dart';
import '../../identity/presentation/cubit/auth_cubit.dart';
import '../domain/support_ticket.dart';
import '../../onboarding/presentation/document_image_source.dart';
import 'support_attachments.dart';
import 'support_copy.dart';
import '../../../core/design_system/components/dealgo_app_header.dart';

/// S021 — create a support request. Pops `true` once the backend stored it.
class SupportTicketCreatePage extends StatefulWidget {
  const SupportTicketCreatePage({
    required this.shellPath,
    this.initialCategory,
    super.key,
  });

  final String shellPath;
  final SupportCategory? initialCategory;

  @override
  State<SupportTicketCreatePage> createState() =>
      _SupportTicketCreatePageState();
}

class _SupportTicketCreatePageState extends State<SupportTicketCreatePage>
    with TextDraftMixin {
  final _subject = TextEditingController();
  final _description = TextEditingController();
  late SupportCategory _category =
      widget.initialCategory ?? SupportCategory.ride;
  HistoryItem? _related;
  var _submitting = false;
  String? _subjectError;
  String? _descriptionError;
  String? _formError;
  var _photos = <PickedDocumentImage>[];

  bool get _canLinkJobs => supportRoleForShell(widget.shellPath) == 'CUSTOMER';

  String? get _token {
    final auth = context.read<AuthCubit>().state;
    return auth is AuthSignedIn ? auth.tokens.accessToken : null;
  }

  @override
  void initState() {
    super.initState();
    // Typed request survives an app kill; cleared once the ticket is stored.
    bindTextDraft('support.${supportRoleForShell(widget.shellPath)}', {
      'subject': _subject,
      'description': _description,
    });
  }

  @override
  void dispose() {
    _subject.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickCategory() async {
    final l10n = AppLocalizations.of(context);
    final picked = await showDealGoSheet<SupportCategory>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final category in SupportCategory.values)
              ListTile(
                key: Key('support-category-${category.name}'),
                leading: Icon(supportCategoryIcon(category)),
                title: Text(supportCategoryLabel(l10n, category)),
                trailing: category == _category
                    ? const Icon(DealGoIcons.check, color: DealGoColors.primary)
                    : null,
                onTap: () => Navigator.of(context).pop(category),
              ),
          ],
        ),
      ),
    );
    if (picked != null && mounted) {
      setState(() => _category = picked);
    }
  }

  Future<void> _pickRelated() async {
    final token = _token;
    if (token == null) return;
    final l10n = AppLocalizations.of(context);
    final rides = context.read<ListRideHistory>();
    final food = context.read<ListFoodHistory>();
    List<HistoryItem> items;
    try {
      final results = await Future.wait([rides(token), food(token)]);
      items = [...results[0], ...results[1]];
    } on ApiException {
      items = const [];
    }
    if (!mounted) return;
    final picked = await showDealGoSheet<Object>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.7,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.all(DealGoSpacing.s16),
                child: Text(
                  l10n.supportRelatedPickTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              ListTile(
                key: const Key('support-related-none'),
                leading: const Icon(DealGoIcons.help),
                title: Text(l10n.supportRelatedNone),
                onTap: () => Navigator.of(context).pop(false),
              ),
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(DealGoSpacing.s16),
                  child: Text(l10n.supportRelatedEmpty),
                ),
              for (final item in items.take(20))
                ListTile(
                  key: Key('support-related-${item.id}'),
                  leading: Icon(
                    item.kind == HistoryKind.ride
                        ? DealGoIcons.car
                        : DealGoIcons.restaurant,
                  ),
                  title: Text(item.title),
                  subtitle: Text('${shortRef(item.id)} · ${item.meta}'),
                  onTap: () => Navigator.of(context).pop(item),
                ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || picked == null) return;
    setState(() {
      if (picked is HistoryItem) {
        _related = picked;
        if (_category == SupportCategory.ride ||
            _category == SupportCategory.food) {
          _category = picked.kind == HistoryKind.ride
              ? SupportCategory.ride
              : SupportCategory.food;
        }
      } else {
        _related = null;
      }
    });
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final subject = _subject.text.trim();
    final description = _description.text.trim();
    setState(() {
      _subjectError = subject.length < 3 ? l10n.supportSubjectTooShort : null;
      _descriptionError = description.length < 10
          ? l10n.supportDescriptionTooShort
          : null;
      _formError = null;
    });
    final token = _token;
    if (_subjectError != null || _descriptionError != null || token == null) {
      return;
    }
    final related = _related;
    setState(() => _submitting = true);
    try {
      await context.read<SupportRepository>().create(
        accessToken: token,
        ticket: NewSupportTicket(
          category: _category,
          subject: subject,
          description: description,
          role: supportRoleForShell(widget.shellPath),
          relatedType: related == null
              ? null
              : related.kind == HistoryKind.ride
              ? SupportRelatedType.ride
              : SupportRelatedType.foodOrder,
          relatedId: related?.id,
          attachments: supportUploads(_photos),
        ),
      );
      clearTextDraft();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.supportCreated)));
      context.pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _formError =
            supportUploadErrorText(l10n, error) ??
            switch (error.errorCode) {
              'SUPPORT_TICKET_LIMIT_REACHED' => l10n.supportLimitReached,
              'SUPPORT_TEXT_TOO_LONG' => l10n.supportTextTooLong,
              _ => l10n.supportSendFailed,
            };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final related = _related;
    return Scaffold(
      backgroundColor: DealGoColors.canvas,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DealGoAppHeader(title: l10n.supportCreateTitle),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  DealGoDimensions.pageGutter,
                  DealGoSpacing.s16,
                  DealGoDimensions.pageGutter,
                  DealGoSpacing.s16,
                ),
                children: [
                  Text(
                    l10n.supportCreateHeading,
                    style: textTheme.headlineSmall,
                  ),
                  const SizedBox(height: DealGoSpacing.s20),
                  _PickerField(
                    fieldKey: const Key('support-category-field'),
                    label: l10n.supportFieldCategory,
                    value: supportCategoryLabel(l10n, _category),
                    onTap: _pickCategory,
                  ),
                  if (_canLinkJobs) ...[
                    const SizedBox(height: DealGoSpacing.s16),
                    _PickerField(
                      fieldKey: const Key('support-related-field'),
                      label: l10n.supportFieldRelated,
                      value: related == null
                          ? l10n.supportRelatedNone
                          : '${shortRef(related.id)} · ${related.title}',
                      onTap: _pickRelated,
                    ),
                  ],
                  const SizedBox(height: DealGoSpacing.s16),
                  DealGoTextField(
                    fieldKey: const Key('support-subject'),
                    label: l10n.supportFieldSubject,
                    controller: _subject,
                    maxLength: 120,
                    errorText: _subjectError,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: DealGoSpacing.s8),
                  DealGoTextField(
                    fieldKey: const Key('support-description'),
                    label: l10n.supportFieldDescription,
                    controller: _description,
                    maxLines: 5,
                    maxLength: 2000,
                    errorText: _descriptionError,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  if (supportImageSource(context) case final source?) ...[
                    Text(l10n.supportAttachTitle, style: textTheme.labelLarge),
                    const SizedBox(height: DealGoSpacing.s4),
                    SupportAttachmentPicker(
                      source: source,
                      picked: _photos,
                      enabled: !_submitting,
                      onChanged: (next) => setState(() => _photos = next),
                    ),
                  ],
                  const SizedBox(height: DealGoSpacing.s12),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: DealGoColors.subtlePurple,
                      borderRadius: BorderRadius.circular(DealGoRadius.input),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(DealGoSpacing.s12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            DealGoIcons.shield,
                            size: 18,
                            color: DealGoColors.primary,
                          ),
                          const SizedBox(width: DealGoSpacing.s8),
                          Expanded(
                            child: Text(
                              l10n.supportPrivacyNote,
                              style: textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DealGoDimensions.pageGutter,
                DealGoSpacing.s8,
                DealGoDimensions.pageGutter,
                DealGoSpacing.s12,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_formError != null) ...[
                    Text(
                      _formError!,
                      key: const Key('support-form-error'),
                      style: textTheme.bodySmall?.copyWith(
                        color: DealGoColors.danger,
                      ),
                    ),
                    const SizedBox(height: DealGoSpacing.s8),
                  ],
                  DealGoPrimaryButton(
                    key: const Key('support-submit'),
                    label: l10n.supportSubmit,
                    isLoading: _submitting,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.fieldKey,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final Key fieldKey;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: textTheme.labelLarge),
        const SizedBox(height: DealGoSpacing.s8),
        DealGoCard(
          key: fieldKey,
          onTap: onTap,
          child: Row(
            children: [
              Expanded(child: Text(value, style: textTheme.bodyMedium)),
              const Icon(
                DealGoIcons.chevronRight,
                color: DealGoColors.textSecondary,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
