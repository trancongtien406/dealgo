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
  const ContactPhoneLine({required this.phone, this.dialer, super.key});

  /// E.164 as sent by the server.
  final String phone;

  /// Test seam; defaults to `url_launcher`.
  final PhoneDialer? dialer;

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
    final display = displayVnPhone(phone);
    final label = AppLocalizations.of(context).contactPhoneDial(display);
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
