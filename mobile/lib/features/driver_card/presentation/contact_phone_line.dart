import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/design_system/icons/dealgo_icons.dart';
import '../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../identity/domain/phone_input.dart';

typedef PhoneDialer = Future<bool> Function(Uri uri);

Future<bool> _systemDialer(Uri uri) async {
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } on Object {
    return false;
  }
}

/// The other party's phone number with a dial button that hands the call to
/// the phone app (`tel:`), next to the in-app voice call.
class ContactPhoneLine extends StatelessWidget {
  const ContactPhoneLine({
    required this.phone,
    this.dialer,
    this.fullWidth = false,
    super.key,
  });

  /// E.164 as sent by the server.
  final String phone;

  /// Test seam; defaults to `url_launcher`.
  final PhoneDialer? dialer;

  /// Full-width card with caller icon, label and dial action badge.
  final bool fullWidth;

  Future<void> _dial(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final failed = AppLocalizations.of(context).contactPhoneDialFailed;
    final ok = await (dialer ?? _systemDialer)(Uri(scheme: 'tel', path: phone));
    if (!ok) {
      messenger?.showSnackBar(SnackBar(content: Text(failed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final display = displayVnPhone(phone);
    final label = l10n.contactPhoneDial(display);

    if (fullWidth) {
      return Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: Container(
          decoration: BoxDecoration(
            color: DealGoColors.subtlePurple.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(DealGoRadius.card),
            border: Border.all(
              color: DealGoColors.primary.withValues(alpha: 0.15),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: const Key('contact-phone-dial'),
            onTap: () => _dial(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DealGoSpacing.s12,
                vertical: DealGoSpacing.s8,
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: DealGoColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      DealGoIcons.phoneOutgoing,
                      size: 15,
                      color: DealGoColors.primary,
                    ),
                  ),
                  const SizedBox(width: DealGoSpacing.s8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.contactPhoneSimLabel,
                          style: textTheme.labelSmall?.copyWith(
                            color: DealGoColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          display,
                          key: const Key('contact-phone-number'),
                          style: textTheme.titleSmall?.copyWith(
                            color: DealGoColors.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DealGoSpacing.s8,
                      vertical: DealGoSpacing.s6,
                    ),
                    decoration: BoxDecoration(
                      color: DealGoColors.primary,
                      borderRadius: BorderRadius.circular(DealGoRadius.pill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.contactPhoneCallNow,
                          style: textTheme.labelSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          DealGoIcons.phone,
                          size: 12,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: DealGoColors.subtlePurple,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const Key('contact-phone-dial'),
          onTap: () => _dial(context),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 32),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DealGoSpacing.s12,
                vertical: DealGoSpacing.s4,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    DealGoIcons.phoneOutgoing,
                    size: 15,
                    color: DealGoColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      display,
                      key: const Key('contact-phone-number'),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: DealGoColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
