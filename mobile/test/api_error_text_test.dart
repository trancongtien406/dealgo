import 'package:dealgo/core/l10n/api_error_text.dart';
import 'package:dealgo/core/l10n/ui_message.dart';
import 'package:dealgo/core/network/api_exception.dart';
import 'package:dealgo/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final vi = lookupAppLocalizations(const Locale('vi'));
  final en = lookupAppLocalizations(const Locale('en'));

  ApiException err(int status, String code) =>
      ApiException(statusCode: status, message: 'English server text', errorCode: code);

  test('known codes get their own sentence in both languages', () {
    expect(apiErrorText(vi, err(409, 'FOOD_ALREADY_ASSIGNED')), vi.apiErrJobTaken);
    expect(apiErrorText(en, err(422, 'VOUCHER_MIN_ORDER')), en.apiErrVoucherMinOrder);
    expect(apiErrorText(vi, err(0, 'NETWORK_ERROR')), vi.apiErrNetwork);
  });

  test('unknown codes fall back by status and never echo server text', () {
    for (final status in [400, 401, 403, 404, 409, 429, 500, 503]) {
      final text = apiErrorText(vi, err(status, 'SOMETHING_NEW'));
      expect(text, isNot(contains('English server text')));
      expect(text, isNotEmpty);
    }
    expect(apiErrorText(vi, err(401, 'X')), vi.errorSessionExpired);
    expect(apiErrorText(vi, err(503, 'X')), vi.apiErrServer);
  });

  test('fallback is used for non-API failures and unmapped 4xx', () {
    expect(apiErrorText(vi, StateError('x'), fallback: 'F'), 'F');
    expect(apiErrorText(vi, err(400, 'X'), fallback: 'F'), 'F');
    expect(apiErrorText(vi, StateError('x')), vi.apiErrGeneric);
  });

  test('UiMessage resolves keys and errors per locale', () {
    final keyed = UiMessage((l10n) => l10n.errorSessionExpired);
    expect(keyed.resolve(en), en.errorSessionExpired);
    final failed = UiMessage.error(err(404, 'RIDE_NOT_FOUND'));
    expect(failed.resolve(vi), vi.apiErrRideNotFound);
    expect(failed.error, isA<ApiException>());
  });
}
