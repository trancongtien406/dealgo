import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_env.dart';
import '../domain/help_faq.dart';

/// Public help page on the website; its FAQs and Messenger link are managed in
/// Admin Web (Settings › Website).
Uri helpCenterWebUri(Locale locale) => Uri.https(
  appLinkHost,
  '/support',
  locale.languageCode == 'en' ? const {'lang': 'en'} : null,
);

typedef SupportLinkOpener = Future<bool> Function(Uri uri, {bool inApp});

Future<bool> _launch(Uri uri, {bool inApp = false}) async {
  if (inApp) {
    try {
      if (await launchUrl(uri, mode: LaunchMode.inAppBrowserView)) return true;
    } on Object {
      // Fall through to the system browser.
    }
  }
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } on Object {
    return false;
  }
}

/// Opens the website help page; returns false when nothing could open it.
Future<bool> openHelpCenterWeb(
  BuildContext context, {
  SupportLinkOpener open = _launch,
}) => open(helpCenterWebUri(Localizations.localeOf(context)), inApp: true);

/// Opens the admin-configured Messenger chat (Messenger app when installed);
/// falls back to the website help page when no link is set or it can't open.
Future<bool> openSupportMessenger(
  BuildContext context, {
  SupportLinkOpener open = _launch,
}) async {
  final webUri = helpCenterWebUri(Localizations.localeOf(context));
  Uri? messenger;
  try {
    messenger = await context.read<HelpFaqRepository>().messengerUrl();
  } on Object {
    messenger = null;
  }
  if (messenger != null && await open(messenger)) return true;
  return open(webUri, inApp: true);
}
