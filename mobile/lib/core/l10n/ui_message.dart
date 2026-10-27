import '../../l10n/app_localizations.dart';
import 'api_error_text.dart';

/// Something a cubit wants to tell the user. Cubits have no BuildContext, so they keep the
/// cause (an error or an l10n lookup) and the widget turns it into text with [resolve].
class UiMessage {
  UiMessage(String Function(AppLocalizations l10n) text)
    : _text = text,
      error = null;

  /// A failed call: known error codes get their own sentence, otherwise [fallback] or a
  /// generic one (see [apiErrorText]).
  UiMessage.error(
    Object this.error, {
    String Function(AppLocalizations l10n)? fallback,
  }) : _text = ((l10n) =>
           apiErrorText(l10n, error, fallback: fallback?.call(l10n)));

  final String Function(AppLocalizations l10n) _text;

  /// The underlying failure, when there is one (tests and code-specific branches).
  final Object? error;

  String resolve(AppLocalizations l10n) => _text(l10n);
}
