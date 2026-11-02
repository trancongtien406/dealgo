import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design_system/icons/dealgo_icons.dart';
import '../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../core/network/api_exception.dart';
import '../../../l10n/app_localizations.dart';
import '../../identity/domain/entities/auth_state.dart';
import '../../identity/presentation/cubit/auth_cubit.dart';
import '../../onboarding/presentation/document_image_source.dart';
import '../domain/support_ticket.dart';

/// Photo source for the composer, or null when the app did not provide one.
DocumentImageSource? supportImageSource(BuildContext context) {
  try {
    return RepositoryProvider.of<DocumentImageSource>(context);
  } on Object {
    return null;
  }
}

List<SupportUpload> supportUploads(List<PickedDocumentImage> picked) => [
  for (final (i, image) in picked.indexed)
    SupportUpload(
      label: 'photo-${i + 1}',
      contentType: image.contentType,
      contentBase64: image.contentBase64,
    ),
];

/// Upload error codes from DocumentStoreService (DEC-PROD-020), or null.
String? supportUploadErrorText(AppLocalizations l10n, ApiException error) =>
    switch (error.errorCode) {
      'UPLOAD_TOO_LARGE' => l10n.supportAttachTooLarge,
      'UPLOAD_TYPE_NOT_ALLOWED' ||
      'UPLOAD_TYPE_MISMATCH' => l10n.supportAttachBadType,
      'STORAGE_UNAVAILABLE' => l10n.supportAttachUnavailable,
      _ => null,
    };

/// Up to [supportMaxAttachments] photos picked from camera or gallery.
class SupportAttachmentPicker extends StatelessWidget {
  const SupportAttachmentPicker({
    required this.source,
    required this.picked,
    required this.onChanged,
    this.enabled = true,
    this.compact = false,
    super.key,
  });

  final DocumentImageSource source;
  final List<PickedDocumentImage> picked;
  final ValueChanged<List<PickedDocumentImage>> onChanged;
  final bool enabled;
  final bool compact;

  Future<void> _add(BuildContext context, {required bool camera}) async {
    final image = await source.pick(camera: camera);
    if (image != null && picked.length < supportMaxAttachments) {
      onChanged([...picked, image]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final full = picked.length >= supportMaxAttachments || !enabled;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (picked.isNotEmpty) ...[
          Wrap(
            spacing: DealGoSpacing.s8,
            runSpacing: DealGoSpacing.s8,
            children: [
              for (final (i, image) in picked.indexed)
                Stack(
                  key: Key('support-attach-thumb-$i'),
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(DealGoRadius.input),
                      child: Image.memory(
                        image.bytes,
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: 64,
                          height: 64,
                          color: DealGoColors.subtlePurple,
                          child: const Icon(DealGoIcons.camera),
                        ),
                      ),
                    ),
                    Positioned(
                      right: -8,
                      top: -8,
                      child: IconButton(
                        key: Key('support-attach-remove-$i'),
                        tooltip: l10n.supportAttachRemove,
                        visualDensity: VisualDensity.compact,
                        iconSize: 14,
                        style: IconButton.styleFrom(
                          backgroundColor: DealGoColors.card,
                          foregroundColor: DealGoColors.text,
                          side: BorderSide(color: DealGoColors.border),
                        ),
                        onPressed: enabled
                            ? () => onChanged([...picked]..removeAt(i))
                            : null,
                        icon: const Icon(DealGoIcons.close),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: DealGoSpacing.s8),
        ],
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: DealGoSpacing.s4,
          children: [
            TextButton.icon(
              key: const Key('support-attach-camera'),
              onPressed: full ? null : () => _add(context, camera: true),
              icon: const Icon(DealGoIcons.camera, size: 18),
              label: Text(l10n.supportAttachCamera),
            ),
            TextButton.icon(
              key: const Key('support-attach-gallery'),
              onPressed: full ? null : () => _add(context, camera: false),
              icon: const Icon(DealGoIcons.image, size: 18),
              label: Text(l10n.supportAttachGallery),
            ),
            if (!compact)
              Text(
                l10n.supportAttachCount(picked.length, supportMaxAttachments),
                style: textTheme.labelSmall,
              ),
          ],
        ),
      ],
    );
  }
}

/// Attachment chips under a message; tapping an image opens it.
class SupportAttachmentList extends StatelessWidget {
  const SupportAttachmentList({
    required this.ticketId,
    required this.message,
    super.key,
  });

  final String ticketId;
  final SupportMessage message;

  Future<void> _open(BuildContext context, SupportAttachment attachment) async {
    final l10n = AppLocalizations.of(context);
    final auth = context.read<AuthCubit>().state;
    final messenger = ScaffoldMessenger.of(context);
    if (!attachment.isImage) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.supportAttachPdfNote)),
      );
      return;
    }
    if (auth is! AuthSignedIn) return;
    try {
      final bytes = await context.read<SupportRepository>().attachment(
        accessToken: auth.tokens.accessToken,
        ticketId: ticketId,
        messageId: message.id,
        index: attachment.index,
      );
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog(
          key: const Key('support-attach-preview'),
          child: InteractiveViewer(
            child: Image.memory(
              bytes,
              errorBuilder: (_, _, _) => Padding(
                padding: const EdgeInsets.all(DealGoSpacing.s24),
                child: Text(l10n.supportAttachOpenFailed),
              ),
            ),
          ),
        ),
      );
    } on ApiException {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.supportAttachOpenFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: DealGoSpacing.s8,
      runSpacing: DealGoSpacing.s4,
      children: [
        for (final attachment in message.attachments)
          ActionChip(
            key: Key('support-attachment-${message.id}-${attachment.index}'),
            avatar: Icon(
              attachment.isImage ? DealGoIcons.image : DealGoIcons.document,
              size: 16,
            ),
            label: Text(
              attachment.isImage
                  ? l10n.supportAttachPhoto(attachment.index + 1)
                  : l10n.supportAttachFile(attachment.index + 1),
            ),
            onPressed: () => _open(context, attachment),
          ),
      ],
    );
  }
}
