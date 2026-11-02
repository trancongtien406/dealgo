import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/design_system/components/dealgo_logo.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../legal/legal_document_page.dart';
import '../../../legal/legal_documents.dart';
import '../../../support/presentation/support_links.dart';
import 'auth_widgets.dart';

/// Shared shell for auth screens (S003–S004): lavender wash, soft brand
/// blobs, header (back / logo / help) and a keyboard-aware scroll body.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    required this.body,
    this.onBack,
    this.backKey,
    this.centerLogo = false,
    this.onLogoDoubleTap,
    this.padBody = true,
    super.key,
  });

  final Widget body;
  final VoidCallback? onBack;
  final Key? backKey;
  final bool centerLogo;
  final VoidCallback? onLogoDoubleTap;
  final bool padBody;

  @override
  Widget build(BuildContext context) {
    final logo = GestureDetector(
      onDoubleTap: onLogoDoubleTap,
      child: const DealGoLogo.wordmark(size: 24),
    );
    // Status bar style comes from the app-wide default (DealGoApp builder).
    return Scaffold(
      backgroundColor: DealGoColors.card,
      body: Stack(
        children: [
          const Positioned.fill(child: _AuthBackdrop()),
          SafeArea(
            child: Column(
              children: [
                SizedBox(
                  height: DealGoDimensions.headerHeight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DealGoSpacing.s4,
                    ),
                    child: Row(
                      children: [
                        if (onBack != null)
                          AuthBackButton(key: backKey, onPressed: onBack!)
                        else
                          const SizedBox(width: DealGoSpacing.s12),
                        if (centerLogo) const Spacer(),
                        logo,
                        const Spacer(),
                        const AuthHelpButton(),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: padBody
                        ? const EdgeInsets.symmetric(
                            horizontal: DealGoSpacing.s20,
                          )
                        : EdgeInsets.zero,
                    child: body,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthBackdrop extends StatelessWidget {
  const _AuthBackdrop();

  @override
  Widget build(BuildContext context) {
    Widget blob(Color color, double size) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -60,
            left: -70,
            child: blob(DealGoColors.primary.withValues(alpha: 0.06), 260),
          ),
          Positioned(
            top: 180,
            right: -80,
            child: blob(DealGoColors.brandGreen.withValues(alpha: 0.05), 230),
          ),
          Positioned(
            bottom: -60,
            left: -50,
            child: blob(DealGoColors.primary.withValues(alpha: 0.045), 220),
          ),
        ],
      ),
    );
  }
}

/// "Trợ giúp" header link: opens the admin-configured Messenger chat, or the
/// website help page when no Messenger link is set.
class AuthHelpButton extends StatelessWidget {
  const AuthHelpButton({super.key});

  Future<void> _open(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final fallback = AppLocalizations.of(context).authHelpHotline;
    if (!await openSupportMessenger(context)) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(fallback)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextButton(
      key: const Key('auth-help-btn'),
      onPressed: () => _open(context),
      child: Text(AppLocalizations.of(context).authHelp),
    );
  }
}

/// Terms / privacy links opening the full documents in-app.
class _AuthLegalLinks extends StatelessWidget {
  const _AuthLegalLinks({required this.prefix, this.alignment});

  final String prefix;
  final WrapAlignment? alignment;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final base = Theme.of(context).textTheme.bodySmall;
    final link = base?.copyWith(
      color: DealGoColors.primary,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
      decorationColor: DealGoColors.primary,
    );

    Widget linkSpan(String text, String slug) => Semantics(
      link: true,
      child: InkWell(
        key: Key('auth-legal-$slug'),
        onTap: () => LegalDocumentPage.open(context, slug),
        borderRadius: BorderRadius.circular(DealGoRadius.small),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: DealGoSpacing.s4),
          child: Text(text, style: link),
        ),
      ),
    );

    return Wrap(
      alignment: alignment ?? WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(prefix, style: base),
        linkSpan(l10n.authLegalTerms, LegalSlug.terms),
        Text(l10n.authTermsAnd, style: base),
        linkSpan(l10n.authPrivacyPolicy, LegalSlug.privacy),
        Text('.', style: base),
      ],
    );
  }
}

/// Reminder of the accepted terms on screens after the method picker.
class AuthLegalFooter extends StatelessWidget {
  const AuthLegalFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DealGoSpacing.s16),
      child: _AuthLegalLinks(
        prefix: AppLocalizations.of(context).authLegalPrefix,
      ),
    );
  }
}

