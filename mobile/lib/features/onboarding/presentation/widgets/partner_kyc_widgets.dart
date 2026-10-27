import 'package:flutter/material.dart';

import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/partner_application.dart';
import '../../domain/entities/partner_documents.dart';
import '../cubit/partner_document_draft.dart';
import '../document_image_source.dart';
import 'onboarding_widgets.dart';

String partnerDocumentLabel(AppLocalizations l10n, String kind) {
  return switch (kind) {
    PartnerDocumentKind.idFront => l10n.partnerKindIdFront,
    PartnerDocumentKind.idBack => l10n.partnerKindIdBack,
    PartnerDocumentKind.selfie => l10n.partnerKindSelfie,
    PartnerDocumentKind.license => l10n.partnerKindLicense,
    PartnerDocumentKind.vehicleReg => l10n.partnerKindVehicleReg,
    PartnerDocumentKind.vehicleInsurance => l10n.partnerKindVehicleInsurance,
    PartnerDocumentKind.businessLicense => l10n.partnerKindBusinessLicense,
    PartnerDocumentKind.repIdFront => l10n.partnerKindRepIdFront,
    PartnerDocumentKind.repIdBack => l10n.partnerKindRepIdBack,
    PartnerDocumentKind.storefront => l10n.partnerKindStorefront,
    _ => kind,
  };
}

String partnerSectionLabel(AppLocalizations l10n, String section) {
  return switch (section) {
    'PERSONAL' => l10n.partnerSectionPersonal,
    'ID_CARD' => l10n.partnerSectionIdCard,
    'SELFIE' => l10n.partnerSectionSelfie,
    'LICENSE' => l10n.partnerSectionLicense,
    'VEHICLE' => l10n.partnerSectionVehicle,
    'BANK' => l10n.partnerSectionBank,
    'SHOP_INFO' => l10n.partnerSectionShopInfo,
    'REPRESENTATIVE' => l10n.partnerSectionRepresentative,
    'BUSINESS_DOCS' => l10n.partnerSectionBusinessDocs,
    'STOREFRONT' => l10n.partnerSectionStorefront,
    _ => l10n.partnerSectionOther,
  };
}

String partnerSubmitErrorText(AppLocalizations l10n, String code) {
  return switch (code) {
    PartnerSubmitError.sessionExpired => l10n.partnerErrorSession,
    PartnerSubmitError.network => l10n.partnerErrorNetwork,
    PartnerSubmitError.missingDocuments => l10n.partnerErrorMissingDocs,
    'UPLOAD_TOO_LARGE' => l10n.partnerErrorTooLarge,
    'UPLOAD_TYPE_NOT_ALLOWED' ||
    'UPLOAD_TYPE_MISMATCH' => l10n.partnerErrorType,
    'STORAGE_UNAVAILABLE' => l10n.partnerErrorStorage,
    _ => l10n.partnerErrorGeneric,
  };
}

/// Formats an ISO timestamp as dd/MM/yyyy HH:mm in Vietnam time (UTC+7).
String partnerFormatTime(String iso) {
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) {
    return iso;
  }
  final t = parsed.toUtc().add(const Duration(hours: 7));
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(t.day)}/${two(t.month)}/${t.year} ${two(t.hour)}:${two(t.minute)}';
}

/// One document slot: preview, status and camera/library actions.
class PartnerDocumentSlot extends StatelessWidget {
  const PartnerDocumentSlot({
    required this.kind,
    required this.draft,
    required this.source,
    required this.onPicked,
    required this.onRemove,
    this.optional = false,
    this.frontCamera = false,
    super.key,
  });

  final String kind;
  final PartnerDocumentDraft draft;
  final DocumentImageSource source;
  final ValueChanged<PickedDocumentImage> onPicked;
  final VoidCallback onRemove;
  final bool optional;
  final bool frontCamera;