/// Required "I have read and agree" checkbox; every sign-in method can create
/// an account, so the method picker stays locked until it is ticked.
class AuthLegalConsent extends StatelessWidget {
  const AuthLegalConsent({
    required this.accepted,
    required this.onChanged,
    this.showError = false,
    super.key,
  });

  final bool accepted;
  final ValueChanged<bool> onChanged;
  final bool showError;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: DealGoSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                key: const Key('auth-legal-consent'),
                value: accepted,
                isError: showError && !accepted,
                onChanged: (value) => onChanged(value ?? false),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: DealGoSpacing.s8),
                  child: _AuthLegalLinks(
                    prefix: l10n.authLegalConsentPrefix,
                    alignment: WrapAlignment.start,
                  ),
                ),
              ),
            ],
          ),
          if (showError && !accepted)
            Padding(
              padding: const EdgeInsets.only(left: DealGoSpacing.s12),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  l10n.authLegalConsentRequired,
                  key: const Key('auth-legal-consent-error'),
                  style: textTheme.bodySmall?.copyWith(
                    color: DealGoColors.danger,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Inline error / info callout under auth forms.
class AuthNotice extends StatelessWidget {
  const AuthNotice({required this.message, this.isError = true, super.key});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? DealGoColors.danger : DealGoColors.primary;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(DealGoSpacing.s12),
        decoration: BoxDecoration(
          color: isError ? DealGoColors.dangerSurface : DealGoColors.lavender,
          borderRadius: BorderRadius.circular(DealGoRadius.input),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isError ? DealGoIcons.alert : DealGoIcons.info,
              size: 18,
              color: color,
            ),
            const SizedBox(width: DealGoSpacing.s8),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: DealGoColors.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Vietnam phone input: flag + "+84" prefix and a digits-only field.
class AuthPhoneField extends StatelessWidget {
  const AuthPhoneField({
    required this.controller,
    required this.onSubmitted,
    required this.onChanged,
    this.enabled = true,
    this.errorText,
    this.autofocus = false,
    super.key,
  });

  final TextEditingController controller;
  final VoidCallback onSubmitted;
  final ValueChanged<String> onChanged;
  final bool enabled;
  final String? errorText;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return TextField(
      key: const Key('phone-field'),
      controller: controller,
      enabled: enabled,
      autofocus: autofocus,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.done,
      autofillHints: const [AutofillHints.telephoneNumberNational],
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9\s]')),
        LengthLimitingTextInputFormatter(14),
      ],
      onChanged: onChanged,
      onSubmitted: (_) => onSubmitted(),
      style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: l10n.authPhoneLabel,
        errorText: errorText,
        errorMaxLines: 3,
        prefixIcon: Padding(
          padding: const EdgeInsets.only(
            left: DealGoSpacing.s12,
            right: DealGoSpacing.s8,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _VietnamFlag(),
              const SizedBox(width: DealGoSpacing.s8),
              Text(
                '+84',
                style: textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: DealGoSpacing.s12),
              Container(width: 1, height: 22, color: DealGoColors.border),
            ],
          ),
        ),
      ),
    );
  }
}

class _VietnamFlag extends StatelessWidget {
  const _VietnamFlag();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: const BoxDecoration(
        color: Color(0xFFDA251D),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: const Text(
        '★',
        style: TextStyle(color: Color(0xFFFFE14A), fontSize: 13, height: 1),
      ),
    );
  }
}