  Future<void> _pick(BuildContext context, {required bool camera}) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final image = await source.pick(camera: camera, front: frontCamera);
      if (image != null) {
        onPicked(image);
      }
    } catch (_) {
      messenger?.showSnackBar(
        SnackBar(content: Text(l10n.partnerDocPickFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final picked = draft.picked[kind];
    final flagged = draft.isFlagged(kind);
    final present = draft.has(kind);
    final (statusText, tone) = flagged
        ? (l10n.partnerDocFlagged, OnboardingBannerTone.warning)
        : picked != null
        ? (l10n.partnerDocPicked, OnboardingBannerTone.success)
        : present
        ? (l10n.partnerDocStored, OnboardingBannerTone.success)
        : (
            optional ? l10n.partnerDocOptional : l10n.partnerDocMissing,
            OnboardingBannerTone.neutral,
          );
    final borderColor = flagged
        ? DealGoColors.amber
        : present
        ? DealGoColors.brandGreen
        : DealGoColors.border;
    return Material(
      key: Key('doc-slot-$kind'),
      color: DealGoColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DealGoRadius.card),
        side: BorderSide(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DealGoSpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    partnerDocumentLabel(l10n, kind),
                    style: textTheme.titleMedium,
                  ),
                ),
                OnboardingStatusChip(label: statusText, tone: tone),
              ],
            ),
            const SizedBox(height: DealGoSpacing.s12),
            ClipRRect(
              borderRadius: BorderRadius.circular(DealGoRadius.input),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: ColoredBox(
                  color: DealGoColors.subtlePurple,
                  child: picked != null
                      ? Image.memory(
                          picked.bytes,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                          errorBuilder: (_, _, _) => const Icon(
                            DealGoIcons.addPhoto,
                            color: DealGoColors.primary,
                          ),
                        )
                      : Icon(
                          present && !flagged
                              ? DealGoIcons.successOutline
                              : DealGoIcons.camera,
                          size: 36,
                          color: present && !flagged
                              ? DealGoColors.brandGreen
                              : DealGoColors.primary,
                        ),
                ),
              ),
            ),
            const SizedBox(height: DealGoSpacing.s8),
            Text(l10n.partnerDocHint, style: textTheme.bodySmall),
            const SizedBox(height: DealGoSpacing.s12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: Key('doc-camera-$kind'),
                    onPressed: () => _pick(context, camera: true),
                    icon: const Icon(DealGoIcons.camera),
                    label: Text(
                      present ? l10n.partnerDocRetake : l10n.partnerDocTake,
                    ),
                  ),
                ),
                const SizedBox(width: DealGoSpacing.s8),
                Expanded(
                  child: OutlinedButton.icon(
                    key: Key('doc-gallery-$kind'),
                    onPressed: () => _pick(context, camera: false),
                    icon: const Icon(DealGoIcons.addPhoto),
                    label: Text(
                      l10n.partnerDocPick,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
            if (picked != null)
              TextButton.icon(
                onPressed: onRemove,
                icon: const Icon(DealGoIcons.close, size: 18),
                label: Text(l10n.partnerDocRemove),
              ),
          ],
        ),
      ),
    );
  }
}

/// Server review outcome: reason, per-section issues and fix buttons.
class PartnerReviewIssuesCard extends StatelessWidget {
  const PartnerReviewIssuesCard({
    required this.reason,
    required this.issues,
    required this.onFix,
    super.key,
  });

  final String? reason;
  final List<PartnerReviewIssue> issues;
  final ValueChanged<String> onFix;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (reason != null && reason!.trim().isNotEmpty) ...[
          Text(l10n.partnerReasonLabel, style: textTheme.titleMedium),
          const SizedBox(height: DealGoSpacing.s8),
          OnboardingInfoBanner(
            message: reason!,
            tone: OnboardingBannerTone.warning,
            icon: DealGoIcons.warning,
          ),
          const SizedBox(height: DealGoSpacing.s16),
        ],
        Text(l10n.partnerIssuesTitle, style: textTheme.titleMedium),
        const SizedBox(height: DealGoSpacing.s12),
        if (issues.isEmpty)
          OnboardingInfoBanner(message: l10n.partnerNoIssues)
        else
          for (final issue in issues) ...[
            DecoratedBox(
              decoration: BoxDecoration(
                color: DealGoColors.card,
                borderRadius: BorderRadius.circular(DealGoRadius.card),
                border: Border.all(color: DealGoColors.amber),
              ),
              child: Padding(
                padding: const EdgeInsets.all(DealGoSpacing.s16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            partnerSectionLabel(l10n, issue.section),
                            style: textTheme.titleMedium?.copyWith(
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: DealGoSpacing.s4),
                          Text(issue.note, style: textTheme.bodySmall),
                        ],
                      ),
                    ),
                    TextButton(
                      key: Key('fix-${issue.section}'),
                      onPressed: () => onFix(issue.section),
                      child: Text(l10n.partnerFix),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: DealGoSpacing.s12),
          ],
        OnboardingInfoBanner(message: l10n.partnerResubmitNote),
      ],
    );
  }
}

/// Timeline row used by the KYC/KYB status pages.
class PartnerTimelineRow extends StatelessWidget {
  const PartnerTimelineRow({
    required this.title,
    required this.subtitle,
    this.done = false,
    this.current = false,
    super.key,
  });

  final String title;
  final String subtitle;
  final bool done;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DealGoColors.card,
        borderRadius: BorderRadius.circular(DealGoRadius.card),
        border: Border.all(color: DealGoColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DealGoSpacing.s16),
        child: Row(
          children: [
            Icon(
              done
                  ? DealGoIcons.success
                  : current
                  ? DealGoIcons.clock
                  : DealGoIcons.radioOff,
              color: done ? DealGoColors.brandGreen : DealGoColors.amber,
            ),
            const SizedBox(width: DealGoSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textTheme.titleMedium?.copyWith(fontSize: 15),
                  ),
                  Text(subtitle, style: textTheme.bodySmall),
                ],
              ),
            ),
            OnboardingStatusChip(
              label: done
                  ? l10n.partnerTimelineDone
                  : current
                  ? l10n.partnerTimelineInProgress
                  : l10n.partnerTimelineWaiting,
              tone: done
                  ? OnboardingBannerTone.success
                  : OnboardingBannerTone.warning,
            ),
          ],
        ),
      ),
    );
  }
}

/// Review row: green when [ok], amber "missing" otherwise.
class PartnerReviewRow extends StatelessWidget {
  const PartnerReviewRow({
    required this.title,
    required this.subtitle,
    required this.ok,
    super.key,
  });

  final String title;
  final String subtitle;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: DealGoSpacing.s12),
      child: Row(
        children: [
          Icon(
            ok ? DealGoIcons.success : DealGoIcons.warning,
            color: ok ? DealGoColors.brandGreen : DealGoColors.amber,
          ),
          const SizedBox(width: DealGoSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.titleMedium?.copyWith(fontSize: 15),
                ),
                if (subtitle.isNotEmpty)
                  Text(subtitle, style: textTheme.bodySmall),
              ],
            ),
          ),
          OnboardingStatusChip(
            label: ok ? l10n.partnerReviewEntered : l10n.partnerReviewMissing,
            tone: ok
                ? OnboardingBannerTone.success
                : OnboardingBannerTone.warning,
          ),
        ],
      ),
    );
  }
}

/// Masks a bank account number to its last 4 digits for review screens.
String partnerMaskAccount(String digits) {
  if (digits.length <= 4) {
    return digits;
  }
  return '•••• ${digits.substring(digits.length - 4)}';
}

/// Payout bank fields shared by KYC (driver) and KYB (merchant).
class PartnerBankFields extends StatelessWidget {
  const PartnerBankFields({
    required this.bankName,
    required this.accountNumber,
    required this.holder,
    required this.onBankName,
    required this.onAccountNumber,
    required this.onHolder,
    super.key,
  });

  final String bankName;
  final String accountNumber;
  final String holder;
  final ValueChanged<String> onBankName;
  final ValueChanged<String> onAccountNumber;
  final ValueChanged<String> onHolder;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OnboardingMockField(
          label: l10n.partnerBankName,
          value: bankName,
          required: true,
          fieldKey: const Key('bank-name'),
          hint: l10n.partnerBankNameHint,
          onChanged: onBankName,
        ),
        const SizedBox(height: DealGoSpacing.s12),
        OnboardingMockField(
          label: l10n.partnerBankAccount,
          value: accountNumber,
          required: true,
          fieldKey: const Key('bank-account'),
          keyboardType: TextInputType.number,
          onChanged: onAccountNumber,
        ),
        const SizedBox(height: DealGoSpacing.s12),
        OnboardingMockField(
          label: l10n.partnerBankHolder,
          value: holder,
          required: true,
          fieldKey: const Key('bank-holder'),
          hint: l10n.partnerBankHolderHint,
          onChanged: onHolder,
        ),
        const SizedBox(height: DealGoSpacing.s16),
        OnboardingInfoBanner(
          message: l10n.partnerBankNote,
          tone: OnboardingBannerTone.neutral,
          icon: DealGoIcons.shieldPlain,
        ),
      ],
    );
  }
}
